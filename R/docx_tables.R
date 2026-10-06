# =============================================================================
# R/docx_tables.R
# The Word (.docx) format shared by every table in 05_exhibits/ (decided
# 2026-09-30, from the researcher's hand-formatted Table 2): Calibri 11 pt, no
# bold, no vertical lines, horizontal rules only under each header row, above a
# chosen body row (e.g. above N) and at the bottom; row labels left-aligned,
# numbers right-aligned, headers centred. The title goes in a paragraph above
# the table and the notes in paragraphs below it, not inside the table.
#
# Only the .docx is built here; the .html/.tex versions keep their own
# (tinytable) format. Sourced by table2_and_ed_tables.R and
# ed_table_descriptive_statistics.R.
# =============================================================================

library(flextable)
library(officer)

DOCX_FONT      <- "Calibri"
DOCX_SIZE      <- 11
DOCX_NOTE_SIZE <- 9
DOCX_RULE      <- officer::fp_border(color = "black", width = 0.5)

# Applies the shared format to a flextable.
#   rule_after_body_row: body row(s) with a rule below them (e.g. the last
#                        coefficient row, so the rule sits above N)
#   widths_cm:           width of the first column and of every other column
style_docx_table <- function(ft, rule_after_body_row = integer(0),
                             widths_cm = c(4.75, 2.75)) {
  n_col <- length(ft$col_keys)
  ft <- flextable::font(ft, fontname = DOCX_FONT, part = "all")
  ft <- flextable::fontsize(ft, size = DOCX_SIZE, part = "all")
  ft <- flextable::bold(ft, bold = FALSE, part = "all")
  ft <- flextable::border_remove(ft)
  ft <- flextable::align(ft, j = 1, align = "left", part = "all")
  if (n_col > 1) {
    ft <- flextable::align(ft, j = 2:n_col, align = "right",  part = "body")
    ft <- flextable::align(ft, j = 2:n_col, align = "center", part = "header")
  }
  ft <- flextable::valign(ft, valign = "bottom", part = "all")
  # A rule under every header row, as in the model file.
  for (i in seq_len(flextable::nrow_part(ft, "header")))
    ft <- flextable::hline(ft, i = i, border = DOCX_RULE, part = "header")
  for (i in rule_after_body_row)
    ft <- flextable::hline(ft, i = i, border = DOCX_RULE, part = "body")
  ft <- flextable::hline_bottom(ft, border = DOCX_RULE, part = "body")
  ft <- flextable::width(ft, j = 1, width = widths_cm[1], unit = "cm")
  if (n_col > 1)
    ft <- flextable::width(ft, j = 2:n_col, width = widths_cm[2], unit = "cm")
  ft
}

# Writes title (paragraph above), table and notes (paragraphs below) to `path`.
write_docx_table <- function(ft, title, notes, path) {
  txt <- function(size) officer::fp_text(font.family = DOCX_FONT, font.size = size)
  doc <- officer::read_docx()
  doc <- officer::body_add_fpar(doc, officer::fpar(officer::ftext(title, txt(DOCX_SIZE))))
  doc <- flextable::body_add_flextable(doc, ft, align = "left")
  for (n in notes)
    doc <- officer::body_add_fpar(doc, officer::fpar(officer::ftext(n, txt(DOCX_NOTE_SIZE))))
  print(doc, target = path)
  invisible(path)
}
