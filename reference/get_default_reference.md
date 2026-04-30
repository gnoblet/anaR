# Load the ANA reference JSON

Returns the bundled `ana_reference` internal dataset by default. Pass
`path` to load a custom `reference.json` from disk instead.

## Usage

``` r
get_default_reference(path = NULL)
```

## Arguments

- path:

  Optional file path to a `reference.json`. If `NULL` (default), returns
  the dataset bundled with the package.

## Value

A named list with a `systems` element.
