fixture_path <- function(file) {
  testthat::test_path("fixtures", file)
}

ref_minimal <- function() {
  jsonlite::read_json(fixture_path("reference_minimal.json"), simplifyVector = FALSE)
}

# Minimal sample data tibble aligned with reference_minimal.json
sample_data <- function() {
  tibble::tibble(
    uoa      = c("Area A", "Area B", "Area C"),
    MET001   = c(3.0,   1.0,   NA),    # Above 2 → flag, no_flag, no_data
    MET002   = c(15.0,  5.0,   NA),    # Above 10 → flag, no_flag, no_data
    MET003   = c(0.20,  0.10,  NA),    # Above 0.15 → flag, no_flag, no_data
    MET004   = c(0.20,  0.10,  NA),    # Above 0.15 → flag, no_flag, no_data
    # MET005 omitted — preference 3, excluded from flagging
    MET006   = c(0.30,  0.10,  NA),    # Above 0.20 → flag, no_flag, no_data
    MET007   = c(3L,    5L,    NA),    # Below 4 → flag, no_flag, no_data
    MET008   = c(0.25,  0.10,  NA)    # market — not in classification systems
  )
}
