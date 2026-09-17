# =============================================================================
# 03_integrate_grid_with_ghsl.R
# Build the unified 2010-2022 common grid and integrate GHSL built-up data.
#
# MIGRATION_PLAN.md 6b0 (decided 2026-08-28): the 2010-2022 descriptive
# framework is unified onto a single common geometry -- the 2022 statistical
# grid (200m cells in areas urban at 2022, 1km elsewhere) -- replacing the
# old dual-grid ("M-family") design, where 2010 and 2022 were each processed
# on their own native grid and reconciled afterwards via a cross-grid join.
#
# This script still builds the raw 2010 grid (grade_ibge_2010.parquet) --
# unchanged in content and purpose -- because the 2000-2010 pre-period
# branch (06_classify_growth_types_2000_2010.R, out of scope for the
# unification per 6b0 item 2) reads it directly. What's new is that this
# script now ALSO uses that 2010 grid as the source for allocating 2010
# population onto the 2022 grid, producing a single common-grid output that
# scripts 04/05/07 build on instead of processing two grids in parallel.
#
# Population allocation (pop_2010_alocada), method:
#   1. Centroid of every 2022 cell -> the 2010 "mother cell" containing it
#      (st_within spatial join; a 2010 mother cell can contain up to ~25
#      subcells at 200m resolution).
#   2. The mother cell's 2010 population is distributed across ALL of its
#      2022 subcells, proportional to each subcell's GHSL built_m2_2010
#      (built-up area as a proxy for where the population actually lived);
#      fallback to a uniform 1/n weight when every subcell's built_m2_2010
#      is 0.
#   3. 2022 cells whose centroid falls outside any 2010 mother cell (grid
#      expansion areas without 2010 coverage) get no pop_2010_alocada.
#
# Root-cause fix (MIGRATION_PLAN.md, "Resolved 2026-08-28 -- root cause
# found, definitively", stage-03 rework Validate runbook entry): the
# pre-rework 06_metricas_municipio.R computed this same allocation but
# filtered subcells to the tipo_crescimento-classified subset BEFORE
# normalizing the weights within each mother cell -- over-concentrating
# 100% of a mother cell's population onto whichever ~11% of subcells
# happened to carry a growth-type label, inflating Table 1's population
# totals. This script allocates pop_2010_alocada across EVERY subcell of a
# mother cell first, with no upstream filter; any later restriction (urban
# flag, growth type, susceptibility) is applied as a plain filter on an
# already-fully-and-correctly-allocated pop_2010_alocada column, in scripts
# 04/05/07 -- never a pre-filter that changes what the weights sum to.
#
# Inputs (all read from data/processed_data/02_hazard_zones/, the frozen
# 01+02 boundary -- see MIGRATION_PLAN.md Task 6a):
#   - amostra_municipios.rds           (script 01)
#   - grade_20XX_BR_com_suscept_alta_agsn.gpkg  (02_population_in_hazard_zones script 03)
#   - grade_20XX_pontos_BR.parquet     (02_population_in_hazard_zones script 01)
#   - grade_20XX_BR.gpkg               (02_population_in_hazard_zones script 01)
#   - GHS_BUILT_S_E2010*.tif, GHS_BUILT_S_E2020*.tif  (script 02)
#
# Outputs:
#   - grade_ibge_2010.gpkg / .parquet
#       Raw 2010 grid (pop 2010 + suscept + AGSN + built_pct_2010), unchanged
#       in content/purpose -- kept solely for 06_classify_growth_types_2000_2010.R.
#   - grade_common_grid_2010_2022.gpkg / .parquet
#       THE common grid scripts 04/05/07 build on: 2022 cell geometry,
#       populacao (2022 census pop), pop_2010_alocada (allocated 2010 pop,
#       bug-fixed), suscept + risk + AGSN, built_pct_2010/2020.
# =============================================================================

source("03_urban_footprint_and_growth_types/00_setup.R")

library(terra)
library(exactextractr)
library(arrow)
library(sfarrow)

# Configuration ----

FILTRO_UF <- NULL  # "PR" = Parana, NULL = all of Brazil

# Directory with the CPRM risk + AGSN grids (output of the Python script
# 10_agsn_na_grade_risco.py)
risk_dir <- processed_data_path("02_hazard_zones")

# National municipal mesh -- read from the gpkg already downloaded/prepared
# by stage 02's own 01_download_prepare_ibge_grid.py instead of
# geobr::read_municipality(). geobr fetches data over HTTP via duckdb, and on
# this network the duckdb extension download has failed persistently ("A
# file must have been corrupted during download"), even across sessions --
# not a transient issue. The national mesh is already on disk (same IBGE
# source), so reading it directly avoids that network dependency. Columns
# and geometry name are standardized to "code_muni"/"geom" to match what the
# rest of this script expects from geobr::read_municipality().
load_national_mesh <- function() {
  m <- st_read(file.path(risk_dir, "malha_municipal_5880.gpkg"), quiet = TRUE) %>%
    rename(code_muni = COD_MUNICIPIO) %>%
    mutate(code_muni = as.character(code_muni))
  names(m)[names(m) == attr(m, "sf_column")] <- "geom"
  st_geometry(m) <- "geom"
  m
}

if (!is.null(FILTRO_UF)) {
  cat(sprintf("\n*** TEST MODE: processing only UF = %s ***\n\n", FILTRO_UF))
}

# 1. Load the sample and split municipalities ----

cat(strrep("=", 60), "\n")
cat("1) LOADING THE MUNICIPALITY SAMPLE\n")
cat(strrep("=", 60), "\n")

sample_df <- readRDS(file.path(processed_data_dir, "amostra_municipios.rds"))
cat("Total municipalities in the sample:", nrow(sample_df), "\n")

if (!is.null(FILTRO_UF)) {
  uf_codes <- list(
    "RO" = "11", "AC" = "12", "AM" = "13", "RR" = "14", "PA" = "15",
    "AP" = "16", "TO" = "17", "MA" = "21", "PI" = "22", "CE" = "23",
    "RN" = "24", "PB" = "25", "PE" = "26", "AL" = "27", "SE" = "28",
    "BA" = "29", "MG" = "31", "ES" = "32", "RJ" = "33", "SP" = "35",
    "PR" = "41", "SC" = "42", "RS" = "43", "MS" = "50", "MT" = "51",
    "GO" = "52", "DF" = "53"
  )
  cod_uf <- uf_codes[[FILTRO_UF]]
  sample_df <- sample_df %>% filter(substr(cod_mun, 1, 2) == cod_uf)
  cat(sprintf("After UF=%s filter: %d municipalities\n", FILTRO_UF, nrow(sample_df)))
}

mun_com_suscept <- sample_df %>% filter(tem_susceptibilidade) %>% pull(cod_mun)
mun_sem_suscept <- sample_df %>% filter(!tem_susceptibilidade) %>% pull(cod_mun)
todos_mun <- sample_df$cod_mun

cat("  With susceptibility:", length(mun_com_suscept), "\n")
cat("  Without susceptibility:", length(mun_sem_suscept),
    "(complete susceptibility and/or CPRM-only-risk arrangements)\n")

# 2. Load the grid with susceptibility + AGSN ----

cat("\n", strrep("=", 60), "\n")
cat("2) LOADING THE GRID WITH SUSCEPTIBILITY + AGSN\n")
cat(strrep("=", 60), "\n")

# Base geometry (2a) and susceptibility values (2b) both come from the same
# risk_dir/grade_20XX_BR_com_suscept_alta_agsn.gpkg file (stage 02's own
# output) -- any update there propagates here automatically.
#
# 2026-08-21 (Migrate, Task 1c): medium susceptibility dropped per CLAUDE.md
# rule 9 (high susceptibility only) -- no more medio read/join here.
# prop_suscept_total/prop_agsn_suscept_total are kept as column names for
# downstream compatibility (scripts 05/07 still read them) but now simply
# equal the alta values, since there's no medio term left to add.
#
# Resulting column schema (compatible with script 05):
#   prop_suscept_alta, prop_suscept_total (== prop_suscept_alta)
#   prop_agsn, prop_agsn_suscept_alta, prop_agsn_suscept_total (== prop_agsn_suscept_alta)

# 2a. Base geometry (geometry, population, area and cod_mun_suscept only) ----

read_base_grid <- function(ano) {
  g <- st_read(
    file.path(risk_dir, sprintf("grade_%d_BR_com_suscept_alta_agsn.gpkg", ano)),
    quiet = TRUE
  ) %>%
    filter(cod_mun_suscept %in% mun_com_suscept) %>%
    mutate(id_celula = as.character(id_celula))
  stopifnot(
    "ID_UNICO missing from the alta grid -- base geometry source needs a fresh look" =
      "ID_UNICO" %in% names(g)
  )
  g %>% select(id_celula, ID_UNICO, populacao, area_total, cod_mun_suscept)
  # geometry column: sf's sticky column, retained automatically regardless of name
}

grade_base_2010 <- read_base_grid(2010)
grade_base_2022 <- read_base_grid(2022)

cat("2010 base grid:", nrow(grade_base_2010), "cells\n")
cat("2022 base grid:", nrow(grade_base_2022), "cells\n")

# 2b. Susceptibility values (same files as script 05) ----
# Reads only the attribute table (no geometry) and renames to the unified schema.

read_susceptibility <- function(path, sufixo, incluir_agsn_total = TRUE) {
  cat(sprintf("  Reading susceptibility %s: %s\n", sufixo, basename(path)))

  df <- st_read(path, quiet = TRUE) |>
    st_drop_geometry() |>
    mutate(ID_UNICO = as.character(ID_UNICO))

  col_suscept  <- if (sufixo == "alta") "prop_suscept" else "prop_suscept_medio"
  col_agsn_com <- paste0("prop_agsn_com_suscept_", sufixo)
  col_agsn_tot <- paste0("prop_agsn_", sufixo)

  # Warn if expected columns are missing
  faltando <- setdiff(c(col_suscept, col_agsn_com), names(df))
  if (length(faltando) > 0) {
    cat(sprintf("    WARNING: missing columns: %s\n", paste(faltando, collapse = ", ")))
    for (col in faltando) df[[col]] <- 0
  }

  df <- df |>
    rename(!!paste0("prop_suscept_", sufixo)      := all_of(col_suscept),
           !!paste0("prop_agsn_suscept_", sufixo) := all_of(col_agsn_com))

  cols_sel <- c("ID_UNICO",
                paste0("prop_suscept_", sufixo),
                paste0("prop_agsn_suscept_", sufixo))

  if (incluir_agsn_total && col_agsn_tot %in% names(df)) {
    df <- df |> rename(prop_agsn = all_of(col_agsn_tot))
    cols_sel <- c(cols_sel, "prop_agsn")
  }

  df |> select(all_of(cols_sel))
}

join_susceptibility <- function(base, ano) {
  s_alta  <- read_susceptibility(
    file.path(risk_dir, sprintf("grade_%d_BR_com_suscept_alta_agsn.gpkg", ano)),
    "alta", incluir_agsn_total = TRUE
  )
  base |>
    left_join(s_alta,  by = "ID_UNICO") |>
    mutate(
      prop_suscept_alta       = replace_na(prop_suscept_alta,       0),
      prop_agsn               = replace_na(prop_agsn,               0),
      prop_agsn_suscept_alta  = replace_na(prop_agsn_suscept_alta,  0),
      prop_suscept_total      = prop_suscept_alta,
      prop_agsn_suscept_total = prop_agsn_suscept_alta
    )
}

cat("\n2010 grid:\n")
grade_suscept_2010 <- join_susceptibility(grade_base_2010, 2010)
cat("\n2022 grid:\n")
grade_suscept_2022 <- join_susceptibility(grade_base_2022, 2022)
rm(grade_base_2010, grade_base_2022)
cat("\n2010 grid with suscept+AGSN:", nrow(grade_suscept_2010), "cells\n")
cat("2022 grid with suscept+AGSN:", nrow(grade_suscept_2022), "cells\n")

# 2b. CPRM risk -- RETIRED (MIGRATION_PLAN.md 6f.1, decided 2026-09-13) ----
# prop_risco / prop_agsn_com_risco are no longer carried onto the common grid.
# The consumer sweep before the change found no reader anywhere in stages 04,
# 05 or 05_exhibits/robustness/; the only downstream reference was a presence
# check in 05_classify_growth_types.R, removed with this. Stage 02 is frozen
# and still produces grade_{2010,2022}_BR_com_risco_agsn.gpkg -- this stage
# just stops reading them. The removed code is preserved verbatim in the
# private working repository, not here.
# 2b. Diagnostics: municipalities with susceptibility missing from the gpkg ----

mun_no_gpkg_2010 <- unique(grade_suscept_2010$cod_mun_suscept)
mun_no_gpkg_2022 <- unique(grade_suscept_2022$cod_mun_suscept)
mun_suscept_fora_2010 <- setdiff(mun_com_suscept, mun_no_gpkg_2010)
mun_suscept_fora_2022 <- setdiff(mun_com_suscept, mun_no_gpkg_2022)

if (length(mun_suscept_fora_2010) > 0 || length(mun_suscept_fora_2022) > 0) {
  cat("\n  WARNING: municipalities with susceptibility missing from the gpkg:\n")
  if (length(mun_suscept_fora_2010) > 0) {
    cat("    2010 grid:", length(mun_suscept_fora_2010), "municipalities\n")
    info <- sample_df %>% filter(cod_mun %in% mun_suscept_fora_2010) %>%
      select(any_of(c("cod_mun", "nome_arranjo", "pop_2022", "tem_susceptibilidade")))
    print(info, n = 20)
  }
  if (length(mun_suscept_fora_2022) > 0) {
    cat("    2022 grid:", length(mun_suscept_fora_2022), "municipalities\n")
    info <- sample_df %>% filter(cod_mun %in% mun_suscept_fora_2022) %>%
      select(any_of(c("cod_mun", "nome_arranjo", "pop_2022", "tem_susceptibilidade")))
    print(info, n = 20)
  }
}

# 3. Expand the grid for municipalities without susceptibility ----

cat("\n", strrep("=", 60), "\n")
cat("3) EXPANDING THE GRID FOR MUNICIPALITIES WITHOUT SUSCEPTIBILITY\n")
cat(strrep("=", 60), "\n")

# Helper to expand a grid (2010 or 2022)
expand_grid_for_uncovered <- function(ano, pontos_path, grade_completa_path,
                                      malha, col_pop_original) {
  cat(sprintf("\n  Expanding %d grid...\n", ano))

  if (file.exists(pontos_path)) {
    cat("    Using the points geoparquet with a bbox filter (fast)...\n")

    # Filter the parquet by the mesh bbox via GDAL (avoids loading all of Brazil)
    bbox_wkt <- st_as_text(st_as_sfc(st_bbox(st_transform(malha, 5880))))

    # sf::read_sf(wkt_filter=) uses GDAL's Parquet driver, which this GDAL
    # build lacks ("source could be corrupt or not supported") -- reading via
    # sfarrow (uses the arrow package instead of the OGR driver) and applying
    # the bbox filter afterwards in R, since sfarrow does no file-level filter.
    pontos <- sfarrow::st_read_parquet(pontos_path)

    if (is.na(st_crs(pontos))) {
      warning("Missing CRS in the parquet -- assuming EPSG:5880 (SIRGAS 2000 Polyconic)")
      st_crs(pontos) <- 5880
    }

    pontos <- st_crop(pontos, st_bbox(st_transform(malha, st_crs(pontos))))
    cat("    Points loaded (bbox-filtered):", nrow(pontos), "\n")

    malha_proj <- st_transform(malha, st_crs(pontos))

    pontos_nos_mun <- st_join(pontos, malha_proj %>% select(code_muni, geom),
                              join = st_within)
    pontos_nos_mun <- pontos_nos_mun %>% filter(!is.na(code_muni))
    cat("    Cells identified via points:", nrow(pontos_nos_mun), "\n")

    # Municipalities with no cell in the spatial join -> fall back to bbox recovery
    mun_esperados <- as.character(malha$code_muni)
    mun_no_parquet <- as.character(unique(pontos_nos_mun$code_muni))
    mun_sem_celula_parquet <- setdiff(mun_esperados, mun_no_parquet)
    if (length(mun_sem_celula_parquet) > 0) {
      cat(sprintf("    WARNING: %d municipalities with no cell in the parquet spatial join",
                  length(mun_sem_celula_parquet)),
          "-> will go through bbox recovery:\n")
      info <- sample_df %>%
        filter(cod_mun %in% mun_sem_celula_parquet) %>%
        select(cod_mun, NM_CIDADE, pop_2022, tem_susceptibilidade)
      print(info, n = 50)
    } else {
      cat("    OK: all", length(mun_esperados),
          "municipalities have cells in the parquet spatial join.\n")
    }

    ids_necessarios <- unique(pontos_nos_mun$id_celula)

    # Use the same bbox to filter the gpkg via GDAL (avoids loading all of Brazil)
    grade_completa <- st_read(grade_completa_path, quiet = TRUE, wkt_filter = bbox_wkt)
    grade_expandida <- grade_completa %>%
      filter(id_celula %in% ids_necessarios) %>%
      mutate(id_celula = as.character(id_celula))

    if (col_pop_original %in% names(grade_expandida)) {
      grade_expandida <- grade_expandida %>%
        rename(populacao = !!col_pop_original)
    }

    cod_mun_map <- pontos_nos_mun %>%
      st_drop_geometry() %>%
      select(id_celula, code_muni) %>%
      mutate(id_celula = as.character(id_celula),
             cod_mun_suscept = as.character(code_muni)) %>%
      select(id_celula, cod_mun_suscept) %>%
      distinct(id_celula, .keep_all = TRUE)  # border cells: one municipality per cell

    grade_expandida <- grade_expandida %>%
      left_join(cod_mun_map, by = "id_celula")

    rm(pontos, grade_completa)
    gc()

  } else {
    cat("    Points geoparquet not found, falling back to bbox reads...\n")
    grade_expandida <- NULL

    for (i in seq_len(nrow(malha))) {
      mun_i <- malha[i, ]
      # Bbox in the gpkg's native CRS (EPSG:5880) -- wkt_filter is applied by
      # OGR in the file's native CRS; using 4674 (degrees) would misinterpret
      # the coordinates as meters.
      bbox_wkt <- st_as_text(st_as_sfc(st_bbox(st_transform(mun_i, 5880))))
      celulas_i <- st_read(grade_completa_path, quiet = TRUE,
                           wkt_filter = bbox_wkt)
      if (nrow(celulas_i) > 0) {
        celulas_i <- st_transform(celulas_i, st_crs(mun_i))
        centroides_i <- st_centroid(celulas_i)
        dentro <- st_within(centroides_i, mun_i, sparse = FALSE)[, 1]
        celulas_i <- celulas_i[dentro, ]
        celulas_i <- celulas_i %>% mutate(id_celula = as.character(id_celula))
        celulas_i$cod_mun_suscept <- as.character(mun_i$code_muni)
      }
      grade_expandida <- bind_rows(grade_expandida, celulas_i)
      if (i %% 50 == 0) {
        cat(sprintf("    Processed %d/%d municipalities...\n", i, nrow(malha)))
      }
    }
  }

  # Standardize columns
  if (!is.null(grade_expandida) && nrow(grade_expandida) > 0) {
    if (col_pop_original %in% names(grade_expandida)) {
      grade_expandida <- grade_expandida %>%
        rename(populacao = !!col_pop_original)
    }
    grade_expandida <- grade_expandida %>%
      mutate(
        # Susceptibility = 0 for municipalities without mapping (covers all 3
        # cases: completes a susceptibility arrangement, has risk but no
        # susceptibility, completes a risk arrangement)
        prop_suscept_alta       = 0,
        prop_suscept_total      = 0,
        prop_agsn               = 0,
        prop_agsn_suscept_alta  = 0,
        prop_agsn_suscept_total = 0
        # (prop_risco / prop_agsn_com_risco retired -- see 6f.1)
      )
    # Always reproject to 5880, regardless of whether area_total already
    # exists. If grade_completa_path already contains area_total, the
    # original `if` wouldn't run st_transform, leaving grade_expandida in a
    # different CRS than grade_suscept (5880). The later bind_rows would then
    # mix degree- and meter-based coordinates, placing the expanded cells in
    # the ocean.
    grade_expandida <- st_transform(grade_expandida, 5880)
    if (!"area_total" %in% names(grade_expandida)) {
      grade_expandida$area_total <- as.numeric(st_area(grade_expandida))
    }
    cat(sprintf("  %d grid expanded: %s cells\n", ano,
                format(nrow(grade_expandida), big.mark = ".")))
  }

  grade_expandida
}

if (length(mun_sem_suscept) > 0) {

  # 3a. Load the municipal mesh ----

  cat("  Loading the municipal mesh...\n")
  malha <- load_national_mesh()
  malha <- malha %>% filter(code_muni %in% mun_sem_suscept)
  cat("  Municipalities without susceptibility in the mesh:", nrow(malha), "\n")

  # 3b. Expand the 2010 grid ----

  grade_expandida_2010 <- expand_grid_for_uncovered(
    ano = 2010,
    pontos_path = file.path(risk_dir, "grade_2010_pontos_BR.parquet"),
    grade_completa_path = file.path(risk_dir, "grade_2010_BR.gpkg"),
    malha = malha,
    col_pop_original = "POP"
  )

  # 3c. Expand the 2022 grid ----

  grade_expandida_2022 <- expand_grid_for_uncovered(
    ano = 2022,
    pontos_path = file.path(risk_dir, "grade_2022_pontos_BR.parquet"),
    grade_completa_path = file.path(risk_dir, "grade_2022_BR.gpkg"),
    malha = malha,
    col_pop_original = "TOTAL"
  )

  # 3d. CPRM risk into the expanded grids -- RETIRED (6f.1).

  rm(malha)
  gc()

} else {
  cat("  No municipality without susceptibility in the sample. Skipping expansion.\n")
  grade_expandida_2010 <- NULL
  grade_expandida_2022 <- NULL
}

gc()

# 3d. Concatenate grids (suscept + expanded) ----

cat("\n  Concatenating grids...\n")

grade_suscept_2010 <- st_transform(grade_suscept_2010, 5880)
grade_suscept_2022 <- st_transform(grade_suscept_2022, 5880)

# Remove cells from the expanded grid that are already in the susceptibility
# grid. Border cells between municipalities with/without susceptibility can
# be assigned to different municipalities by the Python pipeline (which
# built the gpkg) and by the R spatial join (which built grade_expandida),
# creating duplicate ID_UNICO values with different cod_mun. grade_suscept
# takes precedence since it carries the correct prop_suscept values;
# grade_expandida would have prop_suscept = 0 for those.
if (!is.null(grade_expandida_2010) && nrow(grade_expandida_2010) > 0) {
  ids_suscept_2010 <- grade_suscept_2010$ID_UNICO
  n_antes <- nrow(grade_expandida_2010)
  grade_expandida_2010 <- grade_expandida_2010 %>%
    filter(!ID_UNICO %in% ids_suscept_2010)
  n_removidas <- n_antes - nrow(grade_expandida_2010)
  if (n_removidas > 0) {
    cat(sprintf("  Expanded 2010 grid: %d cells removed (duplicate ID_UNICO with the susceptibility grid)\n",
                n_removidas))
  }
}

if (!is.null(grade_expandida_2022) && nrow(grade_expandida_2022) > 0) {
  ids_suscept_2022 <- grade_suscept_2022$ID_UNICO
  n_antes <- nrow(grade_expandida_2022)
  grade_expandida_2022 <- grade_expandida_2022 %>%
    filter(!ID_UNICO %in% ids_suscept_2022)
  n_removidas <- n_antes - nrow(grade_expandida_2022)
  if (n_removidas > 0) {
    cat(sprintf("  Expanded 2022 grid: %d cells removed (duplicate ID_UNICO with the susceptibility grid)\n",
                n_removidas))
  }
}

cols_comuns <- c("id_celula", "ID_UNICO", "populacao", "area_total",
                 "prop_suscept_alta", "prop_suscept_total",
                 "prop_agsn",
                 "prop_agsn_suscept_alta", "prop_agsn_suscept_total",
                 "cod_mun_suscept")

standardize_columns <- function(gdf, cols) {
  colunas_faltantes <- setdiff(cols, names(gdf))
  for (col in colunas_faltantes) {
    gdf[[col]] <- NA
  }
  gdf %>% select(all_of(cols))
}

grade_2010 <- bind_rows(
  standardize_columns(grade_suscept_2010, cols_comuns),
  if (!is.null(grade_expandida_2010) && nrow(grade_expandida_2010) > 0) {
    standardize_columns(grade_expandida_2010, cols_comuns)
  }
)

grade_2022 <- bind_rows(
  standardize_columns(grade_suscept_2022, cols_comuns),
  if (!is.null(grade_expandida_2022) && nrow(grade_expandida_2022) > 0) {
    standardize_columns(grade_expandida_2022, cols_comuns)
  }
)

cat("Total 2010 grid:", nrow(grade_2010), "cells\n")
cat("Total 2022 grid:", nrow(grade_2022), "cells\n")

grade_2010 <- grade_2010 %>% rename(cod_mun = cod_mun_suscept)
grade_2022 <- grade_2022 %>% rename(cod_mun = cod_mun_suscept)

# 3e. Diagnostics: missing municipalities ----

mun_na_grade_2010 <- unique(grade_2010$cod_mun)
mun_na_grade_2022 <- unique(grade_2022$cod_mun)
mun_faltantes_2010 <- setdiff(todos_mun, mun_na_grade_2010)
mun_faltantes_2022 <- setdiff(todos_mun, mun_na_grade_2022)

cat("\n  Municipalities in the 2010 grid:", length(mun_na_grade_2010),
    "of", length(todos_mun), "\n")
cat("  Municipalities in the 2022 grid:", length(mun_na_grade_2022),
    "of", length(todos_mun), "\n")

if (length(mun_faltantes_2022) > 0) {
  cat("\n  WARNING:", length(mun_faltantes_2022),
      "municipalities missing from the 2022 grid:\n")
  faltantes_info <- sample_df %>%
    filter(cod_mun %in% mun_faltantes_2022) %>%
    select(any_of(c("cod_mun", "nome_arranjo", "pop_2022", "tem_susceptibilidade")))
  print(faltantes_info, n = 50)
}

# 3f. Recover missing municipalities via bbox ----
# If, after concatenation, sample municipalities are still missing from the
# grid, try to recover them by reading the national gpkg directly by bbox.
# This guarantees no municipality is left out due to a parquet failure.

recover_missing <- function(grade, mun_faltantes, ano, col_pop, grade_path) {
  if (length(mun_faltantes) == 0 || !file.exists(grade_path)) return(grade)

  cat(sprintf("\n  Recovering %d municipalities missing from the %d grid via bbox...\n",
              length(mun_faltantes), ano))

  malha_rec <- load_national_mesh() %>%
    filter(code_muni %in% mun_faltantes)

  recuperadas <- NULL
  for (i in seq_len(nrow(malha_rec))) {
    mun_i <- malha_rec[i, ]
    # Bbox in the gpkg's native CRS (EPSG:5880) -- wkt_filter is applied by
    # OGR in the file's native CRS; using 4674 (degrees) would misinterpret
    # the coordinates as meters, returning 0 cells.
    bbox_wkt <- st_as_text(st_as_sfc(st_bbox(st_transform(mun_i, 5880))))
    celulas_i <- tryCatch(
      st_read(grade_path, quiet = TRUE, wkt_filter = bbox_wkt),
      error = function(e) NULL
    )
    if (!is.null(celulas_i) && nrow(celulas_i) > 0) {
      celulas_i <- st_transform(celulas_i, st_crs(mun_i))
      centroides_i <- st_centroid(celulas_i)
      dentro <- st_within(centroides_i, mun_i, sparse = FALSE)[, 1]
      celulas_i <- celulas_i[dentro, ]
      if (nrow(celulas_i) > 0) {
        celulas_i <- celulas_i %>% mutate(id_celula = as.character(id_celula))
        if (col_pop %in% names(celulas_i)) {
          celulas_i <- celulas_i %>% rename(populacao = !!col_pop)
        }
        celulas_i$cod_mun <- as.character(mun_i$code_muni)
        recuperadas <- bind_rows(recuperadas, celulas_i)
      }
    }
  }

  if (!is.null(recuperadas) && nrow(recuperadas) > 0) {
    # Add susceptibility/risk columns as zero (municipalities without mapping)
    recuperadas <- recuperadas %>%
      mutate(
        prop_suscept_alta       = 0, prop_suscept_total      = 0,
        prop_agsn               = 0, prop_agsn_suscept_alta  = 0,
        prop_agsn_suscept_total = 0
      )
    if (!"area_total" %in% names(recuperadas)) {
      recuperadas <- st_transform(recuperadas, 5880)
      recuperadas$area_total <- as.numeric(st_area(recuperadas))
    }
    n_rec <- length(unique(recuperadas$cod_mun))
    cat(sprintf("    Recovered: %s cells from %d municipalities\n",
                format(nrow(recuperadas), big.mark = "."), n_rec))
    grade <- bind_rows(grade, standardize_columns(recuperadas, names(grade)))
  } else {
    cat("    No cells recovered.\n")
  }

  grade
}

mun_faltantes_2010 <- setdiff(todos_mun, mun_na_grade_2010)
mun_faltantes_2022 <- setdiff(todos_mun, mun_na_grade_2022)

grade_2010 <- recover_missing(
  grade_2010, mun_faltantes_2010, 2010, "POP",
  file.path(risk_dir, "grade_2010_BR.gpkg")
)
grade_2022 <- recover_missing(
  grade_2022, mun_faltantes_2022, 2022, "TOTAL",
  file.path(risk_dir, "grade_2022_BR.gpkg")
)

# Final diagnostics after recovery
mun_ainda_faltantes <- setdiff(todos_mun, unique(grade_2022$cod_mun))
if (length(mun_ainda_faltantes) > 0) {
  cat(sprintf("\n  FINAL WARNING: %d municipalities still missing after recovery:\n",
              length(mun_ainda_faltantes)))
  print(sample_df %>% filter(cod_mun %in% mun_ainda_faltantes) %>%
          select(any_of(c("cod_mun", "nome_arranjo", "pop_2022",
                          "tem_susceptibilidade"))), n = 50)
} else {
  cat("\n  OK: all", length(todos_mun),
      "sample municipalities are represented in the grid.\n")
}

rm(grade_suscept_2010, grade_suscept_2022,
   grade_expandida_2010, grade_expandida_2022)
gc()

# 4. Integrate GHSL (exact_extract) ----

cat("\n", strrep("=", 60), "\n")
cat("4) INTEGRATING GHSL BUILT-S\n")
cat(strrep("=", 60), "\n")

# The 2010 grid only needs built_pct_2010 now: it feeds the population
# allocation weight below and is the one GHSL column
# 06_classify_growth_types_2000_2010.R requires from grade_ibge_2010.parquet.
# Under the pre-rework dual-grid design this grid also carried built_pct_2020,
# needed only to run the (now-eliminated) growth-type classification a
# second time on the 2010 geometry -- that consumer is gone under the
# unification, so extracting E2020 here would just be wasted exact_extract
# runtime (one of the slowest steps in this pipeline, per rule 7).
# The 2022 grid keeps both epochs: it's the single geometry going forward,
# and needs built_pct_2010 (allocation weight, t1 urban criterion) and
# built_pct_2020 (t2 urban criterion, growth-type classification).

ghsl_dir <- file.path(raw_data_dir, "ghsl_raw")
ghsl_tifs <- list.files(ghsl_dir, pattern = "\\.tif$", full.names = TRUE)

if (length(ghsl_tifs) == 0) {
  stop("No GHSL TIF found in ", ghsl_dir,
       "\nRun 02_download_ghsl_data.R first.")
}

cat("TIFs found:", length(ghsl_tifs), "\n")
for (f in ghsl_tifs) cat("  ", basename(f), "\n")

get_ghsl_tif <- function(epoca, tifs) {
  pattern <- sprintf("E%d", epoca)
  match <- grep(pattern, tifs, value = TRUE)
  if (length(match) == 0) stop("GHSL TIF not found for epoch ", epoca)
  match[1]
}

integrate_ghsl <- function(grade, epoca, ghsl_tifs) {
  tif_path <- get_ghsl_tif(epoca, ghsl_tifs)
  cat(sprintf("  Raster: %s\n", basename(tif_path)))

  r <- rast(tif_path)
  cat(sprintf("  Raster CRS: %s\n", crs(r, describe = TRUE)$name))

  grade_mollweide <- st_transform(grade, crs(r))

  cat("  Running exact_extract (sum + count)...\n")
  t0 <- Sys.time()

  resultado_ee <- exact_extract(r, grade_mollweide, fun = c("sum", "count"),
                                progress = TRUE)

  elapsed <- round(as.numeric(difftime(Sys.time(), t0, units = "mins")), 1)
  cat(sprintf("  exact_extract done in %.1f min\n", elapsed))

  col_sum <- names(resultado_ee)[1]
  col_count <- names(resultado_ee)[2]

  built_m2_col <- paste0("built_m2_", epoca)
  n_pixels_col <- paste0("n_pixels_", epoca)
  built_pct_col <- paste0("built_pct_", epoca)

  grade[[built_m2_col]] <- resultado_ee[[col_sum]]
  grade[[n_pixels_col]] <- resultado_ee[[col_count]]
  grade[[built_pct_col]] <- ifelse(
    grade[[n_pixels_col]] > 0,
    grade[[built_m2_col]] / (grade[[n_pixels_col]] * 10000) * 100,
    0
  )

  cat(sprintf("  Cells with built > 0: %d\n",
              sum(grade[[built_m2_col]] > 0, na.rm = TRUE)))
  cat(sprintf("  Mean n_pixels per cell: %.1f\n",
              mean(grade[[n_pixels_col]], na.rm = TRUE)))
  cat(sprintf("  Mean built_pct (where > 0): %.2f%%\n",
              mean(grade[[built_pct_col]][grade[[built_pct_col]] > 0],
                   na.rm = TRUE)))

  rm(r, grade_mollweide, resultado_ee)
  gc()

  grade
}

# 4a. 2010 grid: GHSL E2010 only ----

cat("\n  === 2010 grid (E2010 only -- see note above) ===\n")
grade_2010 <- integrate_ghsl(grade_2010, 2010, ghsl_tifs)

# 4b. 2022 grid: GHSL E2010 + E2020 ----

cat("\n  === 2022 grid (period 2010->2020) ===\n")
for (ep in c(2010, 2020)) {
  cat(sprintf("\n  --- Epoch %d ---\n", ep))
  grade_2022 <- integrate_ghsl(grade_2022, ep, ghsl_tifs)
}

# 5. Allocate 2010 population onto the 2022 grid ----

cat("\n", strrep("=", 60), "\n")
cat("5) ALLOCATING 2010 POPULATION ONTO THE 2022 GRID\n")
cat(strrep("=", 60), "\n")

# Centroid-in-mother-cell join: every 2022 cell's centroid is matched to the
# 2010 cell (mother cell) containing it, then the mother cell's 2010
# population is redistributed across ALL of its matched 2022 subcells,
# proportional to built_m2_2010 (fallback: uniform 1/n if every subcell's
# built_m2_2010 is 0). Applied with no upstream filter -- see the header note
# on the pre-rework bug this fixes.

grade_2010_lookup <- grade_2010 %>%
  st_drop_geometry() %>%
  select(id_cel_2010 = id_celula, pop_2010_cel = populacao)

# Rename id_celula to id_cel_2010 before the join (not after) so the two
# tables never carry a same-named non-geometry column into st_join -- same
# pattern the pre-rework cross-grid step used.
grade_2010_geom <- grade_2010 %>% select(id_cel_2010 = id_celula)

cat("  2022 cell centroids...\n")
centroids_2022 <- st_centroid(grade_2022 %>% select(id_celula, built_m2_2010))

cat("  Spatial join: 2022 centroids -> 2010 polygons...\n")
t0 <- Sys.time()
crossref <- st_join(centroids_2022, grade_2010_geom, join = st_within, left = TRUE) %>%
  st_drop_geometry() %>%
  select(id_celula, id_cel_2010, built_m2_2010)

elapsed <- as.numeric(difftime(Sys.time(), t0, units = "mins"))
n_match <- sum(!is.na(crossref$id_cel_2010))
cat(sprintf("  Done in %.1f min -- matched: %s/%s (%.1f%%)\n",
            elapsed, fmt(n_match), fmt(nrow(crossref)),
            100 * n_match / nrow(crossref)))

crossref <- crossref %>%
  filter(!is.na(id_cel_2010)) %>%
  left_join(grade_2010_lookup, by = "id_cel_2010")

# Allocate over EVERY matched subcell of a mother cell -- no filter of any
# kind before this normalization. This is the root-cause fix: the pre-rework
# code filtered to the tipo_crescimento-classified subset first, which made
# the weights sum to 1 over ~11% of cells instead of the true full set.
alocacao <- crossref %>%
  group_by(id_cel_2010) %>%
  mutate(
    built_m2_2010_total_cel = sum(built_m2_2010, na.rm = TRUE),
    frac = ifelse(built_m2_2010_total_cel > 0,
                  built_m2_2010 / built_m2_2010_total_cel,
                  1 / n()),
    pop_2010_alocada = pop_2010_cel * frac
  ) %>%
  ungroup() %>%
  select(id_celula, pop_2010_alocada)

# Fallback diagnostics: mother cells with no 2010 built-up (uniform weight used)
n_cel_mae_total    <- n_distinct(crossref$id_cel_2010)
n_cel_mae_fallback <- crossref %>%
  group_by(id_cel_2010) %>%
  summarise(usa_fallback = sum(built_m2_2010, na.rm = TRUE) == 0, .groups = "drop") %>%
  pull(usa_fallback) %>% sum(na.rm = TRUE)
cat(sprintf("  2010 mother cells with no built-up (uniform fallback): %s / %s (%.1f%%)\n",
            fmt(n_cel_mae_fallback), fmt(n_cel_mae_total),
            100 * n_cel_mae_fallback / n_cel_mae_total))

n_unmatched <- nrow(grade_2022) - nrow(alocacao)
cat(sprintf("  2022 cells with no 2010 mother cell (grid expansion, no pop_2010_alocada): %s\n",
            fmt(n_unmatched)))

grade_2022 <- grade_2022 %>%
  left_join(alocacao, by = "id_celula")

cat(sprintf("  Total pop_2022 : %s\n", fmt(sum(grade_2022$populacao, na.rm = TRUE))))
cat(sprintf("  Total pop_2010_alocada : %s\n", fmt(sum(grade_2022$pop_2010_alocada, na.rm = TRUE))))
cat(sprintf("  Total pop_2010 (native 2010 grid, for comparison) : %s\n",
            fmt(sum(grade_2010$populacao, na.rm = TRUE))))

rm(centroids_2022, crossref, alocacao, grade_2010_lookup, grade_2010_geom)
gc()

# 6. Save grids ----

cat("\n", strrep("=", 60), "\n")
cat("6) SAVING GRIDS\n")
cat(strrep("=", 60), "\n")

sufixo <- if (!is.null(FILTRO_UF)) paste0("_", FILTRO_UF) else ""

save_grid <- function(grade, nome_base) {
  gpkg_path <- file.path(processed_data_dir, paste0(nome_base, sufixo, ".gpkg"))
  parquet_path <- file.path(processed_data_dir, paste0(nome_base, sufixo, ".parquet"))

  cat(sprintf("\n  Saving %s...\n", nome_base))

  t0 <- Sys.time()
  st_write(grade, gpkg_path, delete_dsn = TRUE, quiet = TRUE)
  elapsed <- round(as.numeric(difftime(Sys.time(), t0, units = "mins")), 1)
  size_mb <- file.size(gpkg_path) / 1024^2
  cat(sprintf("    %s (%.0f MB, %.1f min)\n", basename(gpkg_path), size_mb, elapsed))

  t0 <- Sys.time()
  sfarrow::st_write_parquet(grade, parquet_path)
  elapsed <- round(as.numeric(difftime(Sys.time(), t0, units = "mins")), 1)
  size_mb <- file.size(parquet_path) / 1024^2
  cat(sprintf("    %s (%.0f MB, %.1f min)\n", basename(parquet_path), size_mb, elapsed))
}

# 6a. Raw 2010 grid -- unchanged in content/purpose, kept only for
#     06_classify_growth_types_2000_2010.R ----

grade_2010_final <- grade_2010 %>%
  select(
    id_celula, ID_UNICO, cod_mun, populacao, area_total,
    prop_suscept_alta, prop_suscept_total,
    prop_agsn, prop_agsn_suscept_alta, prop_agsn_suscept_total,
    built_m2_2010, n_pixels_2010, built_pct_2010
  )

save_grid(grade_2010_final, "grade_ibge_2010")

# 6b. Common grid: 2022 geometry + pop_2010_alocada -- THE interface scripts
#     04/05/07 build on ----

grade_common_final <- grade_2022 %>%
  select(
    id_celula, ID_UNICO, cod_mun, populacao, pop_2010_alocada, area_total,
    prop_suscept_alta, prop_suscept_total,
    prop_agsn, prop_agsn_suscept_alta, prop_agsn_suscept_total,
    built_m2_2010, built_m2_2020,
    n_pixels_2010, n_pixels_2020,
    built_pct_2010, built_pct_2020
  )

save_grid(grade_common_final, "grade_common_grid_2010_2022")

# 7. Final summary ----

cat("\n", strrep("=", 60), "\n")
cat("FINAL SUMMARY\n")
cat(strrep("=", 60), "\n")

summarize_grid <- function(grade, label, todos_mun, pop_col = "populacao") {
  cat(sprintf("\n--- %s ---\n", label))
  cat(sprintf("  Cells: %s\n", format(nrow(grade), big.mark = ".")))
  n_mun <- length(unique(grade$cod_mun))
  cat(sprintf("  Municipalities: %d of %d in the sample\n", n_mun, length(todos_mun)))
  cat(sprintf("  Total pop: %s\n",
              format(sum(grade[[pop_col]], na.rm = TRUE), big.mark = ".")))
  cat(sprintf("  Cells with prop_suscept_total > 0: %s\n",
              format(sum(grade$prop_suscept_total > 0, na.rm = TRUE), big.mark = ".")))
  cat(sprintf("  Cells with prop_agsn > 0: %s\n",
              format(sum(grade$prop_agsn > 0, na.rm = TRUE), big.mark = ".")))
}

summarize_grid(grade_2010_final, "grade_ibge_2010 (raw, pre-period only)", todos_mun)
summarize_grid(grade_common_final, "grade_common_grid_2010_2022 (populacao = 2022)", todos_mun)
cat(sprintf("\n  grade_common_grid_2010_2022, pop_2010_alocada total: %s\n",
            fmt(sum(grade_common_final$pop_2010_alocada, na.rm = TRUE))))

cat("\nGHSL built-up (cells with built > 0):")
cat("\n  grade_ibge_2010 (E2010 only):")
cat(sprintf("\n    E2010: %s cells", format(sum(grade_2010_final$built_pct_2010 > 0, na.rm = TRUE), big.mark = ".")))
cat("\n  grade_common_grid_2010_2022:")
for (ep in c(2010, 2020)) {
  col <- paste0("built_pct_", ep)
  n <- sum(grade_common_final[[col]] > 0, na.rm = TRUE)
  cat(sprintf("\n    E%d: %s cells", ep, format(n, big.mark = ".")))
}

# Missing municipalities
mun_faltantes_final <- setdiff(todos_mun, unique(grade_common_final$cod_mun))
if (length(mun_faltantes_final) > 0) {
  cat(sprintf("\n\nMissing municipalities (2022/common grid): %d\n",
              length(mun_faltantes_final)))
  faltantes_info <- sample_df %>%
    filter(cod_mun %in% mun_faltantes_final) %>%
    select(any_of(c("cod_mun", "nome_arranjo", "pop_2022", "tem_susceptibilidade"))) %>%
    arrange(desc(pop_2022))
  print(faltantes_info, n = 50)
}

if (!is.null(FILTRO_UF)) {
  cat(sprintf("\n\n*** TEST MODE: only UF = %s ***", FILTRO_UF))
  cat("\n*** Set FILTRO_UF to NULL to run all of Brazil ***")
}

cat("\n\nScript 03 complete!\n")
cat("Next step: 04_delimit_urban_extent.R\n")
