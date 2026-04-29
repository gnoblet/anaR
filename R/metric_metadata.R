#' Build a tidy tibble of metric metadata from reference JSON
#'
#' Flattens the nested reference JSON (systems → factors → sub_factors →
#' indicators → metrics) into one row per metric. This tibble is the central
#' input for the flagging pipeline — downstream stages join against it rather
#' than re-traversing the JSON.
#'
#' @param json Parsed reference JSON list.
#' @return A tibble with one row per metric and columns:
#'   `metric_id`, `system_id`, `factor_id`, `subfactor_id`,
#'   `subfactor_path`, `factor_path`, `preference`,
#'   `an_threshold`, `direction`, `factor_threshold`, `evidence_threshold`.
#' @export
build_metric_meta_df <- function(json) {
  if (is.null(json) || !is.list(json$systems) || length(json$systems) == 0L) {
    return(tibble::tibble(
      metric_id = character(), system_id = character(),
      factor_id = character(), subfactor_id = character(),
      subfactor_path = character(), factor_path = character(),
      preference = integer(), an_threshold = double(),
      direction = character(), factor_threshold = integer(),
      evidence_threshold = double()
    ))
  }

  purrr::map_dfr(json$systems, function(sys) {
    purrr::map_dfr(sys$factors %||% list(), function(fac) {
      purrr::map_dfr(fac$sub_factors %||% list(), function(sub) {
        purrr::map_dfr(sub$indicators %||% list(), function(ind) {
          purrr::map_dfr(ind$metrics %||% list(), function(met) {
            tibble::tibble(
              metric_id          = met$metric,
              system_id          = sys$id,
              factor_id          = fac$id,
              subfactor_id       = sub$id,
              subfactor_path     = paste(sys$id, fac$id, sub$id, sep = "."),
              factor_path        = paste(sys$id, fac$id, sep = "."),
              preference         = as.integer(met$preference %||% 1L),
              an_threshold       = met$thresholds$an %||% NA_real_,
              direction          = met$above_or_below %||% NA_character_,
              factor_threshold   = as.integer(met$factor_threshold %||% 1L),
              evidence_threshold = met$evidence_threshold %||% NA_real_
            )
          })
        })
      })
    })
  })
}

#' Get all metric IDs from reference JSON
#'
#' Returns metric IDs in encounter order (depth-first traversal), deduplicated.
#'
#' @param json Parsed reference JSON list.
#' @return Character vector of metric IDs (e.g. `"MET001"`).
#' @export
get_all_metric_ids <- function(json) {
  df <- build_metric_meta_df(json)
  if (nrow(df) == 0L) return(character(0))
  unique(df$metric_id)
}

#' Get metadata for a single metric by ID
#'
#' @param json Parsed reference JSON list.
#' @param metric_id Canonical metric ID string (e.g. `"MET001"`).
#' @return A list with elements `metric_id`, `system_id`, `factor_id`,
#'   `subfactor_id`, and `raw` (the original metric list node), or `NULL` if
#'   not found.
#' @export
get_metric_metadata <- function(json, metric_id) {
  if (is.null(json) || is.null(metric_id)) return(NULL)

  for (sys in json$systems %||% list()) {
    for (fac in sys$factors %||% list()) {
      for (sub in fac$sub_factors %||% list()) {
        for (ind in sub$indicators %||% list()) {
          for (met in ind$metrics %||% list()) {
            if (identical(met$metric, metric_id)) {
              return(list(
                metric_id    = met$metric,
                system_id    = sys$id,
                factor_id    = fac$id,
                subfactor_id = sub$id,
                raw          = met
              ))
            }
          }
        }
      }
    }
  }
  NULL
}

#' Build a list of subfactor entries with metric codes and threshold groups
#'
#' Each entry covers one subfactor and contains the three-part dot-separated
#' path, all metric IDs under that subfactor, and the threshold groups derived
#' from `(factor_threshold, evidence_threshold)` pairs.
#'
#' This function is a convenience wrapper around `build_metric_meta_df()` kept
#' for compatibility. Prefer `build_metric_meta_df()` for pipeline work.
#'
#' @param json Parsed reference JSON list.
#' @return A list of entries, each a list with `path` (character), `codes`
#'   (character vector), and `groups` (list of threshold-group lists).
#' @export
build_subfactor_list <- function(json) {
  df <- build_metric_meta_df(json)
  if (nrow(df) == 0L) return(list())

  paths <- unique(df$subfactor_path)

  lapply(paths, function(p) {
    sub_df <- df[df$subfactor_path == p, ]
    codes  <- sub_df$metric_id

    # Group metrics by (factor_threshold, evidence_threshold) pair
    group_keys <- paste(sub_df$factor_threshold, sub_df$evidence_threshold, sep = ":")
    unique_keys <- unique(group_keys)

    groups <- lapply(unique_keys, function(k) {
      rows <- sub_df[group_keys == k, ]
      list(
        factor_threshold   = rows$factor_threshold[[1]],
        evidence_threshold = rows$evidence_threshold[[1]],
        codes              = rows$metric_id
      )
    })

    list(path = p, codes = codes, groups = groups)
  })
}
