# =============================================================================
# minimum_population_filter.R  (pre-Migrate name: 12b_regressao_preperiodo_base_minima.R)
#
# SENSITIVITY OF TABLE 2 TO THE MINIMUM-BASELINE CUT.
#
# g_alta is a growth RATE normalised by pmax(pop_2010_risk_total, 1), so a
# near-zero 2010 baseline turns a handful of people into an implausible
# percentage that dominates the unweighted OLS fit of the g_alta columns.
# 16_estimate_models.R removes those cases with a single cut,
# MIN_POP_RISCO_2010, read from 04_regression_dataset_and_models/00_setup.R.
#
# This script does NOT re-apply that one cut -- that would only reproduce the
# main pipeline. It re-estimates the four Table 2 specifications across a
# SEQUENCE of cuts, at both municipality and arrangement level, and reports
# the treatment coefficient, its standard error and N for each, so the
# sensitivity of the headline result to where the cut is placed can be read
# off a single table.
#
# Cuts swept: CUTS below (100, 200, 500, 1000). The pipeline's own value
# (MIN_POP_RISCO_2010, from 00_setup.R) is marked as the reference row and
# must be one of them -- the script stops if it is not, so the sweep can
# never silently exclude the configuration the paper actually reports.
#
# NOTE (revised 2026-09-16): an earlier version of this script hardcoded
# MIN_POP_RISCO <- 1000 and applied it once, and its header described that as
# identical to the main pipeline's default "decided 2026-09-08". That is no
# longer true on two counts. (i) The cut was REVISED to 200 on 2026-09-12
# (MIGRATION_PLAN.md 6c1, revision paragraph): the 6e weighting correction
# lowered pop_2010_risk_total substantially, so an unchanged nominal 1000 had
# silently become a far more aggressive restriction than 6c1 decided.
# (ii) Holding 1000 here therefore stopped being a cross-check on
# 16_estimate_models.R and became an undeclared second configuration. The cut
# is now read from 00_setup.R and swept, which is what a robustness script
# should do.
#
# Treatment variable (compact growth 2000-2010):
#   pct_area_densif_infill_0010     -- densification + infill share
# Comparison variable (sprawl growth 2000-2010):
#   pct_area_periph_ext_leap_0010   -- peripheral + extension + leapfrog share
#
# The four specifications, at each cut and each level:
#   (1) g_high   Compact   (2) g_high   Sprawl
#   (3) Dpp_high Compact   (4) Dpp_high Sprawl
#
# High susceptibility only (rule 9): Tab A2 (medium) and Tab A3 (high+medium)
# were removed 2026-09-11 -- they referenced columns (g_medio, pp_medio_2010,
# g_alta_medio, ...) that no producing script generates since the medium
# branch was retired at 07_aggregate_municipality_metrics.R (Task 1c). Same
# removal already applied in 16_estimate_models.R (MIGRATION_PLAN.md 6c0).
#
# SEs: municipalities -> clustered by NM_CIDADE (arrangement); arrangements -> HC3.
# Region and urban-hierarchy dummies: included, not shown in the tables.
#
# Inputs:
#   data/processed_data/04_regression/tables/dataset_regressao_municipio.csv  (script 15)
#   data/processed_data/04_regression/tables/dataset_regressao_arranjo.csv    (script 15)
#
# Outputs (data/processed_data/04_regression/figures/):
#   sensitivity_min_pop_risco.csv                    -- tidy, both levels, all cuts
#   sensitivity_min_pop_risco_sample_sizes.csv       -- funnel per cut, both levels
#   tab1b_main_municipios_high_cut<CUT>.html/.tex/.docx    -- one per cut
#   tabA1b_arranjos_high_cut<CUT>.html/.tex/.docx          -- one per cut
#
# NOT RUN as part of 00_run_all.R -- robustness/ is kept live but outside the
# validated exhibit set. Run from the repository root (CLAUDE.md rule 5).
# =============================================================================

source("04_regression_dataset_and_models/00_setup.R")

for (pkg in c("lmtest", "sandwich", "car", "modelsummary", "flextable")) {
  if (!requireNamespace(pkg, quietly = TRUE)) install.packages(pkg)
  library(pkg, character.only = TRUE)
}

cat("\n", strrep("=", 60), "\n")
cat("MINIMUM_POPULATION_FILTER - SENSITIVITY ACROSS CUTS\n")
cat(strrep("=", 60), "\n")

# =============================================================================
# 1) LOAD AND PREPARE DATASETS
# =============================================================================

cat("\n1) Loading datasets...\n")

path_mun <- file.path(tables_dir, "dataset_regressao_municipio.csv")
path_arr <- file.path(tables_dir, "dataset_regressao_arranjo.csv")

if (!file.exists(path_mun)) stop("dataset_regressao_municipio.csv not found -- run script 15")
if (!file.exists(path_arr)) stop("dataset_regressao_arranjo.csv not found -- run script 15")

# Prepara variáveis derivadas comuns
prep <- function(df) {
  df %>% mutate(
    pop_growth        = (pop_urbana_2022 - pop_urbana_2010_cg) /
                          pop_urbana_2010_cg,
    log_pop_2010      = log(pop_urbana_2010_cg + 1),
    log_pib_pc        = log(pib_pc_2010 + 1),
    log_area_2010_km2 = log(area_urbana_2010_m2 / 1e6 + 0.001),
    # Denominator on the MAPPED units (6f.2): pop_urbana_2010_cg is
    # mapped-members-only at arrangement level, so its area must be too,
    # or the ratio spans the two aggregation groups. Identical to
    # area_urbana_2010_m2 at municipality level.
    log_density_2010  = log(pop_urbana_2010_cg /
                              (area_urbana_2010_m2_mapped / 1e6 + 0.001) + 1),
    log_pop_total_2010 = log(pop_total_2010 + 1),
    log_pop_total_2000 = log(pop_2000 + 1),
    log_area_2000_km2  = log(area_2000_m2 / 1e6 + 0.001),
    g_fora_suscept_slums = coalesce(g_slums_1022 - g_alta_slums_1022, 0),
    pct_area_periph_ext_leap = pct_area_peripheral + pct_area_extension + pct_area_leapfrog,
    regiao = factor(regiao,
                    levels = c("Sudeste", "Sul", "Nordeste",
                               "Norte", "Centro-Oeste")),
    urban_class = factor(urban_class,
                         levels = c("Urban Centers", "Metropolises",
                                    "Metropolis Suburbs", "Regional Centers",
                                    "Regional Centers Suburbs"))
  )
}

# Prepara variáveis derivadas do crescimento 2000→2010
prep_0010 <- function(df) {
  df %>% mutate(
    pct_area_densif_infill_0010 = pct_area_densif_0010 + pct_area_infill_0010,
    log_dist_densif_0010        = log(pmax(dist_media_m_densif_0010, 1)),
    log_dist_densif_infill_0010 = log(pmax(dist_media_m_densif_infill_0010, 1)),
    pct_area_periph_ext_leap_0010 = pct_area_peripheral_0010 +
                                     pct_area_extension_0010 +
                                     pct_area_leapfrog_0010
  )
}

ds_mun_full <- read_csv(path_mun, show_col_types = FALSE) %>% prep() %>% prep_0010()
ds_arr_full <- read_csv(path_arr, show_col_types = FALSE) %>% prep() %>% prep_0010()

cat(sprintf("  Municipalities: %d  |  Arrangements: %d  (before any cut)\n",
            nrow(ds_mun_full), nrow(ds_arr_full)))

if (!"pop_2010_risk_total" %in% names(ds_mun_full))
  stop("pop_2010_risk_total not found -- run an up-to-date script 15")

# =============================================================================
# 1b) THE SEQUENCE OF CUTS
# =============================================================================

# The sweep. MIN_POP_RISCO_2010 comes from 00_setup.R and is the value
# 16_estimate_models.R applies; it is the reference row of the sensitivity
# table, not a separate configuration defined here.
CUTS <- c(100, 200, 500, 1000)

if (!MIN_POP_RISCO_2010 %in% CUTS)
  stop(sprintf(paste("The pipeline's cut (MIN_POP_RISCO_2010 = %s, from 00_setup.R) is not",
                     "in CUTS (%s). Add it, so the sweep always contains the configuration",
                     "the paper reports."),
               MIN_POP_RISCO_2010, paste(CUTS, collapse = ", ")))

cat(sprintf("\n1b) Sweeping pop_2010_risk_total > {%s}\n", paste(CUTS, collapse = ", ")))
cat(sprintf("    Pipeline reference cut (00_setup.R): %d\n", MIN_POP_RISCO_2010))

# Sample size retained at each cut, both levels
sample_sizes <- bind_rows(lapply(CUTS, function(cut) {
  n_mun <- sum(ds_mun_full$pop_2010_risk_total > cut, na.rm = TRUE)
  n_arr <- sum(ds_arr_full$pop_2010_risk_total > cut, na.rm = TRUE)
  tibble(
    cut               = cut,
    is_pipeline_cut   = cut == MIN_POP_RISCO_2010,
    n_mun_before      = nrow(ds_mun_full),
    n_mun_after       = n_mun,
    n_mun_dropped     = nrow(ds_mun_full) - n_mun,
    pct_mun_dropped   = 100 * (nrow(ds_mun_full) - n_mun) / nrow(ds_mun_full),
    n_arr_before      = nrow(ds_arr_full),
    n_arr_after       = n_arr,
    n_arr_dropped     = nrow(ds_arr_full) - n_arr,
    pct_arr_dropped   = 100 * (nrow(ds_arr_full) - n_arr) / nrow(ds_arr_full)
  )
}))

cat("\n  Sample retained per cut (before listwise deletion):\n")
print(as.data.frame(sample_sizes), row.names = FALSE, digits = 4)

# =============================================================================
# 2) CONTROLS BY OUTCOME
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

# =============================================================================
# 3) ESTIMATION HELPERS
# =============================================================================

make_f <- function(y, trat, ctrl) {
  as.formula(paste(y, "~", paste(c(trat, ctrl), collapse = " + ")))
}

fit_safe <- function(f, data, label, cluster_col = NULL) {
  vars <- all.vars(f)
  dat  <- data[complete.cases(data[, intersect(vars, names(data))]), ]
  cat(sprintf("    %-44s N = %d\n", label, nrow(dat)))
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
#   municipalities -> clustered by arrangement (NM_CIDADE)
#   arrangements   -> HC3 (each row is already a unique cluster)
vcov_clust <- function(mod) {
  cl <- attr(mod, "cluster_vec")
  if (!is.null(cl)) vcovCL(mod, cluster = cl) else vcovHC(mod, type = "HC3")
}
vcov_hc3 <- function(mod) vcovHC(mod, type = "HC3")

stars_for <- function(p) {
  if (is.na(p)) return("")
  if (p < 0.01) return("***")
  if (p < 0.05) return("**")
  if (p < 0.10) return("*")
  ""
}

# Pulls the treatment row out of one fitted model, with the SE the table for
# that level would report -- clustered for municipalities, HC3 for arrangements.
treatment_row <- function(mod, trat, vcov_fn) {
  if (is.null(mod)) {
    return(tibble(estimate = NA_real_, std_error = NA_real_, statistic = NA_real_,
                  p_value = NA_real_, stars = NA_character_,
                  n_obs = NA_integer_, r_squared = NA_real_))
  }
  ct <- lmtest::coeftest(mod, vcov. = vcov_fn(mod))
  if (!trat %in% rownames(ct)) {
    return(tibble(estimate = NA_real_, std_error = NA_real_, statistic = NA_real_,
                  p_value = NA_real_, stars = NA_character_,
                  n_obs = stats::nobs(mod), r_squared = summary(mod)$r.squared))
  }
  p <- ct[trat, 4]
  tibble(
    estimate  = unname(ct[trat, 1]),
    std_error = unname(ct[trat, 2]),
    statistic = unname(ct[trat, 3]),
    p_value   = unname(p),
    stars     = stars_for(p),
    n_obs     = stats::nobs(mod),
    r_squared = summary(mod)$r.squared
  )
}

# =============================================================================
# 4) SPECIFICATIONS
# =============================================================================

trat_compact <- "pct_area_densif_infill_0010"
trat_periph  <- "pct_area_periph_ext_leap_0010"

y_high <- list(
  "(1) g_high — Compact"   = list(y = "g_alta",        trat = trat_compact,
                                  ctrl = c(CTRL_ALTA, "g_fora_alta")),
  "(2) g_high — Sprawl"    = list(y = "g_alta",        trat = trat_periph,
                                  ctrl = c(CTRL_ALTA, "g_fora_alta")),
  "(3) Dpp_high — Compact" = list(y = "delta_pp_alta", trat = trat_compact,
                                  ctrl = CTRL_DELTA),
  "(4) Dpp_high — Sprawl"  = list(y = "delta_pp_alta", trat = trat_periph,
                                  ctrl = CTRL_DELTA)
)

fit_specs2 <- function(specs, data, prefix, cluster_col = NULL) {
  mods <- lapply(names(specs), function(nm) {
    s <- specs[[nm]]
    fit_safe(make_f(s$y, s$trat, s$ctrl), data, paste(prefix, nm),
             cluster_col = cluster_col)
  })
  names(mods) <- names(specs)
  mods
}

# =============================================================================
# 5) ESTIMATE ACROSS CUTS, BOTH LEVELS
# =============================================================================

cat("\n5) Estimating across cuts...\n")

# models_by_cut[[as.character(cut)]]$mun / $arr -- kept so section 7 can write
# one formatted table per cut without re-fitting.
models_by_cut <- list()
sens_rows     <- list()

for (cut in CUTS) {
  marker <- if (cut == MIN_POP_RISCO_2010) "  <-- pipeline cut" else ""
  cat(sprintf("\n  pop_2010_risk_total > %d%s\n", cut, marker))

  ds_mun <- ds_mun_full %>% filter(pop_2010_risk_total > cut)
  ds_arr <- ds_arr_full %>% filter(pop_2010_risk_total > cut)

  cat(sprintf("   municipalities (level)\n"))
  mods_mun <- fit_specs2(y_high, ds_mun, "Mun-High", cluster_col = "NM_CIDADE")
  cat(sprintf("   arrangements (level)\n"))
  mods_arr <- fit_specs2(y_high, ds_arr, "Arr-High")

  models_by_cut[[as.character(cut)]] <- list(mun = mods_mun, arr = mods_arr)

  for (nm in names(y_high)) {
    s <- y_high[[nm]]

    sens_rows[[length(sens_rows) + 1]] <- bind_cols(
      tibble(cut = cut, is_pipeline_cut = cut == MIN_POP_RISCO_2010,
             level = "municipality", spec = nm, outcome = s$y, treatment = s$trat),
      treatment_row(mods_mun[[nm]], s$trat, vcov_clust)
    )

    sens_rows[[length(sens_rows) + 1]] <- bind_cols(
      tibble(cut = cut, is_pipeline_cut = cut == MIN_POP_RISCO_2010,
             level = "arrangement", spec = nm, outcome = s$y, treatment = s$trat),
      treatment_row(mods_arr[[nm]], s$trat, vcov_hc3)
    )
  }
}

sensitivity <- bind_rows(sens_rows) %>%
  arrange(level, spec, cut) %>%
  mutate(se_type = if_else(level == "municipality",
                           "clustered by NM_CIDADE", "HC3"))

# =============================================================================
# 6) SENSITIVITY TABLE -- CONSOLE AND CSV
# =============================================================================

cat("\n6) Sensitivity of the treatment coefficient to the cut\n")

for (lv in c("municipality", "arrangement")) {
  cat(sprintf("\n  %s level (SEs: %s)\n", toupper(lv),
              if (lv == "municipality") "clustered by NM_CIDADE" else "HC3"))
  bloco <- sensitivity %>%
    filter(level == lv) %>%
    transmute(
      spec, cut,
      coef = sprintf("%.4f%s", estimate, stars),
      se   = sprintf("(%.4f)", std_error),
      N    = n_obs,
      R2   = sprintf("%.3f", r_squared),
      ref  = if_else(is_pipeline_cut, "*", "")
    )
  print(as.data.frame(bloco), row.names = FALSE)
}

cat("\n  ref = '*' marks the cut 16_estimate_models.R actually applies.\n")
cat("  Note: N varies across cuts for two reasons at once -- the cut itself,\n")
cat("  and complete.cases() over ALL formula variables inside fit_safe(),\n")
cat("  which is applied per specification (same rule as 16_estimate_models.R).\n")

dir.create(figures_dir, showWarnings = FALSE, recursive = TRUE)

out_sens <- file.path(figures_dir, "sensitivity_min_pop_risco.csv")
write_csv(sensitivity, out_sens)
cat(sprintf("\n  ✓ %s\n", basename(out_sens)))

out_sizes <- file.path(figures_dir, "sensitivity_min_pop_risco_sample_sizes.csv")
write_csv(sample_sizes, out_sizes)
cat(sprintf("  ✓ %s\n", basename(out_sizes)))

# =============================================================================
# 7) FORMATTED TABLES, ONE PER CUT
# =============================================================================

coef_map_0010 <- c(
  "pct_area_densif_infill_0010"       = "Treatment (compact or sprawl)",
  "pct_area_periph_ext_leap_0010"     = "Treatment (compact or sprawl)",
  "log_pop_total_2000"                = "Log total population 2000",
  "log_area_2000_km2"                 = "Log urban footprint 2000",
  "g_fora_alta"                       = "Pop. growth outside risk zones",
  "pp_alta_2010"                      = "Pop. share in risk zones 2010",
  "topo_prop_inclinado"               = "Steep terrain",
  "pct_nao_constru_fora_alta_2010_q1" = "Safe empty land Q1",
  "palma_commute"                     = "Palma ratio commute",
  "median_rent"                       = "Median rent",
  "prop_favelas_2010"                 = "Slum population share 2010",
  "(Intercept)"                       = "Intercept"
)
# Controls included in regressions but not shown in table:
#   pct_nao_constru_fora_alta_2010_q4, palma_rent, log_pib_pc,
#   log_area_2000_km2, zero_area_2000, region dummies, urban class dummies

note_hidden <- paste(
  "Additional controls included but not shown:",
  "safe empty land Q4, Palma ratio rent, log GDP per capita 2010,",
  "log urban footprint 2000, no urban footprint in 2000 dummy,",
  "region and urban class dummies."
)

gof_0010 <- tribble(
  ~raw,            ~clean,   ~fmt,
  "nobs",          "N",      0L,
  "r.squared",     "R²",     3L,
  "adj.r.squared", "R² adj.", 3L
)

ms_base <- list(
  stars     = c("*" = .10, "**" = .05, "***" = .01),
  coef_map  = coef_map_0010,
  coef_omit = "^regiao|^urban_class",
  gof_map   = gof_0010
)

salvar_tabela <- function(models, titulo, base_name, opts) {
  models <- Filter(Negate(is.null), models)
  if (length(models) == 0) {
    cat(sprintf("  WARNING: no model estimated for %s\n", base_name))
    return(invisible())
  }
  for (ext in c("html", "tex", "docx")) {
    args <- c(list(models = models, title = titulo,
                   output = file.path(figures_dir, paste0(base_name, ".", ext))), opts)
    do.call(modelsummary, args)
    cat(sprintf("  ✓ %s.%s\n", base_name, ext))
  }
}

cat("\n7) Writing one formatted table per cut...\n")

for (cut in CUTS) {
  ref_txt <- if (cut == MIN_POP_RISCO_2010)
    " This is the cut the main pipeline applies." else ""

  note_cut <- sprintf("Sample restricted to pop_2010_risk_total > %d.%s", cut, ref_txt)

  salvar_tabela(
    models_by_cut[[as.character(cut)]]$mun,
    paste(sprintf("Table 1 (cut > %d) — Pre-period urban form (2000–2010) and", cut),
          "high-susceptibility population growth (2010–2022): municipalities.",
          "Cols (1)–(2): growth rate g_high; Cols (3)–(4): change in pop. share Dpp_high."),
    sprintf("tab1b_main_municipios_high_cut%d", cut),
    c(ms_base, list(vcov = vcov_clust,
                    notes = paste(note_cut,
                                  "Standard errors clustered by functional urban area (NM_CIDADE)",
                                  "in parentheses.", note_hidden,
                                  "* p < 0.10, ** p < 0.05, *** p < 0.01.")))
  )

  salvar_tabela(
    models_by_cut[[as.character(cut)]]$arr,
    paste(sprintf("Table A1 (cut > %d) — Pre-period urban form (2000–2010) and", cut),
          "high-susceptibility population growth (2010–2022): functional urban areas.",
          "Cols (1)–(2): g_high; Cols (3)–(4): Dpp_high."),
    sprintf("tabA1b_arranjos_high_cut%d", cut),
    c(ms_base, list(vcov = vcov_hc3,
                    notes = paste(note_cut,
                                  "HC3 heteroskedasticity-robust standard errors in parentheses.",
                                  note_hidden,
                                  "* p < 0.10, ** p < 0.05, *** p < 0.01.")))
  )
}

# =============================================================================
# 8) VIF AT THE PIPELINE CUT
# =============================================================================

cat(sprintf("\n8) VIF — col. (1) g_high Compact, municipalities, at the pipeline cut (> %d):\n",
            MIN_POP_RISCO_2010))
mod_vif <- models_by_cut[[as.character(MIN_POP_RISCO_2010)]]$mun[["(1) g_high — Compact"]]
if (!is.null(mod_vif)) {
  tryCatch(print(round(vif(mod_vif), 2)),
           error = function(e) cat("  (VIF not computed:", e$message, ")\n"))
}

cat("\n", strrep("=", 60), "\n")
cat("DONE\n")
cat(strrep("=", 60), "\n")
cat("\nOutputs in: ", figures_dir, "\n")
