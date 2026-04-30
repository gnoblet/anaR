# Flag a data frame of metric values against the ANA reference

Applies the five-stage flagging pipeline:

1.  Per-metric flag / status / within-10-percent columns

2.  Subfactor-level status (threshold-group rollup)

3.  Factor-level status

4.  System-level status

5.  Preliminary flag (`prelim_flag`) via ANA decision tree

## Usage

``` r
flag_data(df, ref)
```

## Arguments

- df:

  A `data.frame` or tibble with one row per unit of analysis (UOA) and
  one column per metric (e.g. `MET001`). A `uoa` column is expected but
  not strictly required by this function — extra columns are passed
  through.

- ref:

  The reference list returned by
  [`get_default_reference()`](http://guillaume-noblet.com/anaR/reference/get_default_reference.md).

## Value

A tibble with the original columns plus metric-, subfactor-, factor-,
system-, and `prelim_flag` columns appended.

## Details

Preference-3 metrics are excluded from all flagging stages.
