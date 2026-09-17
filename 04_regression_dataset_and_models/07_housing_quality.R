# =============================================================================
# 07_housing_quality.R
# Regression independent variables (2010 Census):
#
#   (a) Housing quality proxy:
#       prop_3mais_banheiros = sum(V027:V033) / V002
#       (share of households with 3+ bathrooms for exclusive use)
#
#   (b) Household income per capita:
#       renda_percapita = V009 / V002  (Basico 2010)
#
# Both classified into quartiles within each arrangement (CD_CIDADE):
#   Q1 = lowest share/income   |   Q4 = highest
#
# Joins with the GHSL x susceptibility grid (script 06) to compute
# built-up area outside high-susceptibility zones, by arrangement x quartile.
#
# Inputs:
#   data/processed_data/04_regression/amostra_universo.csv       (script 01)
#   data/processed_data/04_regression/basico_ibge_2010.parquet   (script 02)
#   data/processed_data/04_regression/ghsl_susceptibility/
#     grade_2022_com_ghsl_suscept_BR.gpkg                        (script 06)
#   data/raw_data/04_regression/setores_censitarios_2010_brasil.rds  (script 04)
#   data/raw_data/04_regression/censo_domicilio_setores_2010.rds     (script 04)
#
# Outputs (data/processed_data/04_regression/housing_quality/):
#   setores_qualidade_BR.gpkg
#   setores_qualidade_BR.parquet
#   resumo_quartis_BR.csv
# Outputs (data/processed_data/04_regression/tables/):
#   builtup_nao_suscept_banheiro_BR.csv
#   builtup_nao_suscept_renda_BR.csv
# =============================================================================

source("04_regression_dataset_and_models/00_setup.R")

cat("\n", strrep("=", 60), "\n")
cat("07_HOUSING_QUALITY.R\n")
cat(strrep("=", 60), "\n")

UF_FILTER <- NULL
suffix    <- if (!is.null(UF_FILTER)) paste0("_UF", UF_FILTER) else "_BR"

# =============================================================================
# 1) SAMPLE
# =============================================================================

cat("\n1) Loading municipality sample ...\n")

univ_path <- file.path(data_dir, "amostra_universo.csv")
if (!file.exists(univ_path))
  stop("Run 01_compose_sample.R first: amostra_universo.csv not found")

amostra <- read_csv(univ_path, show_col_types = FALSE) %>%
  mutate(cod_mun = as.character(cod_mun))

if (!is.null(UF_FILTER))
  amostra <- amostra |> filter(substr(cod_mun, 1, 2) == UF_FILTER)

target_cod_mun <- amostra$cod_mun
cat(sprintf("  %d municipalities in sample\n", length(target_cod_mun)))

# =============================================================================
# 2) CENSUS TRACT GEOMETRY -- geobr 2010
# =============================================================================

cat("\n2) Loading 2010 census tract geometries ...\n")

tract_geom_path <- file.path(raw_data_dir, "setores_censitarios_2010_brasil.rds")
if (!file.exists(tract_geom_path))
  stop("Run 04_download_geobr_censobr.R first: ", tract_geom_path, " not found")

tract_geom <- readRDS(tract_geom_path)
if (!is.null(UF_FILTER))
  tract_geom <- tract_geom |> filter(substr(as.character(code_tract), 1, 2) == UF_FILTER)

tract_geom <- tract_geom |>
  rename_with(tolower) |>
  mutate(
    code_tract = as.character(code_tract),
    cod_mun    = substr(code_tract, 1, 7)
  )

cat(sprintf("  %s tracts downloaded\n", fmt(nrow(tract_geom))))

# =============================================================================
# 3) HOUSEHOLD DATA -- censobr "Domicilio" 2010
# =============================================================================
# V027:V033 = households with 1..7+ exclusive-use bathrooms
# Values <= 3 units are censored by IBGE (NA) -> treated as 0

cat("\n3) Loading 2010 household data ...\n")

dom_path <- file.path(raw_data_dir, "censo_domicilio_setores_2010.rds")
if (!file.exists(dom_path))
  stop("Run 04_download_geobr_censobr.R first: ", dom_path, " not found")
dom <- readRDS(dom_path)

if (!is.null(UF_FILTER))
  dom <- dom |> filter(substr(as.character(code_tract), 1, 2) == UF_FILTER)
dom$code_tract <- as.character(dom$code_tract)

cat(sprintf("  %s tracts loaded\n", fmt(nrow(dom))))

COL_TOTAL_DOM <- "domicilio01_V002"
COLS_3PLUS    <- paste0("domicilio01_V0", 27:33)

missing_dom <- setdiff(c(COL_TOTAL_DOM, COLS_3PLUS), names(dom))
if (length(missing_dom) > 0)
  stop("Missing columns in dom: ", paste(missing_dom, collapse = ", "))

dom <- dom |>
  mutate(
    total_dom = as.numeric(.data[[COL_TOTAL_DOM]]),
    dom_3mais = rowSums(across(all_of(COLS_3PLUS), ~ coalesce(as.numeric(.), 0))),
    prop_3mais_banheiros = if_else(
      !is.na(total_dom) & total_dom > 0,
      dom_3mais / total_dom, NA_real_
    )
  )

cat(sprintf("  prop_3mais_banheiros -- valid tracts: %s / %s\n",
            fmt(sum(!is.na(dom$prop_3mais_banheiros))), fmt(nrow(dom))))

# =============================================================================
# 4) INCOME DATA -- basico_ibge_2010.parquet (script 02)
# =============================================================================

cat("\n4) Loading 2010 income data (basico_ibge_2010.parquet) ...\n")

basico_par <- file.path(data_dir, "basico_ibge_2010.parquet")
if (!file.exists(basico_par))
  stop("Run 02_download_census_basic.R first: basico_ibge_2010.parquet not found")

bas <- arrow::read_parquet(basico_par)

if (!is.null(UF_FILTER))
  bas <- bas |> filter(substr(as.character(code_tract), 1, 2) == UF_FILTER)
bas$code_tract <- as.character(bas$code_tract)
bas <- bas |> rename(moradores = V002)

cat(sprintf("  %s tracts loaded\n", fmt(nrow(bas))))
cat(sprintf("  renda_percapita -- valid tracts: %s / %s\n",
            fmt(sum(!is.na(bas$renda_percapita))), fmt(nrow(bas))))

# =============================================================================
# 5) JOIN GEOMETRY + DATA + ARRANGEMENT
# =============================================================================

cat("\n5) Joining geometries with tabular data ...\n")

setores <- tract_geom |>
  left_join(dom |> select(code_tract, total_dom, dom_3mais, prop_3mais_banheiros),
            by = "code_tract") |>
  left_join(bas |> select(code_tract, moradores, renda_percapita),
            by = "code_tract") |>
  filter(cod_mun %in% target_cod_mun) |>
  left_join(amostra |> select(cod_mun, CD_CIDADE, NM_CIDADE, em_arranjo),
            by = "cod_mun")

cat(sprintf("  %s tracts in the sample's municipalities\n", fmt(nrow(setores))))
cat(sprintf("  missing prop_3mais_banheiros: %s\n", fmt(sum(is.na(setores$prop_3mais_banheiros)))))
cat(sprintf("  missing renda_percapita:      %s\n", fmt(sum(is.na(setores$renda_percapita)))))

# =============================================================================
# 6) QUARTILES BY ARRANGEMENT
# =============================================================================

cat("\n6) Classifying tracts into quartiles by arrangement (CD_CIDADE) ...\n")

setores <- setores |>
  group_by(CD_CIDADE) |>
  mutate(
    quartil_banheiro = if_else(!is.na(prop_3mais_banheiros),
                               ntile(prop_3mais_banheiros, 4L), NA_integer_),
    quartil_renda    = if_else(!is.na(renda_percapita),
                               ntile(renda_percapita, 4L),    NA_integer_)
  ) |>
  ungroup()

cat(sprintf("  Tracts with quartil_banheiro: %s | quartil_renda: %s\n",
            fmt(sum(!is.na(setores$quartil_banheiro))),
            fmt(sum(!is.na(setores$quartil_renda)))))

# =============================================================================
# 7) SAVE TRACTS
# =============================================================================

cat("\n7) Saving tracts with quartiles ...\n")

gpkg_path <- file.path(housing_dir, paste0("setores_qualidade", suffix, ".gpkg"))
sf::st_write(setores, gpkg_path, delete_dsn = TRUE, quiet = TRUE)
cat(sprintf("  OK %s  (%s tracts)\n", basename(gpkg_path), fmt(nrow(setores))))

parquet_path <- file.path(housing_dir, paste0("setores_qualidade", suffix, ".parquet"))
setores |>
  sf::st_drop_geometry() |>
  select(code_tract, cod_mun, CD_CIDADE, NM_CIDADE, em_arranjo,
         total_dom, dom_3mais, prop_3mais_banheiros,
         moradores, renda_percapita, quartil_banheiro, quartil_renda) |>
  arrow::write_parquet(parquet_path)
cat(sprintf("  OK %s\n", basename(parquet_path)))

resumo <- setores |>
  sf::st_drop_geometry() |>
  filter(!is.na(quartil_banheiro)) |>
  group_by(CD_CIDADE, NM_CIDADE, quartil_banheiro) |>
  summarise(
    n_setores      = n(),
    prop_ban_media = mean(prop_3mais_banheiros, na.rm = TRUE),
    prop_ban_min   = min(prop_3mais_banheiros,  na.rm = TRUE),
    prop_ban_max   = max(prop_3mais_banheiros,  na.rm = TRUE),
    renda_media    = mean(renda_percapita,       na.rm = TRUE),
    total_dom_soma = sum(total_dom,              na.rm = TRUE),
    .groups = "drop"
  )
write_csv(resumo, file.path(housing_dir, paste0("resumo_quartis", suffix, ".csv")))
cat(sprintf("  OK resumo_quartis%s.csv  (%d rows)\n", suffix, nrow(resumo)))

# =============================================================================
# 8) GHSL x SUSCEPTIBILITY GRID (script 06)
# =============================================================================

cat("\n8) Loading GHSL x susceptibility grid (script 06) ...\n")

gpkg_grade <- file.path(ghsl_susc_dir,
  paste0("grade_2022_com_ghsl_suscept",
         if (!is.null(UF_FILTER)) paste0("_UF", UF_FILTER) else "", ".gpkg"))

if (!file.exists(gpkg_grade))
  stop("Run python 04_regression_dataset_and_models/06_builtup_in_susceptibility.py first: ",
       basename(gpkg_grade), " not found")

grade <- sf::st_read(gpkg_grade, quiet = TRUE)
cat(sprintf("  %s cells loaded\n", fmt(nrow(grade))))

# High susceptibility only (rule 9): script 06 no longer computes a medium
# branch, so ghsl_suscept_medio_* is not expected here.
cols_ghsl <- c("ghsl_total_2010", "ghsl_total_2020",
               "ghsl_suscept_alta_2010", "ghsl_suscept_alta_2020")
missing_ghsl <- setdiff(cols_ghsl, names(grade))
if (length(missing_ghsl) > 0)
  stop("Missing GHSL columns in the grid: ", paste(missing_ghsl, collapse = ", "))

# =============================================================================
# 9) BUILT-UP OUTSIDE SUSCEPTIBILITY
# =============================================================================

cat("\n9) Computing ghsl_fora_alta (high susceptibility only) ...\n")

grade <- grade |>
  mutate(
    ghsl_fora_alta_2010 = pmax(0, ghsl_total_2010 - ghsl_suscept_alta_2010),
    ghsl_fora_alta_2020 = pmax(0, ghsl_total_2020 - ghsl_suscept_alta_2020)
  )

cat(sprintf("  Cells with fora_alta_2010 > 0: %s\n", fmt(sum(grade$ghsl_fora_alta_2010 > 0, na.rm = TRUE))))

# =============================================================================
# 10) SPATIAL JOIN: cell centroid -> tract
# =============================================================================

cat("\n10) Spatial join: cell centroid -> census tract ...\n")
t0 <- Sys.time()

setores_join <- setores |>
  filter(!is.na(quartil_banheiro) | !is.na(quartil_renda)) |>
  select(code_tract, cod_mun, CD_CIDADE, NM_CIDADE, quartil_banheiro, quartil_renda)

if (sf::st_crs(grade) != sf::st_crs(setores_join))
  setores_join <- sf::st_transform(setores_join, sf::st_crs(grade))

centroids <- sf::st_centroid(grade |> select(id_celula, any_of("ID_UNICO")))

cells_sector <- sf::st_join(centroids, setores_join, join = sf::st_within, left = FALSE)
cat(sprintf("  %s cells assigned a tract (%.1f min)\n",
            fmt(nrow(cells_sector)),
            as.numeric(difftime(Sys.time(), t0, units = "mins"))))

n_no_sector <- nrow(grade) - nrow(cells_sector)
if (n_no_sector > 0)
  cat(sprintf("  Warning: %s cells with no tract (outside any arrangement, or tract without a quartile)\n",
              fmt(n_no_sector)))

# =============================================================================
# 11) JOIN GHSL VALUES WITH QUARTILES
# =============================================================================

cat("\n11) Joining GHSL values with quartiles ...\n")

grade_tab <- grade |>
  sf::st_drop_geometry() |>
  select(id_celula, any_of("ID_UNICO"),
         ghsl_total_2010, ghsl_total_2020,
         ghsl_fora_alta_2010, ghsl_fora_alta_2020)

cells_final <- cells_sector |>
  sf::st_drop_geometry() |>
  left_join(grade_tab, by = "id_celula")

# =============================================================================
# 12) SAVE GRID WITH QUARTILES
# =============================================================================

cat("\n12) Saving grid with quartiles per cell ...\n")

grade_com_quartis <- grade |>
  select(id_celula, any_of("ID_UNICO")) |>
  inner_join(cells_final, by = "id_celula")

gpkg_grade_q <- file.path(ghsl_susc_dir, paste0("grade_com_quartis", suffix, ".gpkg"))
sf::st_write(grade_com_quartis, gpkg_grade_q, delete_dsn = TRUE, quiet = TRUE)
cat(sprintf("  OK %s  (%s cells)\n", basename(gpkg_grade_q), fmt(nrow(grade_com_quartis))))

parquet_grade_q <- file.path(ghsl_susc_dir, paste0("grade_com_quartis", suffix, ".parquet"))
grade_com_quartis |>
  sf::st_drop_geometry() |>
  arrow::write_parquet(parquet_grade_q)
cat(sprintf("  OK %s\n", basename(parquet_grade_q)))

# =============================================================================
# 13) AGGREGATE BY ARRANGEMENT x QUARTILE
# =============================================================================

cat("\n13) Aggregating by arrangement x quartile ...\n")

aggregate_builtup <- function(df, quartile_col) {
  df |>
    filter(!is.na(.data[[quartile_col]])) |>
    group_by(CD_CIDADE, NM_CIDADE, quartil = .data[[quartile_col]]) |>
    summarise(
      n_celulas          = n(),
      ghsl_total_2010_m2 = sum(ghsl_total_2010, na.rm = TRUE),
      ghsl_total_2020_m2 = sum(ghsl_total_2020, na.rm = TRUE),
      ghsl_fora_2010_m2  = sum(ghsl_fora_alta_2010, na.rm = TRUE),
      ghsl_fora_2020_m2  = sum(ghsl_fora_alta_2020, na.rm = TRUE),
      .groups = "drop"
    ) |>
    mutate(
      delta_fora_m2 = ghsl_fora_2020_m2 - ghsl_fora_2010_m2,
      pct_fora_2010 = if_else(ghsl_total_2010_m2 > 0,
                              ghsl_fora_2010_m2 / ghsl_total_2010_m2, NA_real_),
      pct_fora_2020 = if_else(ghsl_total_2020_m2 > 0,
                              ghsl_fora_2020_m2 / ghsl_total_2020_m2, NA_real_)
    ) |>
    arrange(CD_CIDADE, quartil)
}

res_banheiro <- aggregate_builtup(cells_final, "quartil_banheiro")
res_renda    <- aggregate_builtup(cells_final, "quartil_renda")

csv_ban <- file.path(tables_dir, paste0("builtup_nao_suscept_banheiro", suffix, ".csv"))
csv_ren <- file.path(tables_dir, paste0("builtup_nao_suscept_renda",    suffix, ".csv"))
write_csv(res_banheiro, csv_ban)
write_csv(res_renda,    csv_ren)

cat(sprintf("  OK %s  (%d rows)\n", basename(csv_ban), nrow(res_banheiro)))
cat(sprintf("  OK %s  (%d rows)\n", basename(csv_ren), nrow(res_renda)))

cat(sprintf("\n%s\nDONE\n%s\n", strrep("=", 60), strrep("=", 60)))
cat("Outputs generated:\n")
cat(sprintf("  %s\n", gpkg_path))
cat(sprintf("  %s\n", parquet_path))
cat(sprintf("  %s\n", gpkg_grade_q))
cat(sprintf("  %s\n", parquet_grade_q))
cat(sprintf("  %s\n", csv_ban))
cat(sprintf("  %s\n", csv_ren))
cat("Next step: script 08_available_land.R\n")
