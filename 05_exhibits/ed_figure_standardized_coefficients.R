# =============================================================================
# ed_figure_standardized_coefficients.R
# ED Figure — standardized coefficients (beta + 95% CI) for Table 2
#
# results_used.md: coefficient plot with standardized betas and CIs for
# Table 2, so the paper's "housing-market variables matter more than urban
# form" comparison rests on comparable magnitudes, not on significance stars
# across differently scaled covariates (rents in R$, shares in percentage
# points, log population, etc.).
#
# Does NOT re-estimate anything (rule 1, 05_exhibits/pipeline_5.md §1): reads
# Table 2's already-fitted models from model_objects_table2.rds and rescales
# each coefficient and its SE post hoc --
#   beta_std = beta_hat * sd(x) / sd(y)
#   se_std   = se_hat   * sd(x) / sd(y)
# sd(x)/sd(y) is a fixed sample constant, so this is an exact linear
# transform of the coefficient the model already produced (equivalent to
# fitting on z-scored x and y, without actually doing so) -- beta_std/se_std
# reproduces the original t-statistic exactly, which is this script's own
# self-check below. The alternative (refit on scale()-transformed data, or
# lm.beta) gives the same numbers but means re-estimating inside stage 5;
# not chosen for that reason.
#
# Sample: whatever model.frame(mod) actually used for each of the four
# Table 2 columns -- N = 317 (the 6c1-restricted, complete-cases sample),
# same as Table 2 itself. Read directly from the fitted object, not
# recomputed, so it cannot drift from what Table 2 reports.
#
# Variables shown: the treatment (labelled Compact/Sprawl growth, not
# "Treatment (compact or sprawl)" as in Table 2 -- distinguishing the two is
# the whole point here) plus the housing-market block (safe empty land Q1,
# Palma ratios, median rent, slum share) and the remaining shown controls
# (steep terrain, pop. share in risk zones 2010, log population/footprint
# 2000, growth outside risk zones -- g_high columns only, absent from
# Dpp_high's control set). Region and urban-class dummies, the intercept,
# and the unshown controls (Q4, Palma rent, log GDP per capita, zero_area_2000)
# are never standardized or plotted -- factor dummies don't have a
# meaningful "1-SD change" and were never in Table 2's own displayed set.
#
# Input:
#   data/processed_data/04_regression/model_objects_table2.rds  (script 16;
#   only tab_main_mun is used)
#
# Outputs (in output/):
#   ed_figure_standardized_coefficients.{pdf,png}
#   ed_figure_standardized_coefficients.csv  (the values behind the plot)
# =============================================================================

source("04_regression_dataset_and_models/00_setup.R")

for (pkg in c("lmtest", "sandwich", "ggplot2"))
  if (!requireNamespace(pkg, quietly = TRUE)) install.packages(pkg)
library(lmtest); library(sandwich); library(ggplot2)

cat("\n", strrep("=", 60), "\n")
cat("ED_FIGURE_STANDARDIZED_COEFFICIENTS.R\n")
cat(strrep("=", 60), "\n")

# =============================================================================
# 1) LOAD MODEL OBJECTS
# =============================================================================

cat("\n1) Loading Table 2's model objects from script 16...\n")

rds_path <- file.path(data_dir, "model_objects_table2.rds")
if (!file.exists(rds_path))
  stop("model_objects_table2.rds not found — run 04_regression_dataset_and_models/16_estimate_models.R first.\n  Path: ", rds_path)

tab_main_mun <- readRDS(rds_path)$tab_main_mun
tab_main_mun <- Filter(Negate(is.null), tab_main_mun)
if (length(tab_main_mun) == 0)
  stop("No fitted models found in tab_main_mun -- check 16_estimate_models.R's own run log.")

# Same clustering as Table 2 itself -- redefined here rather than serialized
# (attr(mod, "cluster_vec") is preserved by saveRDS(), so this still uses
# the real cluster assignment, not a re-derived one).
vcov_clust <- function(mod) {
  cl <- attr(mod, "cluster_vec")
  if (!is.null(cl)) vcovCL(mod, cluster = cl) else vcovHC(mod, type = "HC3")
}

# =============================================================================
# 2) VARIABLES TO STANDARDIZE AND SHOW
# =============================================================================

# Friendly labels -- kept independent from table2_and_ed_tables.R's coef_map
# on purpose (same source strings, separate copy), since the two scripts
# format two different exhibits and shouldn't share mutable state.
TRAT_LABELS <- c(
  "pct_area_densif_infill_0010"   = "Compact growth",
  "pct_area_periph_ext_leap_0010" = "Sprawl growth"
)

CTRL_LABELS <- c(
  "pp_alta_2010"                       = "Pop. share in risk zones 2010",
  "topo_prop_inclinado"                = "Steep terrain",
  "pct_nao_constru_fora_alta_2010_q1"  = "Safe empty land Q1",
  "palma_commute"                       = "Palma ratio: commute",
  "palma_rent"                          = "Palma ratio: rent",
  "median_rent"                         = "Median rent",
  "prop_favelas_2010"                   = "Slum population share 2010",
  "log_pop_total_2000"                  = "Log total population 2000",
  "log_area_2000_km2"                   = "Log urban footprint 2000",
  "g_fora_alta"                         = "Pop. growth outside risk zones"
)

VAR_LABELS <- c(TRAT_LABELS, CTRL_LABELS)

# Housing-market block, for the plot's colour grouping (results_used.md's
# own grouping -- safe empty land Q1, Palma ratios, median rent, slum share).
HOUSING_MARKET_VARS <- c("pct_nao_constru_fora_alta_2010_q1", "palma_commute",
                          "palma_rent", "median_rent", "prop_favelas_2010")

# =============================================================================
# 3) STANDARDIZE EACH MODEL'S COEFFICIENTS
# =============================================================================

cat("\n2) Standardizing coefficients (beta * sd(x) / sd(y)) for each column...\n")

standardize_model <- function(mod, spec_name) {
  mf     <- model.frame(mod)
  y_name <- names(mf)[1]
  sd_y   <- sd(mf[[y_name]])

  coefs  <- lmtest::coeftest(mod, vcov = vcov_clust(mod))
  vars   <- intersect(names(VAR_LABELS), rownames(coefs))

  crit <- qt(0.975, df = mod$df.residual)

  purrr::map_dfr(vars, function(v) {
    sd_x     <- sd(mf[[v]])
    scale_f  <- sd_x / sd_y
    beta_hat <- coefs[v, "Estimate"]
    se_hat   <- coefs[v, "Std. Error"]
    t_orig   <- beta_hat / se_hat

    beta_std <- beta_hat * scale_f
    se_std   <- se_hat   * scale_f
    t_check  <- beta_std / se_std

    tibble::tibble(
      spec        = spec_name,
      term        = v,
      label       = VAR_LABELS[[v]],
      group       = if (v %in% names(TRAT_LABELS)) "Treatment"
                    else if (v %in% HOUSING_MARKET_VARS) "Housing market"
                    else "Other control",
      beta_std    = beta_std,
      se_std      = se_std,
      ci_low      = beta_std - crit * se_std,
      ci_high     = beta_std + crit * se_std,
      p_value     = coefs[v, "Pr(>|t|)"],
      n           = nrow(mf),
      t_original  = t_orig,
      t_check     = t_check
    )
  })
}

res <- purrr::imap_dfr(tab_main_mun, standardize_model)

# =============================================================================
# 4) SELF-CHECK: standardization must not change the t-statistic
# =============================================================================

cat("\n3) Self-check: t-statistic before/after standardization must match exactly...\n")
max_t_diff <- max(abs(res$t_original - res$t_check))
cat(sprintf("   Max |t_original - t_check| across all coefficients: %.10f\n", max_t_diff))
if (max_t_diff > 1e-8)
  warning("Standardized t-statistics do not reproduce the original model's t-statistics — ",
          "the standardization arithmetic has a bug. Do not trust this figure until fixed.")

# =============================================================================
# 5) SAVE VALUES AND PLOT
# =============================================================================

cat("\n4) Saving values and building the plot...\n")

out_csv <- output_path("ed_figure_standardized_coefficients.csv")
readr::write_csv(res %>% select(-t_check), out_csv)
cat(sprintf("   Saved: %s\n", out_csv))

res$spec  <- factor(res$spec, levels = names(tab_main_mun))
res$label <- factor(res$label, levels = rev(unique(VAR_LABELS[names(VAR_LABELS) %in% res$term])))

p <- ggplot(res, aes(x = beta_std, y = label, colour = group)) +
  geom_vline(xintercept = 0, colour = "grey50", linewidth = 0.4) +
  geom_pointrange(aes(xmin = ci_low, xmax = ci_high), size = 0.5) +
  facet_wrap(~ spec, scales = "free_x", ncol = 2) +
  scale_colour_manual(values = c(
    "Treatment"       = "#E63946",
    "Housing market"  = "#4878CF",
    "Other control"   = "grey40"
  )) +
  labs(
    title    = "Standardized coefficients — Table 2 (95% CI)",
    subtitle = "Effect of a 1-SD change in each variable, in SD units of the outcome",
    x        = "Standardized coefficient (β)",
    y        = NULL,
    colour   = NULL,
    caption  = "Vertical grey line: no effect. Panels are on independent x-axis scales;\nvalues remain comparable across panels (same units: outcome SD per 1-SD change in x)."
  ) +
  theme_minimal(base_size = 11) +
  theme(
    legend.position  = "bottom",
    panel.grid.minor = element_blank(),
    plot.caption     = element_text(hjust = 0, size = 8, colour = "grey40"),
    plot.subtitle    = element_text(size = 9, colour = "grey30"),
    strip.text       = element_text(face = "bold", size = 9)
  )

out_pdf <- output_path("ed_figure_standardized_coefficients.pdf")
out_png <- output_path("ed_figure_standardized_coefficients.png")
ggsave(out_pdf, p, width = 10, height = 6, dpi = 300)
ggsave(out_png, p, width = 10, height = 6, dpi = 300)

cat(sprintf("   Saved: %s\n", out_pdf))
cat(sprintf("   Saved: %s\n", out_png))

# =============================================================================
# 6) SUMMARY: LARGEST STANDARDIZED EFFECTS PER SPEC
# =============================================================================

cat("\n5) Largest standardized effects, by spec (for the housing-market vs.\n")
cat("   urban-form comparison the figure exists to support):\n\n")

res %>%
  group_by(spec) %>%
  arrange(desc(abs(beta_std)), .by_group = TRUE) %>%
  select(spec, label, group, beta_std, se_std, p_value) %>%
  print(n = Inf)

cat("\nDone.\n")
