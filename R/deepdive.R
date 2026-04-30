# -- Layout constants ----------------------------------------------------------

#' Total column count for a deep-dive sheet
#' @param n_hyps Integer number of hypothesis columns.
#' @return Total column count (7 fixed + n_hyps + 1 comment).
#' @export
dd_col_count <- function(n_hyps) 7L + as.integer(n_hyps) + 1L

#' Column widths vector for a deep-dive sheet
#' @param n_hyps Integer number of hypothesis columns.
#' @return Numeric vector of column widths.
#' @export
dd_col_widths <- function(n_hyps) {
  c(10, 36, 22, 10, 14, 16, 12, rep(16, as.integer(n_hyps)), 28)
}

#' Table header row labels for a deep-dive sheet
#' @param hyp_ids Character vector of hypothesis IDs (e.g. `c("H1","H2")`).
#' @return Character vector of header labels.
#' @export
dd_table_headers <- function(hyp_ids) {
  c("Metric ID", "Indicator", "Metric", "Value",
    "Flag", "AN Threshold", "Direction",
    hyp_ids, "Comment")
}

# -- Internal openxlsx2 helpers ------------------------------------------------

# Cell / range dims helpers
.cd <- function(row, col) {
  sprintf("%s%d", openxlsx2::int2col(col), row)
}
.rd <- function(row1, col1, row2 = row1, col2 = col1) {
  sprintf("%s%d:%s%d",
          openxlsx2::int2col(col1), row1,
          openxlsx2::int2col(col2), row2)
}

# wb_color from ARGB ("FFrrggbb") or plain hex ("#rrggbb" or "rrggbb")
.wbc <- function(x) {
  h <- toupper(sub("^#", "", x))
  if (nchar(h) == 8L) h <- substr(h, 3L, 8L)   # strip FF prefix
  openxlsx2::wb_color(hex = h)
}

# Solid fill shortcut
.fill <- function(wb, sheet, dims, argb) {
  openxlsx2::wb_add_fill(wb, sheet, dims, color = .wbc(argb))
}

# All-thin-borders
.borders <- function(wb, sheet, dims, argb = "FFCCCCCC") {
  cc <- .wbc(argb)
  openxlsx2::wb_add_border(wb, sheet, dims,
    bottom_border = "thin", left_border = "thin",
    right_border = "thin", top_border = "thin",
    bottom_color = cc, left_color = cc,
    right_color = cc, top_color = cc)
}

# Alignment shortcut
.align <- function(wb, sheet, dims, h = "left", v = "middle",
                   indent = 0L, wrap = FALSE) {
  openxlsx2::wb_add_cell_style(wb, sheet, dims,
    horizontal = h, vertical = v,
    indent = as.integer(indent),
    wrap_text = wrap)
}

# Add a single cell value (skip if NULL / NA / empty)
.put <- function(wb, sheet, row, col, val) {
  if (is.null(val)) return(invisible(wb))
  if (length(val) == 1L && is.na(val)) return(invisible(wb))
  if (is.character(val) && !nzchar(val)) return(invisible(wb))
  openxlsx2::wb_add_data(wb, sheet, x = val,
                         dims = .cd(row, col), col_names = FALSE)
  invisible(wb)
}

# -- Status helpers ------------------------------------------------------------

.flag_display <- function(s) {
  switch(s, flag = "Flag", no_flag = "No flag", "No data")
}

.flag_argb <- function(s) {
  switch(s, flag = "FFCC0000", no_flag = "FF00703C", "FF888888")
}

.section_summary <- function(flag_n, no_flag_n, missing_n) {
  total  <- flag_n + no_flag_n + missing_n
  status <- if (flag_n > 0) "Flag" else if (total > 0) "No flag" else "No data"
  sprintf("%s   (flag: %d  no_flag: %d  missing: %d)",
          status, flag_n, no_flag_n, missing_n)
}

# Count metric statuses in a uoa_row for a set of metric IDs
.count_statuses <- function(metric_ids, uoa_row) {
  statuses <- vapply(metric_ids, function(id) {
    s <- uoa_row[[paste0(id, "_status")]]
    if (is.null(s) || (length(s) == 1L && is.na(s))) "no_data"
    else as.character(s[[1L]])
  }, character(1L))
  list(flag_n    = sum(statuses == "flag"),
       no_flag_n = sum(statuses == "no_flag"),
       missing_n = sum(statuses == "no_data"))
}

# -- Row builders --------------------------------------------------------------

# Returns updated current_row after adding the row.

.add_system_header <- function(wb, sheet, row, sys_label, uoa_id,
                                num_cols, system_id, color_map) {
  argb_bg   <- .sys_argb(system_id, color_map)
  argb_text <- hex_to_argb(sub("^#", "", sys_text_color(system_id, color_map)))
  text      <- sprintf("%s  --  UOA: %s", sys_label, uoa_id)

  .put(wb, sheet, row, 1L, text)
  openxlsx2::wb_merge_cells(wb, sheet, .rd(row, 1L, row, num_cols))
  .fill(wb, sheet, .cd(row, 1L), argb_bg)
  openxlsx2::wb_add_font(wb, sheet, .cd(row, 1L),
    bold = TRUE, size = 14, color = .wbc(argb_text))
  .align(wb, sheet, .cd(row, 1L), indent = 1L)
  openxlsx2::wb_set_row_heights(wb, sheet, rows = row, heights = 26)

  row + 1L
}

.add_factor_row <- function(wb, sheet, row, factor_label,
                             flag_n, no_flag_n, missing_n,
                             num_cols, system_id, color_map) {
  argb_mid  <- .sys_argb_mid(system_id, color_map)
  argb_flag <- if (flag_n > 0) "FFCC0000" else "FF00703C"

  .put(wb, sheet, row, 1L, paste0("FACTOR  ", factor_label))
  .put(wb, sheet, row, 8L, .section_summary(flag_n, no_flag_n, missing_n))
  openxlsx2::wb_merge_cells(wb, sheet, .rd(row, 1L, row, 7L))
  openxlsx2::wb_merge_cells(wb, sheet, .rd(row, 8L, row, num_cols))
  .fill(wb, sheet, .rd(row, 1L, row, num_cols), argb_mid)
  openxlsx2::wb_add_font(wb, sheet, .cd(row, 1L), bold = TRUE, size = 12)
  openxlsx2::wb_add_font(wb, sheet, .cd(row, 8L),
    bold = TRUE, color = .wbc(argb_flag))
  .align(wb, sheet, .cd(row, 1L), indent = 1L)
  .align(wb, sheet, .cd(row, 8L), h = "right", indent = 1L)
  openxlsx2::wb_set_row_heights(wb, sheet, rows = row, heights = 20)

  row + 1L
}

.add_subfactor_row <- function(wb, sheet, row, sub_label,
                                flag_n, no_flag_n, missing_n,
                                num_cols, system_id, color_map) {
  argb_light <- .sys_argb_light(system_id, color_map)
  argb_flag  <- if (flag_n > 0) "FFCC0000" else "FF00703C"

  .put(wb, sheet, row, 1L, paste0("  Sub-factor  ", sub_label))
  .put(wb, sheet, row, 8L, .section_summary(flag_n, no_flag_n, missing_n))
  openxlsx2::wb_merge_cells(wb, sheet, .rd(row, 1L, row, 7L))
  openxlsx2::wb_merge_cells(wb, sheet, .rd(row, 8L, row, num_cols))
  .fill(wb, sheet, .rd(row, 1L, row, num_cols), argb_light)
  openxlsx2::wb_add_font(wb, sheet, .cd(row, 1L), italic = TRUE, size = 11)
  openxlsx2::wb_add_font(wb, sheet, .cd(row, 8L),
    italic = TRUE, color = .wbc(argb_flag))
  .align(wb, sheet, .cd(row, 1L), indent = 1L)
  .align(wb, sheet, .cd(row, 8L), h = "right", indent = 1L)
  openxlsx2::wb_set_row_heights(wb, sheet, rows = row, heights = 18)

  row + 1L
}

.add_table_header_row <- function(wb, sheet, row, headers) {
  for (i in seq_along(headers)) {
    .put(wb, sheet, row, i, headers[[i]])
  }
  dims <- .rd(row, 1L, row, length(headers))
  openxlsx2::wb_add_font(wb, sheet, dims, bold = TRUE, size = 10)
  .fill(wb, sheet, dims, "FFF2F2F2")
  openxlsx2::wb_add_border(wb, sheet, dims,
    top_border    = "thin",   left_border  = "thin",   right_border = "thin",
    bottom_border = "medium",
    top_color     = .wbc("FFAAAAAA"), left_color   = .wbc("FFAAAAAA"),
    right_color   = .wbc("FFAAAAAA"), bottom_color = .wbc("FF666666"))
  .align(wb, sheet, dims, v = "middle")
  openxlsx2::wb_set_row_heights(wb, sheet, rows = row, heights = 16)

  row + 1L
}

.add_indicator_row <- function(wb, sheet, row, met_id, ind_label,
                                met_label, value, flag_str, an_val,
                                direction, n_hyps) {
  is_flagged <- identical(flag_str, "flag")
  vals <- list(
    met_id,
    ind_label %||% "",
    met_label %||% "",
    if (is.null(value) || (length(value) == 1L && is.na(value))) "" else value,
    .flag_display(flag_str),
    if (is.null(an_val) || (length(an_val) == 1L && is.na(an_val))) "" else an_val,
    direction %||% ""
  )
  for (i in seq_along(vals)) .put(wb, sheet, row, i, vals[[i]])

  num_cols <- dd_col_count(n_hyps)
  row_dims <- .rd(row, 1L, row, num_cols)
  .borders(wb, sheet, row_dims, "FFDDDDDD")
  .align(wb, sheet, row_dims, v = "middle")

  if (is_flagged) {
    .fill(wb, sheet, .rd(row, 1L, row, 7L), "FFFFF0F0")
  }
  openxlsx2::wb_add_font(wb, sheet, .cd(row, 5L),
    color = .wbc(.flag_argb(flag_str)),
    bold  = is_flagged)

  if (n_hyps > 0L) {
    hyp_dims <- .rd(row, 8L, row, 7L + n_hyps)
    openxlsx2::wb_add_data_validation(wb, sheet, hyp_dims,
      type          = "list",
      value         = '"++,+,~,-,--"',
      show_error_msg = FALSE,
      allow_blank   = TRUE)
  }

  openxlsx2::wb_set_row_heights(wb, sheet, rows = row, heights = 15)
  row + 1L
}

# -- Hypothesis reference table ------------------------------------------------

.add_hypothesis_table <- function(wb, sheet, row, sys_hyps,
                                   num_cols, system_id, color_map) {
  hyps <- sys_hyps[["hypotheses"]]
  if (length(hyps) == 0L) return(row)

  argb_mid  <- .sys_argb_mid(system_id, color_map, weight = 0.7)
  argb_text <- hex_to_argb(sub("^#", "", sys_text_color(system_id, color_map)))
  sys_lbl   <- sys_hyps[["systemLabel"]] %||% system_id

  .put(wb, sheet, row, 1L,
       sprintf("Hypotheses for assessing %s deprivation", sys_lbl))
  openxlsx2::wb_merge_cells(wb, sheet, .rd(row, 1L, row, num_cols))
  .fill(wb, sheet, .cd(row, 1L), argb_mid)
  openxlsx2::wb_add_font(wb, sheet, .cd(row, 1L),
    bold = TRUE, size = 11, color = .wbc(argb_text))
  .align(wb, sheet, .cd(row, 1L), h = "center", indent = 1L)
  .borders(wb, sheet, .rd(row, 1L, row, num_cols))
  openxlsx2::wb_set_row_heights(wb, sheet, rows = row, heights = 20)
  row <- row + 1L

  for (hyp in hyps) {
    .put(wb, sheet, row, 1L, hyp[["id"]])
    .put(wb, sheet, row, 2L, hyp[["description"]])
    openxlsx2::wb_merge_cells(wb, sheet, .rd(row, 2L, row, num_cols))
    .fill(wb, sheet, .cd(row, 1L), "FFFFF2CC")
    .fill(wb, sheet, .cd(row, 2L), "FFFFFFFF")
    openxlsx2::wb_add_font(wb, sheet, .cd(row, 1L), bold = TRUE, size = 10)
    openxlsx2::wb_add_font(wb, sheet, .cd(row, 2L), size = 10)
    .align(wb, sheet, .cd(row, 1L), h = "center")
    .align(wb, sheet, .cd(row, 2L), wrap = TRUE, indent = 1L)
    .borders(wb, sheet, .rd(row, 1L, row, num_cols))
    openxlsx2::wb_set_row_heights(wb, sheet, rows = row, heights = 30)
    row <- row + 1L
  }

  openxlsx2::wb_add_data(wb, sheet, x = "",
                         dims = .cd(row, 1L), col_names = FALSE)
  row + 1L
}

# -- Synthesis / conclusion section --------------------------------------------

.add_summary_dropdown_row <- function(wb, sheet, row, label, csv_values,
                                       num_cols, allow_blank = FALSE) {
  .put(wb, sheet, row, 1L, label)
  openxlsx2::wb_merge_cells(wb, sheet, .rd(row, 1L, row, 2L))
  openxlsx2::wb_merge_cells(wb, sheet, .rd(row, 3L, row, 7L))
  .fill(wb, sheet, .rd(row, 1L, row, 2L), "FFF0F0F0")
  .fill(wb, sheet, .cd(row, 3L),          "FFFFFFFF")
  openxlsx2::wb_add_font(wb, sheet, .cd(row, 1L), bold = TRUE, size = 10)
  .align(wb, sheet, .cd(row, 1L), indent = 1L)
  .align(wb, sheet, .cd(row, 3L), indent = 1L)
  .borders(wb, sheet, .rd(row, 1L, row, 7L))
  openxlsx2::wb_add_data_validation(wb, sheet, .cd(row, 3L),
    type           = "list",
    value          = sprintf('"%s"', csv_values),
    show_error_msg = FALSE,
    allow_blank    = allow_blank)
  openxlsx2::wb_set_row_heights(wb, sheet, rows = row, heights = 20)
  row + 1L
}

.add_summary_text_row <- function(wb, sheet, row, label, num_cols) {
  .put(wb, sheet, row, 1L, label)
  .put(wb, sheet, row, 3L, "Please fill in summary")
  openxlsx2::wb_merge_cells(wb, sheet, .rd(row, 1L, row, 2L))
  openxlsx2::wb_merge_cells(wb, sheet, .rd(row, 3L, row, 7L))
  .fill(wb, sheet, .rd(row, 1L, row, 2L), "FFF0F0F0")
  .fill(wb, sheet, .cd(row, 3L),          "FFFFFFFF")
  openxlsx2::wb_add_font(wb, sheet, .cd(row, 1L), bold = TRUE, size = 10)
  openxlsx2::wb_add_font(wb, sheet, .cd(row, 3L),
    italic = TRUE, size = 10, color = .wbc("FFAAAAAA"))
  .align(wb, sheet, .cd(row, 1L), v = "top", indent = 1L)
  .align(wb, sheet, .cd(row, 3L), v = "top", wrap = TRUE, indent = 1L)
  .borders(wb, sheet, .rd(row, 1L, row, 7L))
  openxlsx2::wb_set_row_heights(wb, sheet, rows = row, heights = 60)
  row + 1L
}

# Returns list with synthesis row positions
.add_synthesis_section <- function(wb, sheet, row, num_cols, hyp_ids) {
  # Blank spacer
  row <- row + 1L

  .put(wb, sheet, row, 1L, "SYNTHESIS & CONCLUSION")
  openxlsx2::wb_merge_cells(wb, sheet, .rd(row, 1L, row, num_cols))
  .fill(wb, sheet, .cd(row, 1L), "FF404040")
  openxlsx2::wb_add_font(wb, sheet, .cd(row, 1L),
    bold = TRUE, size = 12, color = .wbc("FFFFFFFF"))
  .align(wb, sheet, .cd(row, 1L), indent = 1L)
  openxlsx2::wb_set_row_heights(wb, sheet, rows = row, heights = 22)
  row <- row + 1L

  # Blank spacer
  row <- row + 1L

  hyp_csv <- if (length(hyp_ids) > 0L) paste(hyp_ids, collapse = ",")
             else "H1,H2,H3,H4,H5"

  row <- .add_summary_dropdown_row(wb, sheet, row,
    "Primary Hypothesis", hyp_csv, num_cols)
  primary_hyp_row <- row - 1L

  row <- .add_summary_dropdown_row(wb, sheet, row,
    "Secondary Hypothesis (if any)", hyp_csv, num_cols, allow_blank = TRUE)
  secondary_hyp_row <- row - 1L

  row <- .add_summary_dropdown_row(wb, sheet, row,
    "Plausibility Judgement",
    "Very likely,Likely,Plausible,Unlikely,Very unlikely", num_cols)
  plausibility_row <- row - 1L

  row <- .add_summary_text_row(wb, sheet, row, "Summary", num_cols)
  summary_row <- row - 1L

  row <- .add_summary_dropdown_row(wb, sheet, row,
    "Triangulation Strength", "Strong,Moderate,Weak", num_cols)
  triangulation_row <- row - 1L

  row <- .add_summary_dropdown_row(wb, sheet, row,
    "Chosen Conclusion",
    paste("C1: Strong Interaction",
          "C2: Limited or indirect Interaction",
          "C3: No interaction",
          "Inconclusive", "Unassessed", sep = ","),
    num_cols)
  conclusion_row <- row - 1L

  list(
    primary_hyp_row   = primary_hyp_row,
    secondary_hyp_row = secondary_hyp_row,
    plausibility_row  = plausibility_row,
    summary_row       = summary_row,
    triangulation_row = triangulation_row,
    conclusion_row    = conclusion_row
  )
}

# -- Landing page --------------------------------------------------------------

.landing_col_widths <- c(30, 22, 22, 32, 42, 22, 28, 44)

.add_landing_page <- function(wb, uoa_row, sheet_meta_list, meta_df) {
  sheet <- "Summary"
  uoa_id <- as.character(uoa_row[["uoa"]] %||% "unknown")

  openxlsx2::wb_set_col_widths(wb, sheet,
    cols = seq_along(.landing_col_widths), widths = .landing_col_widths)

  # Title
  row <- 1L
  .put(wb, sheet, row, 1L, sprintf("UOA Summary  --  %s", uoa_id))
  openxlsx2::wb_merge_cells(wb, sheet, .rd(row, 1L, row, 8L))
  .fill(wb, sheet, .cd(row, 1L), "FF1F4E79")
  openxlsx2::wb_add_font(wb, sheet, .cd(row, 1L),
    bold = TRUE, size = 14, color = .wbc("FFFFFFFF"))
  .align(wb, sheet, .cd(row, 1L), indent = 1L)
  openxlsx2::wb_set_row_heights(wb, sheet, rows = row, heights = 26)
  row <- row + 1L

  # Section header
  .put(wb, sheet, row, 1L, "Systems and outcomes")
  openxlsx2::wb_merge_cells(wb, sheet, .rd(row, 1L, row, 8L))
  .fill(wb, sheet, .cd(row, 1L), "FF7030A0")
  openxlsx2::wb_add_font(wb, sheet, .cd(row, 1L),
    bold = TRUE, size = 12, color = .wbc("FFFFFFFF"))
  .align(wb, sheet, .cd(row, 1L), indent = 1L)
  openxlsx2::wb_set_row_heights(wb, sheet, rows = row, heights = 20)
  row <- row + 1L

  # Column headers
  col_headers <- c("System",
    "Chosen Most Likely Hypothesis",
    "Chosen Secondary Hypothesis (if any)",
    "Conclusion",
    "Conclusion summary",
    "Plausibility judgement",
    "Strength of evidence triangulation",
    "Flagged Factors")
  for (i in seq_along(col_headers)) .put(wb, sheet, row, i, col_headers[[i]])
  header_dims <- .rd(row, 1L, row, 8L)
  openxlsx2::wb_add_font(wb, sheet, header_dims, bold = TRUE, size = 10)
  .fill(wb, sheet, header_dims, "FFF2F2F2")
  .borders(wb, sheet, header_dims, "FFAAAAAA")
  .align(wb, sheet, header_dims, v = "middle", wrap = TRUE)
  openxlsx2::wb_set_row_heights(wb, sheet, rows = row, heights = 30)
  row <- row + 1L

  # One block per system
  for (meta in sheet_meta_list) {
    sys      <- meta[["system"]]
    factors  <- sys[["factors"]]
    if (!is.list(factors) || length(factors) == 0L) next

    syn_rows  <- meta[["synthesis_rows"]]
    safe_name <- gsub("'", "''", meta[["sheet_name"]])

    start_row <- row

    for (fac in factors) {
      fac_id   <- fac[["id"]]
      fac_lbl  <- fac[["label"]] %||% fac_id

      # Metrics in this factor for status counts
      fac_mets <- meta_df$metric_id[meta_df$factor_path ==
                    paste(sys[["id"]], fac_id, sep = ".")]
      cts <- .count_statuses(fac_mets, uoa_row)

      fac_status <- if (cts$flag_n > 0) "Flag" else
                    if ((cts$flag_n + cts$no_flag_n) > 0) "No Flag" else "No data"
      fac_text <- sprintf("%s  [%s  flag:%d ok:%d na:%d]",
                          fac_lbl, fac_status,
                          cts$flag_n, cts$no_flag_n, cts$missing_n)

      .put(wb, sheet, row, 8L, fac_text)
      argb_fac <- if (cts$flag_n > 0) "FFCC0000" else "FF006400"
      .fill(wb, sheet, .cd(row, 8L),   "FFFAFAFA")
      openxlsx2::wb_add_font(wb, sheet, .cd(row, 8L),
        size = 10, color = .wbc(argb_fac))
      .align(wb, sheet, .cd(row, 8L), wrap = TRUE, indent = 1L)
      .borders(wb, sheet, .cd(row, 8L))
      openxlsx2::wb_set_row_heights(wb, sheet, rows = row, heights = 18)
      row <- row + 1L
    }

    end_row <- row - 1L
    n_facs  <- end_row - start_row + 1L

    # Merge & style system cell (col 1)
    if (n_facs > 1L) {
      openxlsx2::wb_merge_cells(wb, sheet, .rd(start_row, 1L, end_row, 1L))
    }
    sys_argb_val <- .sys_argb(sys[["id"]], default_color_map())
    .put(wb, sheet, start_row, 1L, sys[["label"]] %||% sys[["id"]])
    .fill(wb, sheet, .cd(start_row, 1L), sys_argb_val)
    openxlsx2::wb_add_font(wb, sheet, .cd(start_row, 1L),
      bold = TRUE, size = 11,
      color = .wbc(hex_to_argb(sub("^#", "",
        sys_text_color(sys[["id"]], default_color_map())))))
    .align(wb, sheet, .cd(start_row, 1L), wrap = TRUE, indent = 1L)
    .borders(wb, sheet, .cd(start_row, 1L))

    # Formula columns 2-7
    formula_map <- list(
      list(col = 2L, ref_row = syn_rows[["primary_hyp_row"]]),
      list(col = 3L, ref_row = syn_rows[["secondary_hyp_row"]]),
      list(col = 4L, ref_row = syn_rows[["conclusion_row"]]),
      list(col = 5L, ref_row = syn_rows[["summary_row"]]),
      list(col = 6L, ref_row = syn_rows[["plausibility_row"]]),
      list(col = 7L, ref_row = syn_rows[["triangulation_row"]])
    )
    for (fm in formula_map) {
      if (n_facs > 1L) {
        openxlsx2::wb_merge_cells(wb, sheet,
          .rd(start_row, fm[["col"]], end_row, fm[["col"]]))
      }
      formula_str <- sprintf("='%s'!C%d", safe_name, fm[["ref_row"]])
      openxlsx2::wb_add_formula(wb, sheet, x = formula_str,
                                dims = .cd(start_row, fm[["col"]]))
      argb_light <- .sys_argb_light(sys[["id"]], default_color_map())
      .fill(wb, sheet,   .cd(start_row, fm[["col"]]), argb_light)
      .align(wb, sheet,  .cd(start_row, fm[["col"]]), wrap = TRUE, indent = 1L)
      .borders(wb, sheet, .cd(start_row, fm[["col"]]))
    }
  }

  # Analysis outcome block
  row <- row + 1L
  .put(wb, sheet, row, 1L, "ANALYSIS OUTCOME")
  openxlsx2::wb_merge_cells(wb, sheet, .rd(row, 1L, row, 8L))
  .fill(wb, sheet, .cd(row, 1L), "FF1F4E79")
  openxlsx2::wb_add_font(wb, sheet, .cd(row, 1L),
    bold = TRUE, size = 11, color = .wbc("FFFFFFFF"))
  .align(wb, sheet, .cd(row, 1L), indent = 1L)
  openxlsx2::wb_set_row_heights(wb, sheet, rows = row, heights = 20)
  row <- row + 1L

  # Prelim flag (read-only)
  prelim_val <- as.character(uoa_row[["prelim_flag"]] %||% "")
  .put(wb, sheet, row, 1L, "Prelim flag")
  .put(wb, sheet, row, 2L, prelim_val)
  openxlsx2::wb_add_font(wb, sheet, .cd(row, 1L), bold = TRUE, size = 10)
  openxlsx2::wb_add_font(wb, sheet, .cd(row, 2L),
    size = 10, color = .wbc("FF555555"))
  .fill(wb, sheet, .cd(row, 1L), "FFF2F2F2")
  .fill(wb, sheet, .cd(row, 2L), "FFF8F8F8")
  .borders(wb, sheet, .cd(row, 1L))
  .borders(wb, sheet, .cd(row, 2L))
  openxlsx2::wb_set_row_heights(wb, sheet, rows = row, heights = 20)
  row <- row + 1L

  # Final flag (editable dropdown)
  .put(wb, sheet, row, 1L, "Final flag")
  openxlsx2::wb_add_font(wb, sheet, .cd(row, 1L), bold = TRUE, size = 10)
  .fill(wb, sheet, .cd(row, 1L), "FFF2F2F2")
  .fill(wb, sheet, .cd(row, 2L), "FFFFFFFF")
  .borders(wb, sheet, .cd(row, 1L))
  .borders(wb, sheet, .cd(row, 2L))
  openxlsx2::wb_add_data_validation(wb, sheet, .cd(row, 2L),
    type           = "list",
    value          = '"EM,ROEM,ACUTE,ACUTE_NEEDS,INSUFFICIENT_EVIDENCE,NO_DATA"',
    show_error_msg = FALSE,
    allow_blank    = TRUE)
  openxlsx2::wb_set_row_heights(wb, sheet, rows = row, heights = 20)

  invisible(wb)
}

# -- Main export ---------------------------------------------------------------

#' Build a deep-dive Excel workbook for a single unit of analysis
#'
#' Generates one worksheet per system (filtered to systems present in
#' `hypotheses_data`) plus a "Summary" landing page with cross-sheet
#' INDIRECT formulas.
#'
#' @param uoa_row       A named list or single-row data frame (e.g. one row
#'   from [flag_data()] output).
#' @param ref           The reference list from [get_default_reference()].
#' @param hypotheses_data A list of system-hypothesis entries; each entry is a
#'   list with `systemId`, `systemLabel`, and `hypotheses` (a list of
#'   `list(id, description)` entries).
#' @param path          File path for the output `.xlsx` file.
#' @param color_map     Named character vector of system hex colours; defaults
#'   to [default_color_map()].
#' @return `path`, invisibly.
#' @export
build_deep_dive <- function(uoa_row, ref, hypotheses_data, path,
                             color_map = default_color_map()) {
  uoa_id   <- as.character(uoa_row[["uoa"]] %||% "unknown")
  meta_df  <- build_metric_meta_df(ref)

  hyps_by_sys <- stats::setNames(
    hypotheses_data,
    vapply(hypotheses_data, `[[`, "", "systemId")
  )
  included_ids <- names(hyps_by_sys)

  wb <- openxlsx2::wb_workbook()
  wb$add_worksheet("Summary")

  sheet_meta_list <- list()

  for (sys in ref[["systems"]] %||% list()) {
    sys_id <- sys[["id"]]
    if (!sys_id %in% included_ids) next

    sys_hyps  <- hyps_by_sys[[sys_id]]
    hyp_ids   <- vapply(sys_hyps[["hypotheses"]], `[[`, "", "id")
    n_hyps    <- length(hyp_ids)
    num_cols  <- dd_col_count(n_hyps)
    widths    <- dd_col_widths(n_hyps)
    headers   <- dd_table_headers(hyp_ids)

    raw_name   <- as.character(sys[["label"]] %||% sys_id)
    sheet_name <- substr(gsub("[\\\\/*?:\\[\\]]", "_", raw_name), 1L, 31L)
    wb$add_worksheet(sheet_name)

    openxlsx2::wb_set_col_widths(wb, sheet_name,
      cols = seq_along(widths), widths = widths)

    row <- 1L
    row <- .add_system_header(wb, sheet_name, row, raw_name, uoa_id,
                               num_cols, sys_id, color_map)
    row <- .add_hypothesis_table(wb, sheet_name, row, sys_hyps,
                                  num_cols, sys_id, color_map)
    row <- row + 1L   # blank spacer

    for (fac in sys[["factors"]] %||% list()) {
      fac_id  <- fac[["id"]]
      fac_mets <- meta_df$metric_id[
        meta_df$factor_path == paste(sys_id, fac_id, sep = ".")
      ]
      fac_cts <- .count_statuses(fac_mets, uoa_row)

      row <- .add_factor_row(wb, sheet_name, row,
        fac[["label"]] %||% fac_id,
        fac_cts$flag_n, fac_cts$no_flag_n, fac_cts$missing_n,
        num_cols, sys_id, color_map)

      for (sub in fac[["sub_factors"]] %||% list()) {
        sub_id   <- sub[["id"]]
        sub_mets <- meta_df$metric_id[
          meta_df$subfactor_path ==
            paste(sys_id, fac_id, sub_id, sep = ".")
        ]
        if (length(sub_mets) == 0L) next

        sub_cts <- .count_statuses(sub_mets, uoa_row)

        row <- .add_subfactor_row(wb, sheet_name, row,
          sub[["label"]] %||% sub_id,
          sub_cts$flag_n, sub_cts$no_flag_n, sub_cts$missing_n,
          num_cols, sys_id, color_map)

        row <- .add_table_header_row(wb, sheet_name, row, headers)

        for (ind in sub[["indicators"]] %||% list()) {
          ind_label <- ind[["label"]]
          for (met in ind[["metrics"]] %||% list()) {
            met_id  <- met[["metric"]]
            if (is.null(met_id)) next
            pref    <- met[["preference"]] %||% 1L
            raw_val <- uoa_row[[met_id]]
            val     <- if (is.null(raw_val) ||
                           (length(raw_val) == 1L && is.na(raw_val))) NULL
                       else raw_val[[1L]]
            # preference-3 metrics have no _status column
            raw_status <- uoa_row[[paste0(met_id, "_status")]]
            flag_str <- if (is.null(raw_status) ||
                             (length(raw_status) == 1L && is.na(raw_status)))
                          "no_data"
                        else as.character(raw_status[[1L]])

            an_val    <- met[["thresholds"]][["an"]]
            direction <- met[["above_or_below"]]

            row <- .add_indicator_row(wb, sheet_name, row,
              met_id, ind_label, met[["label"]],
              val, flag_str, an_val, direction, n_hyps)
          }
        }
        row <- row + 1L   # blank after subfactor
      }
      row <- row + 1L     # blank after factor
    }

    syn_rows <- .add_synthesis_section(wb, sheet_name, row, num_cols, hyp_ids)
    sheet_meta_list <- c(sheet_meta_list, list(list(
      sheet_name     = sheet_name,
      system         = sys,
      synthesis_rows = syn_rows
    )))
  }

  .add_landing_page(wb, uoa_row, sheet_meta_list, meta_df)
  openxlsx2::wb_save(wb, path)
  invisible(path)
}
