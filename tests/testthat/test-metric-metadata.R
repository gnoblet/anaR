ref <- ref_minimal()

# ── get_all_metric_ids ────────────────────────────────────────────────────────

test_that("get_all_metric_ids returns IDs in encounter order", {
  ids <- get_all_metric_ids(ref)
  expect_equal(ids, c("MET001", "MET002", "MET003", "MET004", "MET005", "MET006", "MET007", "MET008"))
})

test_that("get_all_metric_ids deduplicates if same ID appears twice", {
  dup <- ref
  dup$systems[[1]]$factors[[1]]$sub_factors[[1]]$indicators[[1]]$metrics[[2]] <-
    dup$systems[[1]]$factors[[1]]$sub_factors[[1]]$indicators[[1]]$metrics[[1]]
  ids <- get_all_metric_ids(dup)
  expect_equal(sum(ids == "MET001"), 1L)
})

test_that("get_all_metric_ids returns character(0) for empty systems", {
  expect_equal(get_all_metric_ids(list(systems = list())), character(0))
})

test_that("get_all_metric_ids returns character(0) for NULL input", {
  expect_equal(get_all_metric_ids(NULL), character(0))
})

# ── build_metric_meta_df ──────────────────────────────────────────────────────

test_that("build_metric_meta_df returns one row per metric", {
  df <- build_metric_meta_df(ref)
  expect_s3_class(df, "tbl_df")
  expect_equal(nrow(df), 8L)
})

test_that("build_metric_meta_df has expected columns", {
  df <- build_metric_meta_df(ref)
  expected_cols <- c(
    "metric_id", "system_id", "factor_id", "subfactor_id",
    "subfactor_path", "factor_path",
    "preference", "an_threshold", "direction",
    "factor_threshold", "evidence_threshold"
  )
  expect_true(all(expected_cols %in% names(df)))
})

test_that("build_metric_meta_df populates path columns correctly", {
  df <- build_metric_meta_df(ref)
  met1 <- df[df$metric_id == "MET001", ]
  expect_equal(met1$system_id, "mortality")
  expect_equal(met1$factor_id, "mortality_outcomes")
  expect_equal(met1$subfactor_id, "under5_mortality")
  expect_equal(met1$subfactor_path, "mortality.mortality_outcomes.under5_mortality")
  expect_equal(met1$factor_path, "mortality.mortality_outcomes")
})

test_that("build_metric_meta_df reads thresholds and direction", {
  df <- build_metric_meta_df(ref)
  met1 <- df[df$metric_id == "MET001", ]
  expect_equal(met1$an_threshold, 2.0)
  expect_equal(met1$direction, "Above")
  expect_equal(met1$preference, 1L)
  expect_equal(met1$factor_threshold, 1L)
  expect_equal(met1$evidence_threshold, 1L)
})

test_that("build_metric_meta_df captures different threshold pairs on same subfactor", {
  df <- build_metric_meta_df(ref)
  mortality_sub <- df[df$subfactor_path == "mortality.mortality_outcomes.under5_mortality", ]
  pairs <- paste(mortality_sub$factor_threshold, mortality_sub$evidence_threshold)
  expect_length(unique(pairs), 2L)  # MET001: 1:1, MET002: 2:2
})

test_that("build_metric_meta_df includes preference-3 metrics", {
  df <- build_metric_meta_df(ref)
  expect_true("MET005" %in% df$metric_id)
  expect_equal(df$preference[df$metric_id == "MET005"], 3L)
})

test_that("build_metric_meta_df returns zero-row tibble for empty input", {
  df <- build_metric_meta_df(list(systems = list()))
  expect_s3_class(df, "tbl_df")
  expect_equal(nrow(df), 0L)
})

# ── get_metric_metadata ───────────────────────────────────────────────────────

test_that("get_metric_metadata finds a metric by ID", {
  md <- get_metric_metadata(ref, "MET003")
  expect_false(is.null(md))
  expect_equal(md$metric_id, "MET003")
  expect_equal(md$system_id, "health_outcomes")
  expect_equal(md$factor_id, "acute_malnutrition")
  expect_equal(md$subfactor_id, "gam_prevalence")
})

test_that("get_metric_metadata returns the raw metric list", {
  md <- get_metric_metadata(ref, "MET001")
  expect_equal(md$raw$metric, "MET001")
  expect_equal(md$raw$thresholds$an, 2.0)
})

test_that("get_metric_metadata returns NULL for unknown ID", {
  expect_null(get_metric_metadata(ref, "MET999"))
})

test_that("get_metric_metadata returns NULL for NULL input", {
  expect_null(get_metric_metadata(NULL, "MET001"))
})

# ── build_subfactor_list ──────────────────────────────────────────────────────

test_that("build_subfactor_list returns one entry per subfactor", {
  sl <- build_subfactor_list(ref)
  expect_length(sl, 4L)  # one subfactor per system (4 systems)
})

test_that("build_subfactor_list entry has path, codes, groups", {
  sl <- build_subfactor_list(ref)
  entry <- sl[[1]]
  expect_true(all(c("path", "codes", "groups") %in% names(entry)))
})

test_that("build_subfactor_list path matches subfactor_path convention", {
  sl <- build_subfactor_list(ref)
  paths <- vapply(sl, `[[`, "", "path")
  expect_equal(paths[[1]], "mortality.mortality_outcomes.under5_mortality")
})

test_that("build_subfactor_list groups metrics by threshold pair", {
  sl <- build_subfactor_list(ref)
  mortality_entry <- sl[[which(vapply(sl, `[[`, "", "path") ==
    "mortality.mortality_outcomes.under5_mortality")]]
  expect_length(mortality_entry$groups, 2L)  # 1:1 and 2:2
})
