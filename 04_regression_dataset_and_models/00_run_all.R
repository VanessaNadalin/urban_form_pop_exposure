# =============================================================================
# 00_run_all.R
# Run every script in the 04_regression_dataset_and_models pipeline in
# sequence.
#
# Run from the project root:
#   Rscript 04_regression_dataset_and_models/00_run_all.R
#
# Each script runs in a clean environment to avoid variable conflicts. If a
# script fails, execution stops and the error is shown.
#
# Note: this stage estimates and saves the regression models (16); it does
# not format or export Table 2 or the Extended Data tables -- that belongs
# in 05_exhibits/ (see MIGRATION_PLAN.md), which only reads the results
# already estimated here, without re-estimating anything. 05_exhibits/
# robustness/'s seven scripts are kept live but unnumbered and are not part
# of this run-all.
#
# Manual raw inputs -- place these BEFORE running, no script downloads them:
#   data/raw_data/03_urban_footprint/tabela4709.xlsx   (script 01; SIDRA table 4709)
#   data/raw_data/04_regression/pib_munic.xlsx          (script 05; IBGE municipal GDP)
#   data/raw_data/04_regression/tabela200.xlsx          (script 05; SIDRA table 200)
#   data/raw_data/04_regression/tabela202.xlsx          (script 05; SIDRA table 202)
#   data/raw_data/04_regression/tabela3381.xlsx         (script 14; SIDRA table 3381)
# Everything else this stage reads is either downloaded automatically by the
# script itself (Census Basico zips, JRC water tiles, REGIC xlsx), by script
# 04 (every geobr/censobr dataset used later in this stage -- see its own
# header for the exact list and the manual-fallback procedure if geobr's or
# censobr's data server is unreachable), or via an R package's own cache
# (elevatr/SRTM).
#
# 2026-09-01: the old 04_download_municipal_seats.R was retired
# after IBGE restructured its
# geoftp layout, breaking its per-UF KML directory listing -- it turned out
# to be dead weight anyway (nothing downstream ever read its output). The
# "04" slot was then reused for 04_download_geobr_censobr.R, consolidating
# every geobr/censobr download in this stage into one script, instead of
# each of 07/09/10/11 downloading (and, briefly, separately handling a
# manual-fallback case for) its own. See MIGRATION_PLAN.md 6c0.
# =============================================================================

cat("\n", strrep("=", 70), "\n")
cat("FULL PIPELINE: REGRESSION DATASET AND MODELS\n")
cat(strrep("=", 70), "\n")
cat(sprintf("Start: %s\n", Sys.time()))

t0_total <- Sys.time()

scripts <- c(
  "04_regression_dataset_and_models/01_compose_sample.R",
  "04_regression_dataset_and_models/02_download_census_basic.R",
  "04_regression_dataset_and_models/03_download_jrc_water.R",
  "04_regression_dataset_and_models/04_download_geobr_censobr.R",
  "04_regression_dataset_and_models/05_prepare_gdp.R",
  # 06_builtup_in_susceptibility.py is Python -- run separately, before 07:
  #   python 04_regression_dataset_and_models/06_builtup_in_susceptibility.py
  "04_regression_dataset_and_models/07_housing_quality.R",
  "04_regression_dataset_and_models/08_available_land.R",
  "04_regression_dataset_and_models/09_distance_to_seat.R",
  "04_regression_dataset_and_models/10_topography.R",
  "04_regression_dataset_and_models/11_inequality.R",
  "04_regression_dataset_and_models/12_slum_growth.R",
  "04_regression_dataset_and_models/13_dependent_variables.R",
  "04_regression_dataset_and_models/14_independent_variables.R",
  "04_regression_dataset_and_models/15_final_dataset.R",
  "04_regression_dataset_and_models/16_estimate_models.R"
)

cat("\nNote: script 06 (06_builtup_in_susceptibility.py) is Python and must be\n")
cat("run separately before script 07, since 07 reads its output:\n")
cat("  python 04_regression_dataset_and_models/06_builtup_in_susceptibility.py\n")

for (s in scripts) {
  cat("\n", strrep("*", 70), "\n")
  cat(sprintf(">>> RUNNING: %s\n", s))
  cat(strrep("*", 70), "\n\n")

  t0 <- Sys.time()

  tryCatch({
    source(s, local = new.env(parent = globalenv()))
    elapsed <- round(as.numeric(difftime(Sys.time(), t0, units = "mins")), 1)
    cat(sprintf("\n>>> %s complete in %.1f min\n", basename(s), elapsed))
  }, error = function(e) {
    cat(sprintf("\n!!! ERROR in %s: %s\n", basename(s), conditionMessage(e)))
    stop("Pipeline interrupted.", call. = FALSE)
  })

  # Free memory between scripts
  gc(verbose = FALSE)
}

elapsed_total <- round(as.numeric(difftime(Sys.time(), t0_total, units = "mins")), 1)

cat("\n", strrep("=", 70), "\n")
cat("PIPELINE COMPLETE!\n")
cat(sprintf("Total time: %.1f min\n", elapsed_total))
cat(sprintf("End: %s\n", Sys.time()))
cat(strrep("=", 70), "\n")
