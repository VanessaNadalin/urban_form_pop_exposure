# =============================================================================
# 00_run_all.R
# Run every script in the 05_exhibits pipeline in sequence.
#
# Run from the project root:
#   Rscript 05_exhibits/00_run_all.R
#
# Each script runs in a clean environment to avoid variable conflicts. If a
# script fails, execution stops and the error is shown.
#
# Precondition -- stages 3 and 4 must already have been run, since this
# stage only reads their outputs and never re-estimates or re-derives
# anything itself:
#   data/processed_data/03_urban_footprint/metricas/metricas_municipio_2010_2022.csv
#   data/processed_data/04_regression/tables/dataset_regressao_municipio.csv
#   data/processed_data/04_regression/model_objects_table2.rds
#
# Excludes (deliberately, see 05_exhibits/pipeline_5.md):
#   - ed_sensitivity_leapfrog_threshold.R -- a multi-hour re-run of stage 3,
#     launched deliberately by the researcher, not part of a routine run-all
#     (item 6, skipped for now).
#   - robustness/ -- seven scripts kept live but unnumbered, not part of the
#     validated exhibit set and never promoted into results_used.md (6.8).
# =============================================================================

cat("\n", strrep("=", 70), "\n")
cat("FULL PIPELINE: EXHIBITS\n")
cat(strrep("=", 70), "\n")
cat(sprintf("Start: %s\n", Sys.time()))

t0_total <- Sys.time()

scripts <- c(
  "05_exhibits/table1_population_by_growth_type.R",
  "05_exhibits/figure1_growth_type_layers.R",
  "05_exhibits/figure2_exposure_scatter.R",
  "05_exhibits/table2_and_ed_tables.R",
  "05_exhibits/ed_figure_standardized_coefficients.R"
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
