# =============================================================================
# 15_final_dataset.R
# Selects columns and applies the final filters to the regression datasets,
# producing the files ready for estimation.
#
# Inputs:
#   data/processed_data/04_regression/tables/dataset_completo_municipio.csv  (script 14)
#   data/processed_data/04_regression/tables/dataset_completo_arranjo.csv    (script 14)
#   data/processed_data/04_regression/mun_isol.csv                          (script 01)
#
# Outputs (data/processed_data/04_regression/tables/):
#   dataset_regressao_municipio.csv
#   dataset_regressao_arranjo.csv
#
# NOTE: ano_fundacao was removed from this version of the pipeline.
#       The availability filter applies only to delta_pp_alta (Y).
#
# 2026-08-28 (MIGRATION_PLAN.md 6b0/Migrate stage-04 cleanup): column
# selection trimmed to (a) drop every medium-susceptibility column -- their
# only producers (07_aggregate_municipality_metrics.R, 08_available_land.R,
# 10_topography.R, 12_slum_growth.R) no longer compute a medium branch at
# all (rule 9, high susceptibility only) -- and (b) drop 28 columns
# confirmed, by grepping every reference in 16_estimate_models.R and
# 05_exhibits/robustness/*.R, to be carried through the pipeline without
# ever being read by any model or robustness script (e.g. raw population/
# area/GDP totals whose only use was computing a share or log that IS kept;
# unquartiled or level variants of variables whose quartile/growth-rate
# form is what's actually used).
# =============================================================================

source("04_regression_dataset_and_models/00_setup.R")

cat("\n", strrep("=", 60), "\n")
cat("15_FINAL_DATASET.R\n")
cat(strrep("=", 60), "\n")

# =============================================================================
# 1) LOAD FULL DATASETS
# =============================================================================

cat("\n1) Loading full datasets...\n")

path_mun_in <- file.path(tables_dir, "dataset_completo_municipio.csv")
path_arr_in <- file.path(tables_dir, "dataset_completo_arranjo.csv")

if (!file.exists(path_mun_in) || !file.exists(path_arr_in))
  stop("Run 14_independent_variables.R first.")

met_mun <- read_csv(path_mun_in, show_col_types = FALSE)
met_arr <- read_csv(path_arr_in, show_col_types = FALSE)

cat(sprintf("  Municipalities: %d rows x %d columns\n", nrow(met_mun), ncol(met_mun)))
cat(sprintf("  Arrangements  : %d rows x %d columns\n", nrow(met_arr), ncol(met_arr)))

mun_isol_df <- read_csv(file.path(data_dir, "mun_isol.csv"),
                        show_col_types = FALSE) %>%
  mutate(cod_mun = as.double(cod_mun))

# =============================================================================
# 2) COLUMNS TO SELECT
# =============================================================================

# Dependent variables
cols_y <- c("pp_alta_2010", "pp_alta_2022", "delta_pp_alta", "g_alta",
            # Population counts (needed to diagnose g_alta)
            "pop_2010_risk_total", "pop_2022_risk_total")

# Urban form, 2010-2022
cols_x_forma <- c("area_urbana_2010_m2", "area_urbana_2010_m2_mapped",
                  "pct_area_densif", "pct_area_peripheral",
                  "pct_area_extension", "pct_area_leapfrog",
                  "pop_urbana_2010_cg", "pop_urbana_2022",
                  # growth outside the risk zones
                  "g_fora_alta",
                  # urban growth 2000-2010 (treatment)
                  "pct_urban_growth_0010",
                  "pct_area_densif_0010", "pct_area_peripheral_0010",
                  "pct_area_infill_0010",
                  "pct_area_extension_0010", "pct_area_leapfrog_0010",
                  "pct_area_densif_infill_0010",
                  "pct_area_periph_ext_leap_0010",
                  # 2000 urban density
                  "pop_2000", "area_2000_m2", "urban_density_2000")

# Safe available land
cols_x_terra <- c("pct_nao_constru_fora_alta_2010_q1",
                  "pct_nao_constru_fora_alta_2010_q4")

# Topography
cols_x_topo <- c("topo_prop_inclinado", "topo_prop_restrita",
                 "topo_prop_inclinado_em_alta")

# Distance to seat
cols_x_dist <- c("dist_sede_q1_m", "dist_densif_m",
                 "dist_media_m_densif_0010", "dist_media_m_densif_infill_0010")

# Housing and mobility inequality
cols_x_desig <- c("median_rent", "palma_rent", "palma_commute")

# Controls and auxiliary variables
cols_x_ctrl <- c("regiao", "pib_pc_2010", "hierarquia_grupo", "urban_class",
                 "pop_total_2010", "zero_area_2000",
                 "prop_favelas_2010",
                 "g_slums_1022", "g_alta_slums_1022")

# =============================================================================
# 3) SELECT COLUMNS (silently drops any that don't exist)
# =============================================================================

cat("\n2) Selecting columns...\n")

sel <- function(df, id_cols, ...) {
  all_cols <- c(id_cols, ...)
  df %>% select(all_of(intersect(all_cols, names(df))))
}

ds_mun <- sel(met_mun,
              c("cod_mun", "NM_CIDADE"),
              cols_y, cols_x_forma, cols_x_terra, cols_x_topo,
              cols_x_dist, cols_x_desig, cols_x_ctrl)

# Arrangement dataset = qualified arrangements + isolated municipalities (1-member arrangement)
isol_as_arr <- met_mun %>%
  filter(cod_mun %in% mun_isol_df$cod_mun) %>%
  mutate(CD_CIDADE = cod_mun) %>%
  { if (!"NM_CIDADE" %in% names(.))
      left_join(., mun_isol_df %>% select(cod_mun, NM_CIDADE), by = "cod_mun")
    else . }

ds_arr <- bind_rows(
  sel(met_arr,    c("CD_CIDADE", "NM_CIDADE"),
      cols_y, cols_x_forma, cols_x_terra, cols_x_topo,
      cols_x_dist, cols_x_desig, cols_x_ctrl),
  sel(isol_as_arr, c("CD_CIDADE", "NM_CIDADE"),
      cols_y, cols_x_forma, cols_x_terra, cols_x_topo,
      cols_x_dist, cols_x_desig, cols_x_ctrl)
)

cat(sprintf("  Municipalities before filter: %d\n", nrow(ds_mun)))
cat(sprintf("  Arrangements before filter  : %d\n", nrow(ds_arr)))

# =============================================================================
# 4) FINAL FILTER
# =============================================================================
# Keeps only observations with a valid Y (delta_pp_alta).
# ano_fundacao removed from this version of the pipeline.

cat("\n3) Applying final filters...\n")

ds_mun_valido <- ds_mun %>% filter(!is.na(delta_pp_alta))
ds_arr_valido <- ds_arr %>% filter(!is.na(delta_pp_alta))

cat(sprintf("  Municipality dataset: %d rows x %d columns\n",
            nrow(ds_mun_valido), ncol(ds_mun_valido)))
cat(sprintf("  Arrangement dataset : %d rows x %d columns\n",
            nrow(ds_arr_valido), ncol(ds_arr_valido)))

# =============================================================================
# 5) DIAGNOSTICS
# =============================================================================

cat("\n  Variable coverage (% non-NA) -- municipalities (incomplete variables):\n")
ds_mun_valido %>%
  summarise(across(everything(), ~ round(100 * mean(!is.na(.)), 1))) %>%
  pivot_longer(everything(), names_to = "variavel", values_to = "pct_nao_na") %>%
  filter(pct_nao_na < 100) %>%
  arrange(pct_nao_na) %>%
  { for (i in seq_len(nrow(.)))
      cat(sprintf("    %-45s: %.1f%%\n", .$variavel[i], .$pct_nao_na[i])) }

# =============================================================================
# 6) SAVE
# =============================================================================

cat("\n4) Saving...\n")

path_mun_out <- file.path(tables_dir, "dataset_regressao_municipio.csv")
path_arr_out <- file.path(tables_dir, "dataset_regressao_arranjo.csv")

write_csv(ds_mun_valido, path_mun_out)
cat(sprintf("  OK %s\n", basename(path_mun_out)))

write_csv(ds_arr_valido, path_arr_out)
cat(sprintf("  OK %s\n", basename(path_arr_out)))

cat("\n", strrep("=", 60), "\n")
cat("DONE\n")
cat(strrep("=", 60), "\n")
cat("\nNext step: 16_estimate_models.R\n")
