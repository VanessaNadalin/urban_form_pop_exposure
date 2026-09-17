# =============================================================================
# table2_and_ed_tables.R
# Formats and exports Table 2 and ED Tables 2-5 from the model objects
# 04_regression_dataset_and_models/16_estimate_models.R already fitted and
# saved. Per CLAUDE.md's target structure and MIGRATION_PLAN.md 6d (applied
# 2026-09-11): stage 4 estimates, stage 5 formats. Nothing here re-estimates
# anything -- every coefficient, SE and N below comes straight from the
# saved model objects; this script only chooses labels, notes, and output
# format.
#
# Exhibit -> model object -> output file:
#   Table 2      <- tab_main_mun       -> table2_main_municipalities
#   ED Table 2   <- tab_mediators_mun  -> ed_table2_mediators
#   ED Table 3   <- tab_appA_arr       -> ed_table3_fua
#   ED Table 4   <- tab_horserace_mun  -> ed_table4_horserace
#   ED Table 5   <- tab_interact_mun   -> ed_table5_interactions
#
# The mediator-coefficients-shown variant (former "Table 3b", same models as
# ED Table 2 with a different coef_map to surface the mediators themselves)
# is NOT exported as a deliverable here -- decided 2026-09-10
# (05_exhibits/pipeline_5.md §9): it isn't in results_used.md, and ED Table 2
# already answers the with/without-mediators question. Its coef map is kept
# below, commented out, in case it's wanted again.
#
# Input:
#   data/processed_data/04_regression/model_objects_table2.rds  (script 16)
#
# Outputs (in output/):
#   table2_main_municipalities.{html,tex,docx}
#   ed_table2_mediators.{html,tex,docx}
#   ed_table3_fua.{html,tex,docx}
#   ed_table4_horserace.{html,tex,docx}
#   ed_table5_interactions.{html,tex,docx}
# =============================================================================

source("04_regression_dataset_and_models/00_setup.R")

for (pkg in c("lmtest", "sandwich", "modelsummary", "flextable")) {
  if (!requireNamespace(pkg, quietly = TRUE)) install.packages(pkg)
  library(pkg, character.only = TRUE)
}

cat("\n", strrep("=", 60), "\n")
cat("TABLE2_AND_ED_TABLES.R\n")
cat(strrep("=", 60), "\n")

# =============================================================================
# 1) LOAD MODEL OBJECTS
# =============================================================================

cat("\n1) Loading model objects from script 16...\n")

rds_path <- file.path(data_dir, "model_objects_table2.rds")
if (!file.exists(rds_path))
  stop("model_objects_table2.rds not found — run 04_regression_dataset_and_models/16_estimate_models.R first.\n  Path: ", rds_path)

model_objects <- readRDS(rds_path)

tab_main_mun      <- model_objects$tab_main_mun
tab_appA_arr      <- model_objects$tab_appA_arr
tab_interact_mun  <- model_objects$tab_interact_mun
tab_mediators_mun <- model_objects$tab_mediators_mun
tab_horserace_mun <- model_objects$tab_horserace_mun
metadata          <- model_objects$metadata

MIN_POP_RISCO_2010 <- metadata$min_pop_risco_2010

cat(sprintf("   Estimated: %s\n", format(metadata$date_estimated)))
cat(sprintf("   Municipalities: %d -> %d after pop_2010_risk_total > %d\n",
            metadata$n_mun_pre_filter, metadata$n_mun_post_filter, MIN_POP_RISCO_2010))
cat(sprintf("   Region-interaction columns exclude Centro-Oeste: %d municipalities dropped\n",
            metadata$n_centro_oeste_dropped))

# =============================================================================
# 2) SHARED HELPERS (vcov functions are redefined here, not saved in the
#    .rds -- cheap to duplicate, avoids relying on serialized closures)
# =============================================================================

# vcov by dataset type:
#   municipalities -> clustered by arrangement (CD_CIDADE, via attr(mod, "cluster_vec"))
#   arrangements   -> HC3 (each row is already a unique cluster)
vcov_clust <- function(mod) {
  cl <- attr(mod, "cluster_vec")
  if (!is.null(cl)) vcovCL(mod, cluster = cl) else vcovHC(mod, type = "HC3")
}
vcov_hc3 <- function(mod) vcovHC(mod, type = "HC3")

gof_0010 <- tribble(
  ~raw,            ~clean,    ~fmt,
  "nobs",          "N",        0L,
  "r.squared",     "R²",       3L,
  "adj.r.squared", "R² adj.",  3L
)

save_table <- function(models, title, base_name, opts) {
  models <- Filter(Negate(is.null), models)
  if (length(models) == 0) {
    cat(sprintf("  Warning: no model estimated for %s\n", base_name))
    return(invisible())
  }
  for (ext in c("html", "tex", "docx")) {
    args <- c(list(models = models, title = title,
                   output = output_path(paste0(base_name, ".", ext))), opts)
    do.call(modelsummary, args)
    cat(sprintf("  OK %s.%s\n", base_name, ext))
  }
}

cat("\n2) Formatting and saving tables to output/...\n")

# =============================================================================
# 3) TABLE 2 — main table (body of the article), municipalities
# =============================================================================

coef_map_0010 <- c(
  "pct_area_densif_infill_0010"         = "Treatment (compact or sprawl)",
  "pct_area_periph_ext_leap_0010"       = "Treatment (compact or sprawl)",
  "log_pop_total_2000"                  = "Log total population 2000",
  "log_area_2000_km2"                   = "Log urban footprint 2000",
  "g_fora_alta"                         = "Pop. growth outside risk zones",
  "pp_alta_2010"                        = "Pop. share in risk zones 2010",
  "topo_prop_inclinado"                 = "Steep terrain",
  "pct_nao_constru_fora_alta_2010_q1"  = "Safe empty land Q1",
  "palma_commute"                       = "Palma ratio commute",
  "median_rent"                         = "Median rent",
  "prop_favelas_2010"                   = "Slum population share 2010",
  "(Intercept)"                         = "Intercept"
)
# Controls included in regressions but not shown in table:
#   pct_nao_constru_fora_alta_2010_q4, palma_rent, log_pib_pc,
#   log_area_2000_km2, zero_area_2000, region dummies, urban class dummies

note_hidden <- paste(
  sprintf("Sample restricted to pop_2010_risk_total > %d.", MIN_POP_RISCO_2010),
  "Additional controls included but not shown:",
  "safe empty land Q4 (outside high-susceptibility zones),",
  "Palma ratio rent, log GDP per capita 2010,",
  "no urban footprint in 2000 dummy,",
  "region and urban class dummies."
)

note_mun <- paste(
  "Standard errors clustered by functional urban area (NM_CIDADE) in parentheses.",
  note_hidden,
  "* p < 0.10, ** p < 0.05, *** p < 0.01."
)
note_arr <- paste(
  "HC3 heteroskedasticity-robust standard errors in parentheses.",
  note_hidden,
  "* p < 0.10, ** p < 0.05, *** p < 0.01."
)

ms_base <- list(
  stars    = c("*" = .10, "**" = .05, "***" = .01),
  coef_map = coef_map_0010,
  coef_omit = "^regiao|^urban_class",
  gof_map  = gof_0010
)

ms_opts_mun <- c(ms_base, list(vcov = vcov_clust, notes = note_mun))
ms_opts_arr <- c(ms_base, list(vcov = vcov_hc3,   notes = note_arr))

save_table(
  tab_main_mun,
  paste("Table 2 — Pre-period urban form (2000–2010) and high-susceptibility",
        "population growth (2010–2022): municipalities.",
        "Cols (1)–(2): growth rate g_high; Cols (3)–(4): change in pop. share Dpp_high."),
  "table2_main_municipalities",
  ms_opts_mun
)

# =============================================================================
# 4) ED TABLE 3 — arrangements (functional urban areas), high susceptibility
# =============================================================================

save_table(
  tab_appA_arr,
  paste("ED Table 3 — Pre-period urban form (2000–2010) and high-susceptibility",
        "population growth (2010–2022): functional urban areas.",
        "Cols (1)–(2): g_high; Cols (3)–(4): Dpp_high."),
  "ed_table3_fua",
  ms_opts_arr
)

# =============================================================================
# 5) ED TABLE 5 — interactions (urban_class + regiao, compact + sprawl)
# =============================================================================

coef_map_interact <- c(
  # Compact interactions
  "pct_area_densif_infill_0010" = "Compact growth (main effect)",
  "pct_area_densif_infill_0010:urban_classMetropolises" = "  × Metropolises",
  "pct_area_densif_infill_0010:urban_classMetropolis Suburbs" = "  × Metropolis Suburbs",
  "pct_area_densif_infill_0010:urban_classRegional Centers" = "  × Regional Centers",
  "pct_area_densif_infill_0010:urban_classRegional Centers Suburbs" = "  × Regional Centers Suburbs",
  "pct_area_densif_infill_0010:regiaoSul" = "  × South",
  "pct_area_densif_infill_0010:regiaoNordeste" = "  × Northeast",
  "pct_area_densif_infill_0010:regiaoNorte" = "  × North",
  # Sprawl interactions
  "pct_area_periph_ext_leap_0010" = "Sprawl growth (main effect)",
  "pct_area_periph_ext_leap_0010:urban_classMetropolises" = "  × Metropolises",
  "pct_area_periph_ext_leap_0010:urban_classMetropolis Suburbs" = "  × Metropolis Suburbs",
  "pct_area_periph_ext_leap_0010:urban_classRegional Centers" = "  × Regional Centers",
  "pct_area_periph_ext_leap_0010:urban_classRegional Centers Suburbs" = "  × Regional Centers Suburbs",
  "pct_area_periph_ext_leap_0010:regiaoSul" = "  × South",
  "pct_area_periph_ext_leap_0010:regiaoNordeste" = "  × Northeast",
  "pct_area_periph_ext_leap_0010:regiaoNorte" = "  × North",
  # Controls
  "g_fora_alta" = "Pop. growth outside risk zones",
  "pp_alta_2010" = "Pop. share in risk zones 2010",
  "(Intercept)" = "Intercept"
)

note_interact <- paste(
  "Standard errors clustered by functional urban area (NM_CIDADE) in parentheses.",
  sprintf("Sample restricted to pop_2010_risk_total > %d.", MIN_POP_RISCO_2010),
  "Region-interaction columns (3)-(4) and (7)-(8) exclude Centro-Oeste",
  sprintf("(%d municipalities after the restriction, too few for its interaction terms to be estimated).",
          metadata$n_centro_oeste_dropped),
  "Reference categories: Urban Centers (urban class), Southeast (region).",
  "Main effect = effect in reference category; interactions = differential effect in other categories.",
  "Additional controls included but not shown:",
  "steep terrain, safe empty land (Q1 and Q4), Palma ratios (rent and commute),",
  "median rent, log GDP per capita, log population and area 2000,",
  "slum population share 2010, no urban footprint 2000 dummy.",
  "* p < 0.10, ** p < 0.05, *** p < 0.01."
)

ms_opts_interact <- list(
  stars = c("*" = .10, "**" = .05, "***" = .01),
  coef_map = coef_map_interact,
  coef_omit = "^(?!pct_area)",  # Keep all treatment interactions, omit only non-interacted controls
  gof_map = gof_0010,
  vcov = vcov_clust,
  notes = note_interact
)

save_table(
  tab_interact_mun,
  paste("ED Table 5 — Interactions with urban class and region.",
        "Cols (1)–(2): Compact × urban_class; Cols (3)–(4): Compact × regiao;",
        "Cols (5)–(6): Sprawl × urban_class; Cols (7)–(8): Sprawl × regiao.",
        "Odd cols: g_high; Even cols: Dpp_high."),
  "ed_table5_interactions",
  ms_opts_interact
)

# =============================================================================
# 6) ED TABLE 2 — mediator test (with vs. without housing-market mediators)
# =============================================================================

note_mediators <- paste(
  "Standard errors clustered by functional urban area (NM_CIDADE) in parentheses.",
  "Cols (1)–(4): WITH mediators + treatment;",
  "Cols (5)–(8): NO mediators + treatment;",
  "Cols (9)–(10): WITH mediators, NO treatment (diagnostic).",
  "Mediators: median rent, Palma ratios, safe empty land Q1/Q4.",
  "Cols (9)–(10) test if mediators predict outcome without treatment (confounder vs post-treatment check).",
  "Additional controls included but not shown:",
  "steep terrain, log GDP per capita, log population and area 2000,",
  "slum population share 2010, region dummies, urban class dummies, no urban footprint 2000 dummy.",
  "* p < 0.10, ** p < 0.05, *** p < 0.01."
)

ms_opts_mediators <- list(
  stars = c("*" = .10, "**" = .05, "***" = .01),
  coef_map = coef_map_0010,
  coef_omit = "^(regiao|urban_class|palma|pct_nao|log_pib|log_area|zero_area|prop_favelas)",
  gof_map = gof_0010,
  vcov = vcov_clust,
  notes = note_mediators
)

save_table(
  tab_mediators_mun,
  paste("ED Table 2 — Mediation test: effect of removing housing-market mediator variables.",
        "Cols (1)–(4): WITH mediators + treatment;",
        "Cols (5)–(8): NO mediators + treatment;",
        "Cols (9)–(10): WITH mediators, NO treatment.",
        "Cols (1),(5): g_high Compact; (2),(6): g_high Sprawl;",
        "(3),(7): Dpp_high Compact; (4),(8): Dpp_high Sprawl;",
        "(9): g_high mediators only; (10): Dpp_high mediators only."),
  "ed_table2_mediators",
  ms_opts_mediators
)

# -- Mediator-coefficients-shown variant: NOT exported, see header note -----
# coef_map_mediators_show <- c(
#   "pct_area_densif_infill_0010"        = "Treatment: Compact growth",
#   "pct_area_periph_ext_leap_0010"      = "Treatment: Sprawl growth",
#   "median_rent"                        = "Median rent 2010",
#   "palma_rent"                         = "Palma ratio: rent 2010",
#   "palma_commute"                      = "Palma ratio: commute 2010",
#   "pct_nao_constru_fora_alta_2010_q1" = "Safe empty land Q1 (low availability)",
#   "pct_nao_constru_fora_alta_2010_q4" = "Safe empty land Q4 (high availability)",
#   "pp_alta_2010"                       = "Pop. share in risk zones 2010",
#   "g_fora_alta"                        = "Pop. growth outside risk zones",
#   "topo_prop_inclinado"                = "Steep terrain",
#   "log_pop_total_2000"                 = "Log total population 2000",
#   "(Intercept)"                        = "Intercept"
# )

# =============================================================================
# 7) ED TABLE 4 — horse race (compact and sprawl entered jointly)
# =============================================================================

coef_map_horserace <- c(
  "pct_area_densif_infill_0010" = "Compact growth",
  "pct_area_periph_ext_leap_0010" = "Sprawl growth",
  "g_fora_alta" = "Pop. growth outside risk zones",
  "pp_alta_2010" = "Pop. share in risk zones 2010",
  "log_pop_total_2000" = "Log total population 2000",
  "(Intercept)" = "Intercept"
)

note_horserace <- paste(
  "Standard errors clustered by functional urban area (NM_CIDADE) in parentheses.",
  "Both compact and sprawl growth included in same regression (horse race).",
  "Coefficients show effect of each growth type controlling for the other.",
  "Note: compact + sprawl do not sum to 1 (consolidated growth not shown).",
  "Additional controls included but not shown:",
  "steep terrain, safe empty land (Q1 and Q4), Palma ratios (rent and commute),",
  "median rent, log GDP per capita, log area 2000,",
  "slum population share 2010, region dummies, urban class dummies, no urban footprint 2000 dummy.",
  "* p < 0.10, ** p < 0.05, *** p < 0.01."
)

ms_opts_horserace <- list(
  stars = c("*" = .10, "**" = .05, "***" = .01),
  coef_map = coef_map_horserace,
  coef_omit = "^(regiao|urban_class|palma|pct_nao|median_rent|log_pib|log_area|zero_area|prop_favelas|topo)",
  gof_map = gof_0010,
  vcov = vcov_clust,
  notes = note_horserace
)

save_table(
  tab_horserace_mun,
  paste("ED Table 4 — Horse race: compact and sprawl growth in same regression.",
        "Col (1): g_high (growth rate in risk zones); Col (2): Dpp_high (change in pop. share)."),
  "ed_table4_horserace",
  ms_opts_horserace
)

cat("\n", strrep("=", 60), "\n")
cat("DONE\n")
cat(strrep("=", 60), "\n")
cat("\nOutputs in: ", output_dir, "\n")
