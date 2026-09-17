# =============================================================================
# table1_population_by_growth_type.R
# Table 1 — TWO tables in one (manuscript/results_used.md, "Table 1"):
#   1a. LEVELS table: total population and population at risk, 2010 and 2022,
#       by growth type, with % in risk each year and headline share stats.
#   1b. "Panel a" — stacked bar chart of the 2010-2022 CHANGE, split into
#       high-susceptibility vs. outside high-susceptibility.
#
# Design, table 1b (results_used.md):
#   - One bar per growth type: Consolidated, Compact (densification + infill),
#     Sprawl (peripheral + extension + leapfrog).
#   - Each bar stacks: change in high-susceptibility population (dark, at the
#     base, shared zero baseline) + change in population outside high
#     susceptibility (light, on top). Total bar height = total pop. change.
#   - Consolidated is negative on both segments -> bar stacks below zero.
#   - Units: millions of people, 2010-2022 absolute change.
#
# Source columns (metricas_municipio_2010_2022.csv, MIGRATION_PLAN.md 6b0
# common-grid rework):
#   pop_2010_{type} / pop_2022_{type}           total population, both years, per type
#   pop_2010_risk_{type} / pop_2022_risk_{type} population within high susceptibility,
#                                                both years, per type
# Table 1b's per-type 2010->2022 deltas are derived in this script from those
# levels (delta_{type} = pop_2022_{type} - pop_2010_{type}, likewise for
# _risk_) -- no separate delta_* columns exist under the common-grid schema.
#   change outside high susceptibility = delta_{type} - delta_risk_{type}
#
# Sample: the full regression dataset (dataset_regressao_municipio.csv,
# stage 4 script 15), NOT the pop_2010_risk_total > MIN_POP_RISCO_2010
# restriction 16_estimate_models.R applies before fitting any model
# (MIGRATION_PLAN.md 6c1). That cut is 200, revised from 1000 on 2026-09-12
# after the 6e weighting correction rescaled pop_2010_risk_total (6c1's
# revision paragraph); this comment said 1000 until 2026-09-16. The value is
# irrelevant to what this script computes -- it applies no such cut -- but it
# should not misstate the pipeline. Decided 2026-09-10
# (05_exhibits/pipeline_5.md §4.4): the published Table 1 numbers were
# produced on this same 395-municipality set -- the researcher's March 2026
# run log of 07_tabela_populacao_risco.R matches results_used.md's totals to
# the person on exactly this sample -- and every 6b0 comparison this script
# checks against below was computed on it too. The old "387" in
# results_used.md's L11 was never actually this table's sample and is not a
# pipeline output any more (8 rows that were NA pre-6b0 are now a valid
# pop_2010_risk = pop_2022_risk = 0, i.e. genuine zero exposure, not missing
# data). Cross-checked below against amostra_mun.csv, stage 4 script 01's own
# definition of this set, so any future drift between the two is caught here.
#
# VALIDATION STATUS: this table's numbers changed under the 6b0 common-grid
# rework, and the change is UNDERSTOOD, not an open bug (MIGRATION_PLAN.md
# 6b0, "Correction, 2026-09-08"): the dominant driver is stage-3 script 04's
# urbano_2010 (t1 urban extent) now using pop_2010_alocada instead of the
# pre-rework 2022-population proxy, confirmed against the manuscript's own
# Methods text ("contiguous urban patches... are identified at t1"). So the
# check against results_used.md's PRE-REWORK targets below is EXPECTED to
# show a ~5-25% deviation -- printed for the record, not a STOP condition
# (rule 2's AUDIT.md §4 exception). The check that actually matters, and
# does stop on mismatch, is against diagnostics/legacy_population_proxy_
# check.R's "baseline" variant: that script computes the identical
# aggregation on the identical sample independently, so any difference there
# means THIS script has a bug, not a legitimate methodology change.
#
# Inputs:
#   - data/processed_data/03_urban_footprint/metricas/metricas_municipio_2010_2022.csv
#   - data/processed_data/04_regression/tables/dataset_regressao_municipio.csv (sample, stage 4 script 15)
#   - data/processed_data/04_regression/amostra_mun.csv (sample cross-check, stage 4 script 01)
#   - data/processed_data/03_urban_footprint/tabelas/diagnostico_legacy_proxy_tabela1a.csv
#     (OPTIONAL baseline cross-check. The migration-era diagnostic that produced
#     this file is not part of this repository, so the check is normally skipped;
#     the table itself is unaffected -- see pipeline_5.md section 6.1)
#
# Outputs (in output/, per 05_exhibits/pipeline_5.md):
#   - tabela1a_populacao_totais_tipo.csv   (levels table, 1a)
#   - tabela1_populacao_risco_tipo.csv     (change table, 1b)
#   - tabela1_populacao_risco_tipo.pdf / .png  (stacked bar chart, 1b "panel a")
# =============================================================================

source("03_urban_footprint_and_growth_types/00_setup.R")

library(ggplot2)
library(scales)

cat("\n", strrep("=", 60), "\n")
cat("TABLE1_POPULATION_BY_GROWTH_TYPE.R\n")
cat(strrep("=", 60), "\n")

# stage 3's own tabelas/ dir -- read-only here, only for the optional baseline
# cross-check below (whose producing script is not part of this repository).
# This script's own final outputs go to output_path() instead (pipeline_5.md).
tabelas_dir <- file.path(processed_data_dir, "tabelas")

# --- 1) LOAD DATA ------------------------------------------------------------

cat("\n1) Loading metrics (script 07) and the regression dataset (stage 4 script 15)...\n")

met_path <- file.path(processed_data_dir, "metricas", "metricas_municipio_2010_2022.csv")
if (!file.exists(met_path))
  stop("metricas_municipio_2010_2022.csv not found — run 03_urban_footprint_and_growth_types/07_aggregate_municipality_metrics.R first.\n  Path: ", met_path)
met <- readr::read_csv(met_path, show_col_types = FALSE) %>%
  mutate(cod_mun = as.character(cod_mun))

reg_sample_path <- processed_data_path("04_regression", "tables", "dataset_regressao_municipio.csv")
if (!file.exists(reg_sample_path))
  stop("dataset_regressao_municipio.csv not found — run 04_regression_dataset_and_models/15_final_dataset.R first.\n  Path: ", reg_sample_path)
reg_sample <- readr::read_csv(reg_sample_path, show_col_types = FALSE) %>%
  mutate(cod_mun = as.character(cod_mun)) %>%
  select(cod_mun) %>%
  distinct()

cat(sprintf("   Metrics: %d municipalities\n", nrow(met)))
cat(sprintf("   Regression dataset: %d municipalities\n", nrow(reg_sample)))

# Cross-check against stage 4 script 01's own definition of this set
# (tem_susceptibilidade == TRUE) -- the two are expected to be identical
# (pipeline_5.md §4.1); a mismatch means the sample-composition logic has
# drifted apart, worth stopping on rather than silently using either one.
amostra_mun_path <- processed_data_path("04_regression", "amostra_mun.csv")
if (file.exists(amostra_mun_path)) {
  amostra_mun <- readr::read_csv(amostra_mun_path, show_col_types = FALSE) %>%
    mutate(cod_mun = as.character(cod_mun))
  so_reg    <- setdiff(reg_sample$cod_mun, amostra_mun$cod_mun)
  so_amostr <- setdiff(amostra_mun$cod_mun, reg_sample$cod_mun)
  if (length(so_reg) > 0 || length(so_amostr) > 0)
    stop(sprintf(
      paste("Regression dataset and amostra_mun.csv disagree on sample membership:",
            "%d cod_mun in the regression dataset only, %d in amostra_mun.csv only.",
            "Expected them identical (pipeline_5.md §4.1) -- investigate before",
            "trusting Table 1."),
      length(so_reg), length(so_amostr)))
  cat(sprintf("   Cross-check OK: matches amostra_mun.csv exactly (%d municipalities)\n",
              nrow(amostra_mun)))
} else {
  cat("   NOTE: amostra_mun.csv not found — skipping the sample cross-check.\n")
}

met_sample <- met %>% inner_join(reg_sample, by = "cod_mun")
cat(sprintf("   After restricting to the regression dataset: %d municipalities\n", nrow(met_sample)))

TIPOS_GRUPO <- list(
  Consolidated = c("consolidated"),
  Compact      = c("densification", "infill"),
  Sprawl       = c("peripheral", "extension", "leapfrog")
)

# --- 1b) TABLE 1a — LEVELS: total pop. and pop. at risk, 2010 and 2022 -------
# Common-grid level columns (not derived delta_* values used in section 2
# below):
#   pop_2010_{type} / pop_2022_{type}           total population, both years
#   pop_2010_risk_{type} / pop_2022_risk_{type} pop. at high-susceptibility risk,
#                                                both years
# Same source columns and same regression-dataset sample as table 1b below,
# for internal consistency between the two halves of Table 1.

cat("\n1b) Building Table 1a (levels: population and population-at-risk totals)...\n")

pop_col        <- function(tipo) paste0("pop_2010_", tipo)
pop22_col      <- function(tipo) paste0("pop_2022_", tipo)
risco_col      <- function(tipo) paste0("pop_2010_risk_", tipo)
risco22_col    <- function(tipo) paste0("pop_2022_risk_", tipo)

faltando_niveis <- setdiff(
  c(sapply(unlist(TIPOS_GRUPO), pop_col), sapply(unlist(TIPOS_GRUPO), pop22_col),
    sapply(unlist(TIPOS_GRUPO), risco_col), sapply(unlist(TIPOS_GRUPO), risco22_col)),
  names(met_sample)
)
if (length(faltando_niveis) > 0)
  stop("Missing level columns in metricas_municipio_2010_2022.csv: ", paste(faltando_niveis, collapse = ", "))

tabela1a <- purrr::imap_dfr(TIPOS_GRUPO, function(tipos, grupo) {
  pop_2010    <- sum(rowSums(met_sample[, sapply(tipos, pop_col),     drop = FALSE], na.rm = TRUE), na.rm = TRUE)
  pop_2022    <- sum(rowSums(met_sample[, sapply(tipos, pop22_col),   drop = FALSE], na.rm = TRUE), na.rm = TRUE)
  risco_2010  <- sum(rowSums(met_sample[, sapply(tipos, risco_col),   drop = FALSE], na.rm = TRUE), na.rm = TRUE)
  risco_2022  <- sum(rowSums(met_sample[, sapply(tipos, risco22_col), drop = FALSE], na.rm = TRUE), na.rm = TRUE)

  tibble::tibble(
    growth_type = grupo,
    pop_2010    = pop_2010,
    pop_2022    = pop_2022,
    risco_2010  = risco_2010,
    risco_2022  = risco_2022,
    pct_risco_2010 = 100 * risco_2010 / pop_2010,
    pct_risco_2022 = 100 * risco_2022 / pop_2022,
    change_risco   = risco_2022 - risco_2010
  )
})
tabela1a$growth_type <- factor(tabela1a$growth_type, levels = c("Consolidated", "Compact", "Sprawl"))

tabela1a_total <- tibble::tibble(
  growth_type    = "Total",
  pop_2010       = sum(tabela1a$pop_2010),
  pop_2022       = sum(tabela1a$pop_2022),
  risco_2010     = sum(tabela1a$risco_2010),
  risco_2022     = sum(tabela1a$risco_2022),
  pct_risco_2010 = 100 * sum(tabela1a$risco_2010) / sum(tabela1a$pop_2010),
  pct_risco_2022 = 100 * sum(tabela1a$risco_2022) / sum(tabela1a$pop_2022),
  change_risco   = sum(tabela1a$change_risco)
)

cat("\nTable 1a (levels, population counts and % at risk):\n")
print(bind_rows(tabela1a, tabela1a_total %>% mutate(growth_type = factor(growth_type, levels = c(levels(tabela1a$growth_type), "Total")))))

# Headline share stats quoted in results_used.md's Table 1 text:
#   - "% of new residents [by type] that went to risk" = change in risk /
#     change in total population, for that type (only meaningful for growing
#     types -- Consolidated is shrinking, so this ratio is a ratio of two
#     negatives and is flagged ambiguous in results_used.md itself).
#   - Compact's share of the *net national increase* in at-risk population --
#     computed over the growing types only (Compact + Sprawl), excluding
#     Consolidated's decline, matching how results_used.md's "3.1M" nets out.
#   - Aggregate growth rates: total population vs. population at risk,
#     nationally (all three groups combined).
compact_row <- tabela1a %>% filter(growth_type == "Compact")
sprawl_row  <- tabela1a %>% filter(growth_type == "Sprawl")
net_increase_risco <- compact_row$change_risco + sprawl_row$change_risco

cat("\nHeadline share stats:\n")
cat(sprintf("  Compact  -- pct of new residents going to risk: %.1f%%\n",
            100 * compact_row$change_risco / (compact_row$pop_2022 - compact_row$pop_2010)))
cat(sprintf("  Sprawl   -- pct of new residents going to risk: %.1f%%\n",
            100 * sprawl_row$change_risco  / (sprawl_row$pop_2022  - sprawl_row$pop_2010)))
cat(sprintf("  Compact's share of the net increase in at-risk pop. (Compact+Sprawl only): %.1f%%\n",
            100 * compact_row$change_risco / net_increase_risco))
cat(sprintf("  Aggregate growth -- total population: %.1f%%  |  population at risk: %.1f%%\n",
            100 * (tabela1a_total$pop_2022   - tabela1a_total$pop_2010)   / tabela1a_total$pop_2010,
            100 * (tabela1a_total$risco_2022 - tabela1a_total$risco_2010) / tabela1a_total$risco_2010))

# Check against the pre-rework manuscript targets -- EXPECTED to deviate
# under 6b0 (see VALIDATION STATUS in the header), printed for the record
# only, not a STOP condition. Tolerance is loose (50k people) precisely
# because a real, understood deviation is expected here.
alvo_niveis <- tibble::tibble(
  growth_type = factor(c("Consolidated", "Compact", "Sprawl", "Total"),
                        levels = c("Consolidated", "Compact", "Sprawl", "Total")),
  target_pop_2010   = c(59138249, 27367825, 2900879, 89406953),
  target_pop_2022   = c(55634711, 36107824, 6104483, 97847018),
  target_risco_2010 = c(15627912,  8625881,  988462, 25242255),
  target_risco_2022 = c(14632292, 10779228, 1908404, 27319924)
)
checagem_niveis <- bind_rows(tabela1a, tabela1a_total %>% mutate(growth_type = factor(growth_type, levels = levels(alvo_niveis$growth_type)))) %>%
  left_join(alvo_niveis, by = "growth_type") %>%
  mutate(
    diff_pop_2010   = pop_2010   - target_pop_2010,
    diff_pop_2022   = pop_2022   - target_pop_2022,
    diff_risco_2010 = risco_2010 - target_risco_2010,
    diff_risco_2022 = risco_2022 - target_risco_2022
  )
cat("\nCheck Table 1a against manuscript/results_used.md's PRE-REWORK target values",
    "(tolerance 50,000 people; a deviation here is expected under 6b0, see header):\n")
print(checagem_niveis %>% select(growth_type, starts_with("diff_")))
if (any(abs(unlist(checagem_niveis %>% select(starts_with("diff_")))) > 50000, na.rm = TRUE)) {
  cat("  (Deviation from the pre-rework targets, as expected under 6b0 -- not a STOP",
      "condition. See the baseline cross-check below for the check that actually matters.)\n")
}

# --- 1c) CROSS-CHECK AGAINST THE 6b0 BASELINE (the check that matters) ------
# A migration-era diagnostic computed this exact same aggregation, on this
# exact same sample, independently, and wrote its "baseline" variant to the
# file below. Any difference here (beyond rounding) would point to a real bug
# in one of the two -- unlike the pre-rework-target check above, this one is
# NOT expected to show a "known" deviation. That diagnostic is not part of
# this repository, so the file is normally absent and the check is skipped.
baseline_path <- file.path(tabelas_dir, "diagnostico_legacy_proxy_tabela1a.csv")
if (file.exists(baseline_path)) {
  baseline <- readr::read_csv(baseline_path, show_col_types = FALSE) %>%
    filter(variant == "baseline", growth_type != "Total") %>%
    mutate(growth_type = factor(growth_type, levels = levels(tabela1a$growth_type))) %>%
    select(growth_type, pop_2010, pop_2022, risco_2010, risco_2022)
  contra_baseline <- tabela1a %>%
    select(growth_type, pop_2010, pop_2022, risco_2010, risco_2022) %>%
    inner_join(baseline, by = "growth_type", suffix = c("_this", "_baseline")) %>%
    mutate(
      diff_pop_2010   = pop_2010_this   - pop_2010_baseline,
      diff_pop_2022   = pop_2022_this   - pop_2022_baseline,
      diff_risco_2010 = risco_2010_this - risco_2010_baseline,
      diff_risco_2022 = risco_2022_this - risco_2022_baseline
    )
  cat("\nCross-check against the archived baseline variant",
      "(same sample, same aggregation -- should match exactly):\n")
  print(contra_baseline %>% select(growth_type, starts_with("diff_")))
  if (any(abs(unlist(contra_baseline %>% select(starts_with("diff_")))) > 1, na.rm = TRUE))
    warning("Table 1a does NOT match the archived baseline variant, on what should be an ",
            "identical sample and aggregation. STOP and report this -- it points to a real ",
            "bug, not a known methodology difference.")
} else {
  cat("\nNOTE: diagnostico_legacy_proxy_tabela1a.csv not found — skipping the optional",
      "baseline cross-check. This is expected: the migration-era diagnostic that",
      "produced it is not part of this repository. Table 1 is unaffected.\n")
}

out_csv_1a <- output_path("tabela1a_populacao_totais_tipo.csv")
readr::write_csv(bind_rows(tabela1a, tabela1a_total %>% mutate(growth_type = factor(growth_type, levels = levels(alvo_niveis$growth_type)))), out_csv_1a)
cat(sprintf("\nSaved: %s\n", out_csv_1a))

# --- 2) TABLE 1b — CHANGE (the stacked bar chart, "panel a") -----------------
# TIPOS_GRUPO already defined above (section 1b), reused here. Deltas are
# derived from the same pop_2010_{type}/pop_2022_{type}/pop_2010_risk_{type}/
# pop_2022_risk_{type} levels used for Table 1a above (see the header note --
# no separate delta_* columns exist under the common-grid schema).

cat("\n2) Aggregating population change by growth type...\n")

tabela1 <- purrr::imap_dfr(TIPOS_GRUPO, function(tipos, grupo) {
  pop_2010_cols   <- sapply(tipos, pop_col)
  pop_2022_cols   <- sapply(tipos, pop22_col)
  risco_2010_cols <- sapply(tipos, risco_col)
  risco_2022_cols <- sapply(tipos, risco22_col)

  delta_total <- sum(rowSums(met_sample[, pop_2022_cols,   drop = FALSE], na.rm = TRUE), na.rm = TRUE) -
                 sum(rowSums(met_sample[, pop_2010_cols,   drop = FALSE], na.rm = TRUE), na.rm = TRUE)
  delta_risco <- sum(rowSums(met_sample[, risco_2022_cols, drop = FALSE], na.rm = TRUE), na.rm = TRUE) -
                 sum(rowSums(met_sample[, risco_2010_cols, drop = FALSE], na.rm = TRUE), na.rm = TRUE)
  delta_fora  <- delta_total - delta_risco

  tibble::tibble(
    growth_type                 = grupo,
    pop_change_high_susc_M      = delta_risco / 1e6,
    pop_change_outside_susc_M   = delta_fora  / 1e6,
    pop_change_total_M          = delta_total / 1e6
  )
})

tabela1$growth_type <- factor(tabela1$growth_type, levels = c("Consolidated", "Compact", "Sprawl"))

cat("\nTable 1 (millions of people, 2010-2022 change):\n")
print(tabela1)

# --- 2a) [removed] high+medium susceptibility diagnostic ---------------------
# The pre-rework version of this script carried a diagnostic recomputing
# Table 1's change values with high+medium susceptibility combined, to test
# one of two open hypotheses on the (now-resolved) AUDIT.md discrepancy.
# Dropped here: (1) that hypothesis is already closed ("high-only confirmed
# correct, ruling out high+medium", reconfirmed independently per
# MIGRATION_PLAN.md's Validate runbook entries), and (2) medium susceptibility
# has no equivalent under the common-grid schema at all -- 07_aggregate_
# municipality_metrics.R never produces a medium-susceptibility column,
# consistent with CLAUDE.md rule 9 (high-only).

# --- 2b) CHECK AGAINST results_used.md's PRE-REWORK TARGET VALUES -----------
# Same status as Table 1a's check above: this is arithmetically implied by
# Table 1a's own diffs (change_risco = risco_2022 - risco_2010), so a real
# bug would already have shown up in the baseline cross-check (1c) -- this is
# the pre-rework-target view of the same numbers, for the record.

alvo <- tibble::tibble(
  growth_type            = c("Consolidated", "Compact", "Sprawl"),
  target_high_susc_M     = c(-1.00, 2.15, 0.92),
  target_outside_susc_M  = c(-2.51, 6.59, 2.28)
)

checagem <- tabela1 %>%
  left_join(alvo, by = "growth_type") %>%
  mutate(
    diff_high_susc    = pop_change_high_susc_M    - target_high_susc_M,
    diff_outside_susc = pop_change_outside_susc_M - target_outside_susc_M
  )

cat("\nCheck against results_used.md's PRE-REWORK target values (tolerance 0.02M;",
    "a deviation here is expected under 6b0, see header):\n")
print(checagem %>% select(growth_type, pop_change_high_susc_M, target_high_susc_M, diff_high_susc,
                           pop_change_outside_susc_M, target_outside_susc_M, diff_outside_susc))

if (any(abs(checagem$diff_high_susc) > 0.02) || any(abs(checagem$diff_outside_susc) > 0.02)) {
  cat("  (Deviation from the pre-rework targets, as expected under 6b0 -- not a STOP",
      "condition; see Table 1a's baseline cross-check above.)\n")
}

# --- 3) SAVE TABLE -------------------------------------------------------------

out_csv <- output_path("tabela1_populacao_risco_tipo.csv")
readr::write_csv(tabela1, out_csv)
cat(sprintf("\nSaved: %s\n", out_csv))

# --- 4) PLOT: STACKED BAR CHART -------------------------------------------------

cat("\n3) Building stacked bar chart...\n")

# Explicit ymin/ymax per segment (rather than relying on ggplot's automatic
# stacking) so the dark (risk) segment always sits at the shared zero
# baseline and the light (outside-risk) segment stacks beyond it, whichever
# direction the bar goes — this is what correctly renders Consolidated with
# BOTH segments stacked below zero, per the design requirement.
plot_df <- tabela1 %>%
  mutate(
    dark_ymin  = pmin(0, pop_change_high_susc_M),
    dark_ymax  = pmax(0, pop_change_high_susc_M),
    light_ymin = pmin(pop_change_high_susc_M, pop_change_total_M),
    light_ymax = pmax(pop_change_high_susc_M, pop_change_total_M)
  )

plot_long <- bind_rows(
  plot_df %>% transmute(growth_type, segment = "Change in population in high-susceptibility areas",
                         ymin = dark_ymin, ymax = dark_ymax),
  plot_df %>% transmute(growth_type, segment = "Change in population outside high-susceptibility areas",
                         ymin = light_ymin, ymax = light_ymax)
)
plot_long$segment <- factor(
  plot_long$segment,
  levels = c("Change in population in high-susceptibility areas",
             "Change in population outside high-susceptibility areas")
)

p <- ggplot(plot_long, aes(ymin = ymin, ymax = ymax, fill = segment)) +
  geom_rect(aes(xmin = as.numeric(growth_type) - 0.35, xmax = as.numeric(growth_type) + 0.35),
            colour = "white", linewidth = 0.3) +
  geom_hline(yintercept = 0, colour = "grey30", linewidth = 0.4) +
  scale_x_continuous(breaks = seq_along(levels(plot_long$growth_type)),
                      labels = levels(plot_long$growth_type)) +
  scale_y_continuous(labels = label_number(suffix = " M")) +
  scale_fill_manual(values = c(
    "Change in population in high-susceptibility areas"        = "#B2182B",
    "Change in population outside high-susceptibility areas"   = "#F4A582"
  )) +
  labs(
    title    = "Population change by growth type, 2010-2022",
    subtitle = sprintf("Full regression dataset, N = %d municipalities (no pop_2010_risk_total restriction)",
                        nrow(met_sample)),
    x        = NULL,
    y        = "Population change, 2010-2022 (millions of people)",
    fill     = NULL,
    caption  = "Total population change per growth type is given by the full bar height\n(sum of both stacked segments)."
  ) +
  theme_minimal(base_size = 12) +
  theme(
    legend.position  = "bottom",
    panel.grid.minor = element_blank(),
    plot.caption     = element_text(hjust = 0, size = 8, colour = "grey40")
  )

out_pdf <- output_path("tabela1_populacao_risco_tipo.pdf")
out_png <- output_path("tabela1_populacao_risco_tipo.png")
ggsave(out_pdf, p, width = 7, height = 6, dpi = 300)
ggsave(out_png, p, width = 7, height = 6, dpi = 300)

cat(sprintf("Saved: %s\n", out_pdf))
cat(sprintf("Saved: %s\n", out_png))

cat("\nDone.\n")
