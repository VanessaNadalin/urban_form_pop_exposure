# =============================================================================
# figure2_exposure_scatter.R  (Figure 2; formerly
# regression2/plot_pct_risk_sprawl_vs_compact_population.R)
# Scatterplot: share of growth going to high-risk areas — sprawl vs compact
#
# Creates TWO versions:
# 1) Pure plot (no facets) - tests overall similarity
# 2) Faceted by population size quartiles (pop_mun_2022 from regression dataset)
#
# Sample: the regression sample of 16_estimate_models.R, including its
# pop_2010_risk_total > 200 restriction (MIN_POP_RISCO_2010 below; revised
#         2026-09-12 from 1000, MIGRATION_PLAN.md 6e/6c1 -- originally decided
# 2026-09-10 to keep Figure 2 on the same municipalities as Tables 1/2 --
# MIGRATION_PLAN.md 6c2), then municipalities with positive 2010-2022 growth
# in both sprawl and compact cells.
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

MIN_POP_RISCO_2010 <- 200  # must match 16_estimate_models.R (revised 2026-09-12, was 1000)

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
df_reg_small <- df_reg %>%
  filter(pop_2010_risk_total > MIN_POP_RISCO_2010) %>%
  select(cod_mun) %>%
  distinct()

cat(sprintf("   Regression dataset: %d municipalities; after pop_2010_risk_total > %d: %d\n",
            n_reg_all, MIN_POP_RISCO_2010, nrow(df_reg_small)))

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
# 5) FILTER  (keep rows with BOTH denominators > 0)
# =============================================================================

cat("\n4) Filtering for positive growth in both sprawl and compact...\n")

N_before <- nrow(df)

df_plot <- df %>%
  filter(!is.na(delta_sprawl_total),  delta_sprawl_total  > 0,
         !is.na(delta_compact_total), delta_compact_total > 0)

N_after   <- nrow(df_plot)
N_dropped <- N_before - N_after

cat(sprintf("   N before growth filter: %d\n", N_before))
cat(sprintf("   N after growth filter : %d (final sample)\n", N_after))
cat(sprintf("   N dropped             : %d\n", N_dropped))

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
      "Regression sample (pop_2010_risk_total > %d) with positive growth in both types  |  N = %d",
      MIN_POP_RISCO_2010, N_after),
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
      "Faceted by population quartiles (pop_mun_2022)  |  regression sample, pop_2010_risk_total > %d  |  N = %d",
      MIN_POP_RISCO_2010, N_after),
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
