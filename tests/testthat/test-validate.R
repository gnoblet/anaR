ref <- ref_minimal()

# Build metric_map from the fixture — keyed by metric_id, value is the raw metric list
metric_map <- local({
  df <- build_metric_meta_df(ref)
  met_list <- lapply(df$metric_id, \(id) get_metric_metadata(ref, id)$raw)
  names(met_list) <- df$metric_id
  met_list
})

# ── parse_metric_type ─────────────────────────────────────────────────────────

test_that("parse_metric_type: bare num", {
  p <- parse_metric_type("num")
  expect_equal(p$base, "num")
  expect_null(p$lb)
  expect_null(p$ub)
  expect_false(p$is_open)
})

test_that("parse_metric_type: bare int", {
  p <- parse_metric_type("int")
  expect_equal(p$base, "int")
  expect_null(p$lb)
  expect_null(p$ub)
  expect_false(p$is_open)
})

test_that("parse_metric_type: half-open int[0+]", {
  p <- parse_metric_type("int[0+]")
  expect_equal(p$base, "int")
  expect_equal(p$lb, 0)
  expect_null(p$ub)
  expect_true(p$is_open)
})

test_that("parse_metric_type: closed interval num[0:1]", {
  p <- parse_metric_type("num[0:1]")
  expect_equal(p$base, "num")
  expect_equal(p$lb, 0)
  expect_equal(p$ub, 1)
  expect_false(p$is_open)
})

test_that("parse_metric_type: closed interval num[0+]", {
  p <- parse_metric_type("num[0+]")
  expect_equal(p$base, "num")
  expect_equal(p$lb, 0)
  expect_null(p$ub)
  expect_true(p$is_open)
})

test_that("parse_metric_type: returns NULL for garbage", {
  expect_null(parse_metric_type("garbage"))
  expect_null(parse_metric_type("float[0:1]"))
  expect_null(parse_metric_type(""))
  expect_null(parse_metric_type(NA_character_))
})

# ── validate_csv: header errors ───────────────────────────────────────────────

test_that("validate_csv: missing uoa column → ok=FALSE, header_errors non-empty", {
  df <- tibble::tibble(MET001 = c(1, 2), MET003 = c(0.1, 0.2))
  res <- validate_csv(df, metric_map)
  expect_false(res$ok)
  expect_gt(length(res$header_errors), 0L)
  expect_true(any(grepl("uoa", res$header_errors, ignore.case = TRUE)))
})

test_that("validate_csv: uoa column present → header_errors empty", {
  df <- tibble::tibble(uoa = c("A", "B"), MET001 = c(1.0, 2.0))
  res <- validate_csv(df, metric_map)
  expect_length(res$header_errors, 0L)
})

# ── validate_csv: duplicate UOAs ─────────────────────────────────────────────

test_that("validate_csv: duplicate uoa → ok=FALSE, duplicate_uoas non-empty", {
  df <- tibble::tibble(uoa = c("A", "A", "B"), MET001 = c(1.0, 2.0, 3.0))
  res <- validate_csv(df, metric_map)
  expect_false(res$ok)
  expect_gt(length(res$duplicate_uoas), 0L)
  expect_equal(res$duplicate_uoas[[1]]$uoa, "A")
  expect_length(res$duplicate_uoas[[1]]$rows, 2L)
})

test_that("validate_csv: unique uoas → duplicate_uoas empty", {
  df <- tibble::tibble(uoa = c("A", "B"), MET001 = c(1.0, 2.0))
  res <- validate_csv(df, metric_map)
  expect_length(res$duplicate_uoas, 0L)
})

# ── validate_csv: cell type errors ───────────────────────────────────────────

test_that("validate_csv: string value in num column → cell error", {
  df <- tibble::tibble(uoa = "A", MET001 = "bad")
  res <- validate_csv(df, metric_map)
  expect_false(res$ok)
  expect_gt(nrow(res$cell_errors), 0L)
  expect_equal(res$cell_errors$col_name[[1]], "MET001")
})

test_that("validate_csv: float in int[0+] column → cell error", {
  # MET007 is int[0+]
  df <- tibble::tibble(uoa = "A", MET007 = "2.5")
  res <- validate_csv(df, metric_map)
  expect_false(res$ok)
  expect_true(any(res$cell_errors$col_name == "MET007"))
})

test_that("validate_csv: value below lb in num[0+] column → cell error", {
  # MET001 is num[0+], so negative is invalid
  df <- tibble::tibble(uoa = "A", MET001 = "-1")
  res <- validate_csv(df, metric_map)
  expect_false(res$ok)
  expect_true(any(res$cell_errors$col_name == "MET001"))
})

test_that("validate_csv: value above ub in num[0:1] column → cell error", {
  # MET003 is num[0:1]
  df <- tibble::tibble(uoa = "A", MET003 = "1.5")
  res <- validate_csv(df, metric_map)
  expect_false(res$ok)
  expect_true(any(res$cell_errors$col_name == "MET003"))
})

test_that("validate_csv: valid values → no cell errors", {
  df <- tibble::tibble(uoa = "A", MET001 = "3.0", MET003 = "0.2", MET007 = "3")
  res <- validate_csv(df, metric_map)
  expect_length(res$cell_errors$col_name, 0L)
})

# ── validate_csv: missingness ─────────────────────────────────────────────────

test_that("validate_csv: empty cell with require_non_empty=FALSE → counted in missingness, not error", {
  df <- tibble::tibble(uoa = c("A", "B"), MET001 = c("1.0", NA_character_))
  res <- validate_csv(df, metric_map, opts = list(require_non_empty = FALSE))
  expect_equal(nrow(res$cell_errors), 0L)
  m <- res$missingness[res$missingness$metric == "MET001", ]
  expect_equal(m$missing, 1L)
  expect_equal(m$total, 2L)
})

test_that("validate_csv: empty cell with require_non_empty=TRUE → cell error", {
  df <- tibble::tibble(uoa = c("A", "B"), MET001 = c("1.0", NA_character_))
  res <- validate_csv(df, metric_map, opts = list(require_non_empty = TRUE))
  expect_true(any(res$cell_errors$col_name == "MET001"))
})

# ── validate_csv: metadata columns ───────────────────────────────────────────

test_that("validate_csv: unknown columns become metadata_cols, not errors", {
  df <- tibble::tibble(uoa = "A", MET001 = "1.0", admin1 = "North", notes = "ok")
  res <- validate_csv(df, metric_map)
  expect_true("admin1" %in% res$metadata_cols)
  expect_true("notes" %in% res$metadata_cols)
  expect_length(res$cell_errors$col_name, 0L)
})

# ── validate_csv: ok field ────────────────────────────────────────────────────

test_that("validate_csv: clean data → ok=TRUE", {
  df <- tibble::tibble(uoa = c("A", "B"), MET001 = c("1.0", "2.0"))
  res <- validate_csv(df, metric_map)
  expect_true(res$ok)
})

test_that("validate_csv: meta field counts rows and cols", {
  df <- tibble::tibble(uoa = c("A", "B"), MET001 = c("1.0", "2.0"), admin1 = c("N", "S"))
  res <- validate_csv(df, metric_map)
  expect_equal(res$meta$checked_rows, 2L)
  expect_equal(res$meta$checked_cols, 3L)
})

# ── print.ana_validation_result ───────────────────────────────────────────────

test_that("print.ana_validation_result: smoke test — no error, produces output", {
  df <- tibble::tibble(uoa = "A", MET001 = "1.0")
  res <- validate_csv(df, metric_map)
  expect_output(print(res))
})

# ── get_default_reference ─────────────────────────────────────────────────────

test_that("get_default_reference: returns a list with systems element", {
  ref <- get_default_reference()
  expect_type(ref, "list")
  expect_true("systems" %in% names(ref))
  expect_gt(length(ref$systems), 0L)
})

test_that("get_default_reference: accepts custom path", {
  path <- testthat::test_path("fixtures", "reference_minimal.json")
  ref  <- get_default_reference(path)
  expect_equal(length(ref$systems), 4L)
})
