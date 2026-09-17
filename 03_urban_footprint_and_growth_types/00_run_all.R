# =============================================================================
# 00_run_all.R
# Run every script in the 03_urban_footprint_and_growth_types pipeline in
# sequence.
#
# Run from the project root:
#   Rscript 03_urban_footprint_and_growth_types/00_run_all.R
#
# Each script runs in a clean environment to avoid variable conflicts. If a
# script fails, execution stops and the error is shown.
#
# Note: Table 1 and Figure 1 are NOT part of this pipeline -- they moved to
# 05_exhibits/ (see MIGRATION_PLAN.md), which only reads the results already
# estimated here, without re-estimating anything.
# =============================================================================

cat("\n", strrep("=", 70), "\n")
cat("FULL PIPELINE: URBAN FORM METRICS\n")
cat(strrep("=", 70), "\n")
cat(sprintf("Start: %s\n", Sys.time()))

t0_total <- Sys.time()

scripts <- c(
  "03_urban_footprint_and_growth_types/01_define_sample.R",
  "03_urban_footprint_and_growth_types/02_download_ghsl_data.R",
  "03_urban_footprint_and_growth_types/03_integrate_grid_with_ghsl.R",
  "03_urban_footprint_and_growth_types/04_delimit_urban_extent.R",
  "03_urban_footprint_and_growth_types/05_classify_growth_types.R",
  "03_urban_footprint_and_growth_types/06_classify_growth_types_2000_2010.R",
  "03_urban_footprint_and_growth_types/07_aggregate_municipality_metrics.R"
)

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
