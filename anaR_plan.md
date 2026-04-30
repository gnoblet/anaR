# Implementation Plan: anaR R Package

## Overview

A pure-R port of three TypeScript engine modules from the ANA SvelteKit
dashboard: CSV validation, threshold-based flagging, and Excel deep-dive
export. The package is standalone — it reads a parsed `reference.json`
list and operates on data frames. No Shiny, no SvelteKit coupling.

The R implementation does not aim for line-by-line parity with the
TypeScript source. Where a different design is cleaner in R, use it.

------------------------------------------------------------------------

## Deviations from TypeScript

These are intentional design differences — not bugs or omissions.

| Area                                                                                               | TypeScript approach                                                   | R approach                                                                                                                                                                                                                    | Reason                                                                                                       |
|----------------------------------------------------------------------------------------------------|-----------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------|
| **Flag pipeline shape**                                                                            | Wide data frame; one giant spec-object passed to `mutate(!!!exprs)`   | Long format throughout; `pivot_longer()` → join → `group_by()` + `summarise()` → `pivot_wider()`                                                                                                                              | Eliminates all metaprogramming; stages are independently testable                                            |
| **Metric metadata**                                                                                | Traversed from reference JSON on every call inside `makeMetricSpec()` | Pre-built as a tidy tibble ([`build_metric_meta_df()`](http://guillaume-noblet.com/anaR/reference/build_metric_meta_df.md)) once at pipeline entry; joined like any other table                                               | Centralises the schema; downstream stages join instead of traverse                                           |
| **Subfactor status**                                                                               | Per-row closure that loops over threshold groups                      | `group_by(uoa, subfactor_path, factor_threshold, evidence_threshold)` + `summarise()` then second `summarise()` rollup                                                                                                        | Natural group operation, no closures                                                                         |
| **prelim_flag**                                                                                    | Per-row function with `isFlagged()` closures                          | Stay long; `group_by(uoa)` + `summarise()` with vectorised boolean counts, then `case_when()` on scalars                                                                                                                      | No pivot, no `rowwise()`; fully vectorised, faster, testable without a wide frame                            |
| **reference data**                                                                                 | JSON file read at runtime from filesystem                             | Shipped as an internal package dataset (`R/sysdata.rda`) built from `data-raw/`; `read_reference_json()` accepts an optional path override                                                                                    | Standard R package pattern; no file path management at call site                                             |
| **Reference traversal**                                                                            | For-loops with early returns                                          | [`purrr::map_dfr()`](https://purrr.tidyverse.org/reference/map_dfr.html) chains                                                                                                                                               | Functional, composable, no mutable state                                                                     |
| **[`build_subfactor_list()`](http://guillaume-noblet.com/anaR/reference/build_subfactor_list.md)** | Primary data structure for the flag pipeline                          | Thin wrapper around [`build_metric_meta_df()`](http://guillaume-noblet.com/anaR/reference/build_metric_meta_df.md) for backward compatibility; not the primary interface                                                      | [`build_metric_meta_df()`](http://guillaume-noblet.com/anaR/reference/build_metric_meta_df.md) supersedes it |
| **Column naming**                                                                                  | `MET001_flag`, `subfactor.path.status` (dots from path)               | Same conventions preserved in `pivot_wider(names_glue = ...)`                                                                                                                                                                 | Output compatibility with any downstream tooling that reads the TS format                                    |
| **Intermediate results**                                                                           | Not exposed                                                           | [`flag_data()`](http://guillaume-noblet.com/anaR/reference/flag_data.md) returns the final wide tibble; internal stages (`metrics_long`, `subfactor_statuses`, etc.) available as unexported functions if debugging is needed | Easier to test and inspect each layer                                                                        |

------------------------------------------------------------------------

## Directory Structure

    /home/gnoblet/Documents/GitHub/anaR/
    ├── DESCRIPTION
    ├── NAMESPACE                            # auto-generated by roxygen2
    ├── R/
    │   ├── metric_metadata.R                # ← metricMetadata.ts
    │   ├── validate.R                       # ← validator.ts
    │   ├── flag.R                           # ← flagger.ts
    │   ├── deepdive.R                       # ← deepdive.ts (main builder)
    │   ├── deepdive_colors.R                # ← deepdive.ts colour helpers
    │   ├── utils.R                          # shared internal helpers
    │   └── sysdata.rda                      # internal dataset: ana_reference (built by data-raw/)
    ├── data-raw/
    │   ├── reference.json                   # canonical ANA reference — source of truth
    │   └── prep_reference.R                 # reads reference.json, saves ana_reference to sysdata.rda
    ├── tests/
    │   └── testthat/
    │       ├── helper-fixtures.R            # shared minimal reference list + sample tibbles
    │       ├── fixtures/
    │       │   └── reference_minimal.json   # small hand-authored fixture for unit tests
    │       ├── test-metric-metadata.R
    │       ├── test-validate.R
    │       ├── test-flag.R
    │       └── test-deepdive-colors.R
    └── .Rbuildignore

------------------------------------------------------------------------

## DESCRIPTION

    Package: anaR
    Title: Acute Needs Analysis Engine
    Version: 0.1.0
    Description: Validates, flags, and exports ANA humanitarian data.
    License: MIT + file LICENSE
    Encoding: UTF-8
    Roxygen: list(markdown = TRUE)
    RoxygenNote: 7.3.2
    Imports:
        cli (>= 3.6.0),
        dplyr (>= 1.1.0),
        jsonlite (>= 1.8.0),
        openxlsx2 (>= 1.1),
        purrr (>= 1.0.0),
        readr (>= 2.1.0),
        rlang (>= 1.1.0),
        tibble (>= 3.2.0),
        tidyr (>= 1.3.0)
    Suggests:
        testthat (>= 3.0.0)
    Config/testthat/edition: 3

------------------------------------------------------------------------

## OOP Design

**S3 only** — no S7 or S4. These objects are data containers, not class
hierarchies. S3 gives
[`print()`](https://rdrr.io/r/base/print.html)/[`summary()`](https://rdrr.io/r/base/summary.html)
dispatch for free with zero overhead.

| Object                                                                                | Class                             | Notes                                                                                                                                                                                                                                  |
|---------------------------------------------------------------------------------------|-----------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| [`validate_csv()`](http://guillaume-noblet.com/anaR/reference/validate_csv.md) result | `ana_validation_result` (S3 list) | `print.ana_validation_result()` shows compact status + counts                                                                                                                                                                          |
| [`flag_data()`](http://guillaume-noblet.com/anaR/reference/flag_data.md) result       | plain `tibble`                    | Already a data frame; no class needed                                                                                                                                                                                                  |
| `ana_reference` internal dataset                                                      | plain named `list`                | Built from `data-raw/` via `usethis::use_data(internal = TRUE)`; returned by [`get_default_reference()`](http://guillaume-noblet.com/anaR/reference/get_default_reference.md); `read_reference_json(path)` still accepts a custom path |

------------------------------------------------------------------------

## File → TypeScript Module Mapping

| R file                      | TypeScript source                                       | Public exports                                                                                                                                                                                                                                                                                                                                                                           |
|-----------------------------|---------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `metric_metadata.R`         | `metricMetadata.ts`                                     | [`get_all_metric_ids()`](http://guillaume-noblet.com/anaR/reference/get_all_metric_ids.md), [`build_metric_meta_df()`](http://guillaume-noblet.com/anaR/reference/build_metric_meta_df.md), [`build_subfactor_list()`](http://guillaume-noblet.com/anaR/reference/build_subfactor_list.md), [`get_metric_metadata()`](http://guillaume-noblet.com/anaR/reference/get_metric_metadata.md) |
| `validate.R`                | `validator.ts` + type-string parser from `structure.ts` | [`validate_csv()`](http://guillaume-noblet.com/anaR/reference/validate_csv.md), `read_reference_json()`, [`get_default_reference()`](http://guillaume-noblet.com/anaR/reference/get_default_reference.md)                                                                                                                                                                                |
| `data-raw/prep_reference.R` | — (new)                                                 | Script run by maintainer; writes `ana_reference` to `R/sysdata.rda`                                                                                                                                                                                                                                                                                                                      |
| `flag.R`                    | `flagger.ts`                                            | [`flag_data()`](http://guillaume-noblet.com/anaR/reference/flag_data.md)                                                                                                                                                                                                                                                                                                                 |
| `deepdive.R`                | `deepdive.ts` (workbook builder)                        | [`build_deep_dive()`](http://guillaume-noblet.com/anaR/reference/build_deep_dive.md)                                                                                                                                                                                                                                                                                                     |
| `deepdive_colors.R`         | deepdive.ts colour helpers                              | internal only                                                                                                                                                                                                                                                                                                                                                                            |
| `utils.R`                   | —                                                       | internal only                                                                                                                                                                                                                                                                                                                                                                            |

------------------------------------------------------------------------

## GitHub & Git Setup

### 0. Prerequisites

``` bash
# Confirm gh CLI is authenticated
gh auth status

# Confirm git identity
git config --global user.name
git config --global user.email
```

### 0a. Create the local package directory

``` bash
mkdir -p /home/gnoblet/Documents/GitHub/anaR
cd /home/gnoblet/Documents/GitHub/anaR
```

### 0b. Create GitHub repository

``` bash
# Create public repo on GitHub (adjust --private if preferred)
gh repo create gnoblet/anaR \
  --public \
  --description "Acute Needs Analysis engine: CSV validation, flagging, and Excel export" \
  --clone=false

# Initialise git, add remote, set main branch
git init -b main
git remote add origin https://github.com/gnoblet/anaR.git
```

### 0c. Initial commit after scaffold

After Phase 1 scaffold (usethis), push the skeleton:

``` bash
cd /home/gnoblet/Documents/GitHub/anaR
git add .
git commit -m "chore: initialise anaR package scaffold"
git push -u origin main
```

### Branch workflow (one branch per phase)

``` bash
# Phase 1
git checkout -b feat/metric-metadata
# ... implement + tests ...
git add R/metric_metadata.R tests/testthat/test-metric-metadata.R
git commit -m "feat: add metric_metadata traversal functions"
gh pr create --title "feat: metric_metadata traversal" \
  --body "Ports metricMetadata.ts: get_all_metric_ids, build_metric_meta_df, build_subfactor_list, get_metric_metadata."
gh pr merge --squash --delete-branch

# Phase 2
git checkout main && git pull
git checkout -b feat/validate
gh pr create --title "feat: validate_csv pipeline"
gh pr merge --squash --delete-branch

# Phase 3
git checkout main && git pull
git checkout -b feat/flag
gh pr create --title "feat: flag_data pipeline"
gh pr merge --squash --delete-branch

# Phase 4
git checkout main && git pull
git checkout -b feat/deepdive
gh pr create --title "feat: build_deep_dive Excel export"
gh pr merge --squash --delete-branch
```

### Tagging a release

``` bash
# After all four phases merge to main
git checkout main && git pull
git tag -a v0.1.0 -m "Initial release: validate, flag, deepdive"
git push origin v0.1.0

# Create a GitHub release from the tag
gh release create v0.1.0 \
  --title "v0.1.0 — Initial release" \
  --notes "First release: CSV validation, ANA flagging pipeline, and Excel deep-dive export."
```

------------------------------------------------------------------------

## Implementation Phases

### Phase 1 — Scaffold + `metric_metadata.R`

**Goal:** working package skeleton; all metadata traversal functions
tested and green. Adds
[`build_metric_meta_df()`](http://guillaume-noblet.com/anaR/reference/build_metric_meta_df.md)
— a new function (no TS equivalent) that flattens the reference JSON
into a tidy tibble used downstream by the flag pipeline.

1.  From R, scaffold with usethis:

    ``` r
    usethis::create_package("/home/gnoblet/Documents/GitHub/anaR")
    usethis::use_testthat()
    usethis::use_mit_license()
    usethis::use_roxygen_md()
    usethis::use_package("cli")
    usethis::use_package("dplyr")
    usethis::use_package("jsonlite")
    usethis::use_package("purrr")
    usethis::use_package("readr")
    usethis::use_package("rlang")
    usethis::use_package("tibble")
    usethis::use_package("tidyr")
    usethis::use_package("openxlsx2")
    ```

2.  Set up `data-raw/`:

    ``` r
    usethis::use_data_raw("reference")
    # creates data-raw/reference.R — rename to prep_reference.R
    ```

    Copy `reference.json` from the ANA app
    (`static/data/reference.json`) into `data-raw/reference.json`. Write
    `data-raw/prep_reference.R`:

    ``` r
    # data-raw/prep_reference.R — run once by maintainer after any reference update
    ana_reference <- jsonlite::read_json("data-raw/reference.json", simplifyVector = FALSE)
    usethis::use_data(ana_reference, internal = TRUE, overwrite = TRUE)
    # writes R/sysdata.rda — committed to the package
    ```

    Run the script once to generate `R/sysdata.rda`.

    Add to `validate.R` (or `utils.R`):

    ``` r
    # Returns the bundled reference JSON list. Accepts an optional path to load a
    # custom reference.json instead.
    get_default_reference <- function(path = NULL) {
      if (!is.null(path)) return(jsonlite::read_json(path, simplifyVector = FALSE))
      ana_reference  # the internal dataset from sysdata.rda
    }
    ```

    Add `data-raw/` and `data-raw/reference.json` to `.Rbuildignore`
    (the script and source JSON are for maintainers only; `sysdata.rda`
    is what ships):

    ``` r
    usethis::use_build_ignore("data-raw")
    ```

3.  Create `tests/testthat/fixtures/reference_minimal.json` — three
    systems (`mortality`, `health_outcomes`, `food_systems`), one factor
    each, one subfactor each, two metrics each. Include one preference-3
    metric. Ensure at least two metrics in the same subfactor use
    **different** `(factor_threshold, evidence_threshold)` pairs to
    exercise group splitting.

4.  Create `tests/testthat/helper-fixtures.R` — loads the fixture JSON
    once with
    [`jsonlite::read_json()`](https://jeroen.r-universe.dev/jsonlite/reference/read_json.html)
    and exposes minimal sample tibbles for reuse.

5.  **Write `tests/testthat/test-metric-metadata.R` first (TDD red):**

    - [`get_all_metric_ids()`](http://guillaume-noblet.com/anaR/reference/get_all_metric_ids.md)
      returns IDs in encounter order
    - [`get_all_metric_ids()`](http://guillaume-noblet.com/anaR/reference/get_all_metric_ids.md)
      on empty/invalid input → `character(0)`
    - [`build_metric_meta_df()`](http://guillaume-noblet.com/anaR/reference/build_metric_meta_df.md)
      returns a tibble with one row per metric and columns `metric_id`,
      `system_id`, `factor_id`, `subfactor_id`, `subfactor_path`,
      `factor_path`, `an_threshold`, `direction`, `preference`,
      `factor_threshold`, `evidence_threshold`
    - [`build_metric_meta_df()`](http://guillaume-noblet.com/anaR/reference/build_metric_meta_df.md)
      correctly splits threshold groups (metrics sharing the same pair
      go to the same group key)
    - [`build_subfactor_list()`](http://guillaume-noblet.com/anaR/reference/build_subfactor_list.md)
      produces correct `path`, `codes`, `groups` (kept for backward
      compatibility; delegates to
      [`build_metric_meta_df()`](http://guillaume-noblet.com/anaR/reference/build_metric_meta_df.md)
      internally)
    - [`get_metric_metadata()`](http://guillaume-noblet.com/anaR/reference/get_metric_metadata.md)
      finds a metric and returns path context
    - [`get_metric_metadata()`](http://guillaume-noblet.com/anaR/reference/get_metric_metadata.md)
      returns `NULL` for unknown IDs

6.  Implement `R/metric_metadata.R` using
    **[`purrr::map_dfr()`](https://purrr.tidyverse.org/reference/map_dfr.html)**
    to flatten the nested list tree into a tibble — no for-loops:

    ``` r
    build_metric_meta_df <- function(json) {
      purrr::map_dfr(json$systems, \(sys)
        purrr::map_dfr(sys$factors, \(fac)
          purrr::map_dfr(fac$sub_factors, \(sub)
            purrr::map_dfr(sub$indicators, \(ind)
              purrr::map_dfr(ind$metrics, \(met)
                tibble::tibble(
                  metric_id          = met$metric,
                  system_id          = sys$id,
                  factor_id          = fac$id,
                  subfactor_id       = sub$id,
                  subfactor_path     = paste(sys$id, fac$id, sub$id, sep = "."),
                  factor_path        = paste(sys$id, fac$id, sep = "."),
                  preference         = met$preference %||% 1L,
                  an_threshold       = met$thresholds$an %||% NA_real_,
                  direction          = met$above_or_below %||% NA_character_,
                  factor_threshold   = met$factor_threshold %||% 1L,
                  evidence_threshold = met$evidence_threshold %||% NA_real_
                )
              )
            )
          )
        )
      )
    }
    ```

    [`get_all_metric_ids()`](http://guillaume-noblet.com/anaR/reference/get_all_metric_ids.md)
    delegates to
    [`build_metric_meta_df()`](http://guillaume-noblet.com/anaR/reference/build_metric_meta_df.md)
    and returns `metric_meta_df$metric_id` in encounter order (deduped
    with
    [`dplyr::distinct()`](https://dplyr.tidyverse.org/reference/distinct.html)).

7.  `devtools::check()` — 0 errors, 0 warnings, 0 notes.

8.  Push branch + open PR.

------------------------------------------------------------------------

### Phase 2 — `validate.R`

**Goal:** full CSV validation pipeline using tidy column-oriented
operations instead of per-row imperative loops.

1.  **Write `tests/testthat/test-validate.R` first (TDD red):**

    - `parse_metric_type("num")` →
      `list(base="num", lb=NULL, ub=NULL, is_open=FALSE)`
    - `parse_metric_type("int[0+]")` →
      `list(base="int", lb=0, ub=NULL, is_open=TRUE)`
    - `parse_metric_type("num[0:1]")` →
      `list(base="num", lb=0, ub=1, is_open=FALSE)`
    - `parse_metric_type("garbage")` → `NULL`
    - Missing `uoa` column → `ok = FALSE`, `header_errors` non-empty
    - Duplicate UOA → `ok = FALSE`, cell errors for each affected row
    - String value in `num` column → cell error
    - Float value in `int[0+]` column → cell error
    - Out-of-range value → cell error with human-readable message
    - Empty cell, `require_non_empty = FALSE` → warning not error,
      counted in missingness
    - Unknown columns become `metadata_cols`, not errors
    - `print.ana_validation_result()` — smoke test (no error, produces
      output)

2.  Implement `R/validate.R` using **tidy column operations**
    throughout:

    - Internal: `parse_metric_type(type_str)` — regex port of the TS
      type parser
    - Internal: `check_cell_str(value, type)` — vectorised-safe; returns
      an error string or `NA_character_` (used with
      [`purrr::map2_chr()`](https://purrr.tidyverse.org/reference/map2.html))
    - Internal: `human_readable_type(parsed)` — error message builder
    - Internal: `new_validation_result(...)` — S3 constructor
    - Public: `validate_csv(df, metric_map, opts)` — accepts a
      `data.frame`
    - Public: `read_reference_json(path)` — thin
      [`jsonlite::read_json()`](https://jeroen.r-universe.dev/jsonlite/reference/read_json.html)
      wrapper
    - S3: `print.ana_validation_result()` — one-line status + counts

    **Duplicate UOA detection** — group and filter, no row loops:

    ``` r
    duplicate_uoas <- df |>
      dplyr::mutate(.row = dplyr::row_number() + 1L) |>
      dplyr::group_by(uoa) |>
      dplyr::filter(dplyr::n() > 1) |>
      dplyr::summarise(rows = list(.row), .groups = "drop")
    ```

    **Missingness summary** — `summarise(across(...))` +
    `pivot_longer()`:

    ``` r
    missingness <- df |>
      dplyr::summarise(dplyr::across(
        dplyr::all_of(metric_cols),
        list(total = \(x) dplyr::n(), missing = \(x) sum(is.na(x) | x == ""))
      )) |>
      tidyr::pivot_longer(
        dplyr::everything(),
        names_to      = c("metric", ".value"),
        names_pattern = "(.+)_(total|missing)"
      )
    ```

    **Cell error detection** — pivot to long, join type map, vectorised
    check:

    ``` r
    cell_errors <- df |>
      dplyr::mutate(.row = dplyr::row_number() + 1L) |>
      tidyr::pivot_longer(
        cols      = dplyr::all_of(metric_cols),
        names_to  = "col_name",
        values_to = "value_raw"
      ) |>
      dplyr::left_join(metric_type_df, by = "col_name") |>
      dplyr::mutate(
        error_msg = purrr::map2_chr(value_raw, type, check_cell_str)
      ) |>
      dplyr::filter(!is.na(error_msg)) |>
      dplyr::select(row = .row, col_name, value = value_raw, message = error_msg)
    ```

3.  `devtools::check()` passes. Push branch + open PR.

------------------------------------------------------------------------

### Phase 3 — `flag.R`

**Goal:** exact behavioural parity with `flagger.ts` via a long-format
pipeline. No spec-object metaprogramming — pivot to long, join metadata,
aggregate, pivot wide.

The TS pattern of building dynamic spec objects and calling
`mutate(!!!exprs_list)` is replaced by a pipeline that uses
`pivot_longer()` → `group_by()` + `summarise()` → `pivot_wider()` at
each rollup level, and `rowwise()` + `c_across()` for the multi-system
prelim_flag step.

1.  **Write `tests/testthat/test-flag.R` first (TDD red):**

    - `rollup_statuses(c("flag", "no_flag"))` → `"flag"`
    - `rollup_statuses(c("no_data", "no_data"))` → `"no_data"` (not
      `"insufficient_evidence"`)
    - `rollup_statuses(c("no_flag", "insufficient_evidence"))` →
      `"insufficient_evidence"`
    - `rollup_statuses(character(0))` → `"no_data"`
    - [`evaluate_group_status()`](http://guillaume-noblet.com/anaR/reference/evaluate_group_status.md)
      — flag_n ≥ factor_threshold → `"flag"`
    - [`evaluate_group_status()`](http://guillaume-noblet.com/anaR/reference/evaluate_group_status.md)
      — data_n ≥ evidence_threshold, no flag → `"no_flag"`
    - [`evaluate_group_status()`](http://guillaume-noblet.com/anaR/reference/evaluate_group_status.md)
      — some data, below evidence threshold → `"insufficient_evidence"`
    - [`evaluate_group_status()`](http://guillaume-noblet.com/anaR/reference/evaluate_group_status.md)
      — data_n == 0 → `"no_data"`
    - [`flag_data()`](http://guillaume-noblet.com/anaR/reference/flag_data.md)
      — preference-3 metrics excluded from output flags
    - [`flag_data()`](http://guillaume-noblet.com/anaR/reference/flag_data.md)
      — `MET001_flag`, `MET001_status`, `MET001_within_10perc` computed
      correctly
    - [`flag_data()`](http://guillaume-noblet.com/anaR/reference/flag_data.md)
      — `prelim_flag = "em"` when mortality flagged
    - [`flag_data()`](http://guillaume-noblet.com/anaR/reference/flag_data.md)
      — `prelim_flag = "roem"` when health_outcomes + ≥3 others flagged
    - [`flag_data()`](http://guillaume-noblet.com/anaR/reference/flag_data.md)
      — `prelim_flag = "acute"` when any classification system flagged
    - [`flag_data()`](http://guillaume-noblet.com/anaR/reference/flag_data.md)
      — `prelim_flag = "no_data"` when all classification systems have
      no data
    - [`flag_data()`](http://guillaume-noblet.com/anaR/reference/flag_data.md)
      — throws if `mortality` or `health_outcomes` absent from reference
    - [`flag_data()`](http://guillaume-noblet.com/anaR/reference/flag_data.md)
      — empty input returns zero-row tibble without error

2.  Implement `R/flag.R` — five pipeline stages:

    **Stage 1 — metric-level flags** (vectorised `mutate()`, no loops):

    ``` r
    # Build flat metadata tibble once (from Phase 1)
    meta <- build_metric_meta_df(reference_json) |>
      dplyr::filter(preference != 3L)

    canonical_ids <- meta$metric_id

    # Pivot to long, join metadata, compute four derived columns
    metrics_long <- items_df |>
      tidyr::pivot_longer(
        cols         = dplyr::any_of(canonical_ids),
        names_to     = "metric_id",
        values_to    = "value",
        values_transform = list(value = as.numeric)
      ) |>
      dplyr::left_join(meta, by = "metric_id") |>
      dplyr::mutate(
        flag = dplyr::case_when(
          is.na(an_threshold) | is.na(direction) ~ NA,
          is.na(value)                            ~ NA,
          direction == "Above"                    ~ value >= an_threshold,
          direction == "Below"                    ~ value <= an_threshold
        ),
        status = dplyr::case_when(
          is.na(flag) ~ "no_data",
          flag        ~ "flag",
          .default    = "no_flag"
        ),
        within_10perc = dplyr::case_when(
          is.na(an_threshold) | is.na(value) ~ NA,
          an_threshold == 0                   ~ value == 0,
          .default = abs((value - an_threshold) / an_threshold) <= 0.1
        ),
        within_10perc_change = dplyr::case_when(
          is.na(an_threshold) | is.na(direction) |
            an_threshold == 0 | is.na(value)     ~ NA,
          .default = {
            pct <- abs((value - an_threshold) / an_threshold)
            met <- dplyr::if_else(
              direction == "Above", value >= an_threshold, value <= an_threshold
            )
            pct <= 0.1 & !met
          }
        )
      )
    ```

    **Stage 2 — subfactor status** (group by threshold group, then
    rollup):

    ``` r
    # One row per (uoa, subfactor_path, threshold_group)
    group_statuses <- metrics_long |>
      dplyr::group_by(uoa, subfactor_path, factor_threshold, evidence_threshold) |>
      dplyr::summarise(
        flag_n    = sum(flag == TRUE,  na.rm = TRUE),
        no_flag_n = sum(flag == FALSE, na.rm = TRUE),
        data_n    = flag_n + no_flag_n,
        group_status = evaluate_group_status(flag_n, no_flag_n, data_n,
                                             factor_threshold, evidence_threshold),
        .groups = "drop"
      )

    subfactor_statuses <- group_statuses |>
      dplyr::group_by(uoa, subfactor_path) |>
      dplyr::summarise(
        subfactor_status = rollup_statuses(group_status),
        .groups = "drop"
      )

    # Counts for heatmap columns
    subfactor_counts <- metrics_long |>
      dplyr::group_by(uoa, subfactor_path) |>
      dplyr::summarise(
        missing_n = sum(is.na(value)),
        flag_n    = sum(flag == TRUE,  na.rm = TRUE),
        no_flag_n = sum(flag == FALSE, na.rm = TRUE),
        .groups = "drop"
      )
    ```

    **Stage 3 — factor status** (rollup from subfactor statuses):

    ``` r
    factor_statuses <- subfactor_statuses |>
      dplyr::left_join(
        dplyr::distinct(meta, subfactor_path, factor_path),
        by = "subfactor_path"
      ) |>
      dplyr::group_by(uoa, factor_path) |>
      dplyr::summarise(
        factor_status = rollup_statuses(subfactor_status),
        .groups = "drop"
      )
    ```

    **Stage 4 — system status** (rollup from factor statuses):

    ``` r
    system_statuses <- factor_statuses |>
      dplyr::left_join(
        dplyr::distinct(meta, factor_path, system_id),
        by = "factor_path"
      ) |>
      dplyr::group_by(uoa, system_id) |>
      dplyr::summarise(
        system_status = rollup_statuses(factor_status),
        .groups = "drop"
      )
    ```

    **Stage 5 — prelim_flag** — stay long, one `group_by(uoa)` +
    `summarise()`, no pivot and no `rowwise()`. Inside `summarise()` the
    column vectors for the current group are available, so all
    comparisons are standard vectorised R:

    ``` r
    # classification_ids = all system IDs except mortality and market_functionality
    # ho_id             = health_outcomes_id (a scalar string)

    prelim_flags <- system_statuses |>
      dplyr::group_by(uoa) |>
      dplyr::summarise(
        .mortality_flagged = any(system_id == mortality_id    & system_status == "flag"),
        .ho_flagged        = any(system_id == ho_id           & system_status == "flag"),
        .n_other_flagged   = sum(
          system_id %in% setdiff(classification_ids, ho_id)  & system_status == "flag"
        ),
        .any_class_flagged = any(system_id %in% classification_ids & system_status == "flag"),
        .any_class_insuff  = any(
          system_id %in% classification_ids & system_status == "insufficient_evidence"
        ),
        .all_class_no_data = all(
          system_status[system_id %in% classification_ids] == "no_data"
        ),
        .groups = "drop"
      ) |>
      dplyr::mutate(
        prelim_flag = dplyr::case_when(
          .mortality_flagged                          ~ "em",
          .ho_flagged & .n_other_flagged >= 3        ~ "roem",
          .any_class_flagged                         ~ "acute",
          .any_class_insuff                          ~ "insufficient_evidence",
          .all_class_no_data                         ~ "no_data",
          .default                                   = "acute_needs"
        )
      ) |>
      dplyr::select(uoa, prelim_flag)
    ```

    [`compute_prelim_flags()`](http://guillaume-noblet.com/anaR/reference/compute_prelim_flags.md)
    takes `system_statuses`, `mortality_id`, `ho_id`, and
    `classification_ids` as arguments — all derived from the reference
    JSON once at pipeline entry, not repeated per row.

    **Final join** — pivot each level wide, join back to the original
    frame:

    ``` r
    metrics_wide <- metrics_long |>
      dplyr::select(uoa, metric_id, flag, status, within_10perc, within_10perc_change) |>
      tidyr::pivot_wider(
        names_from  = metric_id,
        values_from = c(flag, status, within_10perc, within_10perc_change),
        names_glue  = "{metric_id}_{.value}"
      )

    subfactor_wide <- subfactor_statuses |>
      tidyr::pivot_wider(
        names_from  = subfactor_path,
        values_from = subfactor_status,
        names_glue  = "{subfactor_path}.status"
      ) |>
      dplyr::left_join(
        subfactor_counts |>
          tidyr::pivot_wider(
            names_from  = subfactor_path,
            values_from = c(flag_n, no_flag_n, missing_n),
            names_glue  = "{subfactor_path}.{.value}"
          ),
        by = "uoa"
      )

    # (factor_wide and system_wide follow the same pattern)

    items_df |>
      dplyr::select(uoa, dplyr::any_of(metadata_cols)) |>
      dplyr::left_join(metrics_wide,    by = "uoa") |>
      dplyr::left_join(subfactor_wide,  by = "uoa") |>
      dplyr::left_join(factor_wide,     by = "uoa") |>
      dplyr::left_join(system_wide,     by = "uoa") |>
      dplyr::left_join(prelim_flags,    by = "uoa")
    ```

    Internal helpers:

    - `rollup_statuses(statuses)` — pure function operating on a
      character vector; no dplyr needed, called inside `summarise()`
    - `evaluate_group_status(flag_n, no_flag_n, data_n, ft, et)` —
      scalar inputs, called inside `summarise()` after aggregation;
      returns a single status string
    - `flag_metrics_long(items_df, meta)` — unexported; returns
      `metrics_long`
    - `compute_subfactor_statuses(metrics_long, meta)` — unexported;
      returns `subfactor_statuses` tibble
    - `compute_factor_statuses(subfactor_statuses, meta)` — unexported
    - `compute_system_statuses(factor_statuses, meta)` — unexported
    - `compute_prelim_flags(system_statuses, mortality_id, health_outcomes_id, classification_ids)`
      — unexported; returns `prelim_flags` tibble with `uoa` +
      `prelim_flag`

    Each unexported stage function is tested independently — the
    integration test for
    [`flag_data()`](http://guillaume-noblet.com/anaR/reference/flag_data.md)
    just verifies end-to-end output correctness.

3.  `devtools::check()` passes. Push branch + open PR.

------------------------------------------------------------------------

### Phase 4 — `deepdive_colors.R` + `deepdive.R`

**Goal:** working Excel export; colour helpers fully tested; integration
smoke test for the workbook builder.

1.  Implement `R/deepdive_colors.R` (pure functions, no I/O):

    - `hex_to_argb(hex)` — prepend `"FF"`, uppercase
    - `mix_with_white(hex, weight)` — port of `mixWithWhite()`
    - `luminance(hex)` — port of
      [`luminance()`](http://guillaume-noblet.com/anaR/reference/luminance.md)
    - `sys_hex(system_id, color_map)` — looks up from a named character
      vector, falls back to `"#718096"`
    - `sys_argb()`, `sys_argb_light()`, `sys_argb_mid()`,
      `sys_text_argb()` — wrappers

2.  **Write `tests/testthat/test-deepdive-colors.R`:**

    - `hex_to_argb("#61d095")` → `"FF61D095"`
    - `mix_with_white("#000000", 0)` → `"#ffffff"`
    - `mix_with_white("#000000", 1)` → `"#000000"`
    - `luminance("#ffffff")` → approximately `1`
    - `luminance("#000000")` → `0`
    - `sys_text_argb("mortality", c(mortality = "#000000"))` →
      `"FFFFFFFF"`

3.  Implement `R/deepdive.R` using `openxlsx2`:

    - Internal row builders (direct ports of the TS `add*` functions):
      `add_system_header()`, `add_factor_row()`, `add_subfactor_row()`,
      `add_table_header_row()`, `add_indicator_row()`,
      `add_hypothesis_table()`, `add_summary_section()`,
      `add_landing_page()`

    - Use
      **[`purrr::walk()`](https://purrr.tidyverse.org/reference/map.html)**
      for side-effectful iteration over systems/factors/subfactors
      instead of for-loops, e.g.:

      ``` r
      purrr::walk(reference_json$systems, \(system) {
        ws <- workbook_add_sheet(wb, system$label)
        add_system_header(ws, system$label, uoa_id, color_map)
        purrr::walk(system$factors, \(factor) {
          add_factor_row(ws, factor, uoa_row, color_map)
          purrr::walk(factor$sub_factors, \(sub) {
            add_subfactor_row(ws, sub, uoa_row, color_map)
            add_table_header_row(ws, headers)
            purrr::walk(sub$indicators, \(ind)
              purrr::walk(ind$metrics, \(met)
                add_indicator_row(ws, met, uoa_row, hyp_count)
              )
            )
          })
        })
      })
      ```

    - Public:
      `build_deep_dive(uoa_row, reference_json, hypotheses_data, color_map, out_path)`
      — writes xlsx to `out_path`, returns `invisible(out_path)`

    - Public:
      [`default_color_map()`](http://guillaume-noblet.com/anaR/reference/default_color_map.md)
      — returns the same hex values as `app.css` as a named character
      vector; caller can override individual entries

    > **color_map note:** replaces
    > `getComputedStyle(document.documentElement)` from the TS original.
    > The caller provides system hex colours;
    > [`default_color_map()`](http://guillaume-noblet.com/anaR/reference/default_color_map.md)
    > ships sensible defaults.

4.  Integration smoke test — add to `test-deepdive-colors.R` or a
    separate `test-deepdive.R`: construct a minimal `uoa_row` tibble,
    call
    [`build_deep_dive()`](http://guillaume-noblet.com/anaR/reference/build_deep_dive.md)
    to a [`tempfile()`](https://rdrr.io/r/base/tempfile.html), assert
    the file exists and
    [`openxlsx2::wb_load()`](https://janmarvin.github.io/openxlsx2/reference/wb_load.html)
    opens it without error.

5.  `devtools::check()` passes. Push branch + open PR.

------------------------------------------------------------------------

## Testing Strategy

| Layer                                                                                                                                                                                  | Test type                                  | File                     |
|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|--------------------------------------------|--------------------------|
| `metric_metadata.R`                                                                                                                                                                    | Unit — pure traversal                      | `test-metric-metadata.R` |
| `validate.R` type parser                                                                                                                                                               | Unit — pure function                       | `test-validate.R`        |
| [`validate_csv()`](http://guillaume-noblet.com/anaR/reference/validate_csv.md)                                                                                                         | Unit + edge cases                          | `test-validate.R`        |
| [`rollup_statuses()`](http://guillaume-noblet.com/anaR/reference/rollup_statuses.md), [`evaluate_group_status()`](http://guillaume-noblet.com/anaR/reference/evaluate_group_status.md) | Unit                                       | `test-flag.R`            |
| [`flag_data()`](http://guillaume-noblet.com/anaR/reference/flag_data.md) pipeline                                                                                                      | Integration (fixture JSON + sample tibble) | `test-flag.R`            |
| `deepdive_colors.R`                                                                                                                                                                    | Unit — pure functions                      | `test-deepdive-colors.R` |
| [`build_deep_dive()`](http://guillaume-noblet.com/anaR/reference/build_deep_dive.md)                                                                                                   | Smoke — file written and loadable          | `test-deepdive-colors.R` |

**Fixture JSON** (`reference_minimal.json`) must include:

- Systems: `mortality`, `health_outcomes`, `food_systems` (minimum three
  for ROEM tests)
- One subfactor per system with at least two metrics in **different**
  threshold groups
- One preference-3 metric to verify exclusion from flagging

------------------------------------------------------------------------

## Risks & Mitigations

- **Risk**: `data-raw/reference.json` will drift out of sync with the
  ANA app’s `static/data/reference.json` as the framework evolves.
  - Mitigation: `data-raw/prep_reference.R` fetches the JSON directly
    from the ANA app repo rather than requiring a manual copy:

    ``` r
    # data-raw/prep_reference.R
    url <- paste0(
      "https://raw.githubusercontent.com/gnoblet/ANA_app_svelte/main/",
      "static/data/reference.json"
    )
    tmp <- tempfile(fileext = ".json")
    download.file(url, tmp, quiet = TRUE)
    ana_reference <- jsonlite::read_json(tmp, simplifyVector = FALSE)
    usethis::use_data(ana_reference, internal = TRUE, overwrite = TRUE)
    ```

    Re-run this script after any ANA app release that touches
    `reference.json`.
- **Risk**: `pivot_wider()` column names use `.` as separator in
  `subfactor_path`
  (e.g. `mortality.mortality_outcomes.under5_mortality`) — dots in
  column names are valid but can confuse
  [`dplyr::select()`](https://dplyr.tidyverse.org/reference/select.html)
  helpers.
  - Mitigation: use `names_glue` with explicit separators; test that
    output column names are stable and predictable.
- **Risk**: prelim_flag decision tree hard-codes three system IDs
  (`mortality`, `health_outcomes`, `market_functionality`). Missing IDs
  will throw.
  - Mitigation: fixture JSON always includes all three; explicit
    error-path tests cover the missing-system case.
- **Risk**: landing page Excel cross-sheet formulas (`=Sheet!C42`)
  depend on row numbers computed at write time — fragile to layout
  changes.
  - Mitigation: store synthesis row numbers in a `synthesis_rows` list
    (same as TS `SynthesisRows` type); integration smoke test validates
    the file opens, not formula values.
- **Risk**: `deepdive.R` was browser-dependent in TS (reads CSS
  variables). In R the caller passes `color_map`.
  - Mitigation:
    [`default_color_map()`](http://guillaume-noblet.com/anaR/reference/default_color_map.md)
    ships with the package so callers don’t need to know the hex values.

------------------------------------------------------------------------

## Success Criteria

`devtools::check()` — 0 errors, 0 warnings, 0 notes on a clean machine

`testthat::test_package("anaR")` — all tests green

[`validate_csv()`](http://guillaume-noblet.com/anaR/reference/validate_csv.md)
produces identical `ok`, `header_errors`, `cell_errors`, and
`missingness_map` for the same input as the TS `validateCsv()`

[`flag_data()`](http://guillaume-noblet.com/anaR/reference/flag_data.md)
produces identical `prelim_flag` values as the TS `flagData()` for the
same reference JSON and input rows

[`build_deep_dive()`](http://guillaume-noblet.com/anaR/reference/build_deep_dive.md)
produces an xlsx file that opens in Excel/LibreOffice without repair
prompt

All public functions documented with roxygen2;
[`?validate_csv`](http://guillaume-noblet.com/anaR/reference/validate_csv.md)
works

GitHub repository exists at `https://github.com/gnoblet/anaR`

Four phase PRs merged to `main` with squash commits

`v0.1.0` tag and GitHub release created
