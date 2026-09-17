# =============================================================================
# R/paths.R
# Central path definitions for the pipeline (per MIGRATION_PLAN.md Task 5/6).
#
# Every script reads/writes data through this file instead of hardcoding
# per-pipeline paths (e.g. "risk_exposure/processed_data"). Stage subfolder
# names match MIGRATION_PLAN.md's data-path map: "02_hazard_zones",
# "03_urban_footprint", "04_regression" (stage 01's own outputs are folded
# into "02_hazard_zones" as the frozen 01+02 boundary; stage 05 has no data/
# subfolder of its own -- its final deliverables go to output_dir instead).
#
# Assumes the working directory is the repository root -- each stage's
# 00_setup.R sources this after setwd() to the repo root, matching the
# existing here::here() convention used throughout the pipeline.
# =============================================================================

data_raw_dir       <- file.path(here::here(), "data", "raw_data")
data_processed_dir <- file.path(here::here(), "data", "processed_data")
output_dir         <- file.path(here::here(), "output")

# raw_data_path("02_hazard_zones", "susceptibilidade_unida.gpkg") ->
#   data/raw_data/02_hazard_zones/susceptibilidade_unida.gpkg
# Creates the stage subfolder on first use if it doesn't exist yet.
raw_data_path <- function(stage, ...) {
  d <- file.path(data_raw_dir, stage)
  dir.create(d, recursive = TRUE, showWarnings = FALSE)
  file.path(d, ...)
}

processed_data_path <- function(stage, ...) {
  d <- file.path(data_processed_dir, stage)
  dir.create(d, recursive = TRUE, showWarnings = FALSE)
  file.path(d, ...)
}

output_path <- function(...) {
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  file.path(output_dir, ...)
}
