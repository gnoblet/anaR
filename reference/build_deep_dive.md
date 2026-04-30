# Build a deep-dive Excel workbook for a single unit of analysis

Generates one worksheet per system (filtered to systems present in
`hypotheses_data`) plus a "Summary" landing page with cross-sheet
INDIRECT formulas.

## Usage

``` r
build_deep_dive(
  uoa_row,
  ref,
  hypotheses_data,
  path,
  color_map = default_color_map()
)
```

## Arguments

- uoa_row:

  A named list or single-row data frame (e.g. one row from
  [`flag_data()`](http://guillaume-noblet.com/anaR/reference/flag_data.md)
  output).

- ref:

  The reference list from
  [`get_default_reference()`](http://guillaume-noblet.com/anaR/reference/get_default_reference.md).

- hypotheses_data:

  A list of system-hypothesis entries; each entry is a list with
  `systemId`, `systemLabel`, and `hypotheses` (a list of
  `list(id, description)` entries).

- path:

  File path for the output `.xlsx` file.

- color_map:

  Named character vector of system hex colours; defaults to
  [`default_color_map()`](http://guillaume-noblet.com/anaR/reference/default_color_map.md).

## Value

`path`, invisibly.
