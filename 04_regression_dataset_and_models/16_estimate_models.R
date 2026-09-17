# =============================================================================
# 16_estimate_models.R
# Pre-period regressions: urban form 2000-2010 and growth of the population
# in risk zones 2010-2022.
#
# Hypothesis: cities that densified near the center in 2000-2010 show higher
# growth of the population in risk zones in the following period (2010-2022),
# because the affordable housing stock concentrated in susceptible areas.
#
# Sample restriction: pop_2010_risk_total > 200 (revised 2026-09-12; was 1000,
# decided 2026-09-08) --
# see MIN_POP_RISCO_2010 below for the full rationale. In short, g_alta's
# growth-rate formula turns a small 2010 baseline into an implausible
# percentage (up to 6,300% observed pre-restriction), which dominates the
# unweighted OLS fit for the g_alta columns; diagnosed and tested at several
# thresholds in diagnostics/g_alta_outlier_check.R (and, in the project's
# working repository, in a companion diagnostic not deposited here).
#
# Treatment variable (compact growth 2000-2010):
#   pct_area_densif_infill_0010     -- densification + infill share
# Comparison variable (sprawl growth 2000-2010):
#   pct_area_periph_ext_leap_0010   -- peripheral + extension + leapfrog share
#
# This script ESTIMATES the models and SAVES the fitted objects; it does
# NOT format or export any table (decided in CLAUDE.md's target structure;
# applied here 2026-09-11, see MIGRATION_PLAN.md 6d). The five model lists
# below are saved to model_objects_table2.rds; 05_exhibits/table2_and_ed_
# tables.R reads that file and produces the actual formatted HTML/TeX/DOCX
# tables in output/ -- coefficient labels, hidden-control notes, and every
# other display choice now live there, not here.
#
# Model lists saved (-> paper exhibit, in table2_and_ed_tables.R):
#   tab_main_mun      -> Table 2   (municipalities, high susceptibility, 4 cols:
#                        (1) g_high Compact (2) g_high Sprawl
#                        (3) Dpp_high Compact (4) Dpp_high Sprawl)
#   tab_appA_arr      -> ED Table 3 (functional urban areas, same 4 specs, HC3)
#   tab_interact_mun  -> ED Table 5 (treatment x urban_class / x regiao, 8 cols;
#                        the 4 regiao columns exclude Centro-Oeste -- decided
#                        2026-09-10, MIGRATION_PLAN.md 6c2, see the fit call below)
#   tab_mediators_mun -> ED Table 2 (with vs. without housing-market mediators,
#                        10 cols)
#   tab_horserace_mun -> ED Table 4 (compact and sprawl entered jointly, 2 cols)
#
#   High susceptibility only (rule 9): the pre-existing medium-susceptibility
#   and high+medium specs (formerly Tables A2/A3) were removed 2026-09 --
#   they referenced columns (g_medio, pp_medio_2010, g_alta_medio, etc.) that
#   no producing script generates anymore, since the medium-susceptibility
#   branch was retired at 07_aggregate_municipality_metrics.R (Task 1c) and
#   the retirement has cascaded through every stage-04 script. Neither table
#   is referenced in results_used.md, so there is no published result lost
#   here. See MIGRATION_PLAN.md 6c0.
#
# SEs: municipalities -> clustered by NM_CIDADE (arrangement); arrangements -> HC3
# (vcov functions are redefined in table2_and_ed_tables.R rather than saved
# here -- cheap to duplicate, and avoids relying on serialized closures).
#
# Inputs:
#   data/processed_data/04_regression/tables/dataset_regressao_municipio.csv  (script 15)
#   data/processed_data/04_regression/tables/dataset_regressao_arranjo.csv    (script 15)
#
# Output:
#   data/processed_data/04_regression/model_objects_table2.rds
# =============================================================================

source("04_regression_dataset_and_models/00_setup.R")

for (pkg in c("lmtest", "sandwich", "car")) {
  if (!requireNamespace(pkg, quietly = TRUE)) install.packages(pkg)
  library(pkg, character.only = TRUE)
}

cat("\n", strrep("=", 60), "\n")
cat("16_ESTIMATE_MODELS.R\n")
cat(strrep("=", 60), "\n")

# =============================================================================
# 1) LOAD AND PREPARE DATASETS
# =============================================================================

cat("\n1) Loading datasets...\n")

path_mun <- file.path(tables_dir, "dataset_regressao_municipio.csv")
path_arr <- file.path(tables_dir, "dataset_regressao_arranjo.csv")

if (!file.exists(path_mun)) stop("dataset_regressao_municipio.csv not found -- run script 15")
if (!file.exists(path_arr)) stop("dataset_regressao_arranjo.csv not found -- run script 15")

# Common derived variables
prep <- function(df) {
  df %>% mutate(
    pop_growth           = (pop_urbana_2022 - pop_urbana_2010_cg) /
                             pop_urbana_2010_cg,
    log_pop_2010         = log(pop_urbana_2010_cg + 1),
    log_pib_pc           = log(pib_pc_2010        + 1),
    log_area_2010_km2    = log(area_urbana_2010_m2 / 1e6 + 0.001),
    # Denominator on the MAPPED units (6f.2): pop_urbana_2010_cg is
    # mapped-members-only at arrangement level, so its area must be too,
    # or the ratio spans the two aggregation groups. Identical to
    # area_urbana_2010_m2 at municipality level.
    log_density_2010     = log(pop_urbana_2010_cg /
                                 (area_urbana_2010_m2_mapped / 1e6 + 0.001) + 1),
    log_pop_total_2010   = log(pop_total_2010 + 1),
    log_pop_total_2000   = log(pop_2000       + 1),
    log_area_2000_km2    = log(area_2000_m2 / 1e6 + 0.001),
    g_fora_suscept_slums = coalesce(g_slums_1022 - g_alta_slums_1022, 0),
    pct_area_periph_ext_leap = pct_area_peripheral + pct_area_extension + pct_area_leapfrog,
    regiao      = factor(regiao,
                         levels = c("Sudeste", "Sul", "Nordeste",
                                    "Norte", "Centro-Oeste")),
    urban_class = factor(urban_class,
                         levels = c("Urban Centers", "Metropolises",
                                    "Metropolis Suburbs", "Regional Centers",
                                    "Regional Centers Suburbs"))
  )
}

# Derived variables for 2000-2010 growth
prep_0010 <- function(df) {
  df %>% mutate(
    pct_area_densif_infill_0010   = pct_area_densif_0010 + pct_area_infill_0010,
    log_dist_densif_0010          = log(pmax(dist_media_m_densif_0010,        1)),
    log_dist_densif_infill_0010   = log(pmax(dist_media_m_densif_infill_0010, 1)),
    pct_area_periph_ext_leap_0010 = pct_area_peripheral_0010 +
                                    pct_area_extension_0010  +
                                    pct_area_leapfrog_0010
  )
}

ds_mun <- read_csv(path_mun, show_col_types = FALSE) %>% prep() %>% prep_0010()
ds_arr <- read_csv(path_arr, show_col_types = FALSE) %>% prep() %>% prep_0010()

# Minimum baseline population in high-susceptibility zones (2010), decided
# 2026-09-08 after diagnosing g_alta's blow-up for municipalities with a
# small/near-zero pop_2010_risk_total: g_alta = 100 * (pop22-pop10) /
# pmax(pop10, 1), so a baseline of a few dozen/hundred people turns any
# absolute change into an implausible growth rate (up to 6,300% observed),
# which dominates the unweighted OLS fit -- see
# diagnostics/g_alta_outlier_check.R. A companion diagnostic, kept in the
# project's working repository and not deposited here, ruled out sample
# composition as the cause: restricting to the exact old N=341 did not fix
# it, since stage 03's common-grid rework changed pop_2010_risk_total for
# municipalities that were always in the sample, not just new ones.
# 1000 was chosen over lower cuts (100, 250, 500 all tested) on principled
# grounds -- large enough that a percentage change is no longer dominated by
# small-number noise -- not to match the pre-rework Table 2 numbers, which
# per rule 2 / AUDIT.md's governing decision are no longer the target to
# reproduce once the common-grid rework's own population values are the
# correct ones.
#
# REVISED 2026-09-12 (researcher) to 200, following the exposure-weighting
# correction (MIGRATION_PLAN.md 6e). The 1000 above was calibrated against the
# any-overlap distribution of pop_2010_risk_total. Area weighting cut that
# column roughly 2.3x nationally (25.3M -> 10.9M in 2010), so the same nominal
# 1000 became a far more aggressive cut than the one tested in 2026-09-08:
# it dropped 107 of 395 municipalities (27%) where it had dropped 41 (10%),
# taking the regression N from 317 to 265. In any-overlap units the weighted
# 1000 is roughly 2300 -- above every threshold that round tested. 200 on the
# weighted series is roughly 460 in those units, inside the tested range.
#
# NOTE for whoever reads the 2026-09-08 rationale above: it recorded evidence
# AGAINST 200 -- at that cut "Log total population 2000" and "Log urban
# footprint 2000" came out inflated and spuriously significant
# (-11.0*/-11.4**, 9.5*), which was read as residual small-baseline leverage.
# That evidence was produced on the any-overlap distribution and does not
# transfer unchanged. Whether it recurs on the weighted series is an empirical
# question the run answers: check those two coefficients in Table 2's output.
# If they are inflated again, the leverage is real at this cut and the choice
# needs revisiting.
#
# ANSWERED 2026-09-17 -- they are NOT inflated; the cut of 200 stands.
# Evidence, from the run of 2026-09-17 on the weighted series, read off
# output/ed_figure_standardized_coefficients.csv (whose p-values come from
# lmtest::coeftest(mod, vcov = vcov_clust(mod)) -- the same clustered path
# this script uses, on these same fitted models):
#
#   spec                      log_pop_total_2000   log_area_2000_km2
#   (1) g_high   Compact      b*=  0.121 p=0.43    b*= -0.318 p=0.13
#   (2) g_high   Sprawl       b*=  0.012 p=0.93    b*= -0.059 p=0.76
#   (3) Dpp_high Compact      b*= -0.099 p=0.48    b*= -0.050 p=0.80
#   (4) Dpp_high Sprawl       b*= -0.259 p=0.13    b*=  0.361 p=0.19
#
# Neither reaches significance in any specification, and the standardized
# magnitudes are ordinary. The 2026-09-08 pattern (-11.0*/-11.4**, 9.5*) was
# an artefact of the any-overlap distribution and does not reappear once
# exposure is area-weighted (6e). So the cut rests on its own evidence here,
# not only on the rescaling argument in 6c1's revision.
#
# Corroborating, from the same day's run of
# 05_exhibits/robustness/minimum_population_filter.R, which sweeps the cut
# over {100, 200, 500, 1000}: the treatment coefficients do not behave like
# small-baseline artefacts. g_high Sprawl STRENGTHENS as the cut rises
# (0.247* / 0.240* / 0.306*** / 0.318***) -- the opposite of what leverage
# from near-zero denominators would produce -- and Dpp_high Compact's point
# estimate is invariant across all four cuts (0.0132 / 0.0135 / 0.0136 /
# 0.0136), losing its star only through the SE widening as N falls. The full
# table is in data/processed_data/04_regression/figures/
# sensitivity_min_pop_risco.csv; the values above are recorded in
# manuscript/results_targets_v2.md with their provenance.
#
# These are run records, not new decisions: MIN_POP_RISCO_2010 is unchanged.
MIN_POP_RISCO_2010 <- 200

n_mun_antes <- nrow(ds_mun)
n_arr_antes <- nrow(ds_arr)
ds_mun <- ds_mun %>% filter(pop_2010_risk_total > MIN_POP_RISCO_2010)
if ("pop_2010_risk_total" %in% names(ds_arr))
  ds_arr <- ds_arr %>% filter(pop_2010_risk_total > MIN_POP_RISCO_2010)
cat(sprintf("\nMinimum baseline population filter (pop_2010_risk_total > %d):\n",
            MIN_POP_RISCO_2010))
cat(sprintf("  Municipalities: %d -> %d (dropped %d)\n",
            n_mun_antes, nrow(ds_mun), n_mun_antes - nrow(ds_mun)))
cat(sprintf("  Arrangements  : %d -> %d (dropped %d)\n",
            n_arr_antes, nrow(ds_arr), n_arr_antes - nrow(ds_arr)))

cat(sprintf("  Municipalities: %d  |  Arrangements: %d\n", nrow(ds_mun), nrow(ds_arr)))

# Diagnostics: NAs per variable, municipalities
# Added to resolve AUDIT.md (Table 2's N=341): results_used.md attributes
# the 387->341 cut specifically to "safe available land and steep terrain",
# but fit_safe() (below) applies complete.cases() over ALL variables in the
# formula -- Y, treatment, and the ~14 CTRL_ALTA variables (including
# regiao, urban_class, housing mediators). This diagnostic shows, variable
# by variable, which columns actually carry NAs in ds_mun -- run this
# script with the real data and check whether only
# pct_nao_constru_fora_alta_2010_q1/q4 and topo_prop_inclinado appear
# (which would reconcile the draft text with the code's mechanism) or
# whether other CTRL_ALTA variables also contribute to the 46-row cut
# (which would require correcting the draft text).
cat("\n  NAs per variable -- municipalities (top 20):\n")
na_mun <- sort(colSums(is.na(ds_mun)), decreasing = TRUE)
print(head(na_mun[na_mun > 0], 20))

# Diagnostics: NAs per variable, arrangements
cat("\n  NAs per variable -- arrangements (top 20):\n")
na_arr <- sort(colSums(is.na(ds_arr)), decreasing = TRUE)
print(head(na_arr[na_arr > 0], 20))

# Verify key variables are present
vars_0010 <- c("pct_area_densif_0010", "pct_area_infill_0010",
               "log_dist_densif_0010", "log_dist_densif_infill_0010")
missing_vars <- setdiff(vars_0010, names(ds_mun))
if (length(missing_vars) > 0)
  cat(sprintf("  Warning: variables missing from ds_mun: %s\n",
              paste(missing_vars, collapse = ", ")))

# =============================================================================
# 2) CONTROLS BY Y VARIABLE
# =============================================================================

CTRL_ALTA <- c(
  "topo_prop_inclinado",
  "pp_alta_2010",
  "pct_nao_constru_fora_alta_2010_q1",
  "pct_nao_constru_fora_alta_2010_q4",
  "palma_rent", "palma_commute", "median_rent",
  "log_pib_pc", "log_pop_total_2000", "log_area_2000_km2", "zero_area_2000",
  "prop_favelas_2010",
  "regiao", "urban_class"
)

CTRL_DELTA <- CTRL_ALTA

# Targeted diagnostic: results_used.md (Table 2, N=341) attributes the
# 387->341 cut specifically to "safe available land and steep terrain".
# Compares the N under that narrow subset of variables directly against the
# N under the FULL CTRL_ALTA (what fit_safe() actually uses) for columns
# (1)/(3) of the main table (g_alta / delta_pp_alta with compact
# treatment). If the two Ns match at 341, the draft text is correct in
# practice (only those variables carry NAs); if not, the text needs
# correcting to describe the full mechanism (complete.cases over all of
# CTRL_ALTA).
VARS_ESTREITAS_DRAFT <- c("pct_area_densif_infill_0010", "g_alta", "delta_pp_alta",
                          "g_fora_alta",
                          "pct_nao_constru_fora_alta_2010_q1",
                          "pct_nao_constru_fora_alta_2010_q4",
                          "topo_prop_inclinado")
n_narrow <- sum(complete.cases(ds_mun[, intersect(VARS_ESTREITAS_DRAFT, names(ds_mun))]))
n_ctrl_alta <- sum(complete.cases(ds_mun[, intersect(c("pct_area_densif_infill_0010", "g_alta", "g_fora_alta", CTRL_ALTA), names(ds_mun))]))
cat(sprintf(
  "\n  N=341 check (results_used.md): N under 'safe land + steep terrain' only = %d | N under full CTRL_ALTA (what the code uses) = %d\n",
  n_narrow, n_ctrl_alta))
if (n_narrow != n_ctrl_alta) {
  message("  Warning: the two Ns do NOT match -- the draft text ('safe available land and ",
          "steep terrain') describes the cut incompletely. See AUDIT.md, ",
          "'Table 2's reported N = 341'. Report the discrepancy, do not silently adjust.")
}

# =============================================================================
# 3) ESTIMATION HELPERS
# =============================================================================

make_f <- function(y, trat, ctrl) {
  as.formula(paste(y, "~", paste(c(trat, ctrl), collapse = " + ")))
}

fit_safe <- function(f, data, label, cluster_col = NULL) {
  vars <- all.vars(f)
  dat  <- data[complete.cases(data[, intersect(vars, names(data))]), ]
  cat(sprintf("    %-40s  N = %d\n", label, nrow(dat)))
  tryCatch({
    mod <- lm(f, data = dat)
    if (!is.null(cluster_col) && cluster_col %in% names(dat))
      attr(mod, "cluster_vec") <- dat[[cluster_col]]
    mod
  }, error = function(e) {
    message("    ERROR in ", label, ": ", e$message); NULL
  })
}

# vcov by dataset type:
#   municipalities -> clustered by arrangement (CD_CIDADE)
#   arrangements   -> HC3 (each row is already a unique cluster)
vcov_clust <- function(mod) {
  cl <- attr(mod, "cluster_vec")
  if (!is.null(cl)) vcovCL(mod, cluster = cl) else vcovHC(mod, type = "HC3")
}
vcov_hc3 <- function(mod) vcovHC(mod, type = "HC3")

# =============================================================================
# 4) Y SPECIFICATIONS BY TABLE
# =============================================================================

trat_compact <- "pct_area_densif_infill_0010"
trat_periph  <- "pct_area_periph_ext_leap_0010"

# Main table + appendix A -- HIGH susceptibility
y_high <- list(
  "(1) g_high — Compact"    = list(y = "g_alta",        trat = trat_compact,
                                    ctrl = c(CTRL_ALTA,  "g_fora_alta")),
  "(2) g_high — Sprawl"     = list(y = "g_alta",        trat = trat_periph,
                                    ctrl = c(CTRL_ALTA,  "g_fora_alta")),
  "(3) Dpp_high — Compact"  = list(y = "delta_pp_alta", trat = trat_compact,
                                    ctrl = CTRL_DELTA),
  "(4) Dpp_high — Sprawl"   = list(y = "delta_pp_alta", trat = trat_periph,
                                    ctrl = CTRL_DELTA)
)

# Controls WITHOUT mediators (mediation test)
CTRL_ALTA_NO_MED <- setdiff(CTRL_ALTA, c("median_rent", "palma_rent", "palma_commute",
                                           "pct_nao_constru_fora_alta_2010_q1",
                                           "pct_nao_constru_fora_alta_2010_q4"))
CTRL_DELTA_NO_MED <- CTRL_ALTA_NO_MED

# Mediator test table (with vs without mediators)
y_mediators <- list(
  "(1) g_high Compact — WITH mediators" = list(
    y = "g_alta", trat = trat_compact, ctrl = c(CTRL_ALTA, "g_fora_alta")
  ),
  "(2) g_high Sprawl — WITH mediators" = list(
    y = "g_alta", trat = trat_periph, ctrl = c(CTRL_ALTA, "g_fora_alta")
  ),
  "(3) Dpp_high Compact — WITH mediators" = list(
    y = "delta_pp_alta", trat = trat_compact, ctrl = CTRL_DELTA
  ),
  "(4) Dpp_high Sprawl — WITH mediators" = list(
    y = "delta_pp_alta", trat = trat_periph, ctrl = CTRL_DELTA
  ),
  "(5) g_high Compact — NO mediators" = list(
    y = "g_alta", trat = trat_compact, ctrl = c(CTRL_ALTA_NO_MED, "g_fora_alta")
  ),
  "(6) g_high Sprawl — NO mediators" = list(
    y = "g_alta", trat = trat_periph, ctrl = c(CTRL_ALTA_NO_MED, "g_fora_alta")
  ),
  "(7) Dpp_high Compact — NO mediators" = list(
    y = "delta_pp_alta", trat = trat_compact, ctrl = CTRL_DELTA_NO_MED
  ),
  "(8) Dpp_high Sprawl — NO mediators" = list(
    y = "delta_pp_alta", trat = trat_periph, ctrl = CTRL_DELTA_NO_MED
  ),
  "(9) g_high — Mediators ONLY (no treatment)" = list(
    y = "g_alta", trat = "1", ctrl = c(CTRL_ALTA, "g_fora_alta")
  ),
  "(10) Dpp_high — Mediators ONLY (no treatment)" = list(
    y = "delta_pp_alta", trat = "1", ctrl = CTRL_DELTA
  )
)

# Horse-race table (compact and sprawl together)
y_horserace <- list(
  "(1) g_high — Compact + Sprawl" = list(
    y = "g_alta",
    trat = paste0(trat_compact, " + ", trat_periph),
    ctrl = c(CTRL_ALTA, "g_fora_alta")
  ),
  "(2) Dpp_high — Compact + Sprawl" = list(
    y = "delta_pp_alta",
    trat = paste0(trat_compact, " + ", trat_periph),
    ctrl = CTRL_DELTA
  )
)

# Expanded interaction table (urban_class + regiao, compact + sprawl)
y_interact <- list(
  "(1) g_high — Compact × urban_class" = list(
    y = "g_alta",
    trat = paste0(trat_compact, " + ", trat_compact, ":urban_class"),
    ctrl = c(CTRL_ALTA, "g_fora_alta")
  ),
  "(2) Dpp_high — Compact × urban_class" = list(
    y = "delta_pp_alta",
    trat = paste0(trat_compact, " + ", trat_compact, ":urban_class"),
    ctrl = CTRL_DELTA
  ),
  "(3) g_high — Compact × regiao" = list(
    y = "g_alta",
    trat = paste0(trat_compact, " + ", trat_compact, ":regiao"),
    ctrl = c(CTRL_ALTA, "g_fora_alta")
  ),
  "(4) Dpp_high — Compact × regiao" = list(
    y = "delta_pp_alta",
    trat = paste0(trat_compact, " + ", trat_compact, ":regiao"),
    ctrl = CTRL_DELTA
  ),
  "(5) g_high — Sprawl × urban_class" = list(
    y = "g_alta",
    trat = paste0(trat_periph, " + ", trat_periph, ":urban_class"),
    ctrl = c(CTRL_ALTA, "g_fora_alta")
  ),
  "(6) Dpp_high — Sprawl × urban_class" = list(
    y = "delta_pp_alta",
    trat = paste0(trat_periph, " + ", trat_periph, ":urban_class"),
    ctrl = CTRL_DELTA
  ),
  "(7) g_high — Sprawl × regiao" = list(
    y = "g_alta",
    trat = paste0(trat_periph, " + ", trat_periph, ":regiao"),
    ctrl = c(CTRL_ALTA, "g_fora_alta")
  ),
  "(8) Dpp_high — Sprawl × regiao" = list(
    y = "delta_pp_alta",
    trat = paste0(trat_periph, " + ", trat_periph, ":regiao"),
    ctrl = CTRL_DELTA
  )
)

# =============================================================================
# 5) ESTIMATE MODELS
# =============================================================================

cat("\n5) Estimating models...\n")

# fit_specs2: trat is specified per column within specs
fit_specs2 <- function(specs, data, prefix, cluster_col = NULL) {
  mods <- lapply(names(specs), function(nm) {
    s <- specs[[nm]]
    fit_safe(make_f(s$y, s$trat, s$ctrl), data, paste(prefix, nm),
             cluster_col = cluster_col)
  })
  names(mods) <- names(specs)
  mods
}

cat("\n  Main table + appendix A — high susceptibility\n")
tab_main_mun <- fit_specs2(y_high, ds_mun, "Mun-High",  cluster_col = "NM_CIDADE")
tab_appA_arr <- fit_specs2(y_high, ds_arr, "Arr-High")

cat("\n  Interaction table — expanded (urban_class + regiao, compact + sprawl)\n")

# Region interactions (cols 3-4, 7-8) exclude Centro-Oeste (decided
# 2026-09-10, MIGRATION_PLAN.md 6c2). After the MIN_POP_RISCO_2010 filter the
# region has 8 municipalities spread over five urban classes (0-1 per class
# except Metropolis Suburbs, 5), and its interaction terms came out with
# standard errors up to 25x the main effect's -- not estimable with any
# useful precision. droplevels() so the region dummies in those columns
# don't carry an all-zero Centro-Oeste column. The urban_class interactions
# (cols 1-2, 5-6) keep the full sample: their cells are the urban-class
# margins, which are all well populated.
ds_mun_regiao <- ds_mun %>%
  filter(regiao != "Centro-Oeste") %>%
  mutate(regiao = droplevels(regiao))
cat(sprintf("    Region-interaction columns exclude Centro-Oeste: %d -> %d municipalities\n",
            nrow(ds_mun), nrow(ds_mun_regiao)))

is_regiao_spec <- grepl(":regiao", vapply(y_interact, function(s) s$trat, character(1)))
tab_interact_mun <- c(
  fit_specs2(y_interact[!is_regiao_spec], ds_mun,        "Mun-Interact",
             cluster_col = "NM_CIDADE"),
  fit_specs2(y_interact[is_regiao_spec],  ds_mun_regiao, "Mun-Interact (no C-O)",
             cluster_col = "NM_CIDADE")
)[names(y_interact)]

cat("\n  Mediator test table (with vs without)\n")
tab_mediators_mun <- fit_specs2(y_mediators, ds_mun, "Mun-Mediators", cluster_col = "NM_CIDADE")

cat("\n  Horse-race table (compact + sprawl together)\n")
tab_horserace_mun <- fit_specs2(y_horserace, ds_mun, "Mun-HorseRace", cluster_col = "NM_CIDADE")

# =============================================================================
# 6) VIF FOR THE MAIN MODEL
# =============================================================================

cat("\n6) VIF — Main table col. (1) g_high, Compact, municipalities:\n")
mod_vif <- tab_main_mun[["(1) g_high — Compact"]]
if (!is.null(mod_vif)) {
  tryCatch(print(round(vif(mod_vif), 2)),
           error = function(e) cat("  (VIF not computed:", e$message, ")\n"))
}

# =============================================================================
# 7) SAVE MODEL OBJECTS FOR STAGE 5
# =============================================================================
# 05_exhibits/table2_and_ed_tables.R reads this file and does all the
# formatting (coefficient labels, notes, output format) that used to happen
# right here -- nothing below is a display choice, only what a downstream
# reader needs to reproduce the fitted models' notes correctly.

cat("\n7) Saving model objects for 05_exhibits/table2_and_ed_tables.R...\n")

model_objects <- list(
  tab_main_mun      = tab_main_mun,
  tab_appA_arr      = tab_appA_arr,
  tab_interact_mun  = tab_interact_mun,
  tab_mediators_mun = tab_mediators_mun,
  tab_horserace_mun = tab_horserace_mun,
  metadata = list(
    min_pop_risco_2010    = MIN_POP_RISCO_2010,
    n_mun_pre_filter       = n_mun_antes,
    n_mun_post_filter      = nrow(ds_mun),
    n_centro_oeste_dropped = nrow(ds_mun) - nrow(ds_mun_regiao),
    date_estimated         = Sys.time()
  )
)

out_rds <- file.path(data_dir, "model_objects_table2.rds")
saveRDS(model_objects, out_rds)
cat(sprintf("  Saved: %s\n", out_rds))

cat("\n", strrep("=", 60), "\n")
cat("DONE\n")
cat(strrep("=", 60), "\n")
cat("\nNext step: run 05_exhibits/table2_and_ed_tables.R to format and export\n")
cat("Table 2 and ED Tables 2-5 into output/.\n")
