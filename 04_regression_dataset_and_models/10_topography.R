# =============================================================================
# 10_topography.R
# Computes topographic restriction within each arrangement's reference
# circle, DISAGGREGATED by municipality.
#
# Methodology:
#   1. For each arrangement, define a circle:
#        center = seat of the most populous municipality
#        radius = 2.5 x the radius of the circle with the same area as the
#                 2010 urban footprint (minimum 5 km)
#   2. For each municipality in the arrangement, compute the intersection of
#      the circle with the municipal territory.
#   3. Within that intersection, classify each pixel as:
#        water  : JRC Global Surface Water occurrence >= 80% (rivers,
#                 lakes, reservoirs) OR ocean (outside Brazil's polygon via
#                 geobr::read_country)
#        steep  : slope > 15% AND not water
#                 (source: SRTM via elevatr; threshold per NBR 11682 / CPRM 2014)
#   4. Denominator = total municipality pixels within the circle
#      (n_pixels_circulo), regardless of water or land
#   5. prop_restrita = prop_agua + prop_inclinado
#
# High susceptibility only (rule 9): prop_inclinado_em_alta is restricted to
# high-susceptibility zones; the medium-susceptibility counterpart this
# script used to also compute was archived under MIGRATION_PLAN.md Task 1
# and is not migrated here.
#
# Inputs:
#   data/processed_data/04_regression/amostra_universo.csv  (from 01_compose_sample.R)
#   data/processed_data/03_urban_footprint/metricas/metricas_arranjo_2010_2022.csv
#     (MIGRATION_PLAN.md 6b0 common-grid rework, 2026-08-28: replaces the
#     retired metricas_arranjo_2010_2020.csv -- area_m2_consolidated/
#     _densification/_peripheral are unchanged in name/meaning by the rework)
#   data/processed_data/04_regression/tables/sedes_municipios_BR.gpkg  (from script 09)
#   data/processed_data/04_regression/jrc_gsw/                        (tiles, script 03)
#   SRTM: downloaded automatically via elevatr, per area of interest
#   data/raw_data/04_regression/brasil_pais_2020.rds     (script 04)
#   data/raw_data/04_regression/malha_municipal_2022.rds (script 04)
#
# Outputs (data/processed_data/04_regression/tables/):
#   topografia_municipio_BR.csv  -- one row per municipality
#     cod_mun, CD_CIDADE, n_pixels_circulo, area_intersecao_m2,
#     prop_agua, prop_inclinado, prop_restrita
#   topografia_arranjo_BR.csv    -- one row per arrangement
#     CD_CIDADE, prop_agua, prop_inclinado, prop_restrita
#     (weighted mean by area_intersecao_m2)
#
# Packages: sf, terra, elevatr, dplyr, readr
# Estimated runtime: ~2-4 h for all of Brazil
# =============================================================================

source("04_regression_dataset_and_models/00_setup.R")
library(terra)
library(elevatr)

cat("\n", strrep("=", 60), "\n")
cat("10_TOPOGRAPHY.R\n")
cat(strrep("=", 60), "\n")

# --- CONFIGURATION -----------------------------------------------------------

UF_FILTER  <- NULL       # NULL = all of Brazil; e.g. "41" = Parana (test)
MIN_RADIUS_M <- 5000     # minimum circle radius: 5 km
SLOPE_STEEP  <- 15       # % -- steep-slope threshold (NBR 11682; CPRM 2014)
SRTM_ZOOM    <- 9        # elevatr zoom (9 ~= ~76 m; 10 ~= ~38 m resolution)
JRC_DIR      <- file.path(data_dir, "jrc_gsw")
CACHE_DIR    <- file.path(data_dir, "srtm_cache")
dir.create(CACHE_DIR, showWarnings = FALSE, recursive = TRUE)

suffix <- if (!is.null(UF_FILTER)) paste0("_UF", UF_FILTER) else "_BR"

if (!is.null(UF_FILTER)) cat(sprintf("  *** TEST MODE: UF = %s ***\n", UF_FILTER))

# --- 0) WATER LAYERS -----------------------------------------------------------

cat("\n0) Loading water layers...\n")

brazil_cache_path <- file.path(raw_data_dir, "brasil_pais_2020.rds")
if (!file.exists(brazil_cache_path))
  stop("Run 04_download_geobr_censobr.R first: ", brazil_cache_path, " not found")
brazil_sf <- readRDS(brazil_cache_path)
brazil_vect <- terra::vect(sf::st_transform(brazil_sf, 4326))
cat("  Brazil outline loaded\n")

jrc_tiles <- list.files(JRC_DIR, pattern = "\\.tif$", full.names = TRUE)
if (length(jrc_tiles) == 0) stop("No JRC tile found at: ", JRC_DIR)
jrc_vrt <- terra::vrt(jrc_tiles)
cat(sprintf("  JRC GSW: %d tiles loaded as VRT\n", length(jrc_tiles)))

# --- 0b) SUSCEPTIBILITY LAYER --------------------------------------------------

cat("\n0b) Loading susceptibility layer...\n")

suscept_alta_path <- file.path(stage02_data_dir, "susceptibilidade_unida.gpkg")

if (!file.exists(suscept_alta_path))
  stop("susceptibilidade_unida.gpkg not found at: ", suscept_alta_path)

# Read and reproject to EPSG:5880 (same projection as slope_uf)
suscept_alta_vect <- terra::vect(suscept_alta_path) |> terra::project("EPSG:5880")

cat(sprintf("  High susceptibility: %d polygons\n", nrow(suscept_alta_vect)))

# --- 1) SAMPLE AND MUNICIPAL MESH ----------------------------------------------

cat("\n1) Loading sample and municipal mesh...\n")

univ_path <- file.path(data_dir, "amostra_universo.csv")
if (!file.exists(univ_path))
  stop("Run 01_compose_sample.R first: amostra_universo.csv not found")
amostra <- read_csv(univ_path, show_col_types = FALSE) %>%
  mutate(cod_mun = as.character(cod_mun))

col_pop <- "pop_2022"

if (!is.null(UF_FILTER))
  amostra <- amostra |> filter(substr(cod_mun, 1, 2) == UF_FILTER)

cat(sprintf("  %d municipalities in sample\n", nrow(amostra)))

target_ufs <- if (is.null(UF_FILTER)) NULL else as.integer(UF_FILTER)

mesh_cache_path <- file.path(raw_data_dir, "malha_municipal_2022.rds")
if (!file.exists(mesh_cache_path))
  stop("Run 04_download_geobr_censobr.R first: ", mesh_cache_path, " not found")
mesh <- readRDS(mesh_cache_path)

if (!is.null(target_ufs))
  mesh <- mesh |> filter(as.integer(substr(code_muni, 1, 2)) %in% target_ufs)

mesh <- mesh |>
  transmute(cod_mun = formatC(as.integer(code_muni), width = 7, flag = "0", format = "d")) |>
  filter(cod_mun %in% amostra$cod_mun) |>
  sf::st_transform(5880)

cat(sprintf("  %d municipal polygons loaded\n", nrow(mesh)))

# --- 2) MUNICIPAL SEATS (sedes_municipios_BR.gpkg from script 09) -------------

cat("\n2) Loading municipal seats...\n")

sedes_gpkg_path <- file.path(tables_dir, paste0("sedes_municipios", suffix, ".gpkg"))
if (!file.exists(sedes_gpkg_path))
  stop("sedes_municipios", suffix, ".gpkg not found -- run 09_distance_to_seat.R first.")

sedes <- sf::st_read(sedes_gpkg_path, quiet = TRUE) |>
  filter(!is.na(ano_sede_calculo), ano == ano_sede_calculo) |>
  distinct(cod_mun, .keep_all = TRUE) |>
  filter(cod_mun %in% amostra$cod_mun)

sede_arranjo <- sedes |>
  sf::st_drop_geometry() |>
  filter(sede_referencia_arranjo, !is.na(CD_CIDADE)) |>
  select(CD_CIDADE, cod_mun_sede = cod_mun)

cat(sprintf("  %d municipalities with a seat loaded\n", nrow(sedes)))
cat(sprintf("  %d arrangements with a seat municipality identified\n", nrow(sede_arranjo)))

# --- 3) CIRCLE RADII (2010 urban footprint area) -------------------------------

cat("\n3) Computing circle radii by arrangement...\n")

metricas_path <- file.path(metricas_dir, "metricas_arranjo_2010_2022.csv")
metricas <- read_csv(metricas_path, show_col_types = FALSE) |>
  mutate(area_urbana_2010 = area_m2_consolidated + area_m2_densification + area_m2_peripheral)

# Radius = 2.5 x the equivalent radius of the circle with the same area as
# the 2010 footprint
raios <- metricas |>
  select(CD_CIDADE, area_urbana_2010) |>
  mutate(
    r_equiv_m = sqrt(area_urbana_2010 / pi),
    raio_m    = pmax(2.5 * r_equiv_m, MIN_RADIUS_M, na.rm = TRUE)
  ) |>
  select(CD_CIDADE, raio_m)

cat(sprintf("  %d arrangements with a defined radius (median %.0f m)\n",
            nrow(raios), median(raios$raio_m)))

# --- 4) REFERENCE CIRCLES -------------------------------------------------------

cat("\n4) Building reference circles...\n")

coords_sedes <- sf::st_coordinates(sedes)
sedes_tbl <- sf::st_drop_geometry(sedes) |>
  mutate(x_sede = coords_sedes[, 1], y_sede = coords_sedes[, 2]) |>
  select(cod_mun, x_sede, y_sede)

circulos <- sede_arranjo |>
  left_join(sedes_tbl, by = c("cod_mun_sede" = "cod_mun")) |>
  left_join(raios, by = "CD_CIDADE") |>
  filter(!is.na(x_sede), !is.na(raio_m))

sedes_sf    <- sf::st_as_sf(circulos, coords = c("x_sede", "y_sede"), crs = 5880)
circulos_sf <- sf::st_buffer(sedes_sf, dist = circulos$raio_m)
circulos_sf$CD_CIDADE <- circulos$CD_CIDADE

cat(sprintf("  %d circles created\n", nrow(circulos_sf)))

# --- 5) CIRCLE x MUNICIPAL TERRITORY INTERSECTION -------------------------------

cat("\n5) Computing circle x municipality intersections...\n")

amostra_arr <- amostra |>
  filter(!is.na(CD_CIDADE)) |>
  select(cod_mun, CD_CIDADE)

malha_arr <- mesh |> left_join(amostra_arr, by = "cod_mun")

intersecoes <- sf::st_intersection(
    malha_arr,
    circulos_sf |> select(CD_CIDADE_circ = CD_CIDADE)
  ) |>
  filter(CD_CIDADE == CD_CIDADE_circ) |>
  select(cod_mun, CD_CIDADE)

areas_inters <- as.numeric(sf::st_area(intersecoes))
intersecoes$area_intersecao_m2 <- areas_inters

cat(sprintf("  %d municipality x arrangement pairs with intersection\n", nrow(intersecoes)))

# --- 6) SRTM + WATER: DOWNLOAD AND CLASSIFICATION BY STATE ----------------------

cat("\n6) Processing topography via SRTM...\n")

ufs_to_process <- unique(substr(intersecoes$cod_mun, 1, 2))
cat(sprintf("  States to process: %s\n", paste(sort(ufs_to_process), collapse = ", ")))

# Downloads a DEM for a geometry (sf/sfc in EPSG:5880) and returns a slope
# raster (%)
download_slope <- function(geom_5880, zoom = SRTM_ZOOM, cache_path = NULL) {
  if (!is.null(cache_path) && file.exists(cache_path))
    return(terra::rast(cache_path))
  geom_4326 <- sf::st_transform(geom_5880, 4326)
  if (!inherits(geom_4326, "sf")) geom_4326 <- sf::st_sf(geometry = geom_4326)
  dem_raw <- elevatr::get_elev_raster(locations = geom_4326, z = zoom,
                                      src = "aws", clip = "locations")
  dem_terra  <- if (inherits(dem_raw, "SpatRaster")) dem_raw else terra::rast(dem_raw)
  dem_proj   <- terra::project(dem_terra, "EPSG:5880")
  slope_rast <- tan(terra::terrain(dem_proj, v = "slope", unit = "radians")) * 100
  if (!is.null(cache_path)) terra::writeRaster(slope_rast, cache_path, overwrite = TRUE)
  slope_rast
}

# Builds a water mask (1 = water, 0 = land) on the slope_uf grid (EPSG:5880).
# Combines ocean (outside Brazil's polygon) and inland water (JRC occurrence >= 80%)
prepare_water_uf <- function(slope_uf) {
  ext_4326   <- terra::ext(terra::project(slope_uf, "EPSG:4326"))
  slope_4326 <- terra::project(slope_uf, "EPSG:4326")

  brazil_crop <- tryCatch(terra::crop(brazil_vect, ext_4326), error = function(e) NULL)
  if (!is.null(brazil_crop) && nrow(brazil_crop) > 0L) {
    land_r <- terra::rasterize(brazil_crop, slope_4326, field = 1L, background = 0L)
    ocean  <- terra::project(terra::ifel(land_r == 0L, 1L, 0L), slope_uf, method = "near")
  } else {
    ocean <- slope_uf * 0
  }

  jrc_crop <- tryCatch({
    terra::project(terra::crop(jrc_vrt, ext_4326), slope_uf, method = "near")
  }, error = function(e) NULL)
  inland_water <- if (!is.null(jrc_crop)) terra::ifel(jrc_crop >= 80, 1L, 0L) else slope_uf * 0

  terra::ifel((ocean + inland_water) >= 1L, 1L, 0L)
}

# Classifies one intersection (sf geom in EPSG:5880):
#   n_pixels_circulo : municipality pixels within the circle (denominator)
#   prop_agua        : water fraction (JRC + ocean)
#   prop_inclinado   : fraction with slope > 15%, excluding water pixels
#   prop_sem_dado    : fraction of land with no SRTM data (data quality)
#   prop_restrita    : prop_agua + prop_inclinado
classify_slope <- function(slope_uf, water_uf, geom_intersecao) {
  geom_v <- terra::vect(geom_intersecao)

  slope_c <- tryCatch(
    terra::crop(slope_uf, geom_v),
    error = function(e) NULL
  )
  if (is.null(slope_c) || terra::ncell(slope_c) == 0L)
    return(data.frame(n_pixels_circulo = NA_integer_, prop_agua = NA_real_,
                      prop_inclinado = NA_real_, prop_sem_dado = NA_real_,
                      prop_restrita = NA_real_))

  water_c <- terra::resample(water_uf, slope_c, method = "near")

  slope_vals <- terra::extract(slope_c, geom_v, touches = FALSE)[[2]]
  water_vals <- terra::extract(water_c, geom_v, touches = FALSE)[[2]]

  n_tot <- length(slope_vals)
  if (n_tot == 0L)
    return(data.frame(n_pixels_circulo = 0L, prop_agua = NA_real_,
                      prop_inclinado = NA_real_, prop_sem_dado = NA_real_,
                      prop_restrita = NA_real_))

  n_agua <- sum(!is.na(water_vals) & water_vals >= 1L)

  land_slope     <- slope_vals[is.na(water_vals) | water_vals < 1L]
  n_inclinado    <- sum(!is.na(land_slope) & land_slope > SLOPE_STEEP)
  n_slope_valido <- sum(!is.na(land_slope))
  n_sem_dado     <- n_tot - n_agua - n_slope_valido

  data.frame(
    n_pixels_circulo = as.integer(n_tot),
    prop_agua        = n_agua / n_tot,
    prop_inclinado   = n_inclinado / n_tot,
    prop_sem_dado    = n_sem_dado / n_tot,
    prop_restrita    = (n_agua + n_inclinado) / n_tot
  )
}

# Classifies slope within high-susceptibility zones, restricted to the same
# reference circle used in classify_slope().
#
# Susceptibility is rasterized locally (directly on slope_c's grid) to avoid
# losing small polygons in the state-level resample.
#
#   prop_inclinado_em_alta : pixels (slope > 15%) n (high susceptibility) n (not water)
#                            / pixels (high susceptibility) n (not water)
#
# Restricted to the circle x municipality intersection.
classify_slope_susceptibility <- function(slope_uf, water_uf,
                                           suscept_alta_vect,
                                           geom_intersecao) {
  na_row <- data.frame(
    n_pixels_suscept_alta  = NA_integer_,
    prop_inclinado_em_alta = NA_real_
  )

  geom_v  <- terra::vect(geom_intersecao)
  slope_c <- tryCatch(terra::crop(slope_uf, geom_v), error = function(e) NULL)
  if (is.null(slope_c) || terra::ncell(slope_c) == 0L) return(na_row)

  water_c <- terra::resample(water_uf, slope_c, method = "near")

  # Rasterize susceptibility directly on the local grid (slope_c) -- more
  # accurate than resampling the whole-state raster
  ext_c <- terra::ext(slope_c)

  rasterize_local <- function(vect, template) {
    cropped <- tryCatch(terra::crop(vect, ext_c), error = function(e) NULL)
    if (is.null(cropped) || nrow(cropped) == 0L) return(template * 0L)
    terra::rasterize(cropped, template, field = 1L, background = 0L)
  }

  alta_c <- rasterize_local(suscept_alta_vect, slope_c)

  slope_vals <- terra::extract(slope_c, geom_v, touches = FALSE)[[2]]
  water_vals <- terra::extract(water_c, geom_v, touches = FALSE)[[2]]
  alta_vals  <- terra::extract(alta_c,  geom_v, touches = FALSE)[[2]]

  not_water <- is.na(water_vals) | water_vals < 1L
  inclinado <- !is.na(slope_vals) & slope_vals > SLOPE_STEEP

  in_alta <- !is.na(alta_vals) & alta_vals >= 1L & not_water

  n_alta <- sum(in_alta, na.rm = TRUE)

  data.frame(
    n_pixels_suscept_alta  = as.integer(n_alta),
    prop_inclinado_em_alta = if (n_alta > 0L) sum(in_alta & inclinado, na.rm = TRUE) / n_alta else NA_real_
  )
}

# --- Main loop: process by state -----------------------------------------------

resultados <- list()

for (uf in sort(ufs_to_process)) {
  cat(sprintf("  UF %s...\n", uf))
  inters_uf <- intersecoes[substr(intersecoes$cod_mun, 1, 2) == uf, ]
  if (nrow(inters_uf) == 0L) next

  cache_path <- file.path(CACHE_DIR, paste0("slope_UF", uf, ".tif"))
  bbox_uf    <- sf::st_union(inters_uf) |> sf::st_buffer(5000)

  slope_uf <- tryCatch(
    download_slope(bbox_uf, cache_path = cache_path),
    error = function(e) { message(sprintf("    ERROR slope UF %s: %s", uf, e$message)); NULL }
  )
  if (is.null(slope_uf)) {
    cat(sprintf("    -> skipping UF %s (download error)\n", uf)); next
  }

  water_uf <- tryCatch(
    prepare_water_uf(slope_uf),
    error = function(e) {
      message(sprintf("    Warning: water mask UF %s: %s", uf, e$message))
      slope_uf * 0
    }
  )

  for (i in seq_len(nrow(inters_uf))) {
    res_base <- tryCatch(
      classify_slope(slope_uf, water_uf, inters_uf[i, ]),
      error = function(e) data.frame(n_pixels_circulo = NA_integer_, prop_agua = NA_real_,
                                     prop_inclinado = NA_real_, prop_sem_dado = NA_real_,
                                     prop_restrita = NA_real_)
    )
    res_suscept <- tryCatch(
      classify_slope_susceptibility(slope_uf, water_uf,
                                     suscept_alta_vect, inters_uf[i, ]),
      error = function(e) data.frame(n_pixels_suscept_alta = NA_integer_,
                                     prop_inclinado_em_alta = NA_real_)
    )
    resultados[[length(resultados) + 1]] <- data.frame(
      cod_mun   = inters_uf$cod_mun[i],
      CD_CIDADE = inters_uf$CD_CIDADE[i],
      res_base,
      res_suscept
    )
  }
  rm(slope_uf, water_uf); gc()
  cat(sprintf("    OK %d municipalities processed\n", nrow(inters_uf)))
}

if (length(resultados) == 0L)
  stop("No state processed successfully -- check access to the elevatr/AWS API.")

topo_mun <- do.call(rbind, resultados)
cat(sprintf("  %d municipalities with topography computed\n",
            sum(!is.na(topo_mun$prop_restrita))))

# --- 7) AGGREGATE TO ARRANGEMENT (weighted mean by intersection area) ----------

cat("\n7) Aggregating topography to arrangement level...\n")

topo_mun_w <- topo_mun |>
  left_join(sf::st_drop_geometry(intersecoes) |>
              select(cod_mun, CD_CIDADE, area_intersecao_m2),
            by = c("cod_mun", "CD_CIDADE"))

topo_arr <- topo_mun_w |>
  filter(!is.na(prop_restrita)) |>
  group_by(CD_CIDADE) |>
  summarise(
    prop_agua              = weighted.mean(prop_agua,              area_intersecao_m2, na.rm = TRUE),
    prop_inclinado         = weighted.mean(prop_inclinado,         area_intersecao_m2, na.rm = TRUE),
    prop_sem_dado          = weighted.mean(prop_sem_dado,          area_intersecao_m2, na.rm = TRUE),
    prop_restrita          = weighted.mean(prop_restrita,          area_intersecao_m2, na.rm = TRUE),
    prop_inclinado_em_alta = weighted.mean(prop_inclinado_em_alta, area_intersecao_m2, na.rm = TRUE),
    .groups = "drop"
  )

cat(sprintf("  %d arrangements with topography\n", nrow(topo_arr)))

# --- 8) PREVIEW ------------------------------------------------------------------

cat("\n  Preview (municipalities):\n"); topo_mun_w |> slice_head(n = 10) |> print()
cat("\n  Preview (arrangements):\n");   topo_arr   |> slice_head(n = 10) |> print()

# --- 9) SAVE -----------------------------------------------------------------

cat("\n9) Saving...\n")

path_mun <- file.path(tables_dir, paste0("topografia_municipio", suffix, ".csv"))
path_arr <- file.path(tables_dir, paste0("topografia_arranjo",   suffix, ".csv"))

write_csv(topo_mun_w, path_mun)
cat(sprintf("  OK %s  (%d rows)\n", basename(path_mun), nrow(topo_mun_w)))

write_csv(topo_arr, path_arr)
cat(sprintf("  OK %s  (%d rows)\n", basename(path_arr), nrow(topo_arr)))

cat("\n", strrep("=", 60), "\n")
cat("DONE\n")
cat(strrep("=", 60), "\n")
cat("\nTopography variables:\n")
cat("  n_pixels_circulo       : total municipality pixels within the circle\n")
cat("  area_intersecao_m2     : area of the circle n municipality intersection (m2)\n")
cat("  prop_agua              : water fraction (JRC occurrence >= 80% + ocean)\n")
cat("  prop_inclinado         : fraction with slope > 15%, excluding water (whole circle)\n")
cat("  prop_sem_dado          : fraction of land with no SRTM data\n")
cat("  prop_restrita          : prop_agua + prop_inclinado\n")
cat("  prop_inclinado_em_alta : slope > 15% / total, restricted to high-susceptibility zones\n")
cat("  Excludes water pixels and uses the same reference circle as the variables above.\n")
