# =============================================================================
# 08_available_land.R
# Regression variable: area NOT built up outside high-susceptibility zones,
# by income quartile and growth type.
#
# High susceptibility only (rule 9): the medium-susceptibility branch this
# script used to compute alongside it was archived under MIGRATION_PLAN.md
# Task 1 and is not migrated here.
#
# Per grid cell (200m x 200m = 40,000 m2):
#   area_fora_suscept_alta          = 40,000 x (1 - prop_suscept_alta)
#   area_nao_constru_fora_alta_2010 = pmax(0, area_fora_alta - ghsl_fora_alta_2010)
#   area_nao_constru_fora_alta_2020 = pmax(0, area_fora_alta - ghsl_fora_alta_2020)
#
# Inputs:
#   data/processed_data/04_regression/ghsl_susceptibility/
#     grade_com_quartis_BR.parquet      (script 07)
#     grade_com_quartis_BR.gpkg         (script 07, for .gpkg export)
#   data/processed_data/02_hazard_zones/
#     grade_2010_BR_com_suscept_alta_agsn.gpkg   -> prop_suscept_alta
#   data/processed_data/03_urban_footprint/crescimento_urbano/
#     grade_growth_types_2010_2022.parquet  -> tipo_crescimento
#     (MIGRATION_PLAN.md 6b0 common-grid rework, 2026-08-28: replaces the
#     retired grade_crescimento_2010_2020_g2010.parquet -- ID_UNICO and
#     tipo_crescimento are the only columns this script reads from it, both
#     unchanged in name/meaning by the rework)
#
# Outputs:
#   data/processed_data/04_regression/ghsl_susceptibility/
#     grade_safe_poor_BR.parquet         (cell-level, all variables)
#     grade_safe_poor_BR.gpkg            (same, with geometry, for QGIS)
#   data/processed_data/04_regression/tables/
#     pct_nao_constru_municipio_BR.csv   (% urban footprint by municipality)
#     pct_nao_constru_arranjo_BR.csv     (% urban footprint by arrangement, key CD_CIDADE)
#     agregado_renda_crescimento_BR.csv  (arrangement x quartil_renda x tipo_crescimento)
# =============================================================================

source("04_regression_dataset_and_models/00_setup.R")

cat("\n", strrep("=", 60), "\n")
cat("08_AVAILABLE_LAND.R\n")
cat(strrep("=", 60), "\n")

UF_FILTER   <- NULL
suffix      <- paste0("_BR", UF_FILTER)
AREA_CELULA <- 40000L   # m2 (200m x 200m)

suscept_alta_gpkg <- file.path(stage02_data_dir, "grade_2010_BR_com_suscept_alta_agsn.gpkg")
cresc_parquet     <- file.path(growth_types_dir, "grade_growth_types_2010_2022.parquet")
grade_q_parquet   <- file.path(ghsl_susc_dir, paste0("grade_com_quartis", suffix, ".parquet"))

for (f in c(grade_q_parquet, suscept_alta_gpkg, cresc_parquet))
  if (!file.exists(f)) stop("File not found: ", f)

# =============================================================================
# 1) GRID WITH QUARTILES (script 07)
# =============================================================================

cat("\n1) Loading grid with quartiles (script 07) ...\n")

grade <- arrow::read_parquet(grade_q_parquet)
cat(sprintf("  %s cells\n", fmt(nrow(grade))))

required_cols <- c("id_celula", "ID_UNICO",
                    "ghsl_fora_alta_2010", "ghsl_fora_alta_2020")
missing <- setdiff(required_cols, names(grade))
if (length(missing) > 0)
  stop("Missing columns in grade_com_quartis:\n  ", paste(missing, collapse = ", "),
       "\nRe-run script 07 to regenerate the parquet with these columns.")

cat(sprintf("  Arrangements present: %d\n", n_distinct(grade$CD_CIDADE)))

# =============================================================================
# 2) SUSCEPTIBILITY PROPORTIONS
# =============================================================================

cat("\n2) Loading susceptibility proportions ...\n")

suscept_alta <- sf::st_read(suscept_alta_gpkg, quiet = TRUE) |>
  sf::st_drop_geometry() |>
  select(ID_UNICO, prop_suscept_alta = prop_suscept) |>
  mutate(ID_UNICO = as.character(ID_UNICO))

cat(sprintf("  High susceptibility: %s cells\n", fmt(nrow(suscept_alta))))

# =============================================================================
# 3) URBAN GROWTH TYPE
# =============================================================================

cat("\n3) Loading urban growth type ...\n")

cresc <- arrow::read_parquet(cresc_parquet) |>
  select(ID_UNICO, tipo_crescimento) |>
  mutate(ID_UNICO = as.character(ID_UNICO))

cat(sprintf("  %s cells | Types: %s\n",
            fmt(nrow(cresc)), paste(sort(unique(cresc$tipo_crescimento)), collapse = ", ")))

# =============================================================================
# 4) JOIN BY ID_UNICO
# =============================================================================

cat("\n4) Joining by ID_UNICO ...\n")

grade <- grade |> mutate(ID_UNICO = as.character(ID_UNICO))

dados <- grade |>
  left_join(suscept_alta, by = "ID_UNICO") |>
  left_join(cresc,        by = "ID_UNICO")

# prop_suscept NA -> cell outside the mapping -> 0
dados <- dados |>
  mutate(prop_suscept_alta = coalesce(prop_suscept_alta, 0))

cat(sprintf("  Cells with no tipo_crescimento: %s (%.1f%%)\n",
            fmt(sum(is.na(dados$tipo_crescimento))),
            100 * mean(is.na(dados$tipo_crescimento))))

# =============================================================================
# 5) AREA NOT BUILT UP OUTSIDE SUSCEPTIBILITY
# =============================================================================

cat("\n5) Computing area not built up outside susceptibility ...\n")

dados <- dados |>
  mutate(
    area_fora_suscept_alta          = AREA_CELULA * (1 - prop_suscept_alta),
    area_nao_constru_fora_alta_2010 = pmax(0, area_fora_suscept_alta - ghsl_fora_alta_2010),
    area_nao_constru_fora_alta_2020 = pmax(0, area_fora_suscept_alta - ghsl_fora_alta_2020)
  )

# =============================================================================
# 6) SAVE GRID (urban footprint: tipo_crescimento != NA)
# =============================================================================

cat("\n6) Saving grade_safe_poor (urban footprint) ...\n")

COLS_SAFE_POOR <- c(
  "id_celula", "ID_UNICO", "cod_mun", "CD_CIDADE", "NM_CIDADE",
  "quartil_renda", "tipo_crescimento",
  "prop_suscept_alta", "area_fora_suscept_alta",
  "ghsl_total_2010", "ghsl_total_2020",
  "ghsl_fora_alta_2010", "ghsl_fora_alta_2020",
  "area_nao_constru_fora_alta_2010", "area_nao_constru_fora_alta_2020"
)

dados_urban <- dados |>
  filter(!is.na(tipo_crescimento)) |>
  select(all_of(COLS_SAFE_POOR)) |>
  mutate(
    area_nao_constru_fora_alta_poor_2010 = if_else(quartil_renda == 1L, area_nao_constru_fora_alta_2010, NA_real_),
    area_nao_constru_fora_alta_poor_2020 = if_else(quartil_renda == 1L, area_nao_constru_fora_alta_2020, NA_real_)
  )

cat(sprintf("  Cells in the urban footprint: %s of %s (%.1f%%)\n",
            fmt(nrow(dados_urban)), fmt(nrow(dados)),
            100 * nrow(dados_urban) / nrow(dados)))

safe_poor_path <- file.path(ghsl_susc_dir, paste0("grade_safe_poor", suffix, ".parquet"))
arrow::write_parquet(dados_urban, safe_poor_path)
cat(sprintf("  OK %s\n", basename(safe_poor_path)))

# Optional GeoPackage (for QGIS)
gpkg_grade_q <- file.path(ghsl_susc_dir, paste0("grade_com_quartis", suffix, ".gpkg"))
if (file.exists(gpkg_grade_q)) {
  cat("  Exporting .gpkg for QGIS ...\n")
  geom_grade <- sf::st_read(gpkg_grade_q, quiet = TRUE) |> select(id_celula)
  grade_safe_poor_sf <- geom_grade |>
    inner_join(sf::st_drop_geometry(dados_urban), by = "id_celula")
  gpkg_path <- file.path(ghsl_susc_dir, paste0("grade_safe_poor", suffix, ".gpkg"))
  sf::st_write(grade_safe_poor_sf, gpkg_path, delete_dsn = TRUE, quiet = TRUE)
  cat(sprintf("  OK %s  (%s cells)\n", basename(gpkg_path), fmt(nrow(grade_safe_poor_sf))))
}

# =============================================================================
# 7) AGGREGATE BY ARRANGEMENT x QUARTIL_RENDA x TIPO_CRESCIMENTO
# =============================================================================

cat("\n7) Aggregating by arrangement x quartil_renda x tipo_crescimento ...\n")

aggregate <- function(df, quartile_col) {
  df |>
    filter(!is.na(.data[[quartile_col]]), !is.na(tipo_crescimento)) |>
    group_by(CD_CIDADE, NM_CIDADE,
             quartil = .data[[quartile_col]], tipo_crescimento) |>
    summarise(
      n_celulas                          = n(),
      area_fora_suscept_alta_m2          = sum(area_fora_suscept_alta,          na.rm = TRUE),
      ghsl_total_2010_m2                 = sum(ghsl_total_2010,                 na.rm = TRUE),
      ghsl_total_2020_m2                 = sum(ghsl_total_2020,                 na.rm = TRUE),
      ghsl_fora_alta_2010_m2             = sum(ghsl_fora_alta_2010,             na.rm = TRUE),
      ghsl_fora_alta_2020_m2             = sum(ghsl_fora_alta_2020,             na.rm = TRUE),
      area_nao_constru_fora_alta_2010_m2 = sum(area_nao_constru_fora_alta_2010, na.rm = TRUE),
      area_nao_constru_fora_alta_2020_m2 = sum(area_nao_constru_fora_alta_2020, na.rm = TRUE),
      .groups = "drop"
    ) |>
    arrange(CD_CIDADE, quartil, tipo_crescimento)
}

res_renda <- aggregate(dados_urban, "quartil_renda")
cat(sprintf("  %d rows\n", nrow(res_renda)))

csv_ren <- file.path(tables_dir, paste0("agregado_renda_crescimento", suffix, ".csv"))
write_csv(res_renda, csv_ren)
cat(sprintf("  OK %s\n", basename(csv_ren)))

# =============================================================================
# 8) % OF THE URBAN FOOTPRINT -- BY MUNICIPALITY AND BY ARRANGEMENT
# =============================================================================
#
# pct_nao_constru_fora_* = area NOT built up outside susceptibility /
#                          total urban footprint area x 100
# Computed for: total footprint, Q1+Q2, Q1, Q4

cat("\n8) Computing % of the urban footprint by municipality and by arrangement ...\n")

calc_pct <- function(df, groups) {
  df |>
    group_by(across(all_of(groups))) |>
    summarise(
      n_celulas                      = n(),
      area_footprint_m2              = n() * AREA_CELULA,
      pct_nao_constru_fora_alta_2010 = 100 * sum(area_nao_constru_fora_alta_2010, na.rm = TRUE) / (n() * AREA_CELULA),
      pct_nao_constru_fora_alta_2020 = 100 * sum(area_nao_constru_fora_alta_2020, na.rm = TRUE) / (n() * AREA_CELULA),
      .groups = "drop"
    )
}

suffix_subset <- function(df, join_key, sufx) {
  cols_rename <- setdiff(names(df), join_key)
  df |>
    rename_with(~ paste0(., sufx), all_of(cols_rename)) |>
    select(all_of(join_key), all_of(paste0(cols_rename, sufx)))
}

dados_q12 <- dados_urban |> filter(quartil_renda %in% c(1L, 2L))
dados_q1  <- dados_urban |> filter(quartil_renda == 1L)
dados_q4  <- dados_urban |> filter(quartil_renda == 4L)

# By municipality
GRUPOS_MUN <- c("cod_mun", "CD_CIDADE", "NM_CIDADE")

pct_municipio <- calc_pct(dados_urban, GRUPOS_MUN) |>
  left_join(suffix_subset(calc_pct(dados_q12, GRUPOS_MUN), GRUPOS_MUN, "_q12"), by = GRUPOS_MUN) |>
  left_join(suffix_subset(calc_pct(dados_q1,  GRUPOS_MUN), GRUPOS_MUN, "_q1"),  by = GRUPOS_MUN) |>
  left_join(suffix_subset(calc_pct(dados_q4,  GRUPOS_MUN), GRUPOS_MUN, "_q4"),  by = GRUPOS_MUN) |>
  mutate(
    dif_pct_q1_total_alta_2010 = pct_nao_constru_fora_alta_2010_q1 - pct_nao_constru_fora_alta_2010,
    dif_pct_q1_total_alta_2020 = pct_nao_constru_fora_alta_2020_q1 - pct_nao_constru_fora_alta_2020,
    dif_pct_q4_total_alta_2010 = pct_nao_constru_fora_alta_2010_q4 - pct_nao_constru_fora_alta_2010,
    dif_pct_q4_total_alta_2020 = pct_nao_constru_fora_alta_2020_q4 - pct_nao_constru_fora_alta_2020
  )

cat(sprintf("  %d municipalities\n", nrow(pct_municipio)))

# By arrangement -- unique key: CD_CIDADE
GRUPOS_ARR <- c("CD_CIDADE", "NM_CIDADE")

pct_arranjo <- calc_pct(dados_urban, GRUPOS_ARR) |>
  left_join(suffix_subset(calc_pct(dados_q12, GRUPOS_ARR), GRUPOS_ARR, "_q12"), by = GRUPOS_ARR) |>
  left_join(suffix_subset(calc_pct(dados_q1,  GRUPOS_ARR), GRUPOS_ARR, "_q1"),  by = GRUPOS_ARR) |>
  left_join(suffix_subset(calc_pct(dados_q4,  GRUPOS_ARR), GRUPOS_ARR, "_q4"),  by = GRUPOS_ARR) |>
  mutate(
    dif_pct_q1_total_alta_2010 = pct_nao_constru_fora_alta_2010_q1 - pct_nao_constru_fora_alta_2010,
    dif_pct_q1_total_alta_2020 = pct_nao_constru_fora_alta_2020_q1 - pct_nao_constru_fora_alta_2020,
    dif_pct_q4_total_alta_2010 = pct_nao_constru_fora_alta_2010_q4 - pct_nao_constru_fora_alta_2010,
    dif_pct_q4_total_alta_2020 = pct_nao_constru_fora_alta_2020_q4 - pct_nao_constru_fora_alta_2020
  )

cat(sprintf("  %d arrangements\n", nrow(pct_arranjo)))

# =============================================================================
# 9) SAVE TABLES
# =============================================================================

cat("\n9) Saving tables ...\n")

csv_pct_mun <- file.path(tables_dir, paste0("pct_nao_constru_municipio", suffix, ".csv"))
csv_pct_arr <- file.path(tables_dir, paste0("pct_nao_constru_arranjo",   suffix, ".csv"))

write_csv(pct_municipio, csv_pct_mun)
write_csv(pct_arranjo,   csv_pct_arr)

cat(sprintf("  OK %s  (%d rows)\n", basename(csv_pct_mun), nrow(pct_municipio)))
cat(sprintf("  OK %s  (%d rows) -- key: CD_CIDADE\n", basename(csv_pct_arr), nrow(pct_arranjo)))

cat(sprintf("\n%s\nDONE\n%s\n", strrep("=", 60), strrep("=", 60)))
cat("Outputs:\n")
cat(sprintf("  %s\n", safe_poor_path))
cat(sprintf("  %s\n", csv_ren))
cat(sprintf("  %s\n", csv_pct_mun))
cat(sprintf("  %s\n", csv_pct_arr))
cat("Next step: script 09_distance_to_seat.R\n")
