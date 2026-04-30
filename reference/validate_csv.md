# Validate a CSV data frame against the ANA metric map

Checks header structure, UOA uniqueness, and per-cell type constraints.
Returns an `ana_validation_result` object with full error detail.

## Usage

``` r
validate_csv(df, metric_map, opts = list())
```

## Arguments

- df:

  A `data.frame` (or tibble) with one row per unit of analysis. All
  values are expected to be character strings or `NA` (as produced by
  [`readr::read_csv()`](https://readr.tidyverse.org/reference/read_delim.html)
  with `col_types = cols(.default = "c")`), but numeric columns are also
  accepted and coerced to character for checking.

- metric_map:

  A named list keyed by metric ID (e.g. `"MET001"`). Each value must be
  a list with at least a `type` element (the type string used for
  cell-level validation).

- opts:

  A list of options:

  - `require_non_empty` (logical, default `FALSE`): if `TRUE`, empty
    cells are treated as errors rather than missing values.

## Value

An `ana_validation_result` list with elements: `ok`, `header_errors`,
`cell_errors` (tibble), `warnings`, `duplicate_uoas`, `missingness`
(tibble), `metadata_cols`, `meta`.
