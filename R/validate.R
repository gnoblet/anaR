# ── Type-string parser ────────────────────────────────────────────────────────

#' Parse an ANA metric type string
#'
#' Converts a type string such as `"num[0:1]"` or `"int[0+]"` into its
#' component parts.
#'
#' @param type_str A single character string (e.g. `"num"`, `"int[0+]"`,
#'   `"num[0:1]"`). Returns `NULL` for unrecognised formats, `NA`, or `""`.
#' @return A list with elements `base` (`"num"` or `"int"`), `lb` (numeric or
#'   `NULL`), `ub` (numeric or `NULL`), `is_open` (logical), or `NULL` if the
#'   format is not recognised.
#' @export
parse_metric_type <- function(type_str) {
  if (is.null(type_str) || is.na(type_str) || !nzchar(type_str)) return(NULL)
  m <- regmatches(
    type_str,
    regexec(
      "^(num|int)(?:\\[(\\d+(?:\\.\\d+)?)(?::(\\d+(?:\\.\\d+)?)|([+]))\\])?$",
      type_str,
      perl = TRUE
    )
  )[[1]]
  if (length(m) == 0L) return(NULL)
  list(
    base    = m[[2]],
    lb      = if (nzchar(m[[3]])) as.numeric(m[[3]]) else NULL,
    ub      = if (nzchar(m[[4]])) as.numeric(m[[4]]) else NULL,
    is_open = nzchar(m[[5]])
  )
}

# ── Human-readable type description ──────────────────────────────────────────

human_readable_type <- function(parsed) {
  noun <- if (parsed$base == "int") "an integer" else "a number"
  if (is.null(parsed$lb) && is.null(parsed$ub)) return(noun)
  if (isTRUE(parsed$is_open) && !is.null(parsed$lb)) {
    adj <- if (parsed$base == "int") "a positive integer" else "a positive number"
    return(sprintf("%s (>= %g)", adj, parsed$lb))
  }
  if (!is.null(parsed$lb) && !is.null(parsed$ub)) {
    hint <- if (parsed$lb == 0 && parsed$ub == 1) {
      if (parsed$base == "int") " (likely a binary)" else " (likely a proportion)"
    } else ""
    return(sprintf("%s between %g and %g%s", noun, parsed$lb, parsed$ub, hint))
  }
  noun
}

# ── Single-cell check ─────────────────────────────────────────────────────────

# Returns an error string, or NA_character_ if the cell is valid.
# "missing" is returned (not NA) when the cell is empty and require_non_empty=FALSE,
# so callers can distinguish "valid but missing" from "no error at all".
check_cell_str <- function(value, type, require_non_empty = FALSE) {
  v <- if (is.na(value)) "" else trimws(as.character(value))

  if (!nzchar(v)) {
    return(if (require_non_empty) "empty value" else NA_character_)
  }

  is_numeric_str <- suppressWarnings(!is.na(as.numeric(v)))

  if (is.null(type) || is.na(type) || !nzchar(trimws(type))) {
    if (is_numeric_str) return(NA_character_)
    return(sprintf("'%s' is a string, not a number", v))
  }

  parsed <- parse_metric_type(trimws(type))

  if (is.null(parsed)) {
    # Unrecognised format — accept if numeric
    if (is_numeric_str) return(NA_character_)
    return(sprintf("'%s' is a string, not a number", v))
  }

  if (!is_numeric_str) {
    return(sprintf("'%s' is a string, not %s", v, human_readable_type(parsed)))
  }

  n <- as.numeric(v)

  if (parsed$base == "int" && n != floor(n)) {
    return(sprintf("value %g is not an integer", n))
  }
  if (!is.null(parsed$lb) && n < parsed$lb) {
    return(sprintf("value %g is not %s", n, human_readable_type(parsed)))
  }
  if (!isTRUE(parsed$is_open) && !is.null(parsed$ub) && n > parsed$ub) {
    return(sprintf("value %g is not %s", n, human_readable_type(parsed)))
  }

  NA_character_
}

# ── S3 constructor ────────────────────────────────────────────────────────────

new_validation_result <- function(ok, header_errors, cell_errors,
                                  warnings, duplicate_uoas, missingness,
                                  metadata_cols, meta) {
  structure(
    list(
      ok             = ok,
      header_errors  = header_errors,
      cell_errors    = cell_errors,
      warnings       = warnings,
      duplicate_uoas = duplicate_uoas,
      missingness    = missingness,
      metadata_cols  = metadata_cols,
      meta           = meta
    ),
    class = "ana_validation_result"
  )
}

#' @export
print.ana_validation_result <- function(x, ...) {
  status <- if (x$ok) "OK" else "INVALID"
  cat(sprintf(
    "<ana_validation_result> [%s]  rows: %d  cols: %d  errors: %d  warnings: %d\n",
    status, x$meta$checked_rows, x$meta$checked_cols,
    nrow(x$cell_errors) + length(x$header_errors),
    length(x$warnings)
  ))
  invisible(x)
}

# ── Main export ───────────────────────────────────────────────────────────────

#' Validate a CSV data frame against the ANA metric map
#'
#' Checks header structure, UOA uniqueness, and per-cell type constraints.
#' Returns an `ana_validation_result` object with full error detail.
#'
#' @param df A `data.frame` (or tibble) with one row per unit of analysis.
#'   All values are expected to be character strings or `NA` (as produced by
#'   [readr::read_csv()] with `col_types = cols(.default = "c")`), but numeric
#'   columns are also accepted and coerced to character for checking.
#' @param metric_map A named list keyed by metric ID (e.g. `"MET001"`). Each
#'   value must be a list with at least a `type` element (the type string used
#'   for cell-level validation).
#' @param opts A list of options:
#'   - `require_non_empty` (logical, default `FALSE`): if `TRUE`, empty cells
#'     are treated as errors rather than missing values.
#' @return An `ana_validation_result` list with elements:
#'   `ok`, `header_errors`, `cell_errors` (tibble), `warnings`,
#'   `duplicate_uoas`, `missingness` (tibble), `metadata_cols`, `meta`.
#' @export
validate_csv <- function(df, metric_map, opts = list()) {
  require_non_empty <- isTRUE(opts$require_non_empty)

  # ── Classify columns ────────────────────────────────────────────────────────
  col_names     <- names(df)
  uoa_idx       <- which(tolower(col_names) == "uoa")
  metric_cols   <- col_names[col_names %in% names(metric_map)]
  metadata_cols <- setdiff(col_names, c(col_names[uoa_idx], metric_cols))

  header_errors <- character()
  if (length(uoa_idx) == 0L) {
    header_errors <- c(header_errors, "Header must include a 'uoa' column")
  }

  empty_result <- new_validation_result(
    ok             = FALSE,
    header_errors  = header_errors,
    cell_errors    = .empty_cell_errors(),
    warnings       = character(),
    duplicate_uoas = list(),
    missingness    = .empty_missingness(),
    metadata_cols  = metadata_cols,
    meta           = list(checked_rows = 0L, checked_cols = length(col_names))
  )

  if (length(uoa_idx) == 0L) return(empty_result)

  uoa_col <- col_names[uoa_idx]
  df      <- dplyr::mutate(df, dplyr::across(dplyr::everything(), as.character))

  # ── Duplicate UOA detection ─────────────────────────────────────────────────
  dup_tbl <- df |>
    dplyr::mutate(.row = dplyr::row_number() + 1L) |>
    dplyr::group_by(dplyr::across(dplyr::all_of(uoa_col))) |>
    dplyr::filter(dplyr::n() > 1L) |>
    dplyr::summarise(rows = list(.row), .groups = "drop")

  duplicate_uoas <- lapply(seq_len(nrow(dup_tbl)), function(i) {
    list(uoa = dup_tbl[[uoa_col]][[i]], rows = dup_tbl$rows[[i]])
  })

  # ── Missingness summary ─────────────────────────────────────────────────────
  missingness <- if (length(metric_cols) > 0L) {
    df |>
      dplyr::summarise(dplyr::across(
        dplyr::all_of(metric_cols),
        list(
          total   = \(x) length(x),
          missing = \(x) sum(is.na(x) | trimws(x) == "")
        )
      )) |>
      tidyr::pivot_longer(
        dplyr::everything(),
        names_to      = c("metric", ".value"),
        names_pattern = "^(.+)_(total|missing)$"
      )
  } else {
    .empty_missingness()
  }

  # ── Cell error detection ────────────────────────────────────────────────────
  metric_type_df <- tibble::tibble(
    col_name = names(metric_map),
    type     = vapply(metric_map, \(m) {
      t <- m$type
      if (is.null(t) || is.na(t)) NA_character_ else as.character(t)
    }, character(1))
  )

  cell_errors <- if (length(metric_cols) > 0L) {
    df |>
      dplyr::mutate(.row = dplyr::row_number() + 1L) |>
      tidyr::pivot_longer(
        cols      = dplyr::all_of(metric_cols),
        names_to  = "col_name",
        values_to = "value_raw"
      ) |>
      dplyr::left_join(metric_type_df, by = "col_name") |>
      dplyr::mutate(
        error_msg = purrr::map2_chr(
          value_raw, type,
          \(v, t) check_cell_str(v, t, require_non_empty)
        )
      ) |>
      dplyr::filter(!is.na(error_msg)) |>
      dplyr::select(row = .row, col_name, value = value_raw, message = error_msg)
  } else {
    .empty_cell_errors()
  }

  # Duplicate-UOA rows also become cell errors
  if (length(duplicate_uoas) > 0L) {
    dup_cell_errors <- purrr::map_dfr(duplicate_uoas, function(d) {
      tibble::tibble(
        row     = d$rows,
        col_name = uoa_col,
        value   = d$uoa,
        message = sprintf("duplicate uoa '%s'", d$uoa)
      )
    })
    cell_errors <- dplyr::bind_rows(cell_errors, dup_cell_errors) |>
      dplyr::arrange(row)
  }

  new_validation_result(
    ok             = length(header_errors) == 0L && nrow(cell_errors) == 0L,
    header_errors  = header_errors,
    cell_errors    = cell_errors,
    warnings       = character(),
    duplicate_uoas = duplicate_uoas,
    missingness    = missingness,
    metadata_cols  = metadata_cols,
    meta           = list(checked_rows = nrow(df), checked_cols = length(col_names))
  )
}

# ── Reference JSON loader ─────────────────────────────────────────────────────

#' Load the ANA reference JSON
#'
#' Returns the bundled `ana_reference` internal dataset by default.
#' Pass `path` to load a custom `reference.json` from disk instead.
#'
#' @param path Optional file path to a `reference.json`. If `NULL` (default),
#'   returns the dataset bundled with the package.
#' @return A named list with a `systems` element.
#' @export
get_default_reference <- function(path = NULL) {
  if (!is.null(path)) {
    return(jsonlite::read_json(path, simplifyVector = FALSE))
  }
  ana_reference
}

# ── Internal helpers ──────────────────────────────────────────────────────────

.empty_cell_errors <- function() {
  tibble::tibble(
    row      = integer(),
    col_name = character(),
    value    = character(),
    message  = character()
  )
}

.empty_missingness <- function() {
  tibble::tibble(metric = character(), total = integer(), missing = integer())
}
