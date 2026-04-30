# ── hex_to_argb ───────────────────────────────────────────────────────────────

test_that("hex_to_argb: converts #rrggbb to FFRRGGBB", {
  expect_equal(hex_to_argb("#cc0000"), "FFCC0000")
  expect_equal(hex_to_argb("#61d095"), "FF61D095")
})

test_that("hex_to_argb: works without leading #", {
  expect_equal(hex_to_argb("718096"), "FF718096")
})

# ── mix_with_white ────────────────────────────────────────────────────────────

test_that("mix_with_white: weight=1 returns original colour", {
  expect_equal(mix_with_white("#000000", 1), "#000000")
  expect_equal(mix_with_white("#ff0000", 1), "#ff0000")
})

test_that("mix_with_white: weight=0 returns white", {
  expect_equal(mix_with_white("#000000", 0), "#ffffff")
  expect_equal(mix_with_white("#cc0000", 0), "#ffffff")
})

test_that("mix_with_white: weight=0.5 blends midpoint", {
  result <- mix_with_white("#ff0000", 0.5)
  # R=round(255+(255-255)*0.5)=255, G=round(255+(0-255)*0.5)=128, B=128
  expect_equal(result, "#ff8080")
})

# ── luminance ─────────────────────────────────────────────────────────────────

test_that("luminance: black is 0", {
  expect_equal(luminance("#000000"), 0)
})

test_that("luminance: white is 1", {
  expect_equal(luminance("#ffffff"), 1)
})

test_that("luminance: pure red ~0.2126", {
  expect_equal(round(luminance("#ff0000"), 4), 0.2126)
})

# ── default_color_map ─────────────────────────────────────────────────────────

test_that("default_color_map: returns named character vector", {
  cm <- default_color_map()
  expect_type(cm, "character")
  expect_true(!is.null(names(cm)))
})

test_that("default_color_map: includes core systems", {
  cm <- default_color_map()
  expect_true("mortality"            %in% names(cm))
  expect_true("health_outcomes"      %in% names(cm))
  expect_true("food_systems"         %in% names(cm))
  expect_true("market_functionality" %in% names(cm))
})

test_that("default_color_map: all values are valid hex colours", {
  cm <- default_color_map()
  expect_true(all(grepl("^#[0-9a-fA-F]{6}$", cm)))
})

# ── sys_hex ───────────────────────────────────────────────────────────────────

test_that("sys_hex: returns hex for known system", {
  cm <- default_color_map()
  expect_equal(sys_hex("mortality", cm), cm[["mortality"]])
})

test_that("sys_hex: returns fallback for unknown system", {
  cm <- default_color_map()
  result <- sys_hex("unknown_system", cm)
  expect_match(result, "^#[0-9a-fA-F]{6}$")
})

# ── sys_text_color ────────────────────────────────────────────────────────────

test_that("sys_text_color: dark background → white text", {
  # mortality is very dark (#460603) → luminance < 0.45 → white
  cm <- default_color_map()
  expect_equal(sys_text_color("mortality", cm), "#ffffff")
})

test_that("sys_text_color: light background → black text", {
  # food_systems is light green (#61d095) → luminance > 0.45 → black
  cm <- default_color_map()
  expect_equal(sys_text_color("food_systems", cm), "#000000")
})
