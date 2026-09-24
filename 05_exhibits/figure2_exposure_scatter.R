# =============================================================================
# figure2_exposure_scatter.R  (Figure 2; formerly
# regression2/plot_pct_risk_sprawl_vs_compact_population.R)
# Scatterplot: share of growth going to high-risk areas — sprawl vs compact
#
# Creates TWO versions:
# 1) Pure plot (no facets) - tests overall similarity
# 2) Faceted by population size quartiles (pop_mun_2022 from regression dataset)
#
# Sample (changed 2026-09-21, researcher): every municipality in
# dataset_regressao_municipio.csv with growth of at least
# MIN_GROWTH_BOTH_TYPES persons in BOTH sprawl and compact cells, 2010-2022.
#
# WHY THIS AND NOT pop_2010_risk_total > 200. This figure plots
# delta_risk / delta_pop by growth type. pop_2010_risk_total is not the
# denominator of anything shown here -- it is g_alta's denominator, which is
# what the cut was designed for in 16_estimate_models.R. Restricting it left
# the ratios unstable: section 11's sweep shows the unclipped fit at slope
# 0.052 under the old rule against 0.530 under this one, with the whole
# difference produced by three municipalities whose growth in one type was
# under a hundred people. A threshold on period growth restricts the actual
# denominator. The old rule also selected municipalities that were already
# more exposed in 2010, raising both medians relative to the study population.
#
# The value 200 is NOT selected by the data: G = 100 and G = 200 give
# essentially the same fit (0.531 vs 0.530), and the results are flat from 100
# to 500. It is set equal to the regressions' minimum-baseline magnitude so the
# two thresholds read as one convention. Section 11 reports the full sweep, and
# the retired rule alongside it, so the insensitivity is visible.
#
# THIS REVERSES MIGRATION_PLAN.md 6c2 (decided 2026-09-10), which put Figure 2
# on the same municipalities as Tables 1/2. A descriptive figure and a
# regression need not share a sample, but the change is deliberate and is
# recorded in 05_exhibits/pipeline_5.md, not left silent.
#
# NOTE: requiring growth in BOTH types conditions on the outcome dimension --
# municipalities that grew almost entirely one way are excluded. At G = 200
# that is 54 dropped for compact against 2 for sprawl. This is inherent to a
# paired comparison (the retired rule dropped 42 against 3) and belongs in the
# figure's caption rather than being left for a reader to discover.
#
# Input:  data/processed_data/03_urban_footprint/metricas/metricas_municipio_2010_2022.csv
#         (MIGRATION_PLAN.md 6b0 common-grid rework, 2026-08-28 -- replaces the retired
#         metricas_municipio_2010_2020.csv; per-type deltas are now derived in this script
#         from pop_2022_<type>/pop_2010_<type>/pop_2022_risk_<type>/pop_2010_risk_<type>
#         instead of being read pre-computed as delta_<type>/delta_risco_alta_<type>)
#         data/processed_data/04_regression/tables/dataset_regressao_municipio.csv (script 15)
# Output (output/, per 05_exhibits/pipeline_5.md -- decided 2026-08-20):
#         plot_pct_risk_sprawl_vs_compact_pure.pdf/png
#         plot_pct_risk_sprawl_vs_compact_population.pdf/png
#
# Run from the repository root (relative paths, CLAUDE.md rule 5).
# =============================================================================

source("04_regression_dataset_and_models/00_setup.R")

# The figure's sample rule: minimum 2010-2022 growth, in persons, required in
# BOTH sprawl and compact cells. See the header for why this replaced the
# pop_2010_risk_total cut on 2026-09-21.
MIN_GROWTH_BOTH_TYPES <- 200

# The retired rule, kept only so section 11 can report it as a comparison row.
# Nothing in the figure's own path reads it.
RETIRED_MIN_POP_RISCO_2010 <- 200

for (pkg in c("ggplot2", "dplyr", "scales"))
  if (!requireNamespace(pkg, quietly = TRUE)) install.packages(pkg)
library(ggplot2); library(dplyr); library(scales)

cat("\n", strrep("=", 60), "\n")
cat("PLOT_PCT_RISK_SPRAWL_VS_COMPACT_POPULATION.R\n")
cat(strrep("=", 60), "\n")

# =============================================================================
# 1) LOAD METRICS DATA
# =============================================================================

cat("\n1) Loading metrics data...\n")

path_csv     <- file.path(metricas_dir, "metricas_municipio_2010_2022.csv")

if (!file.exists(path_csv))
  stop(sprintf("File not found:\n  %s\n\nRun 03_urban_footprint_and_growth_types/07_aggregate_municipality_metrics.R first.", path_csv))

df_raw <- readr::read_csv(path_csv, show_col_types = FALSE)
cat(sprintf("   Raw: %d rows × %d cols\n", nrow(df_raw), ncol(df_raw)))

# Quick column check -- pop_2022_<type>/pop_2010_<type>/pop_2022_risk_<type>/
# pop_2010_risk_<type> replace the retired delta_<type>/delta_risco_alta_<type>
# columns; deltas are derived below instead of read pre-computed.
needed <- c(
  paste0("pop_2022_", c("extension", "leapfrog", "peripheral", "densification", "infill")),
  paste0("pop_2010_", c("extension", "leapfrog", "peripheral", "densification", "infill")),
  paste0("pop_2022_risk_", c("extension", "leapfrog", "peripheral", "densification", "infill")),
  paste0("pop_2010_risk_", c("extension", "leapfrog", "peripheral", "densification", "infill"))
)
missing <- setdiff(needed, names(df_raw))
if (length(missing) > 0)
  stop(sprintf("Missing columns: %s", paste(missing, collapse = ", ")))

# =============================================================================
# 2) LOAD REGRESSION DATASET (to restrict sample)
# =============================================================================

cat("\n2) Loading regression dataset (to restrict to regression municipalities)...\n")

path_reg <- file.path(tables_dir, "dataset_regressao_municipio.csv")
if (!file.exists(path_reg))
  stop(sprintf("File not found:\n  %s\n\nRun 04_regression_dataset_and_models/15_final_dataset.R first.", path_reg))

df_reg <- readr::read_csv(path_reg, show_col_types = FALSE)
cat(sprintf("   Regression dataset: %d rows × %d cols\n", nrow(df_reg), ncol(df_reg)))

# Same minimum-baseline restriction as 16_estimate_models.R, so the figure
# and the regression tables describe the same municipalities.
n_reg_all <- n_distinct(df_reg$cod_mun)
# No pop_2010_risk_total restriction: the figure now uses every municipality in
# the regression dataset, and the sample is decided by the growth threshold in
# section 5 instead.
df_reg_small <- df_reg %>%
  select(cod_mun) %>%
  distinct()

cat(sprintf("   Regression dataset: %d municipalities; no pop_2010_risk_total cut applied: %d\n",
            n_reg_all, nrow(df_reg_small)))

# =============================================================================
# 3) DERIVE RATIOS
# =============================================================================

df <- df_raw %>%
  mutate(
    # Per-type 2010->2022 deltas, derived from the common-grid levels
    # (pop_2022_<type>/pop_2010_<type>, both years on the same grid and
    # classification -- see MIGRATION_PLAN.md 6b0) rather than read
    # pre-computed, as the retired M4/M5 cross-grid schema used to provide.
    delta_sprawl_risk  = (pop_2022_risk_extension  - pop_2010_risk_extension) +
                         (pop_2022_risk_leapfrog   - pop_2010_risk_leapfrog)  +
                         (pop_2022_risk_peripheral - pop_2010_risk_peripheral),
    delta_sprawl_total = (pop_2022_extension  - pop_2010_extension) +
                         (pop_2022_leapfrog   - pop_2010_leapfrog)  +
                         (pop_2022_peripheral - pop_2010_peripheral),
    delta_compact_risk = (pop_2022_risk_densification - pop_2010_risk_densification) +
                         (pop_2022_risk_infill        - pop_2010_risk_infill),
    delta_compact_total= (pop_2022_densification - pop_2010_densification) +
                         (pop_2022_infill        - pop_2010_infill),
    pct_risk_sprawl    = delta_sprawl_risk  / delta_sprawl_total,
    pct_risk_compact   = delta_compact_risk / delta_compact_total,
    growth_total       = delta_sprawl_total + delta_compact_total,
    pop_mun_2022       = pop_2022_total
  )

# Unrestricted copy, kept for the sample-definition variants in section 11.
# Section 4 overwrites `df` with the inner join against the regression
# municipalities, and section 11's retired-rule row needs the frame from
# before that join. Nothing in the figure's own path reads df_all.
df_all <- df

# =============================================================================
# 4) MERGE WITH REGRESSION DATASET (INNER JOIN - restrict to regression sample)
# =============================================================================

cat("\n3) Restricting to regression municipalities (inner join)...\n")

N_metrics <- nrow(df)

df <- df %>%
  inner_join(df_reg_small, by = "cod_mun")

cat(sprintf("   Metrics municipalities: %d\n", N_metrics))
cat(sprintf("   Regression municipalities: %d\n", nrow(df_reg_small)))
cat(sprintf("   After inner join: %d\n", nrow(df)))

# =============================================================================
# 5) FILTER  (minimum growth in BOTH types -- this is the sample rule)
# =============================================================================

cat(sprintf("\n4) Filtering for growth >= %d in both sprawl and compact...\n",
            MIN_GROWTH_BOTH_TYPES))

N_before <- nrow(df)

fail_compact <- is.na(df$delta_compact_total) | df$delta_compact_total < MIN_GROWTH_BOTH_TYPES
fail_sprawl  <- is.na(df$delta_sprawl_total)  | df$delta_sprawl_total  < MIN_GROWTH_BOTH_TYPES

df_plot <- df[!fail_compact & !fail_sprawl, , drop = FALSE]

N_after   <- nrow(df_plot)
N_dropped <- N_before - N_after

cat(sprintf("   N before growth filter: %d\n", N_before))
cat(sprintf("   N after growth filter : %d (final sample)\n", N_after))
cat(sprintf("   N dropped             : %d\n", N_dropped))
cat(sprintf("     compact only: %d | sprawl only: %d | both: %d\n",
            sum(fail_compact & !fail_sprawl),
            sum(fail_sprawl & !fail_compact),
            sum(fail_compact & fail_sprawl)))

# =============================================================================
# 6) CREATE POPULATION QUARTILES
# =============================================================================

cat("\n5) Creating population quartiles...\n")

df_plot <- df_plot %>%
  mutate(
    quartil_pop = cut(
      pop_mun_2022,
      breaks = quantile(pop_mun_2022, probs = c(0, 0.25, 0.5, 0.75, 1), na.rm = TRUE),
      labels = c("Q1: Smallest cities", "Q2: Small-medium", "Q3: Medium-large", "Q4: Largest cities"),
      include.lowest = TRUE
    )
  )

# Summary
cat(sprintf("   Population quartile distribution:\n"))
print(table(df_plot$quartil_pop))

# Population ranges by quartile
cat(sprintf("\n   Population ranges by quartile:\n"))
df_plot %>%
  group_by(quartil_pop) %>%
  summarise(
    n = n(),
    min_pop = min(pop_mun_2022, na.rm = TRUE),
    median_pop = median(pop_mun_2022, na.rm = TRUE),
    max_pop = max(pop_mun_2022, na.rm = TRUE)
  ) %>%
  print(n = Inf)

# =============================================================================
# 7) CLIP VALUES TO [0, 1]
# =============================================================================

df_plot <- df_plot %>%
  mutate(
    pct_risk_sprawl_cl  = pmin(pmax(pct_risk_sprawl,  0), 1),
    pct_risk_compact_cl = pmin(pmax(pct_risk_compact, 0), 1)
  )

# =============================================================================
# 8) PLOT 1: PURE VERSION (NO FACETS)
# =============================================================================

cat("\n6) Creating pure plot (no facets)...\n")

p_pure <- ggplot(df_plot, aes(x = pct_risk_compact_cl, y = pct_risk_sprawl_cl)) +
  geom_abline(slope = 1, intercept = 0,
              linetype = "dashed", colour = "grey50", linewidth = 0.8) +
  geom_point(aes(size = growth_total), colour = "#4878CF", alpha = 0.4) +
  geom_smooth(method = "lm", se = TRUE,
              colour = "#E63946", fill = "#E63946", linewidth = 1.0, alpha = 0.15) +
  scale_size_continuous(
    range  = c(0.5, 6),
    name   = "Total growth\n(pop, 2010–2022)",
    labels = label_number(scale_cut = cut_short_scale())
  ) +
  scale_x_continuous(labels = label_percent(accuracy = 1),
                     limits = c(0, 1), expand = expansion(mult = 0.02)) +
  scale_y_continuous(labels = label_percent(accuracy = 1),
                     limits = c(0, 1), expand = expansion(mult = 0.02)) +
  coord_equal() +
  labs(
    title    = "Share of growth going to high-susceptibility areas: sprawl vs compact",
    subtitle = sprintf(
      "Regression sample; growth of at least %d people in both types  |  N = %d",
      MIN_GROWTH_BOTH_TYPES, N_after),
    x        = "Share of compact growth going to high-risk areas",
    y        = "Share of sprawl growth\ngoing to high-risk areas",
    caption  = "Dashed grey line: 45° reference (equal allocation). Red line: linear regression with 95% CI.\nProximity to 45° line indicates similar risk allocation between growth types."
  ) +
  theme_minimal(base_size = 11) +
  theme(
    legend.position  = "right",
    panel.grid.minor = element_blank(),
    plot.caption     = element_text(hjust = 0, size = 8, colour = "grey40"),
    plot.subtitle    = element_text(size = 9, colour = "grey30"),
    aspect.ratio     = 1
  )

# Save
out_pdf_pure <- output_path("plot_pct_risk_sprawl_vs_compact_pure.pdf")
out_png_pure <- output_path("plot_pct_risk_sprawl_vs_compact_pure.png")

ggsave(out_pdf_pure, p_pure, width = 7.5, height = 7, dpi = 300)
ggsave(out_png_pure, p_pure, width = 7.5, height = 7, dpi = 300)

cat(sprintf("   Saved: %s\n", out_pdf_pure))
cat(sprintf("   Saved: %s\n", out_png_pure))

# =============================================================================
# 9) PLOT 2: FACETED BY POPULATION QUARTILES
# =============================================================================

cat("\n7) Creating plot faceted by population quartiles...\n")

p_pop <- ggplot(df_plot, aes(x = pct_risk_compact_cl, y = pct_risk_sprawl_cl)) +
  geom_abline(slope = 1, intercept = 0,
              linetype = "dashed", colour = "grey50", linewidth = 0.6) +
  geom_point(aes(size = growth_total), colour = "#4878CF", alpha = 0.4) +
  geom_smooth(method = "lm", se = TRUE,
              colour = "#E63946", fill = "#E63946", linewidth = 0.8, alpha = 0.15) +
  facet_wrap(~ quartil_pop, ncol = 2) +
  scale_size_continuous(
    range  = c(0.5, 4),
    name   = "Total growth\n(pop, 2010–2022)",
    labels = label_number(scale_cut = cut_short_scale())
  ) +
  scale_x_continuous(labels = label_percent(accuracy = 1),
                     limits = c(0, 1), expand = expansion(mult = 0.02)) +
  scale_y_continuous(labels = label_percent(accuracy = 1),
                     limits = c(0, 1), expand = expansion(mult = 0.02)) +
  coord_equal() +
  labs(
    title    = "Share of growth going to high-susceptibility areas: sprawl vs compact",
    subtitle = sprintf(
      "Faceted by population quartiles (pop_mun_2022)  |  growth >= %d in both types  |  N = %d",
      MIN_GROWTH_BOTH_TYPES, N_after),
    x        = "Share of compact growth going to high-risk areas",
    y        = "Share of sprawl growth\ngoing to high-risk areas",
    caption  = "Dashed grey line: 45° reference (equal allocation). Red line: linear regression with 95% CI."
  ) +
  theme_minimal(base_size = 10) +
  theme(
    legend.position  = "bottom",
    panel.grid.minor = element_blank(),
    plot.caption     = element_text(hjust = 0, size = 8, colour = "grey40"),
    plot.subtitle    = element_text(size = 8, colour = "grey30"),
    strip.text       = element_text(face = "bold", size = 9)
  )

# Save
out_pdf_pop <- output_path("plot_pct_risk_sprawl_vs_compact_population.pdf")
out_png_pop <- output_path("plot_pct_risk_sprawl_vs_compact_population.png")

ggsave(out_pdf_pop, p_pop, width = 10, height = 10, dpi = 300)
ggsave(out_png_pop, p_pop, width = 10, height = 10, dpi = 300)

cat(sprintf("   Saved: %s\n", out_pdf_pop))
cat(sprintf("   Saved: %s\n", out_png_pop))

# =============================================================================
# 10) SUMMARY DIAGNOSTICS
# =============================================================================

cat("\n", strrep("-", 60), "\n")
cat("SUMMARY DIAGNOSTICS\n")
cat(strrep("-", 60), "\n")

cat("\n[A] OVERALL (PURE PLOT)\n\n")

diff_pair <- df_plot$pct_risk_compact - df_plot$pct_risk_sprawl
share_below_45 <- mean(diff_pair > 0, na.rm = TRUE)

wtest <- tryCatch(
  wilcox.test(df_plot$pct_risk_compact, df_plot$pct_risk_sprawl,
              paired = TRUE, exact = FALSE),
  error = function(e) list(p.value = NA)
)

cat(sprintf("   N                                                       : %d\n", N_after))
cat(sprintf("   Median pct_risk_compact                                 : %.3f (%.1f%%)\n",
            median(df_plot$pct_risk_compact, na.rm = TRUE),
            100 * median(df_plot$pct_risk_compact, na.rm = TRUE)))
cat(sprintf("   Median pct_risk_sprawl                                  : %.3f (%.1f%%)\n",
            median(df_plot$pct_risk_sprawl,  na.rm = TRUE),
            100 * median(df_plot$pct_risk_sprawl,  na.rm = TRUE)))
cat(sprintf("   Median difference (compact - sprawl)                    : %.3f (%.1f pp)\n",
            median(diff_pair, na.rm = TRUE),
            100 * median(diff_pair, na.rm = TRUE)))
cat(sprintf("   Share below 45° line (compact > sprawl)                 : %.1f%%\n",
            100 * share_below_45))
cat(sprintf("   Wilcoxon signed-rank p-value                            : %.4f %s\n",
            wtest$p.value,
            ifelse(wtest$p.value < 0.05, "***", "")))

# Correlation
cr <- cor.test(df_plot$pct_risk_sprawl, df_plot$pct_risk_compact,
               method = "spearman", use = "complete.obs")
cp <- cor.test(df_plot$pct_risk_sprawl, df_plot$pct_risk_compact,
               method = "pearson",   use = "complete.obs")
cat(sprintf("   Pearson correlation                                     : %.3f (p = %.4f)\n",
            cp$estimate, cp$p.value))
cat(sprintf("   Spearman correlation                                    : %.3f (p = %.4f)\n",
            cr$estimate, cr$p.value))

# Linear regression for slope
lm_fit <- lm(pct_risk_sprawl_cl ~ pct_risk_compact_cl, data = df_plot)
lm_summary <- summary(lm_fit)
cat(sprintf("\n   Linear regression: y = %.3f + %.3f * x\n",
            coef(lm_fit)[1], coef(lm_fit)[2]))
cat(sprintf("   Slope (β₁)                                              : %.3f (SE = %.3f)\n",
            coef(lm_fit)[2], lm_summary$coefficients[2, 2]))
cat(sprintf("   R²                                                      : %.3f\n",
            lm_summary$r.squared))
cat(sprintf("   Slope = 1? (t-test)                                     : p = %.4f %s\n",
            2 * pt(abs((coef(lm_fit)[2] - 1) / lm_summary$coefficients[2, 2]),
                   df = lm_fit$df.residual, lower.tail = FALSE),
            ifelse(2 * pt(abs((coef(lm_fit)[2] - 1) / lm_summary$coefficients[2, 2]),
                          df = lm_fit$df.residual, lower.tail = FALSE) > 0.05, "(not rejected)", "***")))

cat("\n[B] BY POPULATION QUARTILES\n\n")

df_plot %>%
  group_by(quartil_pop) %>%
  summarise(
    n = n(),
    median_pct_risk_compact = median(pct_risk_compact, na.rm = TRUE),
    median_pct_risk_sprawl  = median(pct_risk_sprawl, na.rm = TRUE),
    diff = median_pct_risk_compact - median_pct_risk_sprawl,
    share_below_45 = mean(pct_risk_compact > pct_risk_sprawl, na.rm = TRUE),
    correlation = cor(pct_risk_compact, pct_risk_sprawl, use = "complete.obs", method = "spearman")
  ) %>%
  print(n = Inf)

cat("\nDone.\n")

# =============================================================================
# 11) SAMPLE-DEFINITION VARIANTS  (added 2026-09-21 on request)
# =============================================================================
#
# Two ways of deciding which municipalities Figure 2 shows, reported side by
# side. Nothing above this line is changed: variant (a) reuses `df_plot`, the
# exact frame the figure was drawn from, so the reference row and the figure
# cannot disagree.
#
#   (a) THE FIGURE -- the rule adopted 2026-09-21: no pop_2010_risk_total cut,
#       growth >= MIN_GROWTH_BOTH_TYPES in both types.
#   RETIRED -- the rule used until 2026-09-21: pop_2010_risk_total > 200, then
#       growth > 0 in both types. Kept so the change stays auditable.
#   (b) the same growth rule swept over G in (1, 100, 200, 500, 1000). The
#       G = 200 row should reproduce row (a) exactly; if it does not, the
#       figure's path and this block have diverged.
#
# ASSUMPTION, stated because it is a choice and not in the brief: variant (b)
# still restricts to the municipalities of dataset_regressao_municipio.csv
# (all of them, not the MIN_POP-restricted subset). Dropping the baseline cut
# is not the same as abandoning the regression sample, and keeping the same
# municipality universe is what isolates the effect of swapping one filter for
# the other. Change REG_SET_B below to use df_all alone if the intent was to
# leave that universe too.
#
# NOTHING IS CHOSEN HERE. The table is printed and written; which rule the
# figure should use is a decision for the researcher.
#
# On the clip: every statistic below is computed on the UNCLIPPED ratios,
# matching the existing diagnostics block, EXCEPT that the fitted line is
# reported twice -- once unclipped and once on the [0,1]-clipped values the
# existing script fits (L342) and the plot draws (L201, L251). The count of
# points clipped on each axis is reported so the gap between the two fits can
# be read against how many observations the clip moves.

cat("\n", strrep("=", 74), "\n", sep = "")
cat("11) SAMPLE-DEFINITION VARIANTS\n")
cat(strrep("=", 74), "\n", sep = "")

# The sweep. G = 200 is the figure's own rule, so that row must match row (a);
# the others show how little the result moves between 100 and 500.
G_VALUES <- c(1, 100, 200, 500, 1000)

# Municipality universe for variant (b): every municipality in the regression
# dataset, without the pop_2010_risk_total cut.
REG_SET_B <- df_reg %>% select(cod_mun) %>% distinct()

clip01 <- function(x) pmin(pmax(x, 0), 1)

# One row of the comparison table. `d_join` is the metrics frame already
# restricted to the variant's municipality universe; `keep` is the logical
# vector of the growth filter, passed in so each variant can use its own rule.
variant_row <- function(label, rule, n_metrics, d_join, keep, fail_c, fail_s) {
  d <- d_join[keep, , drop = FALSE]
  n <- nrow(d)

  x  <- d$pct_risk_compact
  y  <- d$pct_risk_sprawl
  xc <- clip01(x)
  yc <- clip01(y)

  diff_pair <- x - y
  wt <- tryCatch(
    wilcox.test(x, y, paired = TRUE, exact = FALSE),
    error = function(e) list(p.value = NA_real_)
  )
  fit_raw <- tryCatch(lm(y ~ x),   error = function(e) NULL)
  fit_cl  <- tryCatch(lm(yc ~ xc), error = function(e) NULL)
  cf <- function(f, i) if (is.null(f)) NA_real_ else unname(coef(f)[i])

  data.frame(
    variant                = label,
    rule                   = rule,
    n_metrics              = n_metrics,
    n_in_universe          = nrow(d_join),
    dropped_by_universe    = n_metrics - nrow(d_join),
    n_final                = n,
    dropped_by_growth      = nrow(d_join) - n,
    dropped_compact_only   = sum(fail_c & !fail_s),
    dropped_sprawl_only    = sum(fail_s & !fail_c),
    dropped_both           = sum(fail_c & fail_s),
    median_compact         = median(x, na.rm = TRUE),
    median_sprawl          = median(y, na.rm = TRUE),
    median_diff            = median(diff_pair, na.rm = TRUE),
    share_below_45         = mean(diff_pair > 0, na.rm = TRUE),
    wilcoxon_p             = wt$p.value,
    slope_unclipped        = cf(fit_raw, 2),
    intercept_unclipped    = cf(fit_raw, 1),
    slope_clipped          = cf(fit_cl, 2),
    intercept_clipped      = cf(fit_cl, 1),
    clipped_x_at_0         = sum(!is.na(x) & x < 0),
    clipped_x_at_1         = sum(!is.na(x) & x > 1),
    clipped_y_at_0         = sum(!is.na(y) & y < 0),
    clipped_y_at_1         = sum(!is.na(y) & y > 1),
    stringsAsFactors = FALSE
  )
}

N_METRICS <- nrow(df_all)

# --- (a) reference: the frame the figure was actually drawn from -------------
# df is the post-inner-join frame of section 4; df_plot is it after the
# positive-growth filter of section 5. Recomputing the fail flags on df
# reproduces that filter exactly (section 5).
fail_c_a <- is.na(df$delta_compact_total) | df$delta_compact_total < MIN_GROWTH_BOTH_TYPES
fail_s_a <- is.na(df$delta_sprawl_total)  | df$delta_sprawl_total  < MIN_GROWTH_BOTH_TYPES
keep_a   <- !fail_c_a & !fail_s_a

rows <- list(
  variant_row(
    label     = "(a) the figure",
    rule      = sprintf("no pop_2010_risk_total cut; growth >= %d in both types",
                        MIN_GROWTH_BOTH_TYPES),
    n_metrics = N_METRICS,
    d_join    = df,
    keep      = keep_a,
    fail_c    = fail_c_a,
    fail_s    = fail_s_a
  )
)

# Guard: row (a) must reproduce the figure's own N exactly.
if (rows[[1]]$n_final != N_after)
  warning("Row (a) recomputed N = ", rows[[1]]$n_final,
          " but the figure was drawn on N = ", N_after,
          ". The row does not reproduce the figure -- do not read the ",
          "table until this is resolved.")

# --- the retired rule, for comparison ----------------------------------------
# What the figure showed until 2026-09-21. Reported so the change from one rule
# to the other can be read off a single table rather than from two runs.
retired_set <- df_reg %>%
  filter(pop_2010_risk_total > RETIRED_MIN_POP_RISCO_2010) %>%
  select(cod_mun) %>%
  distinct()
df_ret   <- df_all %>% inner_join(retired_set, by = "cod_mun")
fail_c_r <- is.na(df_ret$delta_compact_total) | df_ret$delta_compact_total <= 0
fail_s_r <- is.na(df_ret$delta_sprawl_total)  | df_ret$delta_sprawl_total  <= 0

rows[[length(rows) + 1L]] <- variant_row(
  label     = "retired rule",
  rule      = sprintf("pop_2010_risk_total > %d, then growth > 0 in both types (until 2026-09-21)",
                      RETIRED_MIN_POP_RISCO_2010),
  n_metrics = N_METRICS,
  d_join    = df_ret,
  keep      = !fail_c_r & !fail_s_r,
  fail_c    = fail_c_r,
  fail_s    = fail_s_r
)

# --- (b) no baseline cut; growth >= G in both types --------------------------
df_b <- df_all %>% inner_join(REG_SET_B, by = "cod_mun")

for (g in G_VALUES) {
  fail_c <- is.na(df_b$delta_compact_total) | df_b$delta_compact_total < g
  fail_s <- is.na(df_b$delta_sprawl_total)  | df_b$delta_sprawl_total  < g
  rows[[length(rows) + 1L]] <- variant_row(
    label     = sprintf("(b) G = %d", g),
    rule      = sprintf("no pop_2010_risk_total cut; growth >= %d in both types", g),
    n_metrics = N_METRICS,
    d_join    = df_b,
    keep      = !fail_c & !fail_s,
    fail_c    = fail_c,
    fail_s    = fail_s
  )
}

variants <- do.call(rbind, rows)

# --- Print -------------------------------------------------------------------

show_cols <- function(cols, title) {
  cat(sprintf("\n%s\n", title))
  d <- variants[, c("variant", cols), drop = FALSE]
  num <- vapply(d, is.numeric, logical(1))
  d[num] <- lapply(d[num], function(v) ifelse(abs(v) >= 1 | v == 0, round(v, 3), signif(v, 3)))
  print(d, row.names = FALSE)
}

cat("\nRules:\n")
for (i in seq_len(nrow(variants)))
  cat(sprintf("  %-14s %s\n", variants$variant[i], variants$rule[i]))

show_cols(c("n_metrics", "n_in_universe", "dropped_by_universe",
            "n_final", "dropped_by_growth",
            "dropped_compact_only", "dropped_sprawl_only", "dropped_both"),
          "Sample and attrition:")

show_cols(c("n_final", "median_compact", "median_sprawl", "median_diff",
            "share_below_45", "wilcoxon_p"),
          "Distribution (unclipped ratios):")

show_cols(c("slope_unclipped", "intercept_unclipped",
            "slope_clipped", "intercept_clipped"),
          "Fitted line, unclipped vs [0,1]-clipped:")

show_cols(c("clipped_x_at_0", "clipped_x_at_1", "clipped_y_at_0", "clipped_y_at_1"),
          "Points moved by the clip (x = compact, y = sprawl):")

# --- Write -------------------------------------------------------------------

out_var <- output_path("figure2_sample_variants.csv")
readr::write_csv(variants, out_var)
cat(sprintf("\n   Saved: %s\n", out_var))

# Pure plot for each variant (b). Variant (a)'s plots are the ones the existing
# code already wrote above, under their existing names, unchanged.
for (g in G_VALUES) {
  fail_c <- is.na(df_b$delta_compact_total) | df_b$delta_compact_total < g
  fail_s <- is.na(df_b$delta_sprawl_total)  | df_b$delta_sprawl_total  < g
  d_g <- df_b[!fail_c & !fail_s, , drop = FALSE] %>%
    mutate(pct_risk_sprawl_cl  = clip01(pct_risk_sprawl),
           pct_risk_compact_cl = clip01(pct_risk_compact))

  p_g <- ggplot(d_g, aes(x = pct_risk_compact_cl, y = pct_risk_sprawl_cl)) +
    geom_abline(slope = 1, intercept = 0,
                linetype = "dashed", colour = "grey50", linewidth = 0.8) +
    geom_point(aes(size = growth_total), colour = "#4878CF", alpha = 0.4) +
    geom_smooth(method = "lm", se = TRUE,
                colour = "#E63946", fill = "#E63946", linewidth = 1.0, alpha = 0.15) +
    scale_size_continuous(
      range  = c(0.5, 6),
      name   = "Total growth\n(pop, 2010-2022)",
      labels = label_number(scale_cut = cut_short_scale())
    ) +
    scale_x_continuous(labels = label_percent(accuracy = 1),
                       limits = c(0, 1), expand = expansion(mult = 0.02)) +
    scale_y_continuous(labels = label_percent(accuracy = 1),
                       limits = c(0, 1), expand = expansion(mult = 0.02)) +
    coord_equal() +
    labs(
      title    = "Share of growth going to high-susceptibility areas: sprawl vs compact",
      subtitle = sprintf(
        "VARIANT (b): no pop_2010_risk_total cut; growth >= %d in both types  |  N = %d",
        g, nrow(d_g)),
      x        = "Share of compact growth going to high-risk areas",
      y        = "Share of sprawl growth\ngoing to high-risk areas",
      caption  = "Dashed grey line: 45 degree reference (equal allocation). Red line: linear regression with 95% CI."
    ) +
    theme_minimal(base_size = 11) +
    theme(
      legend.position  = "right",
      panel.grid.minor = element_blank(),
      plot.caption     = element_text(hjust = 0, size = 8, colour = "grey40"),
      plot.subtitle    = element_text(size = 9, colour = "grey30"),
      aspect.ratio     = 1
    )

  f_pdf <- output_path(sprintf("plot_pct_risk_sprawl_vs_compact_pure_minGrowth%d.pdf", g))
  f_png <- output_path(sprintf("plot_pct_risk_sprawl_vs_compact_pure_minGrowth%d.png", g))
  ggsave(f_pdf, p_g, width = 7.5, height = 7, dpi = 300)
  ggsave(f_png, p_g, width = 7.5, height = 7, dpi = 300)
  cat(sprintf("   Saved: %s\n", f_pdf))
  cat(sprintf("   Saved: %s\n", f_png))
}

cat("\nVariants done. No rule is chosen here.\n")
