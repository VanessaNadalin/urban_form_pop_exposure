# =============================================================================
# 06_classify_growth_types_2000_2010.R
# Classifies urban growth types for the 2000->2010 period using GHSL for
# both population and built-up at each point in time.
#
# Methodology -- analogous to scripts 04 + 05, for the 2000->2010 period:
#
#   Spatial reference: 2010 IBGE grid (geometry already produced by script 03)
#
#   Urban criterion (AND, same as script 04):
#     urbano_2000 = built_pct_2000 >= LIMIAR_BUILT AND
#                  pop_ghsl_2000 / area_km^2 >= LIMIAR_DENS
#     urbano_2010_ghsl = built_pct_2010 >= LIMIAR_BUILT AND
#                       pop_ghsl_2010 / area_km^2 >= LIMIAR_DENS
#     (uses GHSL-POP at both points in time -> symmetric, consistent criterion;
#      pop_ghsl_2010 stands in for the 2010 IBGE Census to keep that symmetry)
#
#   Major/minor patches: classified using pop_ghsl_2000 (t1 population)
#     major = pop_patch > POP_PATCH_A AND dens_patch >= DENS_PATCH_B
#
#   6 growth types (same as script 05):
#     consolidated  - urban t1->t2, major patch, delta built <= LIMIAR_DENSIF
#     densification - urban t1->t2, major patch, delta built > LIMIAR_DENSIF
#     peripheral    - urban t1->t2, minor patch
#     infill        - new cell inside a t1 major patch's topological hole
#     extension     - new cell <= LIMIAR_EXTENSION m from a t1 major patch
#     leapfrog      - new cell > LIMIAR_EXTENSION m from a t1 major patch
#
# Note (per MIGRATION_PLAN.md 6b0): this script stays OUTSIDE the stage-03
# common-grid unification -- there is no 2000 statistical grid, so this
# period keeps using GHSL-POP as its own population source, on the 2010
# IBGE grid geometry, exactly as before.
#
# Updated (researcher request, cross-window consistency check): two points
# where this script had drifted from script 05's algorithm were aligned to
# match it exactly --
#   1. Single-cell analysis units now check the Major/Minor patch criterion
#      (pop_ghsl_2000 > POP_PATCH_A AND density >= DENS_PATCH_B) before
#      falling back to "peripheral", instead of assuming Minor by definition.
#   2. The grid is no longer pre-filtered to cells urban at t1 or t2 before
#      the classification loop -- it uses the full sample grid, like script
#      05, so both windows rasterize the same spatial extent per analysis
#      unit (see the note where grade_urb is built, below).
#
# Inputs:
#   data/processed_data/03_urban_footprint/grade_ibge_2010.parquet        (script 03)
#   data/raw_data/03_urban_footprint/ghsl_raw/GHS_BUILT_S_E2000_*.tif  (script 02)
#   data/raw_data/03_urban_footprint/ghsl_raw/GHS_POP_E2000_*.tif      (script 02)
#   data/raw_data/03_urban_footprint/ghsl_raw/GHS_POP_E2010_*.tif      (script 02)
#   data/processed_data/03_urban_footprint/amostra_municipios.rds         (script 01)
#
# Outputs (data/processed_data/03_urban_footprint/):
#   crescimento_urbano/grade_crescimento_2000_2010_g2010.parquet
#   metricas/metricas_crescimento_2000_2010.csv
#   metricas/metricas_crescimento_2000_2010_arranjo.csv
# =============================================================================

source("03_urban_footprint_and_growth_types/00_setup.R")

library(terra)
library(exactextractr)
library(sf)
library(sfarrow)
library(arrow)
library(dplyr)
library(tidyr)
library(readr)

cat("\n", strrep("=", 60), "\n")
cat("06_CLASSIFY_GROWTH_TYPES_2000_2010.R\n")
cat(strrep("=", 60), "\n")

# =============================================================================
# PARAMETERS
# =============================================================================

LIMIAR_BUILT      <- 10    # minimum % built-up for a cell to be urban
LIMIAR_DENS       <- 300   # minimum inhabitants/km^2 (same as script 04)
LIMIAR_DENSIF     <- 1     # delta built > 1 p.p. -> densification
LIMIAR_EXTENSION  <- 1000  # meters: <= 1000m -> extension; > -> leapfrog
RESOLUCAO         <- 200   # meters (raster template)
CONECTIVIDADE_HOLES <- 4   # Rook (4 directions) for topological holes
POP_PATCH_A       <- 5000  # patch total pop > 5000 -> criterion A
DENS_PATCH_B      <- 1500  # density >= 1500 inhabitants/km^2 -> criterion B
FILTRO_UF         <- NULL  # "PR" for testing; NULL = all of Brazil

cat(sprintf("  Urban criterion   : built_pct >= %g%% AND dens >= %g inhab/km^2\n",
            LIMIAR_BUILT, LIMIAR_DENS))
cat(sprintf("  Major patch       : pop > %d AND dens >= %d inhab/km^2\n",
            POP_PATCH_A, DENS_PATCH_B))
cat(sprintf("  Extension/leapfrog: %dm | Densif.: delta > %g p.p.\n",
            LIMIAR_EXTENSION, LIMIAR_DENSIF))
if (!is.null(FILTRO_UF))
  cat(sprintf("  *** TEST MODE: UF = %s ***\n", FILTRO_UF))

# =============================================================================
# GHSL RASTER PATHS
# =============================================================================

ghsl_dir <- file.path(raw_data_dir, "ghsl_raw")

path_built_2000 <- file.path(ghsl_dir,
  "GHS_BUILT_S_E2000_GLOBE_R2023A_54009_100_V1_0.tif")
path_pop_2000   <- file.path(ghsl_dir,
  "GHS_POP_E2000_GLOBE_R2023A_54009_100_V1_0.tif")
path_pop_2010   <- file.path(ghsl_dir,
  "GHS_POP_E2010_GLOBE_R2023A_54009_100_V1_0.tif")

for (p in c(path_built_2000, path_pop_2000, path_pop_2010)) {
  if (!file.exists(p))
    stop("GHSL raster not found: ", p,
         "\n  Run 02_download_ghsl_data.R first.")
}

# =============================================================================
# 1) LOAD THE 2010 IBGE GRID (script 03)
# =============================================================================

cat("\n1) Loading the 2010 IBGE grid (script 03)...\n")

grade_path <- file.path(processed_data_dir, "grade_ibge_2010.parquet")
if (!file.exists(grade_path))
  stop("grade_ibge_2010.parquet not found -- run script 03 first.\n",
       "  Expected at: ", grade_path)

t0    <- Sys.time()
grade <- sfarrow::st_read_parquet(grade_path)
cat(sprintf("  %s cells (%.1f min)\n",
            fmt(nrow(grade)),
            as.numeric(difftime(Sys.time(), t0, units = "mins"))))

# Ensure a metric CRS (EPSG:5880)
if (is.na(st_crs(grade))) {
  st_crs(grade) <- 5880
} else if (!isTRUE(st_crs(grade)$epsg == 5880)) {
  cat("  Reprojecting to EPSG:5880...\n")
  grade <- st_transform(grade, 5880)
}

# Required columns coming from script 03
cols_necessarias <- c("cod_mun", "populacao", "area_total", "built_pct_2010")
faltando <- setdiff(cols_necessarias, names(grade))
if (length(faltando) > 0)
  stop("Missing columns in the grid (run script 03): ",
       paste(faltando, collapse = ", "))

cat(sprintf("  Available columns: %d\n", ncol(grade)))
cat(sprintf("  built_pct_2010 > 0 : %s cells\n",
            fmt(sum(grade$built_pct_2010 > 0, na.rm = TRUE))))

if (!is.null(FILTRO_UF))
  grade <- grade %>%
    filter(substr(as.character(cod_mun), 1, 2) == FILTRO_UF)

# =============================================================================
# 2) LOAD THE SAMPLE AND FILTER THE GRID
# =============================================================================

cat("\n2) Loading the municipality sample...\n")

# Priority: the regression2 sample; fallback: the UFM pipeline sample
reg2_csv <- file.path(here::here(), "regression2", "data", "amostra_universo.csv")
ufm_rds  <- file.path(processed_data_dir, "amostra_municipios.rds")

if (file.exists(reg2_csv)) {
  cat("  Source: regression2/data/amostra_universo.csv\n")
  amostra <- read_csv(reg2_csv, show_col_types = FALSE) %>%
    mutate(cod_mun   = as.character(as.integer(as.double(cod_mun))),
           CD_CIDADE = as.double(CD_CIDADE))
} else if (file.exists(ufm_rds)) {
  cat("  Source: amostra_municipios.rds\n")
  amostra <- readRDS(ufm_rds) %>%
    mutate(cod_mun   = as.character(as.integer(cod_mun)),
           CD_CIDADE = as.double(CD_CIDADE))
} else {
  stop("No sample found. Run script 01 or regression2/01.")
}

if (!is.null(FILTRO_UF))
  amostra <- amostra %>%
    filter(substr(as.character(cod_mun), 1, 2) == FILTRO_UF)

amostra <- amostra %>%
  mutate(unidade_id = ifelse(
    !is.na(CD_CIDADE),
    paste0("arranjo_", CD_CIDADE),
    paste0("mun_", cod_mun)
  ))

n_before <- nrow(grade)
grade <- grade %>%
  mutate(cod_mun = as.character(cod_mun)) %>%
  inner_join(
    amostra %>% select(cod_mun, CD_CIDADE, unidade_id) %>% distinct(),
    by = "cod_mun"
  )

unidades <- sort(unique(grade$unidade_id))
cat(sprintf("  %d municipalities | %d cells (of %s in the full grid)\n",
            n_distinct(amostra$cod_mun), nrow(grade), fmt(n_before)))
cat(sprintf("  %d analysis units (%d arrangements, %d isolated)\n",
            length(unidades),
            sum(grepl("^arranjo_", unidades)),
            sum(grepl("^mun_",     unidades))))

# =============================================================================
# 3) EXTRACT GHSL PER CELL (exact_extract)
#
# For each raster: reproject the grid to Mollweide (GHSL's native CRS), sum
# pixels within each IBGE cell, compute the derived metric.
#
# GHS-BUILT-S: value in m^2 -> built_pct = sum(m^2) / (n_pixels * 10000) * 100
# GHS-POP    : value in inhabitants -> pop_ghsl = sum(inhabitants) (direct sum)
# =============================================================================

cat("\n3) Extracting GHSL rasters per cell (exact_extract)...\n")

extrair_ghsl <- function(path_raster, grade_sf, suffixo, tipo = c("built", "pop")) {
  tipo <- match.arg(tipo)
  cat(sprintf("  %s ...\n", basename(path_raster)))

  r <- rast(path_raster)
  cat(sprintf("    Raster CRS: %s\n", crs(r, describe = TRUE)$name))

  grade_mol <- st_transform(grade_sf, crs = crs(r))

  t0  <- Sys.time()
  ext <- exact_extract(r, grade_mol, fun = c("sum", "count"), progress = TRUE)
  cat(sprintf("    exact_extract: %.1f min\n",
              as.numeric(difftime(Sys.time(), t0, units = "mins"))))

  rm(r, grade_mol); gc()

  if (tipo == "built") {
    # built-up m^2 / (n_pixels * 10,000 m^2/pixel) * 100 = %
    n_px  <- replace_na(ext[["count"]], 0)
    m2    <- pmax(0, replace_na(ext[["sum"]], 0))
    res   <- list()
    res[[paste0("built_m2_",  suffixo)]] <- m2
    res[[paste0("n_pixels_",  suffixo)]] <- n_px
    res[[paste0("built_pct_", suffixo)]] <- if_else(n_px > 0, m2 / (n_px * 10000) * 100, 0)
    res
  } else {
    # inhabitants -- direct sum (GHSL pixels are already in inhabitants)
    res  <- list()
    res[[paste0("pop_ghsl_", suffixo)]] <- pmax(0, replace_na(ext[["sum"]], 0))
    res
  }
}

# Extract the 3 rasters
res_built_2000 <- extrair_ghsl(path_built_2000, grade, "2000", "built")
res_pop_2000   <- extrair_ghsl(path_pop_2000,   grade, "2000", "pop")
res_pop_2010   <- extrair_ghsl(path_pop_2010,   grade, "2010", "pop")

# Join results onto the grid
grade <- grade %>%
  mutate(
    !!!res_built_2000,
    !!!res_pop_2000,
    !!!res_pop_2010
  )

rm(res_built_2000, res_pop_2000, res_pop_2010); gc()

cat(sprintf("\n  built_pct_2000 > 0 : %s cells\n",
            fmt(sum(grade$built_pct_2000 > 0, na.rm = TRUE))))
cat(sprintf("  pop_ghsl_2000  > 0 : %s cells\n",
            fmt(sum(grade$pop_ghsl_2000  > 0, na.rm = TRUE))))
cat(sprintf("  pop_ghsl_2010  > 0 : %s cells\n",
            fmt(sum(grade$pop_ghsl_2010  > 0, na.rm = TRUE))))

# =============================================================================
# 4) CLASSIFY URBAN EXTENT FOR 2000 AND 2010 (AND logic -- same as script 04)
# =============================================================================

cat("\n4) Classifying urban extent...\n")

grade <- grade %>%
  mutate(
    dens_ghsl_2000   = pop_ghsl_2000 / (area_total / 1e6),
    dens_ghsl_2010   = pop_ghsl_2010 / (area_total / 1e6),
    urbano_2000      = !is.na(built_pct_2000) & built_pct_2000 >= LIMIAR_BUILT &
                       !is.na(dens_ghsl_2000) & dens_ghsl_2000 >= LIMIAR_DENS,
    urbano_2010_ghsl = !is.na(built_pct_2010) & built_pct_2010 >= LIMIAR_BUILT &
                       !is.na(dens_ghsl_2010) & dens_ghsl_2010 >= LIMIAR_DENS
  )

cat(sprintf("  Urban cells in 2000       : %s (%.1f%%)\n",
            fmt(sum(grade$urbano_2000)),
            100 * mean(grade$urbano_2000, na.rm = TRUE)))
cat(sprintf("  Urban cells in 2010 (GHSL): %s (%.1f%%)\n",
            fmt(sum(grade$urbano_2010_ghsl)),
            100 * mean(grade$urbano_2010_ghsl, na.rm = TRUE)))
cat(sprintf("  New 2000->2010            : %s\n",
            fmt(sum(!grade$urbano_2000 & grade$urbano_2010_ghsl, na.rm = TRUE))))

# No urban-only pre-filter -- process the full sample grid, same as script
# 05. Restricting to urban-at-either-year cells here would shrink the raster
# template's bounding box per analysis unit, which can make the
# interior/exterior test used for infill detection touch the template edge
# spuriously near real holes. Cells not urban at either point in time still
# end up NA (see the classification loop and its final override), so this
# only changes which cells sit in the intermediate grid, not the result.
grade_urb <- grade

cat(sprintf("\n  Cells in the sample grid: %s\n", fmt(nrow(grade_urb))))

rm(grade); gc()

# =============================================================================
# 5) CLASSIFICATION FUNCTION (copied from script 05, no logic change)
# =============================================================================

classificar_crescimento <- function(celulas,
                                    col_urb_t1, col_urb_t2,
                                    col_built_t1, col_built_t2,
                                    col_pop,
                                    resolucao     = RESOLUCAO,
                                    limiar_ext    = LIMIAR_EXTENSION,
                                    limiar_densif = LIMIAR_DENSIF,
                                    conect_holes  = CONECTIVIDADE_HOLES,
                                    pop_patch_a   = POP_PATCH_A,
                                    dens_patch_b  = DENS_PATCH_B) {

  n         <- nrow(celulas)
  resultado <- rep(NA_character_, n)

  urb_t1_vec   <- as.integer(celulas[[col_urb_t1]])
  urb_t2_vec   <- as.integer(celulas[[col_urb_t2]])
  built_t1_vec <- as.numeric(celulas[[col_built_t1]]); built_t1_vec[is.na(built_t1_vec)] <- 0
  built_t2_vec <- as.numeric(celulas[[col_built_t2]]); built_t2_vec[is.na(built_t2_vec)] <- 0

  if (!any(urb_t1_vec == 1, na.rm = TRUE) && !any(urb_t2_vec == 1, na.rm = TRUE))
    return(resultado)

  celulas$zurb1   <- ifelse(is.na(urb_t1_vec), 0L, urb_t1_vec)
  celulas$zurb2   <- ifelse(is.na(urb_t2_vec), 0L, urb_t2_vec)
  celulas$zbuilt1 <- built_t1_vec
  celulas$zbuilt2 <- built_t2_vec

  # -- Raster template (EPSG:5880, 2-cell buffer) -----------------------------
  centroides <- st_centroid(celulas)
  coords     <- st_coordinates(centroides)
  x_range    <- range(coords[, "X"], na.rm = TRUE)
  y_range    <- range(coords[, "Y"], na.rm = TRUE)
  crs_wkt    <- st_crs(celulas)$wkt

  template <- rast(
    xmin = floor(x_range[1]   / resolucao) * resolucao - 2 * resolucao,
    xmax = ceiling(x_range[2] / resolucao) * resolucao + 2 * resolucao,
    ymin = floor(y_range[1]   / resolucao) * resolucao - 2 * resolucao,
    ymax = ceiling(y_range[2] / resolucao) * resolucao + 2 * resolucao,
    res  = resolucao,
    crs  = crs_wkt
  )
  if (ncol(template) < 1 || nrow(template) < 1) return(resultado)

  sv_pts  <- vect(centroides)
  sv_poly <- vect(celulas)

  # -- Rasterize polygons -------------------------------------------------------
  r_urb_t1   <- rasterize(sv_poly, template, field = "zurb1",   fun = "max")
  r_urb_t2   <- rasterize(sv_poly, template, field = "zurb2",   fun = "max")
  r_built_t1 <- rasterize(sv_poly, template, field = "zbuilt1", fun = "mean")
  r_built_t2 <- rasterize(sv_poly, template, field = "zbuilt2", fun = "mean")

  ncells <- ncell(template)
  v_t1   <- values(r_urb_t1)[, 1]
  v_t2   <- values(r_urb_t2)[, 1]
  v_bt1  <- values(r_built_t1)[, 1]; v_bt1[is.na(v_bt1)] <- 0
  v_bt2  <- values(r_built_t2)[, 1]; v_bt2[is.na(v_bt2)] <- 0

  # -- t1 patches: Major (A AND B) vs Minor --------------------------------------
  is_major <- rep(FALSE, ncells)

  if (any(!is.na(v_t1) & v_t1 == 1)) {
    v_urb_m <- rep(NA_real_, ncells)
    v_urb_m[!is.na(v_t1) & v_t1 == 1] <- 1
    r_urb_patches <- patches(setValues(rast(template), v_urb_m), directions = 8)
    v_urb_patches <- values(r_urb_patches)[, 1]

    patch_at_cell <- terra::extract(r_urb_patches, sv_pts)[, 2]
    pop_cell  <- as.numeric(celulas[[col_pop]]); pop_cell[is.na(pop_cell)] <- 0
    area_km2  <- as.numeric(celulas$area_total) / 1e6

    df_p <- data.frame(pid = patch_at_cell, pop = pop_cell, area = area_km2)
    df_p <- df_p[!is.na(df_p$pid), ]

    if (nrow(df_p) > 0) {
      ps      <- aggregate(cbind(pop, area) ~ pid, data = df_p, FUN = sum)
      ps$dens <- ps$pop / pmax(ps$area, 1e-9)
      major_ids <- ps$pid[ps$pop > pop_patch_a & ps$dens >= dens_patch_b]
      is_major[!is.na(v_urb_patches) & v_urb_patches %in% major_ids] <- TRUE
    }
  }

  is_c_urban   <- (!is.na(v_t1) & v_t1 == 1) & !is_major
  is_shrinkage <- (!is.na(v_t1) & v_t1 == 1) & (is.na(v_t2) | v_t2 == 0)
  is_growth    <- (!is.na(v_t2) & v_t2 == 1) & (is.na(v_t1) | v_t1 == 0)

  # -- Infill: topological holes in t1 major patches (Rook) ----------------------
  ids_buracos_major <- integer(0)
  r_holes <- NULL

  if (any(is_major)) {
    v_non_major <- rep(NA_real_, ncells)
    v_non_major[!is_major] <- 1
    r_holes <- patches(setValues(rast(template), v_non_major),
                       directions = conect_holes)

    nr <- nrow(r_holes); nc <- ncol(r_holes)
    borda_cells <- unique(c(
      cellFromRowCol(r_holes, rep(1,  nc), 1:nc),
      cellFromRowCol(r_holes, rep(nr, nc), 1:nc),
      cellFromRowCol(r_holes, 1:nr, rep(1,  nr)),
      cellFromRowCol(r_holes, 1:nr, rep(nc, nr))
    ))
    vals_borda        <- values(r_holes)[borda_cells, 1]
    ids_borda         <- unique(vals_borda[!is.na(vals_borda)])
    todos_ids         <- unique(values(r_holes)[!is.na(values(r_holes)[, 1]), 1])
    ids_buracos_major <- setdiff(todos_ids, ids_borda)
  }

  is_buraco_major <- rep(FALSE, ncells)
  if (length(ids_buracos_major) > 0) {
    v_h <- values(r_holes)[, 1]
    is_buraco_major <- !is.na(v_h) & v_h %in% ids_buracos_major
  }
  is_infill <- is_growth & is_buraco_major

  # -- Extension vs Leapfrog ------------------------------------------------------
  is_growth_sem_infill <- is_growth & !is_infill

  if (any(is_major)) {
    v_m          <- rep(NA_real_, ncells)
    v_m[is_major] <- 1
    v_dist_major <- values(distance(setValues(rast(template), v_m)))[, 1]
  } else {
    v_dist_major <- rep(Inf, ncells)
  }

  is_extension <- is_growth_sem_infill & (v_dist_major <= limiar_ext)
  is_leapfrog  <- is_growth_sem_infill & (v_dist_major >  limiar_ext)

  # -- Consolidated / Densification / Peripheral -----------------------------------
  is_continuing_major <- is_major & (!is.na(v_t2) & v_t2 == 1)
  v_delta             <- v_bt2 - v_bt1
  is_densification    <- is_continuing_major & (v_delta > limiar_densif)
  is_consolidated     <- (is_continuing_major & (v_delta <= limiar_densif)) | is_shrinkage
  is_peripheral       <- is_c_urban & (!is.na(v_t2) & v_t2 == 1)

  # -- Assemble the result and extract at centroids --------------------------------
  v_class <- rep(NA_integer_, ncells)
  v_class[is_consolidated]  <- 1L
  v_class[is_densification] <- 2L
  v_class[is_infill]        <- 3L
  v_class[is_extension]     <- 4L
  v_class[is_leapfrog]      <- 5L
  v_class[is_peripheral]    <- 6L

  r_class    <- setValues(rast(template), v_class)
  vals_class <- terra::extract(r_class, sv_pts)[, 2]

  labels    <- c("consolidated", "densification", "infill",
                 "extension", "leapfrog", "peripheral")
  resultado <- ifelse(is.na(vals_class), NA_character_, labels[vals_class])
  resultado[(is.na(urb_t1_vec) | urb_t1_vec != 1) &
            (is.na(urb_t2_vec) | urb_t2_vec != 1)] <- NA_character_

  gc(verbose = FALSE)
  resultado
}

# =============================================================================
# 6) CLASSIFICATION LOOP OVER ANALYSIS UNITS
# =============================================================================

cat("\n6) Classifying 2000->2010 growth...\n")
cat(sprintf("   %d analysis units\n", length(unidades)))

grade_urb$tipo_crescimento_0010 <- NA_character_
n_erro <- 0
t0_total <- Sys.time()

for (i in seq_along(unidades)) {
  uid <- unidades[i]
  idx <- which(grade_urb$unidade_id == uid)
  if (length(idx) == 0) next

  # Single-cell unit -- same Major/Minor check as the multi-cell path (script
  # 05's equivalent block): urban at both points in time is NOT peripheral by
  # default -- it's densification/consolidated if the cell alone clears the
  # Major-patch bar (pop_ghsl_2000 > POP_PATCH_A AND density >= DENS_PATCH_B),
  # and only falls back to peripheral otherwise.
  if (length(idx) < 2) {
    urb_t1_val <- ifelse(is.na(as.integer(grade_urb$urbano_2000[idx])), 0L,
                         as.integer(grade_urb$urbano_2000[idx]))
    urb_t2_val <- ifelse(is.na(as.integer(grade_urb$urbano_2010_ghsl[idx])), 0L,
                         as.integer(grade_urb$urbano_2010_ghsl[idx]))

    if (urb_t1_val == 1 && urb_t2_val == 1) {
      pop_val  <- ifelse(is.na(grade_urb$pop_ghsl_2000[idx]), 0,
                         as.numeric(grade_urb$pop_ghsl_2000[idx]))
      area_val <- ifelse(is.na(grade_urb$area_total[idx]), 1e-9,
                         as.numeric(grade_urb$area_total[idx])) / 1e6
      dens_val <- pop_val / pmax(area_val, 1e-9)
      if (pop_val > POP_PATCH_A && dens_val >= DENS_PATCH_B) {
        b_t2 <- ifelse(is.na(grade_urb$built_pct_2010[idx]), 0, grade_urb$built_pct_2010[idx])
        b_t1 <- ifelse(is.na(grade_urb$built_pct_2000[idx]), 0, grade_urb$built_pct_2000[idx])
        grade_urb$tipo_crescimento_0010[idx] <- ifelse(
          (b_t2 - b_t1) > LIMIAR_DENSIF, "densification", "consolidated"
        )
      } else {
        grade_urb$tipo_crescimento_0010[idx] <- "peripheral"
      }
    } else if (urb_t1_val == 0 && urb_t2_val == 1) {
      grade_urb$tipo_crescimento_0010[idx] <- "leapfrog"
    } else if (urb_t1_val == 1 && urb_t2_val == 0) {
      grade_urb$tipo_crescimento_0010[idx] <- "consolidated"  # shrinkage
    }
    next
  }

  tryCatch({
    tipos <- classificar_crescimento(
      celulas      = grade_urb[idx, ],
      col_urb_t1   = "urbano_2000",
      col_urb_t2   = "urbano_2010_ghsl",
      col_built_t1 = "built_pct_2000",
      col_built_t2 = "built_pct_2010",
      col_pop      = "pop_ghsl_2000"   # t1=2000 population for major/minor patches
    )
    grade_urb$tipo_crescimento_0010[idx] <- tipos
  }, error = function(e) {
    n_erro <<- n_erro + 1
    if (n_erro <= 5)
      message(sprintf("  [ERROR %s]: %s", uid, conditionMessage(e)))
  })

  if (i %% 20 == 0 || i == length(unidades)) {
    elapsed <- as.numeric(difftime(Sys.time(), t0_total, units = "mins"))
    cat(sprintf("\r  [%d/%d] %.1f min | %d errors",
                i, length(unidades), elapsed, n_erro))
    flush.console()
  }
}

cat("\n")
if (n_erro > 0)
  cat(sprintf("  WARNING: %d units failed classification.\n", n_erro))

# Diagnostics
tab <- sort(table(grade_urb$tipo_crescimento_0010, useNA = "ifany"), decreasing = TRUE)
cat("\n  Distribution of 2000->2010 types:\n")
total_class <- sum(tab[!is.na(names(tab))])
for (i in seq_along(tab)) {
  nm  <- names(tab)[i]
  n   <- tab[i]
  pct <- if (isTRUE(!is.na(nm)) && total_class > 0) sprintf(" (%.1f%%)", 100 * n / total_class) else ""
  cat(sprintf("    %-16s : %s%s\n",
              if (is.na(nm)) "NA (not urban)" else nm, fmt(n), pct))
}

# =============================================================================
# 7) AGGREGATE METRICS BY MUNICIPALITY
# =============================================================================

cat("\n7) Aggregating metrics by municipality...\n")

tipos_ordem <- c("consolidated", "densification", "peripheral",
                 "infill", "extension", "leapfrog")

grade_tbl <- grade_urb %>%
  st_drop_geometry() %>%
  filter(!is.na(tipo_crescimento_0010))

# Area by type by municipality
area_tipo_mun <- grade_tbl %>%
  group_by(cod_mun, tipo_crescimento_0010) %>%
  summarise(area_m2 = sum(area_total, na.rm = TRUE), .groups = "drop") %>%
  pivot_wider(
    names_from   = tipo_crescimento_0010,
    names_prefix = "area_m2_",
    values_from  = area_m2,
    values_fill  = 0
  )

for (t in tipos_ordem) {
  col <- paste0("area_m2_", t)
  if (!col %in% names(area_tipo_mun)) area_tipo_mun[[col]] <- 0
}

area_total_mun <- grade_tbl %>%
  group_by(cod_mun) %>%
  summarise(area_urban_2010_m2 = sum(area_total, na.rm = TRUE), .groups = "drop")

metricas_mun <- area_total_mun %>%
  left_join(area_tipo_mun, by = "cod_mun") %>%
  mutate(
    pct_urban_growth_0010      = 100 * (area_m2_infill + area_m2_extension +
                                         area_m2_leapfrog) /
                                        pmax(area_urban_2010_m2, 1),
    pct_area_densif_0010       = 100 * area_m2_densification / pmax(area_urban_2010_m2, 1),
    pct_area_consolidated_0010 = 100 * area_m2_consolidated  / pmax(area_urban_2010_m2, 1),
    pct_area_peripheral_0010   = 100 * area_m2_peripheral    / pmax(area_urban_2010_m2, 1),
    pct_area_infill_0010       = 100 * area_m2_infill        / pmax(area_urban_2010_m2, 1),
    pct_area_extension_0010    = 100 * area_m2_extension     / pmax(area_urban_2010_m2, 1),
    pct_area_leapfrog_0010     = 100 * area_m2_leapfrog      / pmax(area_urban_2010_m2, 1),
    # synthetic treatment variables (used in the regression stage)
    pct_area_densif_infill_0010      = pct_area_densif_0010 + pct_area_infill_0010,
    pct_area_periph_ext_leap_0010    = pct_area_peripheral_0010 +
                                       pct_area_extension_0010  +
                                       pct_area_leapfrog_0010
  )

cat(sprintf("  %d municipalities with metrics\n", nrow(metricas_mun)))

# Average distance of densification+infill cells to the municipal centroid
# (proxy for how far from the core the compact expansion happened)
centroides_mun <- grade_urb %>%
  group_by(cod_mun) %>%
  summarise(.groups = "drop") %>%
  st_centroid()

cells_densif <- grade_urb %>%
  filter(tipo_crescimento_0010 %in% c("densification", "infill")) %>%
  st_centroid()

if (nrow(cells_densif) > 0) {
  nearest_idx <- st_nearest_feature(cells_densif,
                                    centroides_mun[match(cells_densif$cod_mun,
                                                         centroides_mun$cod_mun), ])
  cells_densif$dist_m <- as.numeric(st_distance(
    cells_densif,
    centroides_mun[match(cells_densif$cod_mun, centroides_mun$cod_mun), ],
    by_element = TRUE
  ))

  dist_densif_mun <- cells_densif %>%
    st_drop_geometry() %>%
    group_by(cod_mun) %>%
    summarise(
      dist_media_m_densif_0010       = mean(dist_m, na.rm = TRUE),
      dist_media_m_densif_infill_0010 = mean(dist_m, na.rm = TRUE),
      .groups = "drop"
    )

  metricas_mun <- metricas_mun %>%
    mutate(cod_mun = as.character(cod_mun)) %>%
    left_join(dist_densif_mun %>% mutate(cod_mun = as.character(cod_mun)),
              by = "cod_mun")
} else {
  metricas_mun <- metricas_mun %>%
    mutate(cod_mun = as.character(cod_mun),
           dist_media_m_densif_0010        = NA_real_,
           dist_media_m_densif_infill_0010 = NA_real_)
}

rm(centroides_mun, cells_densif); gc()

# =============================================================================
# 8) AGGREGATE BY ARRANGEMENT
# =============================================================================

cat("\n8) Aggregating by arrangement...\n")

cols_abs <- c("area_urban_2010_m2", paste0("area_m2_", tipos_ordem))

metricas_arr <- metricas_mun %>%
  left_join(
    amostra %>% select(cod_mun, CD_CIDADE) %>% distinct(),
    by = "cod_mun"
  ) %>%
  mutate(
    cod_mun_d = as.double(cod_mun),
    CD_CIDADE = if_else(is.na(CD_CIDADE), cod_mun_d, CD_CIDADE)
  ) %>%
  select(-cod_mun_d) %>%
  group_by(CD_CIDADE) %>%
  summarise(
    across(all_of(cols_abs), ~ sum(.x, na.rm = TRUE)),
    .groups = "drop"
  ) %>%
  mutate(
    pct_urban_growth_0010      = 100 * (area_m2_infill + area_m2_extension +
                                         area_m2_leapfrog) /
                                        pmax(area_urban_2010_m2, 1),
    pct_area_densif_0010       = 100 * area_m2_densification / pmax(area_urban_2010_m2, 1),
    pct_area_consolidated_0010 = 100 * area_m2_consolidated  / pmax(area_urban_2010_m2, 1),
    pct_area_peripheral_0010   = 100 * area_m2_peripheral    / pmax(area_urban_2010_m2, 1),
    pct_area_infill_0010       = 100 * area_m2_infill        / pmax(area_urban_2010_m2, 1),
    pct_area_extension_0010    = 100 * area_m2_extension     / pmax(area_urban_2010_m2, 1),
    pct_area_leapfrog_0010     = 100 * area_m2_leapfrog      / pmax(area_urban_2010_m2, 1),
    pct_area_densif_infill_0010   = pct_area_densif_0010 + pct_area_infill_0010,
    pct_area_periph_ext_leap_0010 = pct_area_peripheral_0010 +
                                    pct_area_extension_0010  +
                                    pct_area_leapfrog_0010
  )

cat(sprintf("  %d arrangements with metrics\n", nrow(metricas_arr)))

# =============================================================================
# 9) SAVE OUTPUTS
# =============================================================================

cat("\n9) Saving outputs...\n")

dir_cresc <- file.path(processed_data_dir, "crescimento_urbano")
dir_metr  <- file.path(processed_data_dir, "metricas")
dir.create(dir_cresc, recursive = TRUE, showWarnings = FALSE)
dir.create(dir_metr,  recursive = TRUE, showWarnings = FALSE)

sufixo <- if (!is.null(FILTRO_UF)) paste0("_", FILTRO_UF) else ""

# Cell-level parquet (no geometry -- only the classified urban footprint)
parquet_path <- file.path(dir_cresc,
  paste0("grade_crescimento_2000_2010_g2010", sufixo, ".parquet"))
grade_urb %>%
  st_drop_geometry() %>%
  select(any_of(c("ID_UNICO", "id_celula")), cod_mun, CD_CIDADE, unidade_id,
         built_pct_2000, built_m2_2000, built_pct_2010,
         pop_ghsl_2000, pop_ghsl_2010,
         dens_ghsl_2000, dens_ghsl_2010,
         urbano_2000, urbano_2010_ghsl,
         tipo_crescimento_0010) %>%
  write_parquet(parquet_path)
cat(sprintf("  - %s  (%s rows)\n",
            basename(parquet_path), fmt(nrow(grade_urb))))

# Municipality-level CSV
mun_path <- file.path(dir_metr,
  paste0("metricas_crescimento_2000_2010", sufixo, ".csv"))
write_csv(metricas_mun, mun_path)
cat(sprintf("  - %s  (%d rows)\n", basename(mun_path), nrow(metricas_mun)))

# Arrangement-level CSV
arr_path <- file.path(dir_metr,
  paste0("metricas_crescimento_2000_2010_arranjo", sufixo, ".csv"))
write_csv(metricas_arr, arr_path)
cat(sprintf("  - %s  (%d rows)\n", basename(arr_path), nrow(metricas_arr)))

cat("\n", strrep("=", 60), "\n")
cat("DONE\n")
cat(strrep("=", 60), "\n")
cat("\nVariables generated by municipality and arrangement:\n")
cat("  pct_urban_growth_0010         : % of the 2010 urban footprint that is new\n")
cat("  pct_area_densif_0010          : densification\n")
cat("  pct_area_consolidated_0010    : consolidated\n")
cat("  pct_area_peripheral_0010      : peripheral\n")
cat("  pct_area_infill_0010          : infill\n")
cat("  pct_area_extension_0010       : extension\n")
cat("  pct_area_leapfrog_0010        : leapfrog\n")
cat("  pct_area_densif_infill_0010   : [TREATMENT] compact = densif + infill\n")
cat("  pct_area_periph_ext_leap_0010 : [TREATMENT] sprawl = periph + ext + leap\n")
cat("\nFiles ready for ingestion by 14_independent_variables.R\n")
