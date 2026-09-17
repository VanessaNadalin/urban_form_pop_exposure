# =============================================================================
# 05_classify_growth_types.R
# Classify urban growth type and carry susceptibility + AGSN through, on the
# single 2010-2022 common grid.
#
# Per MIGRATION_PLAN.md 6b0 (common-grid unification, decided 2026-08-28):
# this classification now runs ONCE, on the common grid built by scripts
# 03/04, instead of twice (once per native grid, reconciled afterwards via a
# cross-grid join in the old script 06). There is a single tipo_crescimento
# per cell -- no more "grade 2022 run" vs. "grade 2010 run" to reconcile.
#
# Major/minor patch sizing (col_pop below) uses pop_2010_alocada -- the
# allocated t1 (2010) population -- rather than populacao (t2/2022), because
# patches are themselves a t1 concept (POP_PATCH_A/DENS_PATCH_B are
# evaluated on the t1-urban patch). Under the pre-unification design, the
# "primary" run (on the 2022 grid) had no real t1 population available and
# used pop_2022 as a best-available proxy for both t1 and t2; 6b0 asks for
# urban classification and density to use the newly available, correctly
# allocated 2010 population instead of that proxy -- this is the intended,
# disclosed effect of the unification, not an incidental change. It is one
# of the things the mandatory Table 1/Figure 2 comparison (6b0 item 3)
# checks for.
#
# Growth classes (6):
#   consolidated  - urban t1->t2, delta built <= threshold, major patch; or shrinkage
#   densification - urban t1->t2, delta built > threshold, major patch
#   infill        - new cell in a major patch's topological hole
#   extension     - new cell <= 1000m from a major patch
#   leapfrog      - new cell > 1000m from a major patch
#   peripheral    - urban t1->t2 in a minor patch
#
# Susceptibility/AGSN columns carried through (medium dropped 2026-08-21,
# Migrate Task 1c -- CLAUDE.md rule 9, high susceptibility only):
#   prop_suscept_alta        - share of the cell in high susceptibility
#   prop_suscept_total       - == prop_suscept_alta (name kept for compatibility)
#   prop_agsn                - total share of the cell in AGSN
#   prop_agsn_suscept_alta   - AGSN intersect high susceptibility
#   prop_agsn_suscept_total  - == prop_agsn_suscept_alta (name kept for compatibility)
#
# Inputs:
#   - grade_urban_form_2010_2022.parquet   (script 04)
#   - amostra_municipios.rds               (script 01)
#
# Note: susceptibility/AGSN/risk columns arrive already joined from script 03
# (via script 04, unchanged) -- this script does not re-join the gpkgs.
#
# Output:
#   - grade_growth_types_2010_2022.parquet   (common grid + tipo_crescimento)
#
# Next step: 07_aggregate_municipality_metrics.R
# =============================================================================

source("03_urban_footprint_and_growth_types/00_setup.R")

library(sfarrow)
library(terra)

# =============================================================================
# PARAMETERS
# =============================================================================

LIMIAR_EXTENSION    <- 1000  # meters: <=1000m = extension, >1000m = leapfrog
LIMIAR_DENSIF       <- 1     # percentage points of delta built-up
RESOLUCAO           <- 200   # meters (raster template resolution)
CONECTIVIDADE_HOLES <- 4     # Rook: connectivity for hole detection
POP_PATCH_A         <- 5000  # Type A criterion: patch total pop > 5000
DENS_PATCH_B        <- 1500  # Type B criterion: density >= 1500 inhab/km^2
# "Major" patch = Type A AND Type B; everything else is Minor (peripheral)

# Column used for major/minor patch sizing -- see header note.
COL_POP_PATCH <- "pop_2010_alocada"

FILTRO_UF <- NULL  # "PR" to test by UF, NULL for all of Brazil

cat("\n", strrep("=", 60), "\n")
cat("05_CLASSIFY_GROWTH_TYPES.R\n")
cat(strrep("=", 60), "\n")
cat(sprintf("  Extension/leapfrog threshold: %dm\n", LIMIAR_EXTENSION))
cat(sprintf("  Densification threshold:      delta > %g p.p.\n", LIMIAR_DENSIF))
cat(sprintf("  Raster resolution:            %dm\n", RESOLUCAO))
cat(sprintf("  Rasterization:                per polygon\n"))
cat(sprintf("  Holes connectivity:           %d (Rook)\n", CONECTIVIDADE_HOLES))
cat(sprintf("  Type A patch:                 pop total > %d\n", POP_PATCH_A))
cat(sprintf("  Type B patch:                 density >= %d inhab/km^2\n", DENS_PATCH_B))
cat(sprintf("  Patch sizing population:      %s\n", COL_POP_PATCH))
if (!is.null(FILTRO_UF)) {
  cat(sprintf("  *** TEST MODE: UF = %s ***\n", FILTRO_UF))
}

# =============================================================================
# 1) LOAD THE GRID FROM SCRIPT 04
# =============================================================================

cat("\n", strrep("=", 60), "\n")
cat("1) LOADING THE GRID\n")
cat(strrep("=", 60), "\n")

garantir_crs <- function(grade, nome) {
  if (is.na(st_crs(grade))) {
    warning(sprintf("Missing CRS in %s -- assuming EPSG:5880", nome))
    st_crs(grade) <- 5880
  } else if (!isTRUE(st_crs(grade)$epsg == 5880)) {
    cat(sprintf("  Reprojecting %s to EPSG:5880...\n", nome))
    grade <- st_transform(grade, 5880)
  }
  grade
}

cat("\nCommon grid (script 04)...\n")
t0 <- Sys.time()
grade <- sfarrow::st_read_parquet(
  file.path(processed_data_dir, "grade_urban_form_2010_2022.parquet")
)
cat(sprintf("  %s cells (%.1f min)\n",
            fmt(nrow(grade)),
            as.numeric(difftime(Sys.time(), t0, units = "mins"))))
grade <- garantir_crs(grade, "grade")

# =============================================================================
# 2) VALIDATE SUSCEPTIBILITY + AGSN (already joined by script 03)
# =============================================================================
# The prop_suscept_* and prop_agsn_* columns were correctly joined in script
# 03 by ID_UNICO, and passed through by script 04 unchanged. Do NOT re-join
# here: the Python gpkgs use id_celula as a sequential index, not as the
# IBGE cell identifier -- joining by id_celula would allocate susceptibility
# values to the WRONG cells.

cat("\n", strrep("=", 60), "\n")
cat("2) VALIDATING SUSCEPTIBILITY + AGSN (from script 03)\n")
cat(strrep("=", 60), "\n")

COLS_SUSCEPT_ESPERADAS <- c(
  "prop_suscept_alta", "prop_suscept_total",
  "prop_agsn", "prop_agsn_suscept_alta",
  "prop_agsn_suscept_total"
)

faltando <- setdiff(COLS_SUSCEPT_ESPERADAS, names(grade))
if (length(faltando) > 0) {
  stop(sprintf(
    paste0(
      "Missing susceptibility columns in the grid:\n  %s\n",
      "Re-run script 03 (03_integrate_grid_with_ghsl.R) to regenerate the parquet."
    ),
    paste(faltando, collapse = ", ")
  ))
}

# Recompute the derived total for consistency (does not change the base) --
# with no medio term, total always equals alta (name kept for compatibility)
grade <- grade |>
  mutate(
    prop_suscept_total      = prop_suscept_alta,
    prop_agsn_suscept_total = prop_agsn_suscept_alta
  )

cat(sprintf("  Cells with suscept_alta  > 0: %s\n",
            fmt(sum(grade$prop_suscept_alta  > 0, na.rm = TRUE))))
cat(sprintf("  Cells with suscept_total > 0: %s\n",
            fmt(sum(grade$prop_suscept_total > 0, na.rm = TRUE))))
cat(sprintf("  Cells with AGSN          > 0: %s\n",
            fmt(sum(grade$prop_agsn          > 0, na.rm = TRUE))))

# CPRM risk columns retired (MIGRATION_PLAN.md 6f.1) -- script 03 no longer
# carries prop_risco / prop_agsn_com_risco onto the common grid, and this was
# their only downstream reader.
# Coverage note: both sample subsets (with/without susceptibility) are covered
# because script 03 expands the grid to every sample municipality before
# scripts 04/05 process it.

# =============================================================================
# 3) DEFINE THE SAMPLE AND ANALYSIS UNITS
# =============================================================================

cat("\n", strrep("=", 60), "\n")
cat("3) DEFINING THE SAMPLE AND UNITS\n")
cat(strrep("=", 60), "\n")

sample_df <- readRDS(file.path(processed_data_dir, "amostra_municipios.rds"))
cat(sprintf("Municipalities in the sample: %d\n", nrow(sample_df)))

if (!is.null(FILTRO_UF)) {
  uf_codes <- list(
    "RO"="11","AC"="12","AM"="13","RR"="14","PA"="15","AP"="16","TO"="17",
    "MA"="21","PI"="22","CE"="23","RN"="24","PB"="25","PE"="26","AL"="27",
    "SE"="28","BA"="29","MG"="31","ES"="32","RJ"="33","SP"="35",
    "PR"="41","SC"="42","RS"="43","MS"="50","MT"="51","GO"="52","DF"="53"
  )
  sample_df <- sample_df |>
    filter(substr(cod_mun, 1, 2) == uf_codes[[FILTRO_UF]])
  cat(sprintf("After UF=%s filter: %d municipalities\n", FILTRO_UF, nrow(sample_df)))
}

sample_df <- sample_df |>
  mutate(
    unidade_id = ifelse(em_arranjo & !is.na(CD_CIDADE),
                        paste0("arranjo_", CD_CIDADE),
                        paste0("mun_", cod_mun))
  )

mun_unidade <- sample_df |> select(cod_mun, unidade_id)
unidades    <- unique(sample_df$unidade_id)

cat(sprintf("Analysis units: %d\n",         length(unidades)))
cat(sprintf("  Arrangements:        %d\n", sum(grepl("^arranjo_", unidades))))
cat(sprintf("  Isolated municipalities: %d\n", sum(grepl("^mun_",     unidades))))

# Filter the grid to the sample and add unidade_id
grade <- grade |>
  filter(cod_mun %in% sample_df$cod_mun) |>
  left_join(st_drop_geometry(mun_unidade), by = "cod_mun")

cat(sprintf("\nFiltered grid: %s cells\n", fmt(nrow(grade))))

# =============================================================================
# 4) CLASSIFICATION FUNCTION (v2)
# Per-polygon rasterization + Rook (4) + Major/Minor patches + peripheral
# =============================================================================

classificar_crescimento <- function(celulas,
                                    col_urb_t1, col_urb_t2,
                                    col_built_t1, col_built_t2,
                                    col_pop      = COL_POP_PATCH,
                                    resolucao    = RESOLUCAO,
                                    limiar_ext   = LIMIAR_EXTENSION,
                                    limiar_densif = LIMIAR_DENSIF,
                                    conect_holes = CONECTIVIDADE_HOLES,
                                    pop_patch_a  = POP_PATCH_A,
                                    dens_patch_b = DENS_PATCH_B) {

  n <- nrow(celulas)
  resultado <- rep(NA_character_, n)

  urb_t1_vec   <- as.integer(celulas[[col_urb_t1]])
  urb_t2_vec   <- as.integer(celulas[[col_urb_t2]])
  built_t1_vec <- as.numeric(celulas[[col_built_t1]]); built_t1_vec[is.na(built_t1_vec)] <- 0
  built_t2_vec <- as.numeric(celulas[[col_built_t2]]); built_t2_vec[is.na(built_t2_vec)] <- 0

  has_urb_t2 <- sum(urb_t2_vec == 1, na.rm = TRUE) > 0
  has_urb_t1 <- sum(urb_t1_vec == 1, na.rm = TRUE) > 0
  if (!has_urb_t1 && !has_urb_t2) return(resultado)

  celulas$zurb1   <- ifelse(is.na(urb_t1_vec), 0L, urb_t1_vec)
  celulas$zurb2   <- ifelse(is.na(urb_t2_vec), 0L, urb_t2_vec)
  celulas$zbuilt1 <- built_t1_vec
  celulas$zbuilt2 <- built_t2_vec

  # --- Raster template ---
  centroides <- st_centroid(celulas)
  coords     <- st_coordinates(centroides)
  x_range    <- range(coords[, "X"], na.rm = TRUE)
  y_range    <- range(coords[, "Y"], na.rm = TRUE)
  crs_wkt    <- st_crs(celulas)$wkt
  buf        <- 2

  template <- rast(
    xmin = floor(x_range[1]   / resolucao) * resolucao - buf * resolucao,
    xmax = ceiling(x_range[2] / resolucao) * resolucao + buf * resolucao,
    ymin = floor(y_range[1]   / resolucao) * resolucao - buf * resolucao,
    ymax = ceiling(y_range[2] / resolucao) * resolucao + buf * resolucao,
    res  = resolucao,
    crs  = crs_wkt
  )
  if (ncol(template) < 1 || nrow(template) < 1) return(resultado)

  sv_pts  <- vect(centroides)
  sv_poly <- vect(celulas)

  # --- Rasterize polygons (each 1km cell fills ~5x5 pixels) ---
  r_urb_t1   <- rasterize(sv_poly, template, field = "zurb1",   fun = "max")
  r_urb_t2   <- rasterize(sv_poly, template, field = "zurb2",   fun = "max")
  r_built_t1 <- rasterize(sv_poly, template, field = "zbuilt1", fun = "mean")
  r_built_t2 <- rasterize(sv_poly, template, field = "zbuilt2", fun = "mean")

  ncells <- ncell(template)
  v_t1   <- values(r_urb_t1)[, 1]
  v_t2   <- values(r_urb_t2)[, 1]
  v_bt1  <- values(r_built_t1)[, 1]; v_bt1[is.na(v_bt1)] <- 0
  v_bt2  <- values(r_built_t2)[, 1]; v_bt2[is.na(v_bt2)] <- 0

  has_urban <- any(!is.na(v_t1) & v_t1 == 1)

  # --- Classify t1 patches: Major (A AND B) vs Minor ---
  is_major <- rep(FALSE, ncells)

  if (has_urban) {
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
      ps        <- aggregate(cbind(pop, area) ~ pid, data = df_p, FUN = sum)
      ps$dens   <- ps$pop / pmax(ps$area, 1e-9)
      major_ids <- ps$pid[ps$pop > pop_patch_a & ps$dens >= dens_patch_b]
      is_major[!is.na(v_urb_patches) & v_urb_patches %in% major_ids] <- TRUE
    }
  }

  is_c_urban <- (!is.na(v_t1) & v_t1 == 1) & !is_major

  # --- Shrinkage and Growth ---
  is_shrinkage <- (!is.na(v_t1) & v_t1 == 1) & (is.na(v_t2) | v_t2 == 0)
  is_growth    <- (!is.na(v_t2) & v_t2 == 1) & (is.na(v_t1) | v_t1 == 0)

  # --- Internal holes in major patches (Infill) -- Rook (4) ---
  ids_buracos_major <- integer(0)
  r_holes <- NULL

  if (any(is_major)) {
    v_non_major <- rep(NA_real_, ncells)
    v_non_major[!is_major] <- 1
    r_holes <- patches(setValues(rast(template), v_non_major),
                       directions = conect_holes)

    nr <- nrow(r_holes); nc <- ncol(r_holes)
    borda_cells <- unique(c(
      cellFromRowCol(r_holes, rep(1, nc),  1:nc),
      cellFromRowCol(r_holes, rep(nr, nc), 1:nc),
      cellFromRowCol(r_holes, 1:nr, rep(1, nr)),
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

  # --- Extension vs Leapfrog (distance to major patches) ---
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

  # --- Consolidated / Densification / Peripheral ---
  is_continuing_major <- is_major & (!is.na(v_t2) & v_t2 == 1)
  v_delta             <- v_bt2 - v_bt1
  is_densification    <- is_continuing_major & (v_delta > limiar_densif)
  # shrinkage grouped into consolidated (occupation involution)
  is_consolidated     <- (is_continuing_major & (v_delta <= limiar_densif)) | is_shrinkage
  is_peripheral       <- is_c_urban & (!is.na(v_t2) & v_t2 == 1)

  # --- Assemble the classification and extract at centroids ---
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

  # Cells not urban at t1 nor t2 stay NA
  resultado[
    (is.na(urb_t1_vec) | urb_t1_vec != 1) &
    (is.na(urb_t2_vec) | urb_t2_vec != 1)
  ] <- NA_character_

  gc(verbose = FALSE)
  return(resultado)
}

# =============================================================================
# 5) PROCESS ALL UNITS
# =============================================================================

cat("\n", strrep("=", 60), "\n")
cat("CLASSIFYING: 2010->2020 (common grid)\n")
cat(strrep("=", 60), "\n")

cols_necessarias <- c("urbano_2010", "urbano_2020", "built_pct_2010", "built_pct_2020",
                      COL_POP_PATCH, "unidade_id", "cod_mun", "area_total")
faltando <- setdiff(cols_necessarias, names(grade))
if (length(faltando) > 0)
  stop("Missing columns in the grid: ", paste(faltando, collapse = ", "))

grade$tipo_crescimento <- NA_character_

unidades_presentes <- unique(grade$unidade_id)
unidades_presentes <- unidades_presentes[!is.na(unidades_presentes)]
n_unidades         <- length(unidades_presentes)
n_processadas      <- 0
n_erro             <- 0
t0_total           <- Sys.time()

cat(sprintf("Units to process: %d\n", n_unidades))

for (i in seq_along(unidades_presentes)) {
  uid <- unidades_presentes[i]
  idx <- which(grade$unidade_id == uid)

  if (length(idx) < 2) {
    # Single-cell unit: Minor by definition
    urb_t1_val <- ifelse(is.na(as.integer(grade$urbano_2010[idx])), 0L,
                         as.integer(grade$urbano_2010[idx]))
    urb_t2_val <- ifelse(is.na(as.integer(grade$urbano_2020[idx])), 0L,
                         as.integer(grade$urbano_2020[idx]))

    if (urb_t1_val == 1 && urb_t2_val == 1) {
      pop_val  <- ifelse(is.na(grade[[COL_POP_PATCH]][idx]), 0,
                         as.numeric(grade[[COL_POP_PATCH]][idx]))
      area_val <- ifelse(is.na(grade$area_total[idx]), 1e-9,
                         as.numeric(grade$area_total[idx])) / 1e6
      dens_val <- pop_val / pmax(area_val, 1e-9)
      if (pop_val > POP_PATCH_A && dens_val >= DENS_PATCH_B) {
        b_t2 <- ifelse(is.na(grade$built_pct_2020[idx]), 0, grade$built_pct_2020[idx])
        b_t1 <- ifelse(is.na(grade$built_pct_2010[idx]), 0, grade$built_pct_2010[idx])
        grade$tipo_crescimento[idx] <- ifelse(
          (b_t2 - b_t1) > LIMIAR_DENSIF, "densification", "consolidated"
        )
      } else {
        grade$tipo_crescimento[idx] <- "peripheral"
      }
    } else if (urb_t1_val == 0 && urb_t2_val == 1) {
      grade$tipo_crescimento[idx] <- "leapfrog"
    } else if (urb_t1_val == 1 && urb_t2_val == 0) {
      grade$tipo_crescimento[idx] <- "consolidated"  # shrinkage
    }
    n_processadas <- n_processadas + 1
    next
  }

  tryCatch({
    tipos <- classificar_crescimento(
      celulas      = grade[idx, ],
      col_urb_t1   = "urbano_2010",
      col_urb_t2   = "urbano_2020",
      col_built_t1 = "built_pct_2010",
      col_built_t2 = "built_pct_2020",
      col_pop      = COL_POP_PATCH
    )
    grade$tipo_crescimento[idx] <- tipos
    n_processadas <- n_processadas + 1
  }, error = function(e) {
    cat(sprintf("\n  ERROR in unit %s (%d cells): %s\n",
                uid, length(idx), conditionMessage(e)))
    n_erro <<- n_erro + 1
  })

  if (i %% 10 == 0 || i == n_unidades) {
    elapsed <- as.numeric(difftime(Sys.time(), t0_total, units = "mins"))
    cat(sprintf("\r  [%d/%d] units (%.1f min, %d errors)",
                i, n_unidades, elapsed, n_erro))
  }
}

cat("\n")
elapsed_total <- as.numeric(difftime(Sys.time(), t0_total, units = "mins"))

cat(sprintf("\n--- Summary: 2010->2020 (common grid) ---\n"))
cat(sprintf("  Processed: %d/%d (%.1f min)\n",
            n_processadas, n_unidades, elapsed_total))
cat(sprintf("  Errors: %d\n", n_erro))

tipos_ordem <- c("consolidated", "densification", "infill",
                 "extension", "leapfrog", "peripheral")
tab <- table(grade$tipo_crescimento, useNA = "always")
cat("  Classification:\n")
for (tipo in tipos_ordem) {
  n <- if (tipo %in% names(tab)) tab[[tipo]] else 0L
  cat(sprintf("    %-16s %s\n", tipo, fmt(n)))
}
cat(sprintf("    %-16s %s\n", "NA (not urban)", fmt(sum(is.na(grade$tipo_crescimento)))))

# =============================================================================
# 6) SAVE
# =============================================================================

cat("\n", strrep("=", 60), "\n")
cat("6) SAVING RESULTS\n")
cat(strrep("=", 60), "\n")

sufixo <- if (!is.null(FILTRO_UF)) paste0("_", FILTRO_UF) else ""
out_dir <- file.path(processed_data_dir, "crescimento_urbano")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

path <- file.path(out_dir, paste0("grade_growth_types_2010_2022", sufixo, ".parquet"))
cat(sprintf("  Saving grade_growth_types_2010_2022%s.parquet...\n", sufixo))
t0 <- Sys.time()
sfarrow::st_write_parquet(grade, path)
elapsed <- round(as.numeric(difftime(Sys.time(), t0, units = "mins")), 1)
cat(sprintf("    %.0f MB, %.1f min\n",
            file.size(path) / 1024^2, elapsed))

# =============================================================================
# 7) FINAL SUMMARY
# =============================================================================

cat("\n", strrep("=", 60), "\n")
cat("FINAL SUMMARY\n")
cat(strrep("=", 60), "\n")

cat(sprintf("\nParameters:\n"))
cat(sprintf("  Extension/leapfrog:  %dm\n",            LIMIAR_EXTENSION))
cat(sprintf("  Densification:       delta > %g p.p.\n", LIMIAR_DENSIF))
cat(sprintf("  Rasterization:       per polygon\n"))
cat(sprintf("  Holes connectivity:  %d (Rook)\n",       CONECTIVIDADE_HOLES))
cat(sprintf("  Type A patch:        pop > %d\n",        POP_PATCH_A))
cat(sprintf("  Type B patch:        dens >= %d inhab/km^2\n", DENS_PATCH_B))
cat(sprintf("  Patch sizing pop:    %s\n",              COL_POP_PATCH))

cat(sprintf("\n--- 2010->2020 (common grid) ---\n"))
cat(sprintf("  Cells:         %s\n",  fmt(nrow(grade))))
cat(sprintf("  Municipalities: %d\n",  length(unique(grade$cod_mun))))
cat(sprintf("  Units:         %d\n",  length(unique(grade$unidade_id))))

tab         <- table(grade$tipo_crescimento)
total_class <- sum(tab)
cat(sprintf("  Classified: %s\n", fmt(total_class)))
for (tipo in tipos_ordem) {
  n   <- if (tipo %in% names(tab)) tab[[tipo]] else 0L
  pct <- if (total_class > 0) 100 * n / total_class else 0
  cat(sprintf("    %-16s %s (%4.1f%%)\n", tipo, fmt(n), pct))
}

cat(sprintf("  Susceptibility (cells > 0):\n"))
cat(sprintf("    alta:  %s\n", fmt(sum(grade$prop_suscept_alta  > 0, na.rm = TRUE))))
cat(sprintf("    total: %s\n", fmt(sum(grade$prop_suscept_total > 0, na.rm = TRUE))))
cat(sprintf("  AGSN (cells > 0):           %s\n",
            fmt(sum(grade$prop_agsn > 0, na.rm = TRUE))))

if (!is.null(FILTRO_UF)) {
  cat(sprintf("\n*** TEST MODE: only UF = %s ***\n", FILTRO_UF))
  cat("*** Set FILTRO_UF to NULL to run all of Brazil ***\n")
}

cat("\nScript 05 complete!\n")
cat("Next step: 07_aggregate_municipality_metrics.R\n")
