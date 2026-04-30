# Build a list of subfactor entries with metric codes and threshold groups

Each entry covers one subfactor and contains the three-part
dot-separated path, all metric IDs under that subfactor, and the
threshold groups derived from `(factor_threshold, evidence_threshold)`
pairs.

## Usage

``` r
build_subfactor_list(json)
```

## Arguments

- json:

  Parsed reference JSON list.

## Value

A list of entries, each a list with `path` (character), `codes`
(character vector), and `groups` (list of threshold-group lists).

## Details

This function is a convenience wrapper around
[`build_metric_meta_df()`](http://guillaume-noblet.com/anaR/reference/build_metric_meta_df.md)
kept for compatibility. Prefer
[`build_metric_meta_df()`](http://guillaume-noblet.com/anaR/reference/build_metric_meta_df.md)
for pipeline work.
