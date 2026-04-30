# Apply the ANA prelim-flag decision tree to system-level statuses

Apply the ANA prelim-flag decision tree to system-level statuses

## Usage

``` r
compute_prelim_flags(system_statuses, mortality_id, ho_id, classification_ids)
```

## Arguments

- system_statuses:

  A tibble with columns `uoa`, `system_id`, `system_status`.

- mortality_id:

  System ID for the mortality system (step 1 — EM).

- ho_id:

  System ID for the health-outcomes system (step 2 — ROEM).

- classification_ids:

  Character vector of system IDs that form the classification set
  (excludes `mortality_id` and `market_functionality`).

## Value

A tibble with columns `uoa` and `prelim_flag`.
