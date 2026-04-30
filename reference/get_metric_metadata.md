# Get metadata for a single metric by ID

Get metadata for a single metric by ID

## Usage

``` r
get_metric_metadata(json, metric_id)
```

## Arguments

- json:

  Parsed reference JSON list.

- metric_id:

  Canonical metric ID string (e.g. `"MET001"`).

## Value

A list with elements `metric_id`, `system_id`, `factor_id`,
`subfactor_id`, and `raw` (the original metric list node), or `NULL` if
not found.
