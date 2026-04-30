ref  <- ref_minimal()
data <- sample_data()

# ── rollup_statuses ───────────────────────────────────────────────────────────

test_that("rollup_statuses: any flag wins", {
  expect_equal(rollup_statuses(c("flag", "no_flag", "insufficient_evidence")), "flag")
})

test_that("rollup_statuses: all no_flag → no_flag", {
  expect_equal(rollup_statuses(c("no_flag", "no_flag")), "no_flag")
})

test_that("rollup_statuses: all no_data stays no_data (not insufficient_evidence)", {
  expect_equal(rollup_statuses(c("no_data", "no_data")), "no_data")
})

test_that("rollup_statuses: mix of no_flag and no_data → insufficient_evidence", {
  expect_equal(rollup_statuses(c("no_flag", "no_data")), "insufficient_evidence")
})

test_that("rollup_statuses: no_flag + insufficient_evidence → insufficient_evidence", {
  expect_equal(rollup_statuses(c("no_flag", "insufficient_evidence")), "insufficient_evidence")
})

test_that("rollup_statuses: empty vector → no_data", {
  expect_equal(rollup_statuses(character(0)), "no_data")
})

# ── evaluate_group_status ─────────────────────────────────────────────────────

test_that("evaluate_group_status: flag_n >= factor_threshold → flag", {
  expect_equal(evaluate_group_status(1L, 0L, 1L, 1L, 1L), "flag")
  expect_equal(evaluate_group_status(2L, 1L, 3L, 2L, 2L), "flag")
})

test_that("evaluate_group_status: data_n >= evidence_threshold, not flagged → no_flag", {
  expect_equal(evaluate_group_status(0L, 2L, 2L, 1L, 2L), "no_flag")
})

test_that("evaluate_group_status: some data but below evidence threshold → insufficient_evidence", {
  expect_equal(evaluate_group_status(0L, 1L, 1L, 2L, 3L), "insufficient_evidence")
})

test_that("evaluate_group_status: no data → no_data", {
  expect_equal(evaluate_group_status(0L, 0L, 0L, 1L, 1L), "no_data")
})

# ── flag_data: input validation ───────────────────────────────────────────────

test_that("flag_data: empty input returns zero-row tibble without error", {
  result <- flag_data(data[0, ], ref)
  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 0L)
})

test_that("flag_data: throws if mortality system absent from reference", {
  bad_ref <- ref
  bad_ref$systems <- bad_ref$systems[
    !vapply(bad_ref$systems, \(s) s$id == "mortality", logical(1))
  ]
  expect_error(flag_data(data, bad_ref), "mortality")
})

test_that("flag_data: throws if health_outcomes system absent from reference", {
  bad_ref <- ref
  bad_ref$systems <- bad_ref$systems[
    !vapply(bad_ref$systems, \(s) s$id == "health_outcomes", logical(1))
  ]
  expect_error(flag_data(data, bad_ref), "health_outcomes")
})

# ── flag_data: metric-level columns ──────────────────────────────────────────

test_that("flag_data: MET001_flag is TRUE when value > threshold", {
  # MET001: Above 2.0; Area A has 3.0
  result <- flag_data(data, ref)
  expect_true(result$MET001_flag[result$uoa == "Area A"])
  expect_false(result$MET001_flag[result$uoa == "Area B"])
  expect_true(is.na(result$MET001_flag[result$uoa == "Area C"]))
})

test_that("flag_data: MET001_status reflects flag correctly", {
  result <- flag_data(data, ref)
  expect_equal(result$MET001_status[result$uoa == "Area A"], "flag")
  expect_equal(result$MET001_status[result$uoa == "Area B"], "no_flag")
  expect_equal(result$MET001_status[result$uoa == "Area C"], "no_data")
})

test_that("flag_data: MET001_within_10perc is TRUE when within 10% of threshold", {
  # threshold = 2.0; value 1.9 is within 10% (|1.9-2|/2 = 0.05)
  d <- tibble::tibble(uoa = "X", MET001 = 1.9)
  result <- flag_data(d, ref)
  expect_true(result$MET001_within_10perc[1])
})

test_that("flag_data: MET001_within_10perc_change is TRUE approaching but not yet flagged", {
  # value 1.9: within 10% of 2.0 but NOT >= 2.0
  d <- tibble::tibble(uoa = "X", MET001 = 1.9)
  result <- flag_data(d, ref)
  expect_true(result$MET001_within_10perc_change[1])
})

test_that("flag_data: preference-3 metric MET005 has no flag column", {
  result <- flag_data(data, ref)
  expect_false("MET005_flag" %in% names(result))
  expect_false("MET005_status" %in% names(result))
})

test_that("flag_data: Below-direction metric MET007 flags when value < threshold", {
  # MET007: Below 4; Area A has 3 → flag; Area B has 5 → no_flag
  result <- flag_data(data, ref)
  expect_true(result$MET007_flag[result$uoa == "Area A"])
  expect_false(result$MET007_flag[result$uoa == "Area B"])
})

# ── flag_data: subfactor / factor / system columns ───────────────────────────

test_that("flag_data: subfactor status column exists and is character", {
  result <- flag_data(data, ref)
  col <- "mortality.mortality_outcomes.under5_mortality.status"
  expect_true(col %in% names(result))
  expect_type(result[[col]], "character")
})

test_that("flag_data: subfactor status is flag when any group is flagged", {
  result <- flag_data(data, ref)
  col <- "mortality.mortality_outcomes.under5_mortality.status"
  expect_equal(result[[col]][result$uoa == "Area A"], "flag")
})

test_that("flag_data: factor status column exists", {
  result <- flag_data(data, ref)
  expect_true("mortality.mortality_outcomes.status" %in% names(result))
})

test_that("flag_data: system status column exists", {
  result <- flag_data(data, ref)
  expect_true("mortality.status" %in% names(result))
})

# ── flag_data: prelim_flag ────────────────────────────────────────────────────

test_that("flag_data: prelim_flag = em when mortality system flagged", {
  # Area A: MET001=3.0 > 2.0 → mortality flagged → em
  result <- flag_data(data, ref)
  expect_equal(result$prelim_flag[result$uoa == "Area A"], "em")
})

test_that("flag_data: prelim_flag = no_data when all classification systems have no_data", {
  d <- tibble::tibble(uoa = "Empty")
  result <- flag_data(d, ref)
  expect_equal(result$prelim_flag, "no_data")
})

test_that("flag_data: prelim_flag = acute when a classification system (not mortality) is flagged", {
  # Only food_systems flagged, not mortality or health_outcomes
  d <- tibble::tibble(
    uoa    = "X",
    MET001 = 0.5,   # mortality: no_flag (below threshold 2.0)
    MET002 = 1.0,   # mortality: no_flag
    MET003 = 0.05,  # health_outcomes: no_flag
    MET004 = 0.05,  # health_outcomes: no_flag
    MET006 = 0.5,   # food_systems: flag (Above 0.20)
    MET007 = 2L     # food_systems: flag (Below 4)
  )
  result <- flag_data(d, ref)
  expect_equal(result$prelim_flag, "acute")
})

test_that("flag_data: prelim_flag = roem when health_outcomes + >=3 others flagged", {
  # Need health_outcomes flagged + 3 other classification systems flagged.
  # Our fixture only has food_systems and market_functionality (excluded).
  # We need to use a reference with more systems.
  # Skip for now — covered by the decision-tree logic unit test below.
  skip("needs a reference with 4+ classification systems")
})

test_that("flag_data: prelim_flag = insufficient_evidence when some data but below thresholds", {
  # MET001 alone with evidence_threshold=1 is sufficient for no_flag.
  # Use MET002 which has evidence_threshold=2, supply only 1 value → insufficient.
  d <- tibble::tibble(uoa = "X", MET002 = 5.0)  # below flag threshold (10.0)
  result <- flag_data(d, ref)
  # mortality subfactor: MET002 has ft=2, et=2; data_n=1 < et=2 → insufficient_evidence
  # health_outcomes and food_systems: no_data
  # classification systems: health_outcomes=no_data, food_systems=no_data → some insuff
  expect_equal(result$prelim_flag[1], "insufficient_evidence")
})

test_that("flag_data: result has one row per input uoa", {
  result <- flag_data(data, ref)
  expect_equal(nrow(result), nrow(data))
  expect_equal(result$uoa, data$uoa)
})

test_that("flag_data: metadata columns are passed through", {
  d <- dplyr::mutate(data, admin1 = "North")
  result <- flag_data(d, ref)
  expect_true("admin1" %in% names(result))
  expect_equal(result$admin1, rep("North", nrow(d)))
})

# ── compute_prelim_flags: decision tree unit test ─────────────────────────────

test_that("compute_prelim_flags: roem when ho flagged + 3 other classification systems flagged", {
  # Build synthetic system_statuses tibble with 5 classification systems
  sys_statuses <- tibble::tibble(
    uoa       = rep("X", 6),
    system_id = c("mortality", "health_outcomes", "food_systems",
                  "water_systems", "living_conditions", "market_functionality"),
    system_status = c("no_flag", "flag", "flag", "flag", "flag", "flag")
  )
  result <- compute_prelim_flags(
    system_statuses  = sys_statuses,
    mortality_id     = "mortality",
    ho_id            = "health_outcomes",
    classification_ids = c("health_outcomes", "food_systems",
                           "water_systems", "living_conditions")
  )
  expect_equal(result$prelim_flag, "roem")
})

test_that("compute_prelim_flags: acute_needs when all classification systems are no_flag", {
  sys_statuses <- tibble::tibble(
    uoa       = rep("X", 3),
    system_id = c("mortality", "health_outcomes", "food_systems"),
    system_status = c("no_flag", "no_flag", "no_flag")
  )
  result <- compute_prelim_flags(
    sys_statuses, "mortality", "health_outcomes",
    c("health_outcomes", "food_systems")
  )
  expect_equal(result$prelim_flag, "acute_needs")
})
