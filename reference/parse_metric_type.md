# Parse an ANA metric type string

Converts a type string such as `"num[0:1]"` or `"int[0+]"` into its
component parts.

## Usage

``` r
parse_metric_type(type_str)
```

## Arguments

- type_str:

  A single character string (e.g. `"num"`, `"int[0+]"`, `"num[0:1]"`).
  Returns `NULL` for unrecognised formats, `NA`, or `""`.

## Value

A list with elements `base` (`"num"` or `"int"`), `lb` (numeric or
`NULL`), `ub` (numeric or `NULL`), `is_open` (logical), or `NULL` if the
format is not recognised.
