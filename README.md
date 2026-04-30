
<!-- README.md is generated from README.Rmd. Please edit that file -->

# anaR <img src="man/figures/logo.svg" align="right" height="139" alt="" />

<!-- badges: start -->

[![R-CMD-check](https://github.com/gnoblet/anaR/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/gnoblet/anaR/actions/workflows/R-CMD-check.yaml)
[![Lifecycle:
experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
<!-- badges: end -->

**anaR** ports the core processing pipeline of the [ANA SvelteKit
dashboard](https://gnoblet.github.io/ANA_app_svelte/) to R: CSV
validation against a reference metric framework, threshold-based
flagging with rollup from metric to system level, and Excel deep-dive
export.

## Installation

### With rv (recommended)

[rv](https://github.com/A2-ai/rv) is a fast R package manager. Add anaR
to your `rproject.toml`:

``` toml
[project]
name = "my-analysis"
r_version = "4.6"

repositories = [
    { alias = "CRAN", url = "https://p3m.dev/cran/latest" }
]

dependencies = [
    { name = "anaR", git = "https://github.com/gnoblet/anaR.git" }
]
```

Then sync:

``` bash
rv sync
```

### With devtools

``` r
devtools::install_github("gnoblet/anaR")
```

## Quick start

``` r
library(anaR)

# Load the built-in reference JSON
ref <- get_default_reference()
```

### 1. Validate a CSV

``` r
parsed   <- readr::read_csv("my_data.csv")
header   <- names(parsed)
rows     <- as.list(as.data.frame(t(parsed)))
metric_map <- ref$metric_map   # flat list keyed by MET001, MET002, ...

result <- validate_csv(header, rows, metric_map)
result$ok            # TRUE / FALSE
result$header_errors # character vector of structural issues
result$cell_errors   # data frame of per-cell type violations
result$missingness_map
```

### 2. Flag data

``` r
# Pass the validated numeric data frame directly
flagged <- flag_data(result$numeric_df, ref$reference_json)

# Inspect prelim flags
dplyr::count(flagged, prelim_flag)
```

`prelim_flag` takes one of: `em`, `roem`, `acute`, `acute_needs`,
`insufficient_evidence`, `no_data`.

### 3. Export a deep-dive workbook

``` r
# One XLSX per unit of analysis
uoa_names <- unique(flagged$uoa)

purrr::walk(uoa_names, function(u) {
  uoa_row <- dplyr::filter(flagged, uoa == u)
  build_deep_dive(
    uoa_row         = uoa_row,
    ref             = ref$reference_json,
    hypotheses_data = list(),   # optional analyst hypotheses
    path            = file.path("deep_dives", paste0(u, ".xlsx"))
  )
})
```

## Colour helpers

The package exposes the system colour palette used by the dashboard and
several utility functions for Excel formatting:

``` r
cm <- default_color_map()
sys_hex("mortality", cm)          # "#460603"
sys_text_color("food_systems", cm) # "#000000"  (dark text on light green)
hex_to_argb("#355975")            # "FF355975"
mix_with_white("#355975", 0.4)    # lighter tint
```

## Documentation

Full function reference and vignettes are available at
<http://guillaume-noblet.com/anaR/>.

## Related

- [ANA SvelteKit dashboard](https://gnoblet.github.io/ANA_app_svelte/) —
  the browser-based counterpart
- [rv package manager](https://github.com/A2-ai/rv) — fast,
  lock-file-based R dependency management
