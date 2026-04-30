ref  <- ref_minimal()
data <- sample_data()

# Minimal hypotheses fixture — two systems, one with hypotheses
hyps_fixture <- list(
  list(
    systemId    = "mortality",
    systemLabel = "Mortality",
    hypotheses  = list()
  ),
  list(
    systemId    = "food_systems",
    systemLabel = "Food Systems",
    hypotheses  = list(
      list(id = "H1", description = "Food hypothesis one"),
      list(id = "H2", description = "Food hypothesis two")
    )
  )
)

flagged  <- flag_data(data, ref)
uoa_row  <- as.list(flagged[flagged$uoa == "Area A", ])

# ── layout helpers ────────────────────────────────────────────────────────────

test_that("dd_col_count: fixed 7 + N + 1 comment", {
  expect_equal(dd_col_count(0L), 8L)
  expect_equal(dd_col_count(3L), 11L)
})

test_that("dd_col_widths: length equals col_count", {
  expect_length(dd_col_widths(2L), dd_col_count(2L))
  expect_length(dd_col_widths(0L), dd_col_count(0L))
})

test_that("dd_table_headers: starts with fixed headers", {
  h <- dd_table_headers(c("H1", "H2"))
  expect_equal(h[1:7], c("Metric ID", "Indicator", "Metric", "Value", "Flag",
                           "AN Threshold", "Direction"))
  expect_equal(h[8:9], c("H1", "H2"))
  expect_equal(h[10], "Comment")
})

# ── build_deep_dive: file creation ───────────────────────────────────────────

test_that("build_deep_dive: returns path and creates file", {
  path   <- tempfile(fileext = ".xlsx")
  result <- build_deep_dive(uoa_row, ref, hyps_fixture, path)
  expect_equal(result, path)
  expect_true(file.exists(path))
  expect_gt(file.size(path), 2000L)
})

test_that("build_deep_dive: workbook has Summary sheet and system sheets", {
  path <- tempfile(fileext = ".xlsx")
  build_deep_dive(uoa_row, ref, hyps_fixture, path)
  wb     <- openxlsx2::wb_load(path)
  sheets <- openxlsx2::wb_get_sheet_names(wb)
  expect_true("Summary" %in% sheets)
  expect_true(any(grepl("Mortality",    sheets, ignore.case = TRUE)))
  expect_true(any(grepl("Food Systems", sheets, ignore.case = TRUE)))
})

test_that("build_deep_dive: skips systems absent from hypotheses_data", {
  path <- tempfile(fileext = ".xlsx")
  build_deep_dive(uoa_row, ref, hyps_fixture, path)
  wb     <- openxlsx2::wb_load(path)
  sheets <- openxlsx2::wb_get_sheet_names(wb)
  # health_outcomes and market_functionality not in hyps_fixture
  expect_false(any(grepl("Health Outcomes",      sheets, ignore.case = TRUE)))
  expect_false(any(grepl("Market Functionality", sheets, ignore.case = TRUE)))
})

test_that("build_deep_dive: works with uoa row having no metric columns", {
  d     <- tibble::tibble(uoa = "Empty")
  flags <- flag_data(d, ref)
  row   <- as.list(flags[1, ])
  path  <- tempfile(fileext = ".xlsx")
  expect_no_error(build_deep_dive(row, ref, hyps_fixture, path))
  expect_true(file.exists(path))
})

test_that("build_deep_dive: custom color_map is accepted", {
  cm   <- c(mortality = "#ff0000", food_systems = "#0000ff")
  path <- tempfile(fileext = ".xlsx")
  expect_no_error(build_deep_dive(uoa_row, ref, hyps_fixture, path, color_map = cm))
})
