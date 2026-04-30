# CLAUDE.md

Guidance for Claude Code when working in this repository.

## Project

**anaR** is an R package that ports the ANA SvelteKit dashboard’s core
pipeline to R. See `DESCRIPTION` for the dependency list and `R/` for
sources.

## r-skills in use

This project uses the following skills from the **r-skills** plugin:

| Skill                    | Purpose                                                     |
|--------------------------|-------------------------------------------------------------|
| `r-skills:plan`          | Design phased implementation plans before writing any code  |
| `r-skills:tdd-guide`     | Write failing tests first, then implement (testthat 3.0)    |
| `r-skills:code-reviewer` | Review for security, quality, and idiomatic R after writing |
| `r-skills:r-oop`         | Guide OOP decisions (S3 / S7 / vctrs) when relevant         |

Invoke them with the corresponding slash command: `/plan`, `/tdd`,
`/code-review`.

## Package manager — rv

Dependencies are managed with [rv](https://github.com/A2-ai/rv), not
renv.

- **`rproject.toml`** — declares R version, repositories, and
  dependencies
- **`rv.lock`** — generated lock file (commit this)
- **`rv/`** — local package cache (do not commit — already in
  `.gitignore`)

Common commands:

``` bash
rv sync          # install / update to match rproject.toml + rv.lock
rv add dplyr     # add a dependency and re-lock
rv remove foo    # remove a dependency
```

Do **not** run `renv::init()` or create `renv.lock` — rv is the single
source of truth.

## pkgdown / GitHub Pages

The package website is built with pkgdown and deployed to GitHub Pages
at <http://guillaume-noblet.com/anaR/>.

Configuration lives in `_pkgdown.yml`. The site uses:

- Bootstrap 5 via bslib
- Brand accent colour `#355975` (navy blue) for navbar, headings, and
  links
- Logo at `man/figures/logo.svg`

To preview locally:

``` r
pkgdown::build_site()
```

The GitHub Actions workflow (`.github/workflows/pkgdown.yaml`) builds
and pushes the site on every push to `main`.

## Development workflow

``` r
devtools::load_all()   # load package in development
devtools::test()       # run testthat suite
devtools::check()      # full R CMD check
devtools::document()   # rebuild roxygen docs + NAMESPACE
pkgdown::build_site()  # rebuild docs website
```

## Style

- Native pipe `|>` — no magrittr `%>%`
- snake_case for all functions and variables
- No comments unless the *why* is non-obvious
- Export only the public API (annotate with `@export` in roxygen)
- Suppress NSE `R CMD check` NOTEs via
  [`utils::globalVariables()`](https://rdrr.io/r/utils/globalVariables.html)
  in `R/utils.R`
