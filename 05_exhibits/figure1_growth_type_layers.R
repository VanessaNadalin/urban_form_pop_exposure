# =============================================================================
# figure1_growth_type_layers.R
# Figure 1 — urban growth classification map (2010-2020), panels a-c
# (results_used.md: "Inputs needed to produce maps by hand, script should
# generate geoparquet files.")
#
# This script exports the geoparquet/gpkg layers the draft asks for. It does
# NOT produce the finished figure — per results_used.md's own wording, panel
# layout, cropping to the illustrative area(s), styling and labelling remain
# a manual GIS step ("by hand").
#
# Panels and their source column, all from ONE grid (single source, one file
# — not three separate exports, since the underlying grid is ~289 MB and all
# three panels share the same geometry and differ only in which column is
# used to symbolize it):
#   Panel a — urban footprint 2010 vs. urban footprint 2020 (to visualise
#             the 2010 footprint and 2010-2020 growth)
#       -> urbano_2010 / urbano_2020 (already on the input grid -- see below)
#   Panel b — urban footprint 2020 classified into the 6 growth types
#       -> tipo_crescimento (already in the input grid, script 05 output)
#   Panel c — urban footprint 2020 classified into 3 groups (consolidated /
#             compact / sprawl) + high-susceptibility layer
#       -> derived column grupo_3tipos (recode of tipo_crescimento, same
#          compact/sprawl grouping as 07_aggregate_municipality_metrics.R and
#          table1_population_by_growth_type.R) + prop_suscept_alta
#          (already in the input grid, inherited from script 03)
#
# urbano_2010 / urbano_2020 are read straight off the grid, computed by
# stage-3 script 04 (classificar_urbano(): built_pct >= 10% AND density >=
# 300 inhab/km^2, jointly) and required as an input by script 05 itself
# (its own cols_necessarias check), so they are guaranteed present on
# grade_growth_types_2010_2022.parquet. An earlier version of this script
# instead RE-DERIVED them from tipo_crescimento (consolidated/densification/
# peripheral => urban in 2010; any non-NA type => urban in 2020) -- that
# derivation disagrees with the real columns for shrinkage cells: a cell
# urban in 2010 but not in 2020 is classified "consolidated" by script 05
# ("shrinkage grouped into consolidated (occupation involution)"), so the
# derived urbano_2020 would wrongly read TRUE for it. Fixed here to use the
# grid's own columns; the one-time crosstab below records how often the two
# actually disagreed.
#
# For panel c's high-susceptibility overlay, this script does NOT regenerate
# the dissolved susceptibility polygon — it already exists as
# data/processed_data/02_hazard_zones/susceptibilidade_unida.gpkg (stage 2
# output) and CLAUDE.md rule 7 says to avoid rerunning slow spatial steps
# redundantly. Load that file directly in QGIS as the overlay layer; this
# script only carries the cell-level prop_suscept_alta share for an
# alternative continuous-shading treatment of the same panel if preferred.
#
# Sample: NOT restricted to the regression dataset (unlike Table 1/Figure 2)
# — Figure 1 is an illustrative map, not a value that must sum to a target
# number, so this script exports the full processing universe and adds an
# `em_amostra_regressao` flag so the researcher can filter to a specific
# illustrative city/region in QGIS.
#
# Inputs:
#   - data/processed_data/03_urban_footprint/crescimento_urbano/grade_growth_types_2010_2022.parquet
#     (03_urban_footprint_and_growth_types/05_classify_growth_types.R; MIGRATION_PLAN.md 6b0
#     common-grid rework -- replaces the retired grade_crescimento_2010_2020.parquet.
#     tipo_crescimento/prop_suscept_alta/cod_mun/urbano_2010/urbano_2020, the only columns
#     this script reads, are unchanged in name/meaning by the rework)
#   - data/processed_data/04_regression/tables/dataset_regressao_municipio.csv
#     (stage 4 script 15, for the sample flag only)
#
# Outputs (in data_processed/figuras/):
#   - figura1_camadas.parquet / .gpkg
#       columns: id_celula, ID_UNICO, cod_mun, em_amostra_regressao,
#                urbano_2010, urbano_2020, tipo_crescimento, grupo_3tipos,
#                prop_suscept_alta, geometry
# =============================================================================

source("03_urban_footprint_and_growth_types/00_setup.R")

library(sfarrow)
library(sf)

cat("\n", strrep("=", 60), "\n")
cat("FIGURE1_GROWTH_TYPE_LAYERS.R\n")
cat(strrep("=", 60), "\n")

figuras_dir <- file.path(processed_data_dir, "figuras")
dir.create(figuras_dir, showWarnings = FALSE)

# --- 1) LOAD DATA -------------------------------------------------------------

cat("\n1) Loading growth-classification grid (script 05)...\n")

cresc_path <- file.path(processed_data_dir, "crescimento_urbano", "grade_growth_types_2010_2022.parquet")
if (!file.exists(cresc_path))
  stop("grade_growth_types_2010_2022.parquet not found — run 03_urban_footprint_and_growth_types/05_classify_growth_types.R first.\n  Path: ", cresc_path)

t0 <- Sys.time()
grade <- sfarrow::st_read_parquet(cresc_path)
cat(sprintf("   %s cells (%.1f min)\n", fmt(nrow(grade)),
            as.numeric(difftime(Sys.time(), t0, units = "mins"))))

cols_precisas <- c("tipo_crescimento", "prop_suscept_alta", "cod_mun", "urbano_2010", "urbano_2020")
faltando <- setdiff(cols_precisas, names(grade))
if (length(faltando) > 0)
  stop("Missing columns in grade_growth_types_2010_2022.parquet: ", paste(faltando, collapse = ", "))

reg_sample_path <- processed_data_path("04_regression", "tables", "dataset_regressao_municipio.csv")
em_amostra <- NULL
if (file.exists(reg_sample_path)) {
  em_amostra <- readr::read_csv(reg_sample_path, show_col_types = FALSE) %>%
    select(cod_mun) %>% distinct() %>%
    mutate(cod_mun = as.character(cod_mun), em_amostra_regressao = TRUE)
} else {
  cat("   WARNING: dataset_regressao_municipio.csv not found — em_amostra_regressao will be all NA.\n")
}

# --- 2) DERIVE PANEL COLUMNS ---------------------------------------------------

cat("\n2) Deriving panel c's 3-group column; checking urbano_2010/urbano_2020...\n")

TIPOS_2010    <- c("consolidated", "densification", "peripheral")
TIPOS_COMPACT <- c("densification", "infill")
TIPOS_SPRAWL  <- c("peripheral", "extension", "leapfrog")

# One-time record of how the OLD derivation (from tipo_crescimento alone)
# would have disagreed with the grid's REAL urbano_2010/urbano_2020 (script
# 04) -- see the header note. panel a below uses the real columns, not this.
urbano_2010_derivado <- grade$tipo_crescimento %in% TIPOS_2010
urbano_2020_derivado <- !is.na(grade$tipo_crescimento)
cat("\n   urbano_2010: derived (from tipo_crescimento) vs. real (script 04):\n")
print(table(derived = urbano_2010_derivado, real = grade$urbano_2010, useNA = "ifany"))
cat("\n   urbano_2020: derived (from tipo_crescimento) vs. real (script 04):\n")
print(table(derived = urbano_2020_derivado, real = grade$urbano_2020, useNA = "ifany"))

grade <- grade %>%
  mutate(
    grupo_3tipos = case_when(
      tipo_crescimento == "consolidated"    ~ "consolidated",
      tipo_crescimento %in% TIPOS_COMPACT   ~ "compact",
      tipo_crescimento %in% TIPOS_SPRAWL    ~ "sprawl",
      TRUE                                  ~ NA_character_
    )
  )

if (!is.null(em_amostra)) {
  grade <- grade %>%
    left_join(em_amostra, by = "cod_mun") %>%
    mutate(em_amostra_regressao = coalesce(em_amostra_regressao, FALSE))
} else {
  grade$em_amostra_regressao <- NA
}

cat("\n   urbano_2010 / urbano_2020 crosstab (real columns, script 04 -- used for panel a):\n")
print(table(urbano_2010 = grade$urbano_2010, urbano_2020 = grade$urbano_2020, useNA = "ifany"))

cat("\n   grupo_3tipos counts:\n")
print(table(grade$grupo_3tipos, useNA = "ifany"))

# --- 3) SELECT COLUMNS AND SAVE -------------------------------------------------

cat("\n3) Selecting output columns and saving...\n")

cols_saida <- intersect(
  c("id_celula", "ID_UNICO", "cod_mun", "em_amostra_regressao",
    "urbano_2010", "urbano_2020", "tipo_crescimento", "grupo_3tipos",
    "prop_suscept_alta"),
  names(grade)
)
saida <- grade[, c(cols_saida, attr(grade, "sf_column"))]

out_parquet <- file.path(figuras_dir, "figura1_camadas.parquet")
out_gpkg    <- file.path(figuras_dir, "figura1_camadas.gpkg")

sfarrow::st_write_parquet(saida, out_parquet)
cat(sprintf("   Saved: %s\n", out_parquet))

sf::st_write(saida, out_gpkg, delete_dsn = TRUE, quiet = TRUE)
cat(sprintf("   Saved: %s (for QGIS)\n", out_gpkg))

cat("\n   Reminder — panel c's high-susceptibility overlay layer already\n")
cat("   exists and is NOT regenerated here:\n")
cat("     data/processed_data/02_hazard_zones/susceptibilidade_unida.gpkg\n")

cat("\nDone. Next step (manual, in QGIS): pick an illustrative city/region\n")
cat("(e.g. filter em_amostra_regressao == TRUE and crop to one cod_mun or\n")
cat("arranjo), then build panels a/b/c by symbolizing this single layer on\n")
cat("urbano_2010/urbano_2020 (panel a), tipo_crescimento (panel b), and\n")
cat("grupo_3tipos + susceptibilidade_unida.gpkg overlay (panel c).\n")