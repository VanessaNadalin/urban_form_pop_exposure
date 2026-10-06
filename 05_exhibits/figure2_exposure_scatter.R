# =============================================================================
# figure2_exposure_scatter.R  (Figure 2; formerly
# regression2/plot_pct_risk_sprawl_vs_compact_population.R)
# Scatterplot, one point per municipality: change in high-susceptibility
# population as a share of population change, compact vs sprawl cells,
# 2010-2022. Also writes the figure's statistics and per-municipality data.
#
# SAMPLE (2026-09-21, researcher): every municipality in
# dataset_regressao_municipio.csv with growth of at least
# MIN_GROWTH_BOTH_TYPES persons in BOTH sprawl and compact cells. The sample is
# restricted on the ratios' DENOMINATORS only; nothing filters on the
# numerators.
#
# Why not pop_2010_risk_total > 200: that cut targets g_alta's denominator in
# 16_estimate_models.R, not the delta_risk / delta_pop ratios plotted here.
# Under it, three municipalities with under a hundred people of growth in one
# type drove the fit. The value 200 is not selected by the data (section 11
# sweeps it); it equals the regressions' minimum-baseline magnitude so the two
# thresholds read as one convention. This reversed MIGRATION_PLAN.md 6c2.
# Requiring growth in BOTH types conditions on the outcome dimension:
# municipalities that grew almost entirely one way are excluded (section 11
# reports how many, by type).
#
# NO [0, 1] CLIP (2026-09-25, researcher). The ratios are plotted and every
# statistic is computed on them as computed. A negative ratio means the
# high-susceptibility population fell while total population grew; a ratio
# above 1 means it grew more than total population (population outside
# high-susceptibility areas fell). The fitted line is OLS; no robust fit is
# reported. MIGRATION_HISTORY.md Part 2, 2026-09-25 (both entries).
#
# FORMAT: Nature Cities single column (89 mm), sans-serif 6-7 pt, vector PDF
# plus 300 dpi PNG. No title, subtitle or caption inside the figure; they go in
# the legend text of the manuscript.
#
# Input:  data/processed_data/03_urban_footprint/metricas/metricas_municipio_2010_2022.csv
#         data/processed_data/04_regression/tables/dataset_regressao_municipio.csv (script 15)
# Output (output/):
#         plot_pct_risk_sprawl_vs_compact_pure.pdf/png   Figure 2
#         figure2_statistics.csv       long format: variant, block, item, value, note
#         figure2_municipality_data.csv  one row per municipality in the figure
#
# Run from the repository root (relative paths, CLAUDE.md rule 5).
# =============================================================================

source("04_regression_dataset_and_models/00_setup.R")

for (pkg in c("ggplot2", "dplyr", "scales", "readr"))
  if (!requireNamespace(pkg, quietly = TRUE)) install.packages(pkg)
library(ggplot2); library(dplyr); library(scales); library(readr)

# ---- Parameters --------------------------------------------------------------

# The figure's sample rule: minimum 2010-2022 growth, in persons, required in
# BOTH sprawl and compact cells.
MIN_GROWTH_BOTH_TYPES <- 200

# The rule used until 2026-09-21, kept only as a comparison variant in
# section 11. Nothing in the figure's own path reads it.
RETIRED_MIN_POP_RISCO_2010 <- 200

# Two ratios closer than this count as a tie (on the 45-degree line).
TIE_TOL <- 1e-9

# Axis window, shared by both axes so the dashed line is a true 45-degree line.
# NULL = the full data range (plus 0). Set to c(lo, hi) only if a few extreme
# points compress the rest; points outside are then drawn at the panel edge
# with their own marker and listed in the console and in
# figure2_municipality_data.csv (flag_offscale). The fitted line always uses
# every point.
# Set 2026-09-25 (researcher): on the full range (-0.90 to 1.21) one compact
# ratio, Ubá/MG at -0.90, stretched both axes; the next lowest is -0.42. This
# window leaves only that point off-scale. Revisit if the data change.
AXIS_LIMITS <- c(-0.45, 1.25)

# Size-legend keys, in persons. Chosen to span the skewed distribution of
# growth_total (2026-09-25 run: median about 18,000, 3rd quartile 44,000,
# max 556,000): near the median, the upper tail, and near the maximum.
# Automatic breaks gave 200,000 and 400,000, which no typical point resembles.
# Keys above the data maximum are dropped by the scale.
SIZE_BREAKS <- c(20000, 100000, 500000)

FIG_WIDTH_MM  <- 89
FIG_HEIGHT_MM <- 105

# UF from the first two digits of the IBGE municipality code.
UF_BY_CODE <- c("11"="RO","12"="AC","13"="AM","14"="RR","15"="PA","16"="AP",
                "17"="TO","21"="MA","22"="PI","23"="CE","24"="RN","25"="PB",
                "26"="PE","27"="AL","28"="SE","29"="BA","31"="MG","32"="ES",
                "33"="RJ","35"="SP","41"="PR","42"="SC","43"="RS","50"="MS",
                "51"="MT","52"="GO","53"="DF")

cat("\n", strrep("=", 60), "\n")
cat("FIGURE2_EXPOSURE_SCATTER.R\n")
cat(strrep("=", 60), "\n")

# =============================================================================
# 1) LOAD METRICS DATA
# =============================================================================

cat("\n1) Loading metrics data...\n")

path_csv <- file.path(metricas_dir, "metricas_municipio_2010_2022.csv")
if (!file.exists(path_csv))
  stop(sprintf("File not found:\n  %s\n\nRun 03_urban_footprint_and_growth_types/07_aggregate_municipality_metrics.R first.", path_csv))

df_raw <- read_csv(path_csv, show_col_types = FALSE)
cat(sprintf("   Raw: %d rows x %d cols\n", nrow(df_raw), ncol(df_raw)))

tipos  <- c("extension", "leapfrog", "peripheral", "densification", "infill")
needed <- c(paste0("pop_2022_", tipos), paste0("pop_2010_", tipos),
            paste0("pop_2022_risk_", tipos), paste0("pop_2010_risk_", tipos),
            "pop_2022_total")
missing <- setdiff(needed, names(df_raw))
if (length(missing) > 0)
  stop(sprintf("Missing columns: %s", paste(missing, collapse = ", ")))

# =============================================================================
# 2) LOAD REGRESSION DATASET (municipality universe, names, baseline exposure)
# =============================================================================

cat("\n2) Loading regression dataset...\n")

path_reg <- file.path(tables_dir, "dataset_regressao_municipio.csv")
if (!file.exists(path_reg))
  stop(sprintf("File not found:\n  %s\n\nRun 04_regression_dataset_and_models/15_final_dataset.R first.", path_reg))

df_reg <- read_csv(path_reg, show_col_types = FALSE)
cat(sprintf("   Regression dataset: %d rows x %d cols\n", nrow(df_reg), ncol(df_reg)))

missing_reg <- setdiff(c("cod_mun", "NM_CIDADE", "pop_2010_risk_total"), names(df_reg))
if (length(missing_reg) > 0)
  stop(sprintf("Missing columns in the regression dataset: %s", paste(missing_reg, collapse = ", ")))

# One row per municipality. The pipeline carries no municipality-name column:
# NM_CIDADE is the functional urban area's name, used here as a label.
# pop_2010_risk_total is renamed on this local copy only, because the metrics
# file may carry a column of the same name.
reg_mun <- df_reg %>%
  group_by(cod_mun) %>%
  summarise(fua_name                = first(NM_CIDADE),
            reg_pop_2010_risk_total = first(pop_2010_risk_total),
            .groups = "drop")

cat(sprintf("   Regression municipalities: %d\n", nrow(reg_mun)))

# =============================================================================
# 3) DERIVE RATIOS
# =============================================================================

# Per-type 2010->2022 deltas from the common-grid levels (MIGRATION_PLAN.md 6b0).
df_all <- df_raw %>%
  mutate(
    delta_sprawl_risk   = (pop_2022_risk_extension  - pop_2010_risk_extension) +
                          (pop_2022_risk_leapfrog   - pop_2010_risk_leapfrog)  +
                          (pop_2022_risk_peripheral - pop_2010_risk_peripheral),
    delta_sprawl_total  = (pop_2022_extension  - pop_2010_extension) +
                          (pop_2022_leapfrog   - pop_2010_leapfrog)  +
                          (pop_2022_peripheral - pop_2010_peripheral),
    delta_compact_risk  = (pop_2022_risk_densification - pop_2010_risk_densification) +
                          (pop_2022_risk_infill        - pop_2010_risk_infill),
    delta_compact_total = (pop_2022_densification - pop_2010_densification) +
                          (pop_2022_infill        - pop_2010_infill),
    pct_risk_sprawl     = delta_sprawl_risk  / delta_sprawl_total,
    pct_risk_compact    = delta_compact_risk / delta_compact_total,
    growth_total        = delta_sprawl_total + delta_compact_total,
    pop_mun_2022        = pop_2022_total,
    uf                  = unname(UF_BY_CODE[substr(as.character(cod_mun), 1, 2)])
  )

N_METRICS <- nrow(df_all)

# =============================================================================
# 4) REGRESSION-DATASET UNIVERSE (inner join)
# =============================================================================

cat("\n3) Restricting to regression municipalities (inner join)...\n")

df_univ <- df_all %>% inner_join(reg_mun, by = "cod_mun")
N_UNIVERSE <- nrow(df_univ)

cat(sprintf("   Metrics municipalities: %d\n", N_METRICS))
cat(sprintf("   After inner join      : %d\n", N_UNIVERSE))

# =============================================================================
# 5) SAMPLE RULE
# =============================================================================
# apply_rule() is used for the figure and for every section-11 variant, so all
# of them are built by the same code. `strict = TRUE` means growth must exceed
# min_growth (the retired rule's "> 0"); otherwise it must reach it (">= G").

apply_rule <- function(d_univ, min_growth, strict = FALSE, baseline_cut = NA_real_) {
  if (!is.na(baseline_cut))
    d_univ <- d_univ[!is.na(d_univ$reg_pop_2010_risk_total) &
                     d_univ$reg_pop_2010_risk_total > baseline_cut, , drop = FALSE]
  too_small <- function(v) if (strict) v <= min_growth else v < min_growth
  fail_c <- is.na(d_univ$delta_compact_total) | too_small(d_univ$delta_compact_total)
  fail_s <- is.na(d_univ$delta_sprawl_total)  | too_small(d_univ$delta_sprawl_total)
  list(d = d_univ[!fail_c & !fail_s, , drop = FALSE],
       n_after_cut = nrow(d_univ), fail_c = fail_c, fail_s = fail_s)
}

cat(sprintf("\n4) Filtering for growth >= %d in both sprawl and compact...\n",
            MIN_GROWTH_BOTH_TYPES))

main_rule <- apply_rule(df_univ, MIN_GROWTH_BOTH_TYPES)
df_plot   <- main_rule$d
N_after   <- nrow(df_plot)

cat(sprintf("   N before growth filter: %d\n", N_UNIVERSE))
cat(sprintf("   N after growth filter : %d (final sample)\n", N_after))
cat(sprintf("   Dropped -- compact only: %d | sprawl only: %d | both: %d\n",
            sum(main_rule$fail_c & !main_rule$fail_s),
            sum(main_rule$fail_s & !main_rule$fail_c),
            sum(main_rule$fail_c &  main_rule$fail_s)))

# =============================================================================
# 6) POPULATION QUARTILES (2022), reported in figure2_municipality_data.csv
# =============================================================================

df_plot <- df_plot %>%
  mutate(
    quartil_pop = cut(
      pop_mun_2022,
      breaks = quantile(pop_mun_2022, probs = c(0, 0.25, 0.5, 0.75, 1), na.rm = TRUE),
      labels = c("Q1: Smallest cities", "Q2: Small-medium", "Q3: Medium-large", "Q4: Largest cities"),
      include.lowest = TRUE
    )
  )

# =============================================================================
# 7) RATIO RANGES, AXIS WINDOW, NEGATIVE AND OFF-SCALE FLAGS
# =============================================================================

cat("\n5) Ratio ranges (unclipped)...\n")

rng_c <- range(df_plot$pct_risk_compact, na.rm = TRUE)
rng_s <- range(df_plot$pct_risk_sprawl,  na.rm = TRUE)
cat(sprintf("   compact: min = %.4f | max = %.4f\n", rng_c[1], rng_c[2]))
cat(sprintf("   sprawl : min = %.4f | max = %.4f\n", rng_s[1], rng_s[2]))

id_cols <- c("cod_mun", "uf", "fua_name", "pct_risk_compact", "pct_risk_sprawl")
cat("\n   Five lowest and five highest per axis (to judge whether AXIS_LIMITS is needed):\n")
for (v in c("pct_risk_compact", "pct_risk_sprawl")) {
  o <- order(df_plot[[v]])
  cat(sprintf("\n   %s, lowest:\n", v))
  print(as.data.frame(df_plot[head(o, 5), id_cols]), row.names = FALSE)
  cat(sprintf("   %s, highest:\n", v))
  print(as.data.frame(df_plot[tail(o, 5), id_cols]), row.names = FALSE)
}

axis_lim <- if (is.null(AXIS_LIMITS)) range(c(rng_c, rng_s, 0)) else range(c(AXIS_LIMITS, 0))

# The fit uses pct_risk_*; only the drawn position (x_draw, y_draw) is pulled
# to the panel edge for off-scale points.
df_plot <- df_plot %>%
  mutate(
    flag_negative_compact = coalesce(pct_risk_compact < 0, FALSE),
    flag_negative_sprawl  = coalesce(pct_risk_sprawl  < 0, FALSE),
    flag_offscale = coalesce(pct_risk_compact < axis_lim[1] | pct_risk_compact > axis_lim[2] |
                             pct_risk_sprawl  < axis_lim[1] | pct_risk_sprawl  > axis_lim[2], FALSE),
    x_draw = pmin(pmax(pct_risk_compact, axis_lim[1]), axis_lim[2]),
    y_draw = pmin(pmax(pct_risk_sprawl,  axis_lim[1]), axis_lim[2]),
    marker = if_else(flag_offscale, "Off-scale (drawn at the panel edge)", "In the axis window")
  )

cat(sprintf("\n   Axis window: [%.4f, %.4f] (%s)\n", axis_lim[1], axis_lim[2],
            if (is.null(AXIS_LIMITS)) "full data range" else "AXIS_LIMITS"))
cat(sprintf("   Off-scale points: %d\n", sum(df_plot$flag_offscale)))
if (any(df_plot$flag_offscale))
  print(as.data.frame(df_plot[df_plot$flag_offscale, id_cols]), row.names = FALSE)
cat(sprintf("   Points with a negative ratio on at least one axis: %d\n",
            sum(df_plot$flag_negative_compact | df_plot$flag_negative_sprawl)))

# =============================================================================
# 8) FIGURE
# =============================================================================

cat("\n6) Drawing Figure 2...\n")

# Negative ratios get no marker of their own (researcher, 2026-09-25); they
# are flagged in figure2_municipality_data.csv and counted in block B.
MARKERS <- c("In the axis window"                  = 16,
             "Off-scale (drawn at the panel edge)" = 17)

p_pure <- ggplot(df_plot) +
  geom_hline(yintercept = 0, colour = "grey30", linewidth = 0.25) +
  geom_vline(xintercept = 0, colour = "grey30", linewidth = 0.25) +
  geom_abline(slope = 1, intercept = 0,
              linetype = "dashed", colour = "grey40", linewidth = 0.35) +
  geom_point(aes(x = x_draw, y = y_draw, size = growth_total, shape = marker),
             colour = "#4878CF", alpha = 0.6, stroke = 0.4) +
  geom_smooth(aes(x = pct_risk_compact, y = pct_risk_sprawl),
              method = "lm", formula = y ~ x, se = TRUE,
              colour = "#E63946", fill = "#E63946", linewidth = 0.5, alpha = 0.15) +
  scale_shape_manual(values = MARKERS, name = NULL) +
  # growth_total = delta_compact_total + delta_sprawl_total, the two ratios'
  # denominators (>= 400 in this sample). Not delta_pop_total, which also
  # counts consolidated cells and can be negative.
  scale_size_area(max_size = 3, name = "Population change in compact and sprawl areas, 2010–2022",
                  breaks = SIZE_BREAKS, labels = label_comma()) +
  scale_x_continuous(labels = label_percent(accuracy = 1), expand = expansion(mult = 0.03)) +
  scale_y_continuous(labels = label_percent(accuracy = 1), expand = expansion(mult = 0.03)) +
  coord_fixed(ratio = 1, xlim = axis_lim, ylim = axis_lim) +
  labs(
    x = "Change in high-susceptibility population as a share\nof compact-area population change",
    y = "Change in high-susceptibility population as a share\nof sprawl-area population change"
  ) +
  # No legend key for the markers (researcher, 2026-09-25): the off-scale
  # triangle is explained in the figure's legend text. The size title sits
  # above its keys so the legend fits the 89 mm width.
  guides(shape = "none",
         size  = guide_legend(title.position = "top", nrow = 1)) +
  theme_minimal(base_size = 7, base_family = "sans") +
  theme(
    legend.position  = "bottom",
    legend.title     = element_text(size = 6.5),
    legend.text      = element_text(size = 6),
    axis.title       = element_text(size = 6.5),
    axis.text        = element_text(size = 6),
    panel.grid.minor = element_blank()
  )

out_pdf_pure <- output_path("plot_pct_risk_sprawl_vs_compact_pure.pdf")
out_png_pure <- output_path("plot_pct_risk_sprawl_vs_compact_pure.png")

ggsave(out_pdf_pure, p_pure, width = FIG_WIDTH_MM, height = FIG_HEIGHT_MM, units = "mm")
ggsave(out_png_pure, p_pure, width = FIG_WIDTH_MM, height = FIG_HEIGHT_MM, units = "mm",
       dpi = 300, bg = "white")

cat(sprintf("   Saved: %s\n", out_pdf_pure))
cat(sprintf("   Saved: %s\n", out_png_pure))

# =============================================================================
# 9) STATISTICS
# =============================================================================
# fig2_stats() returns the long-format rows for one sample variant. Every item
# is written even when its test fails (value NA), so each variant carries the
# same item list. All statistics use the unclipped ratios.
#
#   A sample   B ratios outside [0, 1]   C position relative to the 45-degree line
#   D medians  E Wilcoxon signed-rank    F correlations   G OLS fit
#
# Sign convention for the paired difference: compact - sprawl. Positive = the
# point is below the 45-degree line (compact ratio higher).

fig2_stats <- function(variant, rule, sel) {
  d <- sel$d
  x <- d$pct_risk_compact
  y <- d$pct_risk_sprawl
  ok <- !is.na(x) & !is.na(y)
  x <- x[ok]; y <- y[ok]
  n <- length(x)
  dif <- x - y

  rows <- list()
  put <- function(block, item, value, note = NA_character_) {
    value <- if (length(value) == 0 || is.null(value)) NA_real_ else unname(as.numeric(value[1]))
    rows[[length(rows) + 1L]] <<- data.frame(variant = variant, block = block, item = item,
                                             value = value, note = note,
                                             stringsAsFactors = FALSE)
  }

  # A. Sample
  put("A", "rule", NA, rule)
  put("A", "n_metrics", N_METRICS, "metrics municipalities before any filter")
  put("A", "n_universe", N_UNIVERSE, "regression-dataset municipalities with metrics")
  put("A", "n_after_baseline_cut", sel$n_after_cut,
      "equals n_universe when the variant has no pop_2010_risk_total cut")
  put("A", "n_final", nrow(d))
  put("A", "dropped_compact_only", sum(sel$fail_c & !sel$fail_s), "growth below the rule in compact cells only")
  put("A", "dropped_sprawl_only",  sum(sel$fail_s & !sel$fail_c), "growth below the rule in sprawl cells only")
  put("A", "dropped_both",         sum(sel$fail_c &  sel$fail_s), "growth below the rule in both types")
  put("A", "n_pairs", n, "municipalities with both ratios defined; every statistic below uses these")

  # B. Ratios outside [0, 1]
  put("B", "n_compact_lt0", sum(x < 0))
  put("B", "n_compact_gt1", sum(x > 1))
  put("B", "n_sprawl_lt0",  sum(y < 0))
  put("B", "n_sprawl_gt1",  sum(y > 1))
  put("B", "n_both_lt0",    sum(x < 0 & y < 0))

  # C. Position relative to the 45-degree line
  tie   <- abs(dif) < TIE_TOL
  above <- !tie & dif < 0
  below <- !tie & dif > 0
  tol_note <- sprintf("tie = |compact - sprawl| < %g", TIE_TOL)
  put("C", "n_above", sum(above), paste("sprawl > compact (above the line);", tol_note))
  put("C", "pct_above", 100 * mean(above), "percent of n_pairs")
  put("C", "n_below", sum(below), paste("compact > sprawl (below the line);", tol_note))
  put("C", "pct_below", 100 * mean(below), "percent of n_pairs")
  put("C", "n_ties", sum(tie), tol_note)
  put("C", "pct_ties", 100 * mean(tie), "percent of n_pairs")
  put("C", "n_ties_both_zero", sum(tie & abs(x) < TIE_TOL & abs(y) < TIE_TOL),
      "ties where both ratios are zero")

  # D. Central tendency
  put("D", "median_compact", median(x))
  put("D", "median_sprawl",  median(y))
  put("D", "median_diff", median(dif), "compact - sprawl")
  put("D", "diff_q1", unname(quantile(dif, 0.25)), "compact - sprawl, 25th percentile (quantile type 7)")
  put("D", "diff_q3", unname(quantile(dif, 0.75)), "compact - sprawl, 75th percentile (quantile type 7)")

  # E. Wilcoxon signed-rank, paired, two-sided
  wt <- tryCatch(wilcox.test(x, y, paired = TRUE, exact = FALSE, correct = TRUE),
                 error = function(e) NULL)
  put("E", "wilcoxon_V", if (is.null(wt)) NA else wt$statistic,
      "sum of ranks of positive (compact - sprawl) differences")
  put("E", "wilcoxon_p", if (is.null(wt)) NA else wt$p.value,
      "two-sided; normal approximation with continuity correction")
  put("E", "wilcoxon_n_pairs_used", sum(dif != 0),
      "pairs left after wilcox.test drops exactly-zero differences")

  # F. Association
  cs <- tryCatch(suppressWarnings(cor.test(x, y, method = "spearman", exact = FALSE)),
                 error = function(e) NULL)
  cp <- tryCatch(cor.test(x, y, method = "pearson"), error = function(e) NULL)
  put("F", "spearman_rho", if (is.null(cs)) NA else cs$estimate)
  put("F", "spearman_p",   if (is.null(cs)) NA else cs$p.value,
      "asymptotic t approximation (exact = FALSE); an exact p is not computable with tied ranks")
  put("F", "pearson_r", if (is.null(cp)) NA else cp$estimate)
  put("F", "pearson_p", if (is.null(cp)) NA else cp$p.value, "t test, n - 2 df")

  # G. OLS fit: sprawl ratio on compact ratio
  fit <- tryCatch(lm(y ~ x), error = function(e) NULL)
  if (!is.null(fit) && nrow(summary(fit)$coefficients) == 2) {
    cf    <- summary(fit)$coefficients
    slope <- cf[2, 1]; se <- cf[2, 2]; icpt <- cf[1, 1]
    p_s1  <- 2 * pt(abs((slope - 1) / se), df = fit$df.residual, lower.tail = FALSE)
    cross <- if (abs(1 - slope) > 1e-12) icpt / (1 - slope) else NA_real_
    r2    <- summary(fit)$r.squared
  } else {
    slope <- se <- icpt <- p_s1 <- cross <- r2 <- NA_real_
  }
  put("G", "ols_slope", slope)
  put("G", "ols_slope_se", se, "classical OLS standard error")
  put("G", "ols_intercept", icpt)
  put("G", "ols_r2", r2)
  put("G", "ols_p_slope_eq_1", p_s1, "two-sided t test of H0: slope = 1")
  put("G", "crossing_x", cross,
      "compact ratio where the OLS line meets the 45-degree line: intercept / (1 - slope)")
  put("G", "n_compact_above_crossing", if (is.na(cross)) NA else sum(x > cross))

  do.call(rbind, rows)
}

MAIN_VARIANT <- "(a) the figure"
MAIN_RULE    <- sprintf("no pop_2010_risk_total cut; growth >= %d in both types", MIN_GROWTH_BOTH_TYPES)

stats_main <- fig2_stats(MAIN_VARIANT, MAIN_RULE, main_rule)

cat("\n", strrep("-", 60), "\n", sep = "")
cat("FIGURE 2 STATISTICS (unclipped; paired difference = compact - sprawl)\n")
cat(strrep("-", 60), "\n", sep = "")
cat(sprintf("   Rule: %s\n", MAIN_RULE))
for (i in seq_len(nrow(stats_main))) {
  r <- stats_main[i, ]
  if (r$item == "rule") next
  cat(sprintf("   %s  %-26s %s\n", r$block, r$item,
              if (is.na(r$value)) "NA" else format(signif(r$value, 6), scientific = FALSE)))
}

# =============================================================================
# 10) PER-MUNICIPALITY DATA
# =============================================================================

muni_out <- df_plot %>%
  transmute(cod_mun, uf, fua_name,
            delta_compact_risk, delta_compact_total,
            delta_sprawl_risk,  delta_sprawl_total,
            pct_risk_compact, pct_risk_sprawl,
            growth_total, pop_mun_2022,
            quartil_pop = as.character(quartil_pop),
            flag_negative_compact, flag_negative_sprawl, flag_offscale)

out_muni <- output_path("figure2_municipality_data.csv")
write_csv(muni_out, out_muni)
cat(sprintf("\n   Saved: %s\n", out_muni))

# =============================================================================
# 11) SAMPLE-DEFINITION VARIANTS
# =============================================================================
# The same statistics under other sample rules, all unclipped, all from the
# regression-dataset universe of section 4:
#   (b) growth >= G in both types, G in G_VALUES. G = 200 must reproduce (a).
#   (c) pop_2010_risk_total > MIN_POP_RISCO_2010 (00_setup.R; the Table 2
#       baseline cut) AND growth >= MIN_GROWTH_BOTH_TYPES in both types.
#   retired rule -- used until 2026-09-21: pop_2010_risk_total >
#       RETIRED_MIN_POP_RISCO_2010, then growth > 0 in both types.
# Nothing is chosen here.

cat("\n", strrep("=", 74), "\n", sep = "")
cat("11) SAMPLE-DEFINITION VARIANTS\n")
cat(strrep("=", 74), "\n", sep = "")

G_VALUES <- c(1, 100, 200, 500, 1000)

stats_list <- list(stats_main)

for (g in G_VALUES)
  stats_list[[length(stats_list) + 1L]] <- fig2_stats(
    sprintf("(b) G = %d", g),
    sprintf("no pop_2010_risk_total cut; growth >= %d in both types", g),
    apply_rule(df_univ, g))

stats_list[[length(stats_list) + 1L]] <- fig2_stats(
  sprintf("(c) baseline cut + G = %d", MIN_GROWTH_BOTH_TYPES),
  sprintf("pop_2010_risk_total > %d; growth >= %d in both types",
          MIN_POP_RISCO_2010, MIN_GROWTH_BOTH_TYPES),
  apply_rule(df_univ, MIN_GROWTH_BOTH_TYPES, baseline_cut = MIN_POP_RISCO_2010))

stats_list[[length(stats_list) + 1L]] <- fig2_stats(
  "retired rule",
  sprintf("pop_2010_risk_total > %d, then growth > 0 in both types (until 2026-09-21)",
          RETIRED_MIN_POP_RISCO_2010),
  apply_rule(df_univ, 0, strict = TRUE, baseline_cut = RETIRED_MIN_POP_RISCO_2010))

stats_all <- do.call(rbind, stats_list)

get_stat <- function(v, it) {
  val <- stats_all$value[stats_all$variant == v & stats_all$item == it]
  if (length(val) == 1) val else NA_real_
}

# Guard: the G = 200 row must reproduce the figure's own sample and fit.
g_ref <- sprintf("(b) G = %d", MIN_GROWTH_BOTH_TYPES)
if (MIN_GROWTH_BOTH_TYPES %in% G_VALUES &&
    (!isTRUE(get_stat(g_ref, "n_final") == get_stat(MAIN_VARIANT, "n_final")) ||
     !isTRUE(abs(get_stat(g_ref, "ols_slope") - get_stat(MAIN_VARIANT, "ols_slope")) < 1e-10)))
  warning("Variant '", g_ref, "' does not reproduce '", MAIN_VARIANT,
          "'. The sweep and the figure have diverged -- do not read the table until resolved.")

variant_labels <- unique(stats_all$variant)
key_items <- c("n_after_baseline_cut", "n_final", "dropped_compact_only", "dropped_sprawl_only",
               "dropped_both", "n_compact_lt0", "n_compact_gt1", "n_sprawl_lt0", "n_sprawl_gt1",
               "n_above", "n_below", "n_ties", "median_compact", "median_sprawl", "median_diff",
               "wilcoxon_p", "spearman_rho", "pearson_r", "ols_slope", "ols_intercept", "crossing_x")
wide <- as.data.frame(sapply(key_items, function(it) sapply(variant_labels, get_stat, it = it)))
wide <- cbind(variant = variant_labels, round(wide, 4))

cat("\nRules:\n")
for (v in variant_labels)
  cat(sprintf("  %-28s %s\n", v, stats_all$note[stats_all$variant == v & stats_all$item == "rule"]))
cat("\n")
print(wide, row.names = FALSE)

# =============================================================================
# 12) WRITE STATISTICS
# =============================================================================

out_stats <- output_path("figure2_statistics.csv")
write_csv(stats_all, out_stats)
cat(sprintf("\n   Saved: %s\n", out_stats))

cat("\nDone.\n")
