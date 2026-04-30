# Get all metric IDs from reference JSON

Returns metric IDs in encounter order (depth-first traversal),
deduplicated.

## Usage

``` r
get_all_metric_ids(json)
```

## Arguments

- json:

  Parsed reference JSON list.

## Value

Character vector of metric IDs (e.g. `"MET001"`).
