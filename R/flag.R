# ── Status helpers ────────────────────────────────────────────────────────────

#' Roll up a vector of status strings to a single status
#'
#' Priority: `flag > no_flag > insufficient_evidence > no_data`. A mix of
#' `no_flag` and `no_data` (or `insufficient_evidence`) collapses to
#' `insufficient_evidence`.
#'
#' @param statuses A character vector of status values.
#' @return A single status string.
#' @export
rollup_statuses <- function(statuses) {
  if (length(statuses) == 0L)          return("no_data")
  if (any(statuses == "flag"))          return("flag")
  if (all(statuses == "no_data"))       return("no_data")
  if (all(statuses == "no_flag"))       return("no_flag")
  "insufficient_evidence"
}

#' Evaluate flag status for a single threshold group
#'
#' @param flag_n    Number of metrics with status `"flag"`.
#' @param no_flag_n Number of metrics with status `"no_flag"`.
#' @param data_n    Total metrics with any data (`flag_n + no_flag_n`).
#' @param factor_threshold   Minimum flag count to declare `"flag"`.
#' @param evidence_threshold Minimum data count to declare `"no_flag"`.
#' @return A single status string.
#' @export
evaluate_group_status <- function(flag_n, no_flag_n, data_n,
                                  factor_threshold, evidence_threshold) {
  if (flag_n >= factor_threshold) return("flag")
  if (data_n == 0L)               return("no_data")
  if (data_n >= evidence_threshold) return("no_flag")
  "insufficient_evidence"
}

# ── Prelim-flag decision tree ─────────────────────────────────────────────────

#' Apply the ANA prelim-flag decision tree to system-level statuses
#'
#' @param system_statuses  A tibble with columns `uoa`, `system_id`,
#'   `system_status`.
#' @param mortality_id     System ID for the mortality system (step 1 — EM).
#' @param ho_id            System ID for the health-outcomes system (step 2 —
#'   ROEM).
#' @param classification_ids Character vector of system IDs that form the
#'   classification set (excludes `mortality_id` and `market_functionality`).
#' @return A tibble with columns `uoa` and `prelim_flag`.
#' @export
compute_prelim_flags <- function(system_statuses, mortality_id, ho_id,
                                 classification_ids) {
  system_statuses |>
    dplyr::group_by(uoa) |>
    dplyr::summarise(
      mortality_flag = any(system_id == mortality_id &
                             system_status == "flag"),
      ho_flag        = any(system_id == ho_id &
                             system_status == "flag"),
      n_other_classif_flagged = sum(
        system_id != ho_id &
          system_id %in% classification_ids &
          system_status == "flag"
      ),
      any_classif_flagged = any(
        system_id %in% classification_ids & system_status == "flag"
      ),
      any_insuff  = any(system_status == "insufficient_evidence"),
      all_no_data = all(system_status == "no_data"),
      .groups = "drop"
    ) |>
    dplyr::mutate(
      prelim_flag = dplyr::case_when(
        mortality_flag                            ~ "em",
        ho_flag & n_other_classif_flagged >= 3L   ~ "roem",
        any_classif_flagged                       ~ "acute",
        all_no_data                               ~ "no_data",
        any_insuff                                ~ "insufficient_evidence",
        TRUE                                      ~ "acute_needs"
      )
    ) |>
    dplyr::select(uoa, prelim_flag)
}

# ── Main pipeline ─────────────────────────────────────────────────────────────

#' Flag a data frame of metric values against the ANA reference
#'
#' Applies the five-stage flagging pipeline:
#' 1. Per-metric flag / status / within-10-percent columns
#' 2. Subfactor-level status (threshold-group rollup)
#' 3. Factor-level status
#' 4. System-level status
#' 5. Preliminary flag (`prelim_flag`) via ANA decision tree
#'
#' Preference-3 metrics are excluded from all flagging stages.
#'
#' @param df  A `data.frame` or tibble with one row per unit of analysis (UOA)
#'   and one column per metric (e.g. `MET001`). A `uoa` column is expected but
#'   not strictly required by this function — extra columns are passed through.
#' @param ref The reference list returned by [get_default_reference()].
#' @return A tibble with the original columns plus metric-, subfactor-, factor-,
#'   system-, and `prelim_flag` columns appended.
#' @export
flag_data <- function(df, ref) {
  if (nrow(df) == 0L) return(tibble::as_tibble(df))

  sys_ids <- vapply(ref$systems, `[[`, "", "id")
  if (!"mortality" %in% sys_ids) {
    cli::cli_abort("Reference must include a {.val mortality} system.")
  }
  if (!"health_outcomes" %in% sys_ids) {
    cli::cli_abort("Reference must include a {.val health_outcomes} system.")
  }

  meta      <- build_metric_meta_df(ref)
  flag_meta <- meta |> dplyr::filter(preference != 3L)

  all_systems        <- unique(meta$system_id)
  mortality_id       <- "mortality"
  ho_id              <- "health_outcomes"
  classification_ids <- setdiff(all_systems, c(mortality_id, "market_functionality"))

  flag_cols <- intersect(names(df), flag_meta$metric_id)

  # ── Stage 1: metric-level flags ────────────────────────────────────────────
  if (length(flag_cols) > 0L) {
    long <- df |>
      dplyr::select(uoa, dplyr::all_of(flag_cols)) |>
      tidyr::pivot_longer(
        cols      = dplyr::all_of(flag_cols),
        names_to  = "metric_id",
        values_to = "value"
      ) |>
      dplyr::left_join(flag_meta, by = "metric_id") |>
      dplyr::mutate(
        flag = dplyr::case_when(
          is.na(value)          ~ NA,
          direction == "Above"  ~ value >= an_threshold,
          direction == "Below"  ~ value <= an_threshold,
          TRUE                  ~ NA
        ),
        status = dplyr::case_when(
          is.na(flag) ~ "no_data",
          flag        ~ "flag",
          TRUE        ~ "no_flag"
        ),
        within_10perc = dplyr::if_else(
          is.na(value),
          NA,
          abs(value - an_threshold) / abs(an_threshold) <= 0.10
        ),
        within_10perc_change = dplyr::if_else(
          is.na(within_10perc),
          NA,
          within_10perc & !flag
        )
      )

    metric_wide <- long |>
      dplyr::select(uoa, metric_id, flag, status, within_10perc, within_10perc_change) |>
      tidyr::pivot_wider(
        names_from  = metric_id,
        values_from = c(flag, status, within_10perc, within_10perc_change),
        names_glue  = "{metric_id}_{.value}"
      )
  } else {
    long        <- tibble::tibble(
      uoa = character(), metric_id = character(), value = numeric(),
      subfactor_path = character(), factor_path = character(),
      system_id = character(), factor_threshold = integer(),
      evidence_threshold = integer(), flag = logical(),
      status = character()
    )
    metric_wide <- tibble::tibble(uoa = df$uoa)
  }

  # ── Stage 2: subfactor statuses ────────────────────────────────────────────
  if (nrow(long) > 0L) {
    group_statuses <- long |>
      dplyr::group_by(uoa, subfactor_path, factor_threshold, evidence_threshold) |>
      dplyr::summarise(
        group_status = evaluate_group_status(
          flag_n             = sum(status == "flag",                      na.rm = TRUE),
          no_flag_n          = sum(status == "no_flag",                   na.rm = TRUE),
          data_n             = sum(status %in% c("flag", "no_flag"),      na.rm = TRUE),
          factor_threshold   = factor_threshold[[1]],
          evidence_threshold = evidence_threshold[[1]]
        ),
        .groups = "drop"
      )

    subfactor_statuses <- group_statuses |>
      dplyr::group_by(uoa, subfactor_path) |>
      dplyr::summarise(
        subfactor_status = rollup_statuses(group_status),
        .groups = "drop"
      )
  } else {
    subfactor_statuses <- tibble::tibble(
      uoa = character(), subfactor_path = character(), subfactor_status = character()
    )
  }

  # ── Stage 3: factor statuses ───────────────────────────────────────────────
  subfactor_to_factor <- dplyr::distinct(flag_meta, subfactor_path, factor_path)

  if (nrow(subfactor_statuses) > 0L) {
    factor_statuses <- subfactor_statuses |>
      dplyr::left_join(subfactor_to_factor, by = "subfactor_path") |>
      dplyr::group_by(uoa, factor_path) |>
      dplyr::summarise(
        factor_status = rollup_statuses(subfactor_status),
        .groups = "drop"
      )
  } else {
    factor_statuses <- tibble::tibble(
      uoa = character(), factor_path = character(), factor_status = character()
    )
  }

  # ── Stage 4: system statuses ───────────────────────────────────────────────
  factor_to_system <- dplyr::distinct(flag_meta, factor_path, system_id)

  if (nrow(factor_statuses) > 0L) {
    system_statuses_partial <- factor_statuses |>
      dplyr::left_join(factor_to_system, by = "factor_path") |>
      dplyr::group_by(uoa, system_id) |>
      dplyr::summarise(
        system_status = rollup_statuses(factor_status),
        .groups = "drop"
      )
  } else {
    system_statuses_partial <- tibble::tibble(
      uoa = character(), system_id = character(), system_status = character()
    )
  }

  full_system_statuses <- tidyr::expand_grid(
    uoa       = df$uoa,
    system_id = all_systems
  ) |>
    dplyr::left_join(system_statuses_partial, by = c("uoa", "system_id")) |>
    dplyr::mutate(
      system_status = dplyr::coalesce(system_status, "no_data")
    )

  # ── Stage 5: prelim_flag ───────────────────────────────────────────────────
  prelim_df <- compute_prelim_flags(
    full_system_statuses,
    mortality_id       = mortality_id,
    ho_id              = ho_id,
    classification_ids = classification_ids
  )

  # ── Pivot aggregates wide ──────────────────────────────────────────────────
  subfactor_wide <- if (nrow(subfactor_statuses) > 0L) {
    tidyr::pivot_wider(
      subfactor_statuses,
      names_from  = subfactor_path,
      values_from = subfactor_status,
      names_glue  = "{subfactor_path}.status"
    )
  } else {
    tibble::tibble(uoa = df$uoa)
  }

  factor_wide <- if (nrow(factor_statuses) > 0L) {
    tidyr::pivot_wider(
      factor_statuses,
      names_from  = factor_path,
      values_from = factor_status,
      names_glue  = "{factor_path}.status"
    )
  } else {
    tibble::tibble(uoa = df$uoa)
  }

  system_wide <- tidyr::pivot_wider(
    full_system_statuses,
    names_from  = system_id,
    values_from = system_status,
    names_glue  = "{system_id}.status"
  )

  # ── Final join ─────────────────────────────────────────────────────────────
  df |>
    dplyr::left_join(metric_wide,    by = "uoa") |>
    dplyr::left_join(subfactor_wide, by = "uoa") |>
    dplyr::left_join(factor_wide,    by = "uoa") |>
    dplyr::left_join(system_wide,    by = "uoa") |>
    dplyr::left_join(prelim_df,      by = "uoa")
}
