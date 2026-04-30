# Build a tidy tibble of metric metadata from reference JSON

Flattens the nested reference JSON (systems → factors → sub_factors →
indicators → metrics) into one row per metric. This tibble is the
central input for the flagging pipeline — downstream stages join against
it rather than re-traversing the JSON.

## Usage

``` r
build_metric_meta_df(json)
```

## Arguments

- json:

  Parsed reference JSON list.

## Value

A tibble with one row per metric and columns: `metric_id`, `system_id`,
`factor_id`, `subfactor_id`, `subfactor_path`, `factor_path`,
`preference`, `an_threshold`, `direction`, `factor_threshold`,
`evidence_threshold`.
