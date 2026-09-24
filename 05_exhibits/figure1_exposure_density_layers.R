# =============================================================================
# figure1_exposure_density_layers.R
# Figure 1 — layers for the population-at-risk panels (2010, 2022, change),
# mapped alongside the three growth-type groups (consolidated / compact /
# sprawl). figure1_growth_type_layers.R exports the growth-type panels.
#
# Added at the researcher's request on 2026-09-23 to test a new figure. The
# researcher then made these the new panels of Figure 1 (MIGRATION_HISTORY.md
# Part 2, 2026-09-23). Still to add: the panels' entry in results_used.md.
#
# Like figure1_growth_type_layers.R, this script only exports layers; the
# map itself is made by hand in QGIS.
#
# What it adds to the stage-3 common grid (no other column is changed):
#   pop_risk_2010   = pop_2010_alocada x prop_suscept_total
#   pop_risk_2022   = populacao        x prop_suscept_total
#   delta_pop_risk  = pop_risk_2022 - pop_risk_2010
#   dens_risk_2010, dens_risk_2022, delta_dens_risk
#                   = the three columns above per km^2 of cell area
#                     (area_total / 1e6)
#
# The weighting is the same area-weighted rule script 07 uses
# (MIGRATION_HISTORY.md 6e). The density columns are there because the
# common grid mixes 200 m cells (urban in 2022) and 1 km cells (elsewhere):
# a map of raw counts would make every 1 km cell look up to 25x "denser"
# than a 200 m cell of the same density. Symbolize on dens_* for density,
# on pop_risk_* / delta_pop_risk for counts.
#
# Input — grade_growth_types_2010_2022.parquet (stage 3 script 05) rather
# than grade_common_grid_2010_2022: it is the same common grid (same cells,
# same populacao / pop_2010_alocada / prop_suscept_total, carried through
# scripts 04 and 05) plus urbano_2010 / urbano_2020 / tipo_crescimento, so
# one layer holds both the exposure columns and the growth-type map.
#
# All cells of the processing universe are exported, urban or not. Summing
# pop_risk_* over the whole layer therefore does NOT give Table 1's totals,
# which count only cells urban in the relevant year with a growth type. The
# check in section 3 reproduces script 07's totals on that subset, to show
# the cell-level columns are consistent with the municipal file.
#
# Inputs:
#   - data/processed_data/03_urban_footprint/crescimento_urbano/grade_growth_types_2010_2022.parquet
#   - data/processed_data/03_urban_footprint/metricas/metricas_municipio_2010_2022.csv
#     (consistency check only; skipped if absent)
#   - data/processed_data/04_regression/tables/dataset_regressao_municipio.csv
#     (em_amostra_regressao flag only; all NA if absent)
#
# Output (data/processed_data/03_urban_footprint/figuras/ — a large GIS input,
# not a final exhibit, so not in output/; same convention as Figure 1):
#   - exposure_density_layers.gpkg
# =============================================================================

source("03_urban_footprint_and_growth_types/00_setup.R")

library(sfarrow)
library(sf)

cat("\n", strrep("=", 60), "\n")
cat("FIGURE1_EXPOSURE_DENSITY_LAYERS.R\n")
cat(strrep("=", 60), "\n")

figuras_dir <- file.path(processed_data_dir, "figuras")
dir.create(figuras_dir, showWarnings = FALSE)

TIPOS         <- c("consolidated", "densification", "infill",
                   "extension", "leapfrog", "peripheral")
TIPOS_COMPACT <- c("densification", "infill")
TIPOS_SPRAWL  <- c("peripheral", "extension", "leapfrog")

# --- 1) LOAD -------------------------------------------------------------------

cat("\n1) Loading growth-classification grid (stage 3 script 05)...\n")

grid_path <- file.path(processed_data_dir, "crescimento_urbano",
                       "grade_growth_types_2010_2022.parquet")
if (!file.exists(grid_path))
  stop("grade_growth_types_2010_2022.parquet not found — run stage 3 first.\n  Path: ", grid_path)

t0 <- Sys.time()
grade <- sfarrow::st_read_parquet(grid_path)
cat(sprintf("   %s cells (%.1f min)\n", fmt(nrow(grade)),
            as.numeric(difftime(Sys.time(), t0, units = "mins"))))

cols_needed <- c("id_celula", "cod_mun", "populacao", "pop_2010_alocada",
                 "prop_suscept_total", "area_total",
                 "urbano_2010", "urbano_2020", "tipo_crescimento")
missing_cols <- setdiff(cols_needed, names(grade))
if (length(missing_cols) > 0)
  stop("Missing columns in the grid: ", paste(missing_cols, collapse = ", "))

# Same guard as script 07: prop_suscept_total is used as a multiplicative
# weight, so it must be a proportion with no NAs.
stopifnot(
  "prop_suscept_total has NAs" = !anyNA(grade$prop_suscept_total),
  "prop_suscept_total outside [0, 1]" =
    all(grade$prop_suscept_total >= -1e-9 & grade$prop_suscept_total <= 1 + 1e-9),
  "area_total must be positive" = all(grade$area_total > 0, na.rm = TRUE)
)

# --- 2) DERIVE COLUMNS -----------------------------------------------------------

cat("\n2) Computing population at risk per cell...\n")

grade <- grade %>%
  mutate(
    pop_risk_2010   = pop_2010_alocada * prop_suscept_total,
    pop_risk_2022   = populacao        * prop_suscept_total,
    delta_pop_risk  = pop_risk_2022 - pop_risk_2010,
    area_km2        = area_total / 1e6,
    dens_risk_2010  = pop_risk_2010  / area_km2,
    dens_risk_2022  = pop_risk_2022  / area_km2,
    delta_dens_risk = delta_pop_risk / area_km2,
    grupo_3tipos = case_when(
      tipo_crescimento == "consolidated"  ~ "consolidated",
      tipo_crescimento %in% TIPOS_COMPACT ~ "compact",
      tipo_crescimento %in% TIPOS_SPRAWL  ~ "sprawl",
      TRUE                                ~ NA_character_
    )
  )

cat(sprintf("   Cells with pop_risk_2022 > 0: %s\n", fmt(sum(grade$pop_risk_2022 > 0, na.rm = TRUE))))
cat("   grupo_3tipos counts:\n")
print(table(grade$grupo_3tipos, useNA = "ifany"))

reg_sample_path <- processed_data_path("04_regression", "tables", "dataset_regressao_municipio.csv")
if (file.exists(reg_sample_path)) {
  em_amostra <- readr::read_csv(reg_sample_path, show_col_types = FALSE) %>%
    distinct(cod_mun) %>%
    mutate(cod_mun = as.character(cod_mun), em_amostra_regressao = TRUE)
  grade <- grade %>%
    mutate(cod_mun = as.character(cod_mun)) %>%
    left_join(em_amostra, by = "cod_mun") %>%
    mutate(em_amostra_regressao = coalesce(em_amostra_regressao, FALSE))
} else {
  cat("   WARNING: dataset_regressao_municipio.csv not found — em_amostra_regressao will be all NA.\n")
  grade$em_amostra_regressao <- NA
}

# --- 3) CONSISTENCY CHECK AGAINST SCRIPT 07 --------------------------------------
# Script 07 sums pop x prop_suscept_total over cells urban in the relevant
# year with a growth type. Reproducing that subset here must give the same
# totals as metricas_municipio_2010_2022.csv. Informational: a gap is
# reported, not stopped on, since this script changes nothing upstream.

cat("\n3) Consistency check against script 07's municipal totals...\n")

metricas_path <- file.path(processed_data_dir, "metricas", "metricas_municipio_2010_2022.csv")
if (file.exists(metricas_path)) {
  metricas <- readr::read_csv(metricas_path, show_col_types = FALSE)
  cells <- st_drop_geometry(grade)

  grid_2010 <- sum(cells$pop_risk_2010[cells$urbano_2010 %in% TRUE & cells$tipo_crescimento %in% TIPOS], na.rm = TRUE)
  grid_2022 <- sum(cells$pop_risk_2022[cells$urbano_2020 %in% TRUE & cells$tipo_crescimento %in% TIPOS], na.rm = TRUE)
  mun_2010  <- sum(metricas$pop_2010_risk_total, na.rm = TRUE)
  mun_2022  <- sum(metricas$pop_2022_risk_total, na.rm = TRUE)

  cat(sprintf("   2010: grid subset %s | script 07 %s | diff %s\n",
              fmt(round(grid_2010)), fmt(round(mun_2010)), fmt(round(grid_2010 - mun_2010))))
  cat(sprintf("   2022: grid subset %s | script 07 %s | diff %s\n",
              fmt(round(grid_2022)), fmt(round(mun_2022)), fmt(round(grid_2022 - mun_2022))))
  if (abs(grid_2010 - mun_2010) > 1 || abs(grid_2022 - mun_2022) > 1)
    warning("Cell-level totals differ from script 07's municipal file — check before using the layer.")
} else {
  cat("   metricas_municipio_2010_2022.csv not found — check skipped.\n")
}

# --- 4) SAVE ---------------------------------------------------------------------

cat("\n4) Saving...\n")

cols_out <- c("id_celula", "cod_mun", "em_amostra_regressao",
              "urbano_2010", "urbano_2020", "tipo_crescimento", "grupo_3tipos",
              "prop_suscept_total", "area_km2",
              "pop_2010_alocada", "populacao",
              "pop_risk_2010", "pop_risk_2022", "delta_pop_risk",
              "dens_risk_2010", "dens_risk_2022", "delta_dens_risk")
out <- grade[, c(cols_out, attr(grade, "sf_column"))]

out_gpkg <- file.path(figuras_dir, "exposure_density_layers.gpkg")
t0 <- Sys.time()
sf::st_write(out, out_gpkg, delete_dsn = TRUE, quiet = TRUE)
cat(sprintf("   Saved: %s (%.0f MB, %.1f min)\n", out_gpkg,
            file.size(out_gpkg) / 1024^2,
            as.numeric(difftime(Sys.time(), t0, units = "mins"))))

cat("\nDone. In QGIS: symbolize dens_risk_* / delta_dens_risk for the density map,\n")
cat("grupo_3tipos for the growth-type map; filter em_amostra_regressao or cod_mun\n")
cat("to crop to an illustrative city.\n")
