# =============================================================================
# 13_dependent_variables.R
# Builds the dependent variables (Y) and baseline urban-form variables for
# the regression datasets (municipalities and arrangements).
#
# DEPENDENT VARIABLE -- single grid (MIGRATION_PLAN.md 6b0, common-grid
# rework, coordinated diff per 6c):
#   pop_2010_* / pop_2022_* = 2010 (allocated) and 2022 population on the
#     common 2010-2022 grid (03_integrate_grid_with_ghsl.R +
#     07_aggregate_municipality_metrics.R -- replaces the old
#     pop10e_*/pop22_* cross-grid between two separate grids)
#
#   g_alta        : growth rate WITHIN the HIGH susceptibility zone 2010-2022,
#                   normalized by pop_2010_risk_total (denominator = the
#                   zone's own initial population)
#   delta_pp_alta : change in percentage points of the population share in
#                   high susceptibility
#
#   2026-08-28: the "medio"/"alta_medio" branch (g_medio, pp_medio_*,
#   delta_pp_medio, g_alta_medio, pp_alta_medio_*, delta_pp_alta_medio,
#   g_fora_medio, g_fora_alta_medio) was removed -- these columns depended on
#   pop10e_risco_medio_total/pop22_risco_medio_total, which script 07 no
#   longer produces since the medium-susceptibility branch was retired
#   (CLAUDE.md rule 9, high-only; Migrate Task 1c). None of them is
#   referenced in results_used.md -- they were not used by any published
#   result.
#
# BASELINE URBAN FORM (2010-2022):
#   pct_area_densif, _peripheral, _extension, _leapfrog
#   delta_pp_densif, pct_pop_densif_2010/2022
#   g_fora_alta
#
# Inputs:
#   data/processed_data/03_urban_footprint/metricas/metricas_municipio_2010_2022.csv
#   data/processed_data/03_urban_footprint/metricas/metricas_arranjo_2010_2022.csv
#   data/processed_data/04_regression/amostra_mun.csv / amostra_arr.csv
#   (from 01_compose_sample.R)
#
# Outputs (data/processed_data/04_regression/tables/):
#   met_municipio_com_y_BR.csv
#   met_arranjo_com_y_BR.csv
# =============================================================================

source("04_regression_dataset_and_models/00_setup.R")

cat("\n", strrep("=", 60), "\n")
cat("13_DEPENDENT_VARIABLES.R\n")
cat(strrep("=", 60), "\n")

# =============================================================================
# 1) SAMPLE AND FILTERS
# =============================================================================

cat("\n1) Loading sample...\n")

for (f in c("amostra_mun.csv", "amostra_arr.csv")) {
  if (!file.exists(file.path(data_dir, f)))
    stop("Run 01_compose_sample.R first to generate: ", f)
}

cod_mun_mun   <- as.double(read_csv(file.path(data_dir, "amostra_mun.csv"),
                                    show_col_types = FALSE)$cod_mun)
cd_cidade_arr <- read_csv(file.path(data_dir, "amostra_arr.csv"),
                          show_col_types = FALSE) %>%
  pull(CD_CIDADE) %>% as.double() %>% unique()

cat(sprintf("  Municipal sample     : %d municipalities\n", length(cod_mun_mun)))
cat(sprintf("  Qualified arrangements: %d CD_CIDADEs\n", length(cd_cidade_arr)))

# =============================================================================
# 2) LOAD METRICS
# =============================================================================

cat("\n2) Loading metrics (stage 03, common 2010-2022 grid)...\n")

met_mun <- read_csv(
  file.path(metricas_dir, "metricas_municipio_2010_2022.csv"),
  show_col_types = FALSE
) %>% filter(cod_mun %in% cod_mun_mun)

met_arr <- read_csv(
  file.path(metricas_dir, "metricas_arranjo_2010_2022.csv"),
  show_col_types = FALSE
) %>% filter(CD_CIDADE %in% cd_cidade_arr)

cat(sprintf("  Municipalities: %d  |  Arrangements: %d\n", nrow(met_mun), nrow(met_arr)))

# =============================================================================
# 3) DEPENDENT VARIABLE (Y)
# =============================================================================

cat("\n3) Computing dependent variables (Y)...\n")

calc_y <- function(df) {
  df %>% mutate(
    pp_alta_2010  = 100 * pop_2010_risk_total / pop_2010_total,
    pp_alta_2022  = 100 * pop_2022_risk_total / pop_2022_total,
    delta_pp_alta = pp_alta_2022 - pp_alta_2010,

    # Population growth rate WITHIN the risk zones (growth / the zone's own initial population)
    g_alta = 100 * (pop_2022_risk_total - pop_2010_risk_total) / pmax(pop_2010_risk_total, 1)
  )
}

met_mun <- calc_y(met_mun)
met_arr <- calc_y(met_arr)

cat(sprintf("  Municipalities with valid Y: %d\n", sum(!is.na(met_mun$delta_pp_alta))))
cat(sprintf("  Arrangements   with valid Y: %d\n",  sum(!is.na(met_arr$delta_pp_alta))))

# =============================================================================
# 4) URBAN FORM VARIABLES (2010-2022)
# =============================================================================

cat("\n4) Computing urban form variables...\n")

vars_forma <- function(df) {
  df %>% mutate(
    # area_urban_2022_m2 already comes ready from
    # 07_aggregate_municipality_metrics.R (sum of the 6 types, single grid --
    # no need to recompute it here)
    area_urbana_2010_m2 = area_m2_consolidated + area_m2_densification + area_m2_peripheral,

    pct_area_densif     = 100 * area_m2_densification / pmax(area_urban_2022_m2, 1),
    pct_area_peripheral = 100 * area_m2_peripheral    / pmax(area_urban_2022_m2, 1),
    pct_area_extension  = 100 * area_m2_extension     / pmax(area_urban_2022_m2, 1),
    pct_area_leapfrog   = 100 * area_m2_leapfrog      / pmax(area_urban_2022_m2, 1),

    pct_crescimento_area = pct_urban_growth,

    # Population shares by type (previously came ready from
    # 06_metricas_municipio.R as pct_pop_densification/_2010;
    # 07_aggregate_municipality_metrics.R now only exposes the absolute
    # values pop_2022_<type>/pop_2010_<type> -- the share is computed here,
    # by the consumer)
    pct_pop_densif_2022 = 100 * pop_2022_densification / pmax(pop_2022_total, 1),
    pct_pop_densif_2010 = 100 * pop_2010_densification / pmax(pop_2010_total, 1),
    delta_pp_densif      = pct_pop_densif_2022 - pct_pop_densif_2010,

    pop_urbana_2010_cg  = pop_2010_total,
    pop_urbana_2022     = pop_2022_total
  )
}

# Density denominator on the mapped units (6f.2). Script 07 emits
# area_urbana_2010_m2_mapped for ARRANGEMENTS only, where the distinction
# exists. A municipality is a single unit that is either mapped or not, and the
# unmapped ones are excluded from the regression sample upstream, so at
# municipality level the mapped denominator IS area_urbana_2010_m2 -- the
# fallback below makes that explicit and keeps the column present in both
# files, so every downstream consumer can use it unconditionally.
add_mapped_area <- function(df) {
  if ("area_urbana_2010_m2_mapped" %in% names(df)) return(df)
  df %>% mutate(area_urbana_2010_m2_mapped = area_urbana_2010_m2)
}

met_mun <- vars_forma(met_mun) %>% add_mapped_area()
met_arr <- vars_forma(met_arr) %>% add_mapped_area()

# =============================================================================
# 5) GROWTH OUTSIDE THE RISK ZONES (2010-2022)
# =============================================================================

cat("\n5) Computing growth outside the risk zones...\n")

calc_g_fora <- function(df) {
  df %>% mutate(
    pop_fora_alta_2010 = pop_2010_total - pop_2010_risk_total,
    pop_fora_alta_2022 = pop_2022_total - pop_2022_risk_total,
    g_fora_alta         = 100 * (pop_fora_alta_2022 - pop_fora_alta_2010) /
                            pmax(pop_2010_total, 1)
  )
}

met_mun <- calc_g_fora(met_mun)
met_arr <- calc_g_fora(met_arr)

cat(sprintf("  Municipalities with valid g_fora_alta: %d\n", sum(!is.na(met_mun$g_fora_alta))))
cat(sprintf("  Arrangements   with valid g_fora_alta: %d\n",  sum(!is.na(met_arr$g_fora_alta))))

# =============================================================================
# 6) SAVE
# =============================================================================

cat("\n6) Saving...\n")

path_mun <- file.path(tables_dir, "met_municipio_com_y_BR.csv")
path_arr <- file.path(tables_dir, "met_arranjo_com_y_BR.csv")

write_csv(met_mun, path_mun)
cat(sprintf("  OK %s  (%d rows x %d columns)\n", basename(path_mun), nrow(met_mun), ncol(met_mun)))

write_csv(met_arr, path_arr)
cat(sprintf("  OK %s  (%d rows x %d columns)\n", basename(path_arr), nrow(met_arr), ncol(met_arr)))

cat("\n", strrep("=", 60), "\n")
cat("DONE\n")
cat(strrep("=", 60), "\n")
cat("\nDependent variables (Y):\n")
cat("  g_alta        : growth rate WITHIN the high susceptibility zone x 100\n")
cat("                  (numerator = pop growth; denominator = the zone's initial pop)\n")
cat("  delta_pp_alta : change in p.p. of the share in high susceptibility\n")
cat("  g_fora_alta   : pop growth OUTSIDE high susceptibility (complement)\n")
cat("\nUrban form variables (2010-2022):\n")
cat("  pct_area_densif / _peripheral / _extension / _leapfrog\n")
cat("  delta_pp_densif, pct_pop_densif_2010, pct_pop_densif_2022\n")
cat("  area_urbana_2010_m2, area_urban_2022_m2, pct_crescimento_area\n")
