# =============================================================================
# 00_setup.R
# Packages, paths and helper functions for the urban form pipeline
# =============================================================================

# --- Packages ------------------------------------------------------------------
library(sf)
library(terra)
library(dplyr)
library(tidyr)
library(readxl)
library(readr)
library(stringr)
library(stringi)
library(geobr)
library(purrr)

# --- Paths -----------------------------------------------------------------------
# Central path definitions (data/raw_data, data/processed_data, output/),
# shared across all five pipeline folders -- see R/paths.R.
source("R/paths.R")

# Raw input data (DUR_Municipios.xlsx, tabela4709.xlsx, GHSL tifs)
raw_data_dir <- raw_data_path("03_urban_footprint")

# Processed output data
processed_data_dir <- processed_data_path("03_urban_footprint")

# Output subfolders (ghsl_raw lives under raw_data_dir -- it's raw downloaded
# data, not processed by this pipeline, see MIGRATION_PLAN.md Task 6b)
dir.create(file.path(raw_data_dir, "ghsl_raw"), showWarnings = FALSE)
dir.create(file.path(processed_data_dir, "crescimento_urbano"), showWarnings = FALSE)
dir.create(file.path(processed_data_dir, "metricas"), showWarnings = FALSE)

# --- Helper functions --------------------------------------------------------

# Format numbers with a thousands separator (dot) and decimal comma
# Avoids the "big.mark and decimal.mark are both '.'" warning
fmt <- function(x, ...) format(x, big.mark = ".", decimal.mark = ",", ...)

cat("Directories configured:\n")
cat("  raw_data_dir:", raw_data_dir, "\n")
cat("  processed_data_dir:", processed_data_dir, "\n")
