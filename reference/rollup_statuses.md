# Roll up a vector of status strings to a single status

Priority: `flag > no_flag > insufficient_evidence > no_data`. A mix of
`no_flag` and `no_data` (or `insufficient_evidence`) collapses to
`insufficient_evidence`.

## Usage

``` r
rollup_statuses(statuses)
```

## Arguments

- statuses:

  A character vector of status values.

## Value

A single status string.
