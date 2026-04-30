# Package index

## Validation

Validate a CSV data frame against the ANA metric map before flagging.

- [`validate_csv()`](http://guillaume-noblet.com/anaR/reference/validate_csv.md)
  : Validate a CSV data frame against the ANA metric map
- [`parse_metric_type()`](http://guillaume-noblet.com/anaR/reference/parse_metric_type.md)
  : Parse an ANA metric type string
- [`get_default_reference()`](http://guillaume-noblet.com/anaR/reference/get_default_reference.md)
  : Load the ANA reference JSON

## Flagging

Apply ANA thresholds and roll up metric → subfactor → factor → system →
preliminary flag.

- [`flag_data()`](http://guillaume-noblet.com/anaR/reference/flag_data.md)
  : Flag a data frame of metric values against the ANA reference
- [`rollup_statuses()`](http://guillaume-noblet.com/anaR/reference/rollup_statuses.md)
  : Roll up a vector of status strings to a single status
- [`evaluate_group_status()`](http://guillaume-noblet.com/anaR/reference/evaluate_group_status.md)
  : Evaluate flag status for a single threshold group
- [`compute_prelim_flags()`](http://guillaume-noblet.com/anaR/reference/compute_prelim_flags.md)
  : Apply the ANA prelim-flag decision tree to system-level statuses

## Metric metadata

Traverse the reference JSON hierarchy and build flat lookup tables.

- [`build_metric_meta_df()`](http://guillaume-noblet.com/anaR/reference/build_metric_meta_df.md)
  : Build a tidy tibble of metric metadata from reference JSON
- [`get_all_metric_ids()`](http://guillaume-noblet.com/anaR/reference/get_all_metric_ids.md)
  : Get all metric IDs from reference JSON
- [`get_metric_metadata()`](http://guillaume-noblet.com/anaR/reference/get_metric_metadata.md)
  : Get metadata for a single metric by ID
- [`build_subfactor_list()`](http://guillaume-noblet.com/anaR/reference/build_subfactor_list.md)
  : Build a list of subfactor entries with metric codes and threshold
  groups

## Deep-dive Excel export

Build a formatted XLSX workbook for a single unit of analysis.

- [`build_deep_dive()`](http://guillaume-noblet.com/anaR/reference/build_deep_dive.md)
  : Build a deep-dive Excel workbook for a single unit of analysis
- [`dd_col_count()`](http://guillaume-noblet.com/anaR/reference/dd_col_count.md)
  : Total column count for a deep-dive sheet
- [`dd_col_widths()`](http://guillaume-noblet.com/anaR/reference/dd_col_widths.md)
  : Column widths vector for a deep-dive sheet
- [`dd_table_headers()`](http://guillaume-noblet.com/anaR/reference/dd_table_headers.md)
  : Table header row labels for a deep-dive sheet

## Colour helpers

Pure colour utilities used by the deep-dive exporter; also useful for
custom theming.

- [`default_color_map()`](http://guillaume-noblet.com/anaR/reference/default_color_map.md)
  : Default ANA system colour map
- [`sys_hex()`](http://guillaume-noblet.com/anaR/reference/sys_hex.md) :
  Get the base hex colour for a system
- [`sys_text_color()`](http://guillaume-noblet.com/anaR/reference/sys_text_color.md)
  : Text colour (black or white) for contrast on a system background
- [`hex_to_argb()`](http://guillaume-noblet.com/anaR/reference/hex_to_argb.md)
  : Convert a CSS hex colour to Excel ARGB format
- [`mix_with_white()`](http://guillaume-noblet.com/anaR/reference/mix_with_white.md)
  : Mix a hex colour with white
- [`luminance()`](http://guillaume-noblet.com/anaR/reference/luminance.md)
  : Perceived luminance of a hex colour
