# ── Color helpers ─────────────────────────────────────────────────────────────

#' Convert a CSS hex colour to Excel ARGB format
#'
#' @param hex A hex colour string, with or without a leading `#`
#'   (e.g. `"#cc0000"` or `"cc0000"`).
#' @return A string in `"FFrrggbb"` format (uppercase).
#' @export
hex_to_argb <- function(hex) {
  clean <- toupper(sub("^#", "", trimws(hex)))
  paste0("FF", clean)
}

#' Mix a hex colour with white
#'
#' @param hex   A `#rrggbb` hex colour string.
#' @param weight Numeric in `[0, 1]`: 0 = pure white, 1 = original colour.
#' @return A `#rrggbb` hex string.
#' @export
mix_with_white <- function(hex, weight) {
  clean <- sub("^#", "", tolower(hex))
  parse_ch <- function(s) as.integer(paste0("0x", s))
  r <- round(255 + (parse_ch(substr(clean, 1, 2)) - 255) * weight)
  g <- round(255 + (parse_ch(substr(clean, 3, 4)) - 255) * weight)
  b <- round(255 + (parse_ch(substr(clean, 5, 6)) - 255) * weight)
  clamp <- function(v) max(0L, min(255L, as.integer(v)))
  sprintf("#%02x%02x%02x", clamp(r), clamp(g), clamp(b))
}

#' Perceived luminance of a hex colour
#'
#' Uses the standard WCAG relative luminance formula.
#'
#' @param hex A `#rrggbb` hex colour string.
#' @return A numeric in `[0, 1]` (0 = black, 1 = white).
#' @export
luminance <- function(hex) {
  clean <- sub("^#", "", tolower(hex))
  parse_ch <- function(s) as.integer(paste0("0x", s)) / 255
  r <- parse_ch(substr(clean, 1, 2))
  g <- parse_ch(substr(clean, 3, 4))
  b <- parse_ch(substr(clean, 5, 6))
  0.2126 * r + 0.7152 * g + 0.0722 * b
}

# ── System colour map ─────────────────────────────────────────────────────────

#' Default ANA system colour map
#'
#' Returns a named character vector mapping system IDs to their base hex
#' colours, mirroring the CSS custom properties in the ANA SvelteKit app.
#'
#' @return A named character vector of `#rrggbb` hex strings.
#' @export
default_color_map <- function() {
  c(
    mortality                 = "#460603",
    health_outcomes           = "#a8201a",
    food_systems              = "#61d095",
    water_systems             = "#0e79b2",
    living_conditions         = "#dbb957",
    market_functionality      = "#b47eb3",
    health_nutrition_services = "#e49273",
    protection                = "#805ad5"
  )
}

# ── Derived colour accessors ──────────────────────────────────────────────────

#' Get the base hex colour for a system
#'
#' @param system_id  A system ID string (e.g. `"mortality"`).
#' @param color_map  Named character vector from [default_color_map()].
#' @return A `#rrggbb` hex string; falls back to `"#718096"` for unknown IDs.
#' @export
sys_hex <- function(system_id, color_map) {
  val <- color_map[system_id]
  if (is.na(val)) "#718096" else unname(val)
}

#' Text colour (black or white) for contrast on a system background
#'
#' @param system_id A system ID string.
#' @param color_map Named character vector from [default_color_map()].
#' @return `"#ffffff"` for dark backgrounds, `"#000000"` for light ones.
#' @export
sys_text_color <- function(system_id, color_map) {
  if (luminance(sys_hex(system_id, color_map)) > 0.45) "#000000" else "#ffffff"
}

# Internal helpers — not exported; used only within deepdive.R

.sys_argb <- function(system_id, color_map) {
  hex_to_argb(sys_hex(system_id, color_map))
}

.sys_argb_light <- function(system_id, color_map, weight = 0.25) {
  hex_to_argb(mix_with_white(sys_hex(system_id, color_map), weight))
}

.sys_argb_mid <- function(system_id, color_map, weight = 0.45) {
  hex_to_argb(mix_with_white(sys_hex(system_id, color_map), weight))
}
