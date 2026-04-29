#' anaR: Acute Needs Analysis Engine
#'
#' Validates, flags, and exports ANA humanitarian data.
#'
#' @keywords internal
"_PACKAGE"

# ── Package-level imports ─────────────────────────────────────────────────────
# Declared here so every module can use qualified calls (pkg::fun()) without
# per-function @importFrom noise, while keeping R CMD check satisfied.

#' @importFrom cli cli_abort cli_warn cli_inform
#' @importFrom dplyr mutate filter select left_join group_by summarise
#'   case_when any_of all_of distinct across n if_else
#' @importFrom jsonlite read_json
#' @importFrom openxlsx2 wb_workbook wb_add_worksheet wb_add_data
#' @importFrom purrr map_dfr map walk
#' @importFrom readr read_csv
#' @importFrom rlang `%||%`
#' @importFrom tibble tibble as_tibble
#' @importFrom tidyr pivot_longer pivot_wider
NULL
