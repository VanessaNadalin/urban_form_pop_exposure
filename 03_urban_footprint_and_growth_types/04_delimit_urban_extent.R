# =============================================================================
# 04_delimit_urban_extent.R
# Classify each cell of the common grid as urban/non-urban, at both points in
# time, based on two combined (AND) criteria:
#   1. Built-up surface (GHSL built_pct)
#   2. Population density (inhabitants/km^2)
#
# Methodology:
#   URBAN cell = built_pct >= LIMIAR_BUILT (%) AND dens_hab_km2 >= LIMIAR_DENS
#
#   The AND criterion excludes built-up areas with no population (sheds,
#   airports, infrastructure) and keeps only cells with meaningful human
#   presence.
#
#   LIMIAR_DENS is applied as a density (inhabitants/km^2), computed from
#   population / (area_total_m2 / 1e6). This keeps the criterion consistent
#   across the grid's two cell sizes (200m x 200m in urban areas, 1km x 1km
#   elsewhere):
#     - 200m x 200m cell (0.04 km^2): LIMIAR_DENS = 300 inhab/km^2 -> 12 people
#     - 1km x 1km cell   (1 km^2):    LIMIAR_DENS = 300 inhab/km^2 -> 300 people
#
# Per MIGRATION_PLAN.md 6b0 (common-grid unification, decided 2026-08-28):
# both urbano_2010 and urbano_2020 are now computed directly on the single
# 2022 grid geometry, each with its own year's population --
# populacao (2022 census) for urbano_2020, pop_2010_alocada (allocated 2010
# population, root-cause bug fixed in script 03) for urbano_2010. This
# replaces the pre-unification design, where each grid only carried the
# flag matching its own native census year, and the complementary flag was
# computed downstream in script 05 using the OTHER year's population as a
# "best available" proxy -- that proxying is no longer needed now that a
# real (allocated) 2010 population exists on this grid.
#
# Inputs:
#   - grade_common_grid_2010_2022.parquet  (script 03)
#
# Outputs:
#   - grade_urban_form_2010_2022.gpkg / .parquet  (common grid + urbano_2010 + urbano_2020)
#
# Next step: 05_classify_growth_types.R
# =============================================================================

source("03_urban_footprint_and_growth_types/00_setup.R")

library(sfarrow)

# --- Configuration ----

# Built-up surface threshold (% of the cell)
LIMIAR_BUILT <- 10   # lowered from 20% to capture dense/informal housing

# Population density threshold (inhabitants/km^2)
# 300 inhab/km^2 is a standard minimum-urban-density reference
# Equivalent to ~12 people in a 200m x 200m cell (0.04 km^2)
LIMIAR_DENS <- 300

cat(sprintf("\nUrban criterion: built_pct >= %g%% AND dens_hab_km2 >= %g\n",
            LIMIAR_BUILT, LIMIAR_DENS))

# Helper: classify urban with the AND criterion
classificar_urbano <- function(built_pct, populacao, area_total_m2,
                               lim_built, lim_dens) {
  dens <- populacao / (area_total_m2 / 1e6)
  !is.na(built_pct) & built_pct >= lim_built &
    !is.na(dens) & dens >= lim_dens
}

# =============================================================================
# 1) LOAD THE COMMON GRID FROM SCRIPT 03
# =============================================================================

cat("\n", strrep("=", 60), "\n")
cat("1) LOADING THE COMMON GRID FROM SCRIPT 03\n")
cat(strrep("=", 60), "\n\n")

t0 <- Sys.time()
grade <- sfarrow::st_read_parquet(
  file.path(processed_data_dir, "grade_common_grid_2010_2022.parquet")
)
cat(sprintf("Common grid: %s cells (%.1f min)\n",
            fmt(nrow(grade)),
            as.numeric(difftime(Sys.time(), t0, units = "mins"))))

# =============================================================================
# 2) CLASSIFY URBAN EXTENT
# =============================================================================

cat("\n", strrep("=", 60), "\n")
cat(sprintf("2) CLASSIFYING URBAN EXTENT\n"))
cat(sprintf("   built_pct >= %g%% AND dens_hab_km2 >= %g\n",
            LIMIAR_BUILT, LIMIAR_DENS))
cat(strrep("=", 60), "\n")

grade <- grade %>%
  mutate(
    urbano_2010 = classificar_urbano(built_pct_2010, pop_2010_alocada, area_total,
                                     LIMIAR_BUILT, LIMIAR_DENS),
    urbano_2020 = classificar_urbano(built_pct_2020, populacao, area_total,
                                     LIMIAR_BUILT, LIMIAR_DENS)
  )

n_cel      <- nrow(grade)
n_urb_2010 <- sum(grade$urbano_2010, na.rm = TRUE)
n_urb_2020 <- sum(grade$urbano_2020, na.rm = TRUE)

cat(sprintf("\n--- t1: 2010 (built_pct_2010 + pop_2010_alocada) ---\n"))
cat(sprintf("  Total cells:     %s\n", fmt(n_cel)))
cat(sprintf("  Urban in 2010:   %s (%.1f%%)\n",
            fmt(n_urb_2010), 100 * n_urb_2010 / n_cel))

pop_urb_2010   <- sum(grade$pop_2010_alocada[grade$urbano_2010], na.rm = TRUE)
pop_total_2010 <- sum(grade$pop_2010_alocada, na.rm = TRUE)
cat(sprintf("  Pop in urban cells 2010: %s (%.1f%% of total)\n",
            fmt(pop_urb_2010),
            100 * pop_urb_2010 / pop_total_2010))

cat(sprintf("\n--- t2: 2020/2022 (built_pct_2020 + populacao) ---\n"))
cat(sprintf("  Total cells:     %s\n", fmt(n_cel)))
cat(sprintf("  Urban in 2020:   %s (%.1f%%)\n",
            fmt(n_urb_2020), 100 * n_urb_2020 / n_cel))

pop_urb_2020   <- sum(grade$populacao[grade$urbano_2020], na.rm = TRUE)
pop_total_2022 <- sum(grade$populacao, na.rm = TRUE)
cat(sprintf("  Pop in urban cells 2020: %s (%.1f%% of total)\n",
            fmt(pop_urb_2020),
            100 * pop_urb_2020 / pop_total_2022))

# =============================================================================
# 3) SAVE
# =============================================================================

cat("\n", strrep("=", 60), "\n")
cat("3) SAVING THE GRID WITH URBAN CLASSIFICATION\n")
cat(strrep("=", 60), "\n")

gpkg_path    <- file.path(processed_data_dir, "grade_urban_form_2010_2022.gpkg")
parquet_path <- file.path(processed_data_dir, "grade_urban_form_2010_2022.parquet")

t0 <- Sys.time()
st_write(grade, gpkg_path, delete_dsn = TRUE, quiet = TRUE)
elapsed <- round(as.numeric(difftime(Sys.time(), t0, units = "mins")), 1)
size_mb <- file.size(gpkg_path) / 1024^2
cat(sprintf("  %s (%.0f MB, %.1f min)\n",
            basename(gpkg_path), size_mb, elapsed))

t0 <- Sys.time()
sfarrow::st_write_parquet(grade, parquet_path)
elapsed <- round(as.numeric(difftime(Sys.time(), t0, units = "mins")), 1)
size_mb <- file.size(parquet_path) / 1024^2
cat(sprintf("  %s (%.0f MB, %.1f min)\n",
            basename(parquet_path), size_mb, elapsed))

# =============================================================================
# 4) FINAL SUMMARY
# =============================================================================

cat("\n", strrep("=", 60), "\n")
cat("FINAL SUMMARY\n")
cat(strrep("=", 60), "\n")

cat(sprintf("\nUrban criterion: built_pct >= %g%% AND dens_hab_km2 >= %g\n",
            LIMIAR_BUILT, LIMIAR_DENS))

cat(sprintf("\nUrban cells in 2010 (pop_2010_alocada): %s\n", fmt(n_urb_2010)))
cat(sprintf("Urban cells in 2020/2022 (populacao):    %s\n", fmt(n_urb_2020)))

cat("\nScript 04 complete!\n")
cat("Next step: 05_classify_growth_types.R\n")
