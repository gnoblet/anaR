# Evaluate flag status for a single threshold group

Evaluate flag status for a single threshold group

## Usage

``` r
evaluate_group_status(
  flag_n,
  no_flag_n,
  data_n,
  factor_threshold,
  evidence_threshold
)
```

## Arguments

- flag_n:

  Number of metrics with status `"flag"`.

- no_flag_n:

  Number of metrics with status `"no_flag"`.

- data_n:

  Total metrics with any data (`flag_n + no_flag_n`).

- factor_threshold:

  Minimum flag count to declare `"flag"`.

- evidence_threshold:

  Minimum data count to declare `"no_flag"`.

## Value

A single status string.
