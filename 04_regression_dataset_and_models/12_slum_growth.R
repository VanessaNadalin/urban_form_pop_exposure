# =============================================================================
# 12_slum_growth.R
# Computes population growth in slums (subnormal agglomerations -- AGSN)
# inside and outside high-susceptibility zones, between 2010 and 2022.
#
# High susceptibility only (rule 9): the medium-susceptibility branch this
# script used to also compute (from grade_{ano}_BR_com_suscept_medio_agsn.gpkg)
# was archived under MIGRATION_PLAN.md Task 1 and is not migrated here.
#
# Source: IBGE census grids (2010 and 2022) overlaid with high susceptibility
#   and AGSN. Files in data/processed_data/02_hazard_zones/:
#     grade_2010_BR_com_suscept_alta_agsn.gpkg
#     grade_2022_BR_com_suscept_alta_agsn.gpkg
#
# Per grid cell:
#   pop_agsn_com_alta = populacao x prop_agsn_com_suscept_alta
#   pop_agsn_total    = populacao x prop_agsn_alta  (total AGSN population in
#                       the cell, regardless of the susceptibility overlap)
#
# Final variables by municipality and arrangement:
#   pop_alta_slums_2010 / pop_total_slums_2010
#   pop_alta_slums_2022 / pop_total_slums_2022
#   g_slums_1022            : % growth, total AGSN population, 2010-2022
#   g_alta_slums_1022       : % growth, AGSN population within high susceptibility
#
# g_fora_alta_slums_1022 (growth outside high susceptibility) is NOT computed
# here: 16_estimate_models.R derives the equivalent g_fora_suscept_slums
# directly from g_slums_1022 - g_alta_slums_1022, so a precomputed version
# was a confirmed-dead column (MIGRATION_PLAN.md 6c0).
#
# Inputs:
#   data/processed_data/02_hazard_zones/grade_{year}_BR_com_suscept_alta_agsn.gpkg
#   data/processed_data/04_regression/amostra_universo.csv  (from 01_compose_sample.R)
#
# Outputs (data/processed_data/04_regression/tables/):
#   slums_municipio_BR.csv
#   slums_arranjo_BR.csv
# =============================================================================

source("04_regression_dataset_and_models/00_setup.R")
library(sf)

cat("\n", strrep("=", 60), "\n")
cat("12_SLUM_GROWTH.R\n")
cat(strrep("=", 60), "\n")

# =============================================================================
# 1) SAMPLE (cod_mun -> CD_CIDADE mapping)
# =============================================================================

cat("\n1) Loading sample...\n")

amostra <- read_csv(file.path(data_dir, "amostra_universo.csv"),
                    show_col_types = FALSE) %>%
  mutate(cod_mun   = as.double(cod_mun),
         CD_CIDADE = as.double(CD_CIDADE))
cat(sprintf("  %d municipalities in sample\n", nrow(amostra)))

# =============================================================================
# 2) READING FUNCTION
# =============================================================================

# Reads only the 4 flat columns actually needed, via an OGR SQL query, so
# GDAL never parses this national grid's polygon geometry (millions of
# 200m cells) just to have st_drop_geometry() discard it -- this is what
# made the script slow. sf::st_read() returns a plain data.frame (no sf
# class) whenever the query's column list omits the geometry column.
# cod_col : "cod_mun_suscept" (the high-susceptibility grid's municipality column)
read_agsn_grade <- function(path, cod_col) {
  col_com   <- "prop_agsn_com_suscept_alta"
  col_total <- "prop_agsn_alta"
  layer     <- sf::st_layers(path)$name[1]

  query <- sprintf(
    'SELECT "%s" AS cod_mun, "populacao" AS populacao, "%s" AS prop_com, "%s" AS prop_total FROM "%s"',
    cod_col, col_com, col_total, layer
  )

  sf::st_read(path, query = query, quiet = TRUE) %>%
    mutate(
      cod_mun    = as.double(cod_mun),
      populacao  = as.numeric(populacao),
      prop_com   = as.numeric(prop_com),
      prop_total = as.numeric(prop_total),
      pop_com    = populacao * coalesce(prop_com,   0),
      pop_tot    = populacao * coalesce(prop_total, 0)
    ) %>%
    group_by(cod_mun) %>%
    summarise(
      pop_alta_slums        = sum(pop_com, na.rm = TRUE),
      pop_total_agsn_alta_  = sum(pop_tot, na.rm = TRUE),
      .groups = "drop"
    )
}

# =============================================================================
# 3) LOAD GRIDS
# =============================================================================

path_alta_10 <- file.path(stage02_data_dir, "grade_2010_BR_com_suscept_alta_agsn.gpkg")
path_alta_22 <- file.path(stage02_data_dir, "grade_2022_BR_com_suscept_alta_agsn.gpkg")

missing <- c(path_alta_10, path_alta_22)[!file.exists(c(path_alta_10, path_alta_22))]
if (length(missing) > 0) {
  for (f in missing) cat(sprintf("  MISSING: %s\n", f))
  stop("AGSN gpkg files not found -- check data/processed_data/02_hazard_zones/")
}

cat("\n3) Reading AGSN census grids...\n")
cat("  2010 -- high susceptibility...\n")
alta_10 <- read_agsn_grade(path_alta_10, "cod_mun_suscept")
cat("  2022 -- high susceptibility...\n")
alta_22 <- read_agsn_grade(path_alta_22, "cod_mun_suscept")

# =============================================================================
# 4) BUILD TABLES BY YEAR
# =============================================================================

cat("\n4) Building slum population tables...\n")

slums_10 <- alta_10 %>%
  mutate(
    pop_alta_slums_2010      = coalesce(pop_alta_slums, 0),
    pop_total_slums_2010     = coalesce(pop_total_agsn_alta_, 0)
  ) %>%
  select(cod_mun, pop_alta_slums_2010, pop_total_slums_2010)

slums_22 <- alta_22 %>%
  mutate(
    pop_alta_slums_2022      = coalesce(pop_alta_slums, 0),
    pop_total_slums_2022     = coalesce(pop_total_agsn_alta_, 0)
  ) %>%
  select(cod_mun, pop_alta_slums_2022, pop_total_slums_2022)

# =============================================================================
# 5) COMPUTE GROWTH AND AGGREGATE
# =============================================================================

cat("\n5) Computing growth 2010-2022...\n")

# g_fora_alta_slums_1022 (and its pop_fora_alta_slums_* precursors) is not
# computed here: 16_estimate_models.R derives the equivalent
# g_fora_suscept_slums directly from g_slums_1022 - g_alta_slums_1022, so a
# precomputed version was never read by anything (confirmed dead column,
# MIGRATION_PLAN.md 6c0).
slums_mun <- full_join(slums_10, slums_22, by = "cod_mun") %>%
  mutate(
    g_slums_1022      = ifelse(pop_total_slums_2010 > 0,
      100 * (pop_total_slums_2022 - pop_total_slums_2010) / pop_total_slums_2010, NA_real_),
    g_alta_slums_1022 = ifelse(pop_alta_slums_2010 > 0,
      100 * (pop_alta_slums_2022  - pop_alta_slums_2010)  / pop_alta_slums_2010,  NA_real_)
  )

cat(sprintf("  %d municipalities with slum data\n", nrow(slums_mun)))
cat(sprintf("  Municipalities with g_slums_1022      : %d\n", sum(!is.na(slums_mun$g_slums_1022))))
cat(sprintf("  Municipalities with g_alta_slums      : %d\n", sum(!is.na(slums_mun$g_alta_slums_1022))))

# -- Aggregate to arrangement -------------------------------------------------
cat("\n  Aggregating to arrangements...\n")

slums_arr <- slums_mun %>%
  left_join(amostra %>% select(cod_mun, CD_CIDADE), by = "cod_mun") %>%
  mutate(CD_CIDADE = coalesce(as.double(CD_CIDADE), as.double(cod_mun))) %>%
  group_by(CD_CIDADE) %>%
  summarise(
    pop_alta_slums_2010  = sum(pop_alta_slums_2010,  na.rm = TRUE),
    pop_total_slums_2010 = sum(pop_total_slums_2010, na.rm = TRUE),
    pop_alta_slums_2022  = sum(pop_alta_slums_2022,  na.rm = TRUE),
    pop_total_slums_2022 = sum(pop_total_slums_2022, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(
    g_slums_1022      = ifelse(pop_total_slums_2010 > 0,
      100 * (pop_total_slums_2022 - pop_total_slums_2010) / pop_total_slums_2010, NA_real_),
    g_alta_slums_1022 = ifelse(pop_alta_slums_2010 > 0,
      100 * (pop_alta_slums_2022  - pop_alta_slums_2010)  / pop_alta_slums_2010,  NA_real_)
  )

cat(sprintf("  %d arrangements with slum data\n", nrow(slums_arr)))

# =============================================================================
# 6) SAVE
# =============================================================================

cat("\n6) Saving...\n")

path_mun <- file.path(tables_dir, "slums_municipio_BR.csv")
path_arr <- file.path(tables_dir, "slums_arranjo_BR.csv")

write_csv(slums_mun, path_mun)
cat(sprintf("  OK %s  (%d rows)\n", basename(path_mun), nrow(slums_mun)))

write_csv(slums_arr, path_arr)
cat(sprintf("  OK %s  (%d rows)\n", basename(path_arr), nrow(slums_arr)))

cat("\n", strrep("=", 60), "\n")
cat("DONE\n")
cat(strrep("=", 60), "\n")
cat("\nVariables generated:\n")
cat("  pop_alta_slums_2010 / 2022     : pop in AGSN n high susceptibility\n")
cat("  pop_total_slums_2010 / 2022    : total pop in AGSN (regardless of susceptibility)\n")
cat("  g_slums_1022                   : % growth, total AGSN pop, 2010-2022\n")
cat("  g_alta_slums_1022              : % growth, AGSN pop n high susceptibility\n")
