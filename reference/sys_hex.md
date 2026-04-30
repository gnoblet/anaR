# Get the base hex colour for a system

Get the base hex colour for a system

## Usage

``` r
sys_hex(system_id, color_map)
```

## Arguments

- system_id:

  A system ID string (e.g. `"mortality"`).

- color_map:

  Named character vector from
  [`default_color_map()`](http://guillaume-noblet.com/anaR/reference/default_color_map.md).

## Value

A `#rrggbb` hex string; falls back to `"#718096"` for unknown IDs.
