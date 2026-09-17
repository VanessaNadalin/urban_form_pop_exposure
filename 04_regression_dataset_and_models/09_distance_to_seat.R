# =============================================================================
# 09_distance_to_seat.R
# Computes the Euclidean distance from each urban-footprint cell (2022 grid)
# to the reference municipal seat:
#   - Isolated municipalities : the municipality's own seat
#   - Population arrangements : seat of the arrangement's most populous member
#
# Seat source: geobr::read_municipal_seat(), cascading from 1950 forward
# (see MIGRATION_PLAN.md 6c0 -- the old header describing KML files as the
# seat source didn't match this script's actual logic even before tonight's
# rework; 04_download_municipal_seats.R, since archived, was never wired in).
#
# Aggregates by municipality and by arrangement:
#   - Total (all urban-footprint cells)
#   - Q1+Q2 (poorest 50% by income per capita)
#   - Q1    (poorest 25%)
#   - dif_dist_q1_total = dist_media_q1 - dist_media_total
#   - By growth type (densification, extension, etc.) as wide columns
#
# Note: road-network distance (e.g. OSRM + OSM) would be more realistic but
# is infeasible at national scale via API. For relative intra-municipal
# comparisons across quartiles, Euclidean distance is standard in the
# literature (Alonso-Muth-Mills) and sufficient here.
#
# Inputs:
#   data/processed_data/04_regression/ghsl_susceptibility/grade_safe_poor_{suffix}.gpkg
#   data/processed_data/04_regression/amostra_universo.csv  (from 01_compose_sample.R)
#   data/raw_data/04_regression/sedes_municipais_geobr_1950_2010.rds  (script 04;
#     named list, one entry per fallback year)
#
# Outputs (in data/processed_data/04_regression/tables/):
#   dist_sede_municipio_{suffix}.csv
#     -- one row per municipality; includes dist_media_m_densification etc. (wide)
#   dist_sede_arranjo_{suffix}.csv
#     -- one row per arrangement; includes dist_media_m_densification etc. (wide)
#   dist_sede_tipo_arranjo_{suffix}.csv
#     -- arrangement x tipo_crescimento x quartil_renda (long, full breakdown)
#   dist_sede_tipo_arranjo_simples_{suffix}.csv
#     -- arrangement x tipo_crescimento (long, no quartile -- base of the wide table above)
#   sedes_municipios_{suffix}.gpkg
#     -- seat points (geobr) for visual comparison 1970 vs 2010;
#        attributes: cod_mun, ano, CD_CIDADE, NM_CIDADE, pop, sede_referencia_arranjo
# =============================================================================

source("04_regression_dataset_and_models/00_setup.R")

UF_FILTER <- NULL   # NULL = all of Brazil

cat("\n", strrep("=", 60), "\n")
cat("09_DISTANCE_TO_SEAT.R\n")
cat(strrep("=", 60), "\n")
if (!is.null(UF_FILTER)) cat(sprintf("  *** TEST MODE: UF = %s ***\n", UF_FILTER))

suffix <- if (!is.null(UF_FILTER)) paste0("_UF", UF_FILTER) else "_BR"

# =============================================================================
# 1) LOAD GRID WITH QUARTILES AND GROWTH TYPE
# =============================================================================

cat("\n1) Loading grade_safe_poor...\n")

gpkg_path <- file.path(ghsl_susc_dir, paste0("grade_safe_poor", suffix, ".gpkg"))
grade <- sf::st_read(gpkg_path, quiet = TRUE)
cat(sprintf("  %s cells (urban footprint)\n", fmt(nrow(grade))))
cat(sprintf("  Arrangements present: %s\n",
            fmt(length(unique(grade$CD_CIDADE[!is.na(grade$CD_CIDADE)])))))

# Ensure a metric CRS (EPSG:5880) so distances come out in meters
if (is.na(st_crs(grade)) || st_crs(grade)$epsg != 5880) {
  cat("  Reprojecting to EPSG:5880...\n")
  grade <- st_transform(grade, 5880)
}

# Cell centroids (one point per cell)
cat("  Computing centroids...\n")
grade_pts <- st_centroid(grade)

# =============================================================================
# 2) IDENTIFY THE REFERENCE SEAT PER CELL
# =============================================================================
# For arrangements: seat = the arrangement's most populous municipality.
# For isolated municipalities: seat = the municipality itself.

cat("\n2) Identifying reference seat by arrangement...\n")

univ_path <- file.path(data_dir, "amostra_universo.csv")
if (!file.exists(univ_path))
  stop("Run 01_compose_sample.R first: amostra_universo.csv not found")
amostra <- read_csv(univ_path, show_col_types = FALSE) %>%
  mutate(cod_mun = as.character(cod_mun))

col_pop <- "pop_2022"

cat(sprintf("  %d municipalities in sample\n", nrow(amostra)))

sede_arranjo <- amostra |>
  filter(!is.na(CD_CIDADE)) |>
  group_by(CD_CIDADE) |>
  slice_max(order_by = .data[[col_pop]], n = 1, with_ties = FALSE) |>
  ungroup() |>
  select(CD_CIDADE, cod_mun_sede = cod_mun)

cat(sprintf("  %d arrangements -> seat identified\n", nrow(sede_arranjo)))

# Join: each cell receives the reference cod_mun used to look up its seat
grade_pts <- grade_pts |>
  left_join(sede_arranjo, by = "CD_CIDADE") |>
  mutate(
    cod_mun_ref = if_else(!is.na(cod_mun_sede), cod_mun_sede, cod_mun)
  )

# =============================================================================
# 3) LOAD MUNICIPAL SEATS
# =============================================================================

cat("\n3) Loading municipal seats ...\n")

seats_cache_path <- file.path(raw_data_dir, "sedes_municipais_geobr_1950_2010.rds")
if (!file.exists(seats_cache_path))
  stop("Run 04_download_geobr_censobr.R first: ", seats_cache_path, " not found")
seats_cache <- readRDS(seats_cache_path)

load_seats <- function(year) {
  seats_raw <- seats_cache[[as.character(year)]]
  if (is.null(seats_raw))
    stop(sprintf("%s has no entry for year %d.", seats_cache_path, year))
  seats_raw |>
    mutate(cod_mun = as.character(code_muni)) |>
    select(cod_mun) |>
    sf::st_transform(5880)
}

fallback_years  <- c(1950, 1960, 1970, 1980, 1991, 2010)
seats_by_year   <- lapply(fallback_years, load_seats)
names(seats_by_year) <- as.character(fallback_years)

for (y in fallback_years)
  cat(sprintf("  %d: %d seats in Brazil\n", y, nrow(seats_by_year[[as.character(y)]])))

# Cascade: use the oldest available year per municipality
needed_ref_muns <- unique(grade_pts$cod_mun_ref)
seats           <- NULL
remaining_muns  <- needed_ref_muns

for (year in fallback_years) {
  available <- seats_by_year[[as.character(year)]] |>
    filter(cod_mun %in% remaining_muns) |>
    mutate(ano_sede = year)
  if (nrow(available) > 0) {
    seats          <- bind_rows(seats, available)
    remaining_muns <- setdiff(remaining_muns, available$cod_mun)
  }
  cat(sprintf("  %d -> %d municipalities covered  (still without a seat: %d)\n",
              year, nrow(available), length(remaining_muns)))
  if (length(remaining_muns) == 0) break
}

if (length(remaining_muns) > 0)
  cat(sprintf("  No seat in any year: %s\n", paste(remaining_muns, collapse = ", ")))

cat(sprintf("  Total: %d seats for %d reference municipalities (EPSG:5880)\n",
            nrow(seats), length(needed_ref_muns)))

# Point overrides: replace the cascade's seat with the 2010 one
# BH (3106200): the historical seat is far from the actual center
# Tubarao (4217204): same issue
override_2010 <- c("3106200", "4217204")
override_2010 <- intersect(override_2010, seats_by_year[["2010"]]$cod_mun)
if (length(override_2010) > 0) {
  seats <- seats[!seats$cod_mun %in% override_2010, ]
  new_seats <- seats_by_year[["2010"]] |>
    filter(cod_mun %in% override_2010) |>
    mutate(ano_sede = 2010L)
  seats <- bind_rows(seats, new_seats)
  cat(sprintf("  Override -> 2010 seat applied: %s\n",
              paste(override_2010, collapse = ", ")))
}

# All filtered seats (every year) -- used in the visual-comparison .gpkg
seats_all_years <- lapply(fallback_years, function(y) {
  seats_by_year[[as.character(y)]] |>
    filter(cod_mun %in% needed_ref_muns) |>
    mutate(ano = as.integer(y))
}) |> bind_rows()

# =============================================================================
# 4) COMPUTE EUCLIDEAN DISTANCE PER CELL
# =============================================================================

cat("\n4) Computing Euclidean distances (EPSG:5880)...\n")

muns_with_seat <- intersect(unique(grade_pts$cod_mun_ref), seats$cod_mun)

dist_list <- lapply(muns_with_seat, function(mun) {
  cells   <- grade_pts[grade_pts$cod_mun_ref == mun, ]
  seat_pt <- seats[seats$cod_mun == mun, ]
  dists   <- as.numeric(sf::st_distance(cells, seat_pt))
  data.frame(
    id_celula   = cells$id_celula,
    dist_sede_m = dists,
    stringsAsFactors = FALSE
  )
})

dist_df <- do.call(rbind, dist_list)
# The grid may have multiple rows per cell; distance is deterministic
dist_df <- dist_df[!duplicated(dist_df$id_celula), ]
cat(sprintf("  %s cells with distance computed\n", fmt(nrow(dist_df))))

# Join distances onto the grid (without geometry)
grade_dist <- sf::st_drop_geometry(grade_pts) |>
  left_join(dist_df, by = "id_celula")

# Restrict to the filtered sample
n_before <- nrow(grade_dist)
grade_dist <- grade_dist |> filter(CD_CIDADE %in% amostra$CD_CIDADE)
cat(sprintf("  %s cells removed (outside the sample)  ->  %s cells remaining\n",
            fmt(n_before - nrow(grade_dist)), fmt(nrow(grade_dist))))

n_no_dist <- sum(is.na(grade_dist$dist_sede_m))
if (n_no_dist > 0)
  cat(sprintf("  Warning: %d cells with no distance (municipality with no geobr seat)\n", n_no_dist))

cat(sprintf("  Overall mean distance: %.0f m\n",
            mean(grade_dist$dist_sede_m, na.rm = TRUE)))
cat(sprintf("  Overall median distance: %.0f m\n",
            median(grade_dist$dist_sede_m, na.rm = TRUE)))

# =============================================================================
# 5) AGGREGATE
# =============================================================================

cat("\n5) Aggregating...\n")

calc_dist <- function(df, groups) {
  df |>
    filter(!is.na(dist_sede_m)) |>
    group_by(across(all_of(groups))) |>
    summarise(
      n_celulas      = n(),
      dist_media_m   = mean(dist_sede_m),
      dist_mediana_m = median(dist_sede_m),
      .groups        = "drop"
    )
}

suffix_dist <- function(df, join_key, sufx) {
  cols <- setdiff(names(df), join_key)
  df |>
    rename_with(~ paste0(., sufx), all_of(cols)) |>
    select(all_of(join_key), all_of(paste0(cols, sufx)))
}

dados_q12 <- grade_dist |> filter(quartil_renda %in% c(1L, 2L))
dados_q1  <- grade_dist |> filter(quartil_renda == 1L)

# -- By municipality --------------------------------------------------------
GRUPOS_MUN <- c("cod_mun", "CD_CIDADE", "NM_CIDADE")

dist_municipio <- calc_dist(grade_dist, GRUPOS_MUN) |>
  left_join(suffix_dist(calc_dist(dados_q12, GRUPOS_MUN), GRUPOS_MUN, "_q12"), by = GRUPOS_MUN) |>
  left_join(suffix_dist(calc_dist(dados_q1,  GRUPOS_MUN), GRUPOS_MUN, "_q1"),  by = GRUPOS_MUN) |>
  mutate(
    dif_dist_q1_total = dist_media_m_q1 - dist_media_m
  )

cat(sprintf("  %d municipalities\n", nrow(dist_municipio)))

# -- By arrangement -----------------------------------------------------------
GRUPOS_ARR <- c("CD_CIDADE", "NM_CIDADE")

dist_arranjo <- calc_dist(grade_dist, GRUPOS_ARR) |>
  left_join(suffix_dist(calc_dist(dados_q12, GRUPOS_ARR), GRUPOS_ARR, "_q12"), by = GRUPOS_ARR) |>
  left_join(suffix_dist(calc_dist(dados_q1,  GRUPOS_ARR), GRUPOS_ARR, "_q1"),  by = GRUPOS_ARR) |>
  mutate(
    dif_dist_q1_total = dist_media_m_q1 - dist_media_m
  )

cat(sprintf("  %d arrangements\n", nrow(dist_arranjo)))

# -- Breakdown by arrangement x tipo_crescimento x quartil_renda -------------
GRUPOS_TIPO_ARR <- c("CD_CIDADE", "NM_CIDADE", "tipo_crescimento", "quartil_renda")

dist_tipo_arranjo <- grade_dist |>
  filter(!is.na(dist_sede_m), !is.na(tipo_crescimento), !is.na(quartil_renda)) |>
  group_by(across(all_of(GRUPOS_TIPO_ARR))) |>
  summarise(
    n_celulas      = n(),
    dist_media_m   = mean(dist_sede_m),
    dist_mediana_m = median(dist_sede_m),
    .groups        = "drop"
  )

cat(sprintf("  %d rows in the breakdown table (arrangement x type x quartile)\n",
            nrow(dist_tipo_arranjo)))

# -- By arrangement x tipo_crescimento (no quartile) -------------------------
GRUPOS_TIPO_ARR_S <- c("CD_CIDADE", "NM_CIDADE", "tipo_crescimento")

dist_tipo_arranjo_simples <- grade_dist |>
  filter(!is.na(dist_sede_m), !is.na(tipo_crescimento)) |>
  group_by(across(all_of(GRUPOS_TIPO_ARR_S))) |>
  summarise(
    n_celulas      = n(),
    dist_media_m   = mean(dist_sede_m),
    dist_mediana_m = median(dist_sede_m),
    .groups        = "drop"
  )

cat(sprintf("  %d rows in the simple table (arrangement x type)\n",
            nrow(dist_tipo_arranjo_simples)))

# -- By municipality x tipo_crescimento (no quartile) ------------------------
GRUPOS_TIPO_MUN_S <- c("cod_mun", "CD_CIDADE", "NM_CIDADE", "tipo_crescimento")

dist_tipo_mun_simples <- grade_dist |>
  filter(!is.na(dist_sede_m), !is.na(tipo_crescimento)) |>
  group_by(across(all_of(GRUPOS_TIPO_MUN_S))) |>
  summarise(
    n_celulas      = n(),
    dist_media_m   = mean(dist_sede_m),
    dist_mediana_m = median(dist_sede_m),
    .groups        = "drop"
  )

# -- Wide: dist_media_m_{type} for the main outputs --------------------------
tipo_wide_arranjo <- dist_tipo_arranjo_simples |>
  select(CD_CIDADE, NM_CIDADE, tipo_crescimento, dist_media_m) |>
  tidyr::pivot_wider(
    names_from   = tipo_crescimento,
    values_from  = dist_media_m,
    names_prefix = "dist_media_m_"
  )

dist_arranjo <- dist_arranjo |>
  left_join(tipo_wide_arranjo, by = c("CD_CIDADE", "NM_CIDADE"))

tipo_wide_mun <- dist_tipo_mun_simples |>
  select(cod_mun, CD_CIDADE, NM_CIDADE, tipo_crescimento, dist_media_m) |>
  tidyr::pivot_wider(
    names_from   = tipo_crescimento,
    values_from  = dist_media_m,
    names_prefix = "dist_media_m_"
  )

dist_municipio <- dist_municipio |>
  left_join(tipo_wide_mun, by = c("cod_mun", "CD_CIDADE", "NM_CIDADE"))

cat(sprintf("  Wide columns in dist_arranjo: %s\n",
            paste(grep("^dist_media_m_", names(dist_arranjo), value = TRUE),
                  collapse = ", ")))

# =============================================================================
# 6) DISTANCE BY GROWTH TYPE 2000-2010
#
# Loads grade_crescimento_2000_2010_g2010.parquet (stage 03) and joins it to
# grade_dist by ID_UNICO to get tipo_crescimento_0010. Computes:
#   dist_media_m_densif_0010        -- densification cells 2000-2010
#   dist_media_m_densif_infill_0010 -- densification + infill cells 2000-2010
# =============================================================================

cat("\n6) Distance by growth type 2000-2010...\n")

cresc_0010_path <- file.path(growth_types_dir, "grade_crescimento_2000_2010_g2010.parquet")

if (!file.exists(cresc_0010_path)) {
  cat("  Warning: grade_crescimento_2000_2010_g2010.parquet not found.\n")
  cat("  -> Run 03_urban_footprint_and_growth_types/06_classify_growth_types_2000_2010.R first.\n")
  cat("  -> The dist_*_0010 variables will not be generated.\n")
} else {
  cresc_0010 <- arrow::read_parquet(cresc_0010_path)

  cresc_key <- if ("ID_UNICO" %in% names(cresc_0010)) "ID_UNICO" else "id_celula"
  cat(sprintf("  Parquet loaded: %s rows  |  key: %s\n",
              fmt(nrow(cresc_0010)), cresc_key))
  cat(sprintf("  Types present: %s\n",
              paste(sort(unique(cresc_0010$tipo_crescimento_0010)), collapse = ", ")))

  # Note: grade_dist inherits ID_UNICO from grade_safe_poor (script 08).
  # Do not use id_celula: that is the sequential GHSL id, different from
  # IBGE's ID_UNICO.
  grade_dist <- grade_dist |>
    mutate(ID_UNICO = as.character(ID_UNICO)) |>
    left_join(
      cresc_0010 |>
        select(ID_UNICO = all_of(cresc_key), tipo_crescimento_0010) |>
        mutate(ID_UNICO = as.character(ID_UNICO)),
      by = "ID_UNICO"
    ) |>
    mutate(
      densif_0010        = tipo_crescimento_0010 == "densification",
      densif_infill_0010 = tipo_crescimento_0010 %in% c("densification", "infill")
    )

  n_join <- sum(!is.na(grade_dist$tipo_crescimento_0010))
  cat(sprintf("  Cells with tipo_crescimento_0010: %s of %s (%.1f%%)\n",
              fmt(n_join), fmt(nrow(grade_dist)),
              100 * n_join / nrow(grade_dist)))

  calc_dist_mask <- function(df, groups, mask_col, sufx) {
    df |>
      filter(!is.na(dist_sede_m), .data[[mask_col]] == TRUE) |>
      group_by(across(all_of(groups))) |>
      summarise(!!paste0("dist_media_m_", sufx) := mean(dist_sede_m),
                .groups = "drop")
  }

  dist_municipio <- dist_municipio |>
    left_join(
      calc_dist_mask(grade_dist, GRUPOS_MUN, "densif_0010",        "densif_0010"),
      by = GRUPOS_MUN
    ) |>
    left_join(
      calc_dist_mask(grade_dist, GRUPOS_MUN, "densif_infill_0010", "densif_infill_0010"),
      by = GRUPOS_MUN
    )

  dist_arranjo <- dist_arranjo |>
    left_join(
      calc_dist_mask(grade_dist, GRUPOS_ARR, "densif_0010",        "densif_0010"),
      by = GRUPOS_ARR
    ) |>
    left_join(
      calc_dist_mask(grade_dist, GRUPOS_ARR, "densif_infill_0010", "densif_infill_0010"),
      by = GRUPOS_ARR
    )

  cat(sprintf("  dist_media_m_densif_0010        -- municipalities with a value: %d\n",
              sum(!is.na(dist_municipio$dist_media_m_densif_0010))))
  cat(sprintf("  dist_media_m_densif_infill_0010 -- municipalities with a value: %d\n",
              sum(!is.na(dist_municipio$dist_media_m_densif_infill_0010))))
}

# =============================================================================
# 7) PREVIEW
# =============================================================================

cat("\n  Preview (municipalities):\n")
dist_municipio |>
  select(NM_CIDADE, cod_mun, n_celulas,
         dist_media_m, dist_media_m_q1, dif_dist_q1_total) |>
  print(n = 10)

cat("\n  Preview (arrangements):\n")
dist_arranjo |>
  select(NM_CIDADE, n_celulas,
         dist_media_m, dist_media_m_q1, dif_dist_q1_total) |>
  print()

# =============================================================================
# 8) SAVE
# =============================================================================

cat("\n8) Saving...\n")

save_table <- function(df, name) {
  path <- file.path(tables_dir, paste0(name, suffix, ".csv"))
  write_csv(df, path)
  cat(sprintf("  OK %s  (%d rows)\n", basename(path), nrow(df)))
}

save_table(dist_municipio,            "dist_sede_municipio")
save_table(dist_arranjo,              "dist_sede_arranjo")
save_table(dist_tipo_arranjo,         "dist_sede_tipo_arranjo")
save_table(dist_tipo_arranjo_simples, "dist_sede_tipo_arranjo_simples")

# Comparison GeoPackage (all years) for visual verification
cols_amostra <- intersect(c("cod_mun", "CD_CIDADE", "NM_CIDADE", col_pop),
                          names(amostra))
ano_calculo  <- sf::st_drop_geometry(seats) |> select(cod_mun, ano_sede_calculo = ano_sede)

sedes_gpkg <- seats_all_years |>
  left_join(amostra[, cols_amostra], by = "cod_mun") |>
  left_join(ano_calculo, by = "cod_mun") |>
  mutate(sede_referencia_arranjo = cod_mun %in% sede_arranjo$cod_mun_sede) |>
  select(cod_mun, ano, ano_sede_calculo,
         any_of(c("CD_CIDADE", "NM_CIDADE")), sede_referencia_arranjo)

gpkg_sedes <- file.path(tables_dir, paste0("sedes_municipios", suffix, ".gpkg"))
sf::st_write(sedes_gpkg, gpkg_sedes, delete_dsn = TRUE, quiet = TRUE)
cat(sprintf("  OK %s  (%d municipalities x %d years, CRS EPSG:5880)\n",
            basename(gpkg_sedes),
            length(unique(sedes_gpkg$cod_mun)),
            length(unique(sedes_gpkg$ano))))

cat("\n", strrep("=", 60), "\n")
cat("DONE\n")
cat(strrep("=", 60), "\n")
cat("\nVariables in dist_sede_municipio / dist_sede_arranjo:\n")
cat("  dist_media_m / dist_mediana_m            : whole footprint\n")
cat("  dist_media_m_q12 / dist_mediana_m_q12    : Q1+Q2 (poorest 50%)\n")
cat("  dist_media_m_q1  / dist_mediana_m_q1     : Q1 (poorest 25%)\n")
cat("  dif_dist_q1_total                        : dist_media_q1 - dist_media_total\n")
cat("  dist_media_m_densification               : mean, densification cells 2010-2022\n")
cat("  dist_media_m_extension / _infill / ...   : same, by growth type 2010-2022\n")
cat("  dist_media_m_densif_0010                 : mean, densification cells 2000-2010\n")
cat("  dist_media_m_densif_infill_0010          : mean, densification+infill cells 2000-2010\n")
