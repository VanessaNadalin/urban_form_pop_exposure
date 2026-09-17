# =============================================================================
# build_results_targets.R
# Reads the current exhibit outputs and writes manuscript/results_targets_v2.md
# -- the single source for every number the manuscript will use.
#
# THE SCRIPT IS THE DELIVERABLE. The .md is its output: regenerated on every
# run, never hand-edited. Anything edited by hand there is lost on the next run.
#
# Run from the repository root:
#   Rscript 05_exhibits/build_results_targets.R
#
# READ-ONLY with respect to every pipeline file. The only thing it writes is
# manuscript/results_targets_v2.md. It does not touch results_used.md, and it
# never re-runs a pipeline step.
#
# -----------------------------------------------------------------------------
# SOURCING RULES, in order of preference
#
# 1. A CSV an exhibit script wrote            -> read it, record path + mtime.
# 2. model_objects_table2.rds                 -> every coefficient, recomputed
#    through the SAME vcov path 16_estimate_models.R uses (coeftest with
#    vcov_clust / vcov_hc3, cluster vector off attr(mod, "cluster_vec")).
# 3. Recomputed here from the regression dataset / classified grid, mirroring
#    the exhibit script's own logic, ONLY where the exhibit prints the value to
#    console and writes it to no file. Every such entry is labelled
#    "recomputed here" and names the script whose logic was mirrored.
#
# NEVER parsed: .docx, .html, .png, .pdf. Those are formatted artefacts; a
# coefficient read out of one cannot be checked against the model that
# produced it.
#
# STALENESS is DIRECTIONAL, because the pipeline has an order. The reference
# clock is the most recent stage-04 run (model_objects_table2.rds, falling back
# to dataset_regressao_municipio.csv). Each input is ranked relative to it:
#
#   upstream   (stages 02, 03, 04) runs BEFORE the models, so being older than
#              the reference is CORRECT ORDER. Stage 02's outputs are the frozen
#              deposited intermediates and are months older by design. An
#              upstream input is stale only when it is NEWER than the reference:
#              it was regenerated after the fit, so the models are behind it.
#   downstream (stage-05 exhibit outputs) is produced FROM the models, so it is
#              stale when OLDER than the reference: built from an earlier fit.
#   exempt     hand-supplied drop-ins; existence only.
#
# An earlier version of this script tested one direction for everything and
# wrongly flagged stages 02 and 03 as stale on a correctly-ordered run.
#
# Every entry carries the file it came from and that file's mtime. A missing or
# stale input yields PENDING with the reason. The script NEVER substitutes a
# value it cannot source -- no defaults, no carried-over numbers, no values
# taken from documentation.
# =============================================================================

# --- Bootstrap ----------------------------------------------------------------
# 05_exhibits/ has no 00_setup.R of its own: its scripts source either stage
# 03's or stage 04's. This script needs both stages' paths, so it sources
# stage 04's (which defines stage03_data_dir, metricas_dir, tables_dir,
# data_dir, figures_dir and MIN_POP_RISCO_2010, and sources R/paths.R for
# raw_data_path()/processed_data_path()/output_path()). No setwd() anywhere:
# the working directory must already be the repository root.

if (!file.exists("04_regression_dataset_and_models/00_setup.R"))
  stop("Run this from the repository root: 04_regression_dataset_and_models/00_setup.R not found ",
       "relative to '", getwd(), "'.")

source("04_regression_dataset_and_models/00_setup.R")

for (pkg in c("lmtest", "sandwich")) {
  if (!requireNamespace(pkg, quietly = TRUE)) install.packages(pkg)
  library(pkg, character.only = TRUE)
}

# Stage 03's own name for its processed folder, as its scripts use it.
stage03_proc_dir <- stage03_data_dir

# R/paths.R models data/ and output/ only; the manuscript folder is not one of
# its stages, so it is derived from the same here::here() root paths.R uses.
manuscript_path <- function(...) {
  d <- file.path(here::here(), "manuscript")
  dir.create(d, recursive = TRUE, showWarnings = FALSE)
  file.path(d, ...)
}

OUT_MD <- manuscript_path("results_targets_v2.md")

# A file whose mtime predates the stage-04 reference by more than this is
# reported STALE. One hour absorbs ordinary within-run ordering (stage 05 runs
# after stage 04, so its outputs are normally NEWER, not older).
STALE_TOLERANCE_SECS <- 3600

RUN_TIME <- Sys.time()

`%||%` <- function(a, b) if (is.null(a)) b else a

cat("\n", strrep("=", 70), "\n", sep = "")
cat("BUILD_RESULTS_TARGETS.R\n")
cat(strrep("=", 70), "\n", sep = "")
cat(sprintf("Run: %s\n", format(RUN_TIME, "%Y-%m-%d %H:%M:%S %Z")))

repo_commit <- tryCatch({
  x <- suppressWarnings(system("git rev-parse --short HEAD", intern = TRUE,
                               ignore.stderr = TRUE))
  if (length(x) == 0 || !nzchar(x[1])) "UNKNOWN" else x[1]
}, error = function(e) "UNKNOWN")

repo_dirty <- tryCatch({
  x <- suppressWarnings(system("git status --porcelain", intern = TRUE,
                               ignore.stderr = TRUE))
  length(x) > 0
}, error = function(e) NA)

cat(sprintf("Repo commit: %s%s\n", repo_commit,
            if (isTRUE(repo_dirty)) " (working tree has uncommitted changes)" else ""))

# =============================================================================
# 1) INPUT REGISTRY
# =============================================================================
# Every path this script may read, registered once so the run header can print
# the full manifest with mtimes whether or not the file was actually needed.

INPUTS <- new.env(parent = emptyenv())

# rank says where the input sits relative to the stage-04 reference run, which
# is what makes staleness directional:
#   "upstream"   stages 02-04 -- produced BEFORE the models. Being older than
#                the reference is correct pipeline order, not staleness. It is
#                stale only if it is NEWER, i.e. it was regenerated after the
#                models were fitted, so the models no longer reflect it.
#   "downstream" stage-05 exhibit outputs -- produced FROM the models. Stale if
#                OLDER than the reference, i.e. built from a previous fit.
#   "exempt"     hand-supplied drop-ins with no position in the run order; only
#                their existence is checked.
reg_input <- function(key, path, what, rank = "upstream") {
  assign(key, list(key = key, path = path, what = what, rank = rank), envir = INPUTS)
  invisible(path)
}

inp <- function(key) get(key, envir = INPUTS)

inp_path   <- function(key) inp(key)$path
inp_exists <- function(key) file.exists(inp_path(key))
inp_mtime  <- function(key) if (inp_exists(key)) file.mtime(inp_path(key)) else as.POSIXct(NA)

# Path shown in the .md: repo-relative where possible, so the file is portable.
rel_path <- function(p) {
  root <- normalizePath(here::here(), winslash = "/", mustWork = FALSE)
  pp   <- normalizePath(p, winslash = "/", mustWork = FALSE)
  if (startsWith(pp, paste0(root, "/"))) substring(pp, nchar(root) + 2L) else p
}

fmt_mtime <- function(t) if (is.na(t)) "—" else format(t, "%Y-%m-%d %H:%M:%S")

# ---- stage 02 ----------------------------------------------------------------
reg_input("s02_resumo_alta", file.path(stage02_data_dir, "resumo_municipal_suscept_alta_agsn.csv"),
          "stage 02 municipal summary, high susceptibility (03_cross_grid_high_susceptibility.py)")
reg_input("s02_resumo_risco", file.path(stage02_data_dir, "resumo_municipal_risco_agsn.csv"),
          "stage 02 municipal summary, CPRM risk (04_cross_grid_cprm_risk.py)")

# ---- stage 03 ----------------------------------------------------------------
reg_input("s03_amostra_rds", amostra_rds,
          "stage 03 sample (01_define_sample.R)")
reg_input("s03_metricas_mun", file.path(metricas_dir, "metricas_municipio_2010_2022.csv"),
          "stage 03 municipality metrics (07_aggregate_municipality_metrics.R)")
reg_input("s03_metricas_arr", file.path(metricas_dir, "metricas_arranjo_2010_2022.csv"),
          "stage 03 arrangement metrics (07_aggregate_municipality_metrics.R)")
reg_input("s03_grade_growth", file.path(stage03_proc_dir, "crescimento_urbano",
                                        "grade_growth_types_2010_2022.parquet"),
          "stage 03 classified grid (05_classify_growth_types.R)")

# ---- stage 04 ----------------------------------------------------------------
reg_input("s04_amostra_mun", file.path(data_dir, "amostra_mun.csv"),
          "stage 04 municipality sample (01_compose_sample.R)")
reg_input("s04_mun_isol", file.path(data_dir, "mun_isol.csv"),
          "stage 04 isolated municipalities (01_compose_sample.R)")
reg_input("s04_amostra_arr", file.path(data_dir, "amostra_arr.csv"),
          "stage 04 qualified-arrangement members (01_compose_sample.R)")
reg_input("s04_amostra_universo", file.path(data_dir, "amostra_universo.csv"),
          "stage 04 processing universe (01_compose_sample.R)")
reg_input("s04_ds_mun", file.path(tables_dir, "dataset_regressao_municipio.csv"),
          "stage 04 municipality regression dataset (15_final_dataset.R)")
reg_input("s04_ds_arr", file.path(tables_dir, "dataset_regressao_arranjo.csv"),
          "stage 04 arrangement regression dataset (15_final_dataset.R)")
reg_input("s04_models", file.path(data_dir, "model_objects_table2.rds"),
          "stage 04 fitted models + metadata (16_estimate_models.R)")

# ---- stage 05 outputs --------------------------------------------------------
reg_input("s05_tab1a", output_path("tabela1a_populacao_totais_tipo.csv"),
          "Table 1a (table1_population_by_growth_type.R)", rank = "downstream")
reg_input("s05_tab1b", output_path("tabela1_populacao_risco_tipo.csv"),
          "Table 1b (table1_population_by_growth_type.R)", rank = "downstream")
reg_input("s05_edfig", output_path("ed_figure_standardized_coefficients.csv"),
          "ED Figure standardized betas (ed_figure_standardized_coefficients.R)", rank = "downstream")
reg_input("s05_fig1_layers", file.path(stage03_proc_dir, "figuras", "figura1_camadas.parquet"),
          "Figure 1 layers (figure1_growth_type_layers.R)", rank = "downstream")

# ---- robustness --------------------------------------------------------------
reg_input("rb_sensitivity", file.path(figures_dir, "sensitivity_min_pop_risco.csv"),
          "minimum-baseline sweep (robustness/minimum_population_filter.R)", rank = "downstream")
reg_input("rb_sens_sizes", file.path(figures_dir, "sensitivity_min_pop_risco_sample_sizes.csv"),
          "minimum-baseline sweep, sample sizes (robustness/minimum_population_filter.R)", rank = "downstream")

# ---- optional drop-in --------------------------------------------------------
# ED Table 3's PRE-6f coefficients cannot be recomputed from the current
# pipeline: 6f.2 changed stage 03's arrangement denominators, so reproducing
# them means re-running stage 03 under the old rule. If an archived copy of the
# pre-6f arrangement coefficients exists as a CSV with columns
# spec,estimate,std_error,p_value,n_obs it is read; otherwise those entries are
# PENDING. Nothing is invented.
reg_input("pre6f_ed3", file.path(data_dir, "pre_6f_ed_table3_coefficients.csv"),
          "OPTIONAL archived pre-6f ED Table 3 coefficients (supplied by hand, if at all)", rank = "exempt")

# =============================================================================
# 2) STALENESS REFERENCE
# =============================================================================

ref_key <- if (inp_exists("s04_models")) "s04_models" else
           if (inp_exists("s04_ds_mun")) "s04_ds_mun" else NA_character_
STAGE04_REF_TIME <- if (is.na(ref_key)) as.POSIXct(NA) else inp_mtime(ref_key)

cat(sprintf("Stage-04 reference clock: %s (%s)\n",
            fmt_mtime(STAGE04_REF_TIME),
            if (is.na(ref_key)) "NOT FOUND — every entry will be PENDING" else rel_path(inp_path(ref_key))))

# Returns NULL if usable, or a reason string if the input cannot be trusted.
input_problem <- function(key) {
  if (!inp_exists(key))
    return(sprintf("file not found: %s", rel_path(inp_path(key))))
  rank <- inp(key)$rank %||% "upstream"
  if (rank == "exempt") return(NULL)
  if (is.na(STAGE04_REF_TIME))
    return("stage-04 reference clock unavailable (model_objects_table2.rds and dataset_regressao_municipio.csv both missing)")
  mt   <- inp_mtime(key)
  gap  <- as.numeric(difftime(mt, STAGE04_REF_TIME, units = "secs"))
  if (rank == "upstream" && gap > STALE_TOLERANCE_SECS)
    return(sprintf("STALE: mtime %s is LATER than the stage-04 run (%s) -- this input was regenerated after the models were fitted, so the models no longer reflect it. Re-run stage 04.",
                   fmt_mtime(mt), fmt_mtime(STAGE04_REF_TIME)))
  if (rank == "downstream" && gap < -STALE_TOLERANCE_SECS)
    return(sprintf("STALE: mtime %s predates the stage-04 run (%s) -- this exhibit was built from an earlier fit. Re-run stage 05.",
                   fmt_mtime(mt), fmt_mtime(STAGE04_REF_TIME)))
  NULL
}

# =============================================================================
# 3) ENTRY ACCUMULATOR
# =============================================================================

ENTRIES <- list()

# july: the value results_used.md carries (character, or NA if it states none).
# changed_by: the MIGRATION_PLAN.md section that explains the change.
add <- function(section, item, value, source_key = NA_character_,
                status = "VERIFIED", july = NA_character_,
                changed_by = NA_character_, note = NA_character_,
                source_label = NA_character_) {
  src_txt <- if (!is.na(source_label)) source_label
             else if (!is.na(source_key)) sprintf("`%s` (%s)",
                                                  rel_path(inp_path(source_key)),
                                                  fmt_mtime(inp_mtime(source_key)))
             else "—"
  ENTRIES[[length(ENTRIES) + 1L]] <<- list(
    section = section, item = item,
    value = if (length(value) == 0 || is.na(value[1])) "—"
            else if (length(value) > 1) paste(as.character(value), collapse = "; ")
            else as.character(value),
    status = status, source = src_txt,
    july = if (is.na(july)) "—" else july,
    changed_by = if (is.na(changed_by)) "—" else changed_by,
    note = if (is.na(note)) "" else note
  )
  invisible(NULL)
}

pending <- function(section, item, reason, july = NA_character_,
                    changed_by = NA_character_, note = NA_character_) {
  add(section, item, NA, status = "PENDING", july = july, changed_by = changed_by,
      note = if (is.na(note)) reason else paste0(reason, ". ", note),
      source_label = "—")
}

# Runs f() only if every required input is usable; otherwise emits one PENDING
# per item in `items`, carrying the reason.
guarded <- function(section, keys, items, f, july = NULL, changed_by = NULL) {
  probs <- unlist(lapply(keys, input_problem))
  if (length(probs) > 0) {
    reason <- paste(unique(probs), collapse = "; ")
    for (i in seq_along(items))
      pending(section, items[[i]], reason,
              july = if (!is.null(july) && !is.null(july[[items[[i]]]])) july[[items[[i]]]] else NA_character_,
              changed_by = if (!is.null(changed_by) && !is.null(changed_by[[items[[i]]]])) changed_by[[items[[i]]]] else NA_character_)
    return(invisible(FALSE))
  }
  ok <- tryCatch({ f(); TRUE }, error = function(e) {
    for (i in seq_along(items))
      pending(section, items[[i]], sprintf("read/compute error: %s", conditionMessage(e)))
    FALSE
  })
  invisible(ok)
}

# --- number formatting --------------------------------------------------------
# VECTORISED. These are called on whole columns as well as on scalars -- the
# per-cut stability rows format a vector of estimates in one call. A scalar-only
# version using `if (length(x) == 0 || is.na(x))` errors on any vector of length
# > 1 under R >= 4.3 ("'length = 4' in coercion to 'logical(1)'"), which is what
# silently killed the stability block on the 2026-09-17 run.
fmt_vec <- function(x, f) {
  x <- suppressWarnings(as.numeric(x))
  if (length(x) == 0) return("—")
  out <- rep("—", length(x))
  ok <- !is.na(x)
  if (any(ok)) out[ok] <- f(x[ok])
  out
}
n_fmt <- function(x) fmt_vec(x, function(v) formatC(round(v), format = "d", big.mark = ","))
f3    <- function(x) fmt_vec(x, function(v) sprintf("%.3f", v))
f4    <- function(x) fmt_vec(x, function(v) sprintf("%.4f", v))
pct1  <- function(x) fmt_vec(x, function(v) sprintf("%.1f%%", v))

# Scalar-only by contract: take the first element rather than risk the same
# non-scalar `if` that broke the formatters.
stars_for <- function(p) {
  p <- suppressWarnings(as.numeric(p))[1]
  if (is.na(p)) return("")
  if (p < 0.01) return("***"); if (p < 0.05) return("**"); if (p < 0.10) return("*"); ""
}
coef_txt <- function(est, se, p) sprintf("%s%s (SE %s)", f4(est), stars_for(p), f4(se))

# =============================================================================
# 4) CONSISTENCY MANIFEST
# =============================================================================
# The model-building constants below are a COPY of 16_estimate_models.R's.
# The two can drift if either is edited without the other. The manifest prints the literal constants so this
# block can be eyeball-diffed against 16_estimate_models.R's source (search
# there for "CTRL_ALTA <-", "trat_compact <-").

CTRL_ALTA <- c(
  "topo_prop_inclinado", "pp_alta_2010",
  "pct_nao_constru_fora_alta_2010_q1", "pct_nao_constru_fora_alta_2010_q4",
  "palma_rent", "palma_commute", "median_rent",
  "log_pib_pc", "log_pop_total_2000", "log_area_2000_km2", "zero_area_2000",
  "prop_favelas_2010", "regiao", "urban_class"
)
CTRL_DELTA <- CTRL_ALTA
CTRL_ALTA_NO_MED <- setdiff(CTRL_ALTA, c("median_rent", "palma_rent", "palma_commute",
                                          "pct_nao_constru_fora_alta_2010_q1",
                                          "pct_nao_constru_fora_alta_2010_q4"))
trat_compact <- "pct_area_densif_infill_0010"
trat_periph  <- "pct_area_periph_ext_leap_0010"
TREATMENT_TERMS <- c(trat_compact, trat_periph)

# prep() / prep_0010(): copies of 16_estimate_models.R's, used only for the
# values recomputed in section 8 below. The fitted models themselves come from
# the .rds and are never refitted here.
prep <- function(df) {
  df %>% mutate(
    pop_growth         = (pop_urbana_2022 - pop_urbana_2010_cg) / pop_urbana_2010_cg,
    log_pop_2010       = log(pop_urbana_2010_cg + 1),
    log_pib_pc         = log(pib_pc_2010 + 1),
    log_area_2010_km2  = log(area_urbana_2010_m2 / 1e6 + 0.001),
    log_density_2010   = log(pop_urbana_2010_cg / (area_urbana_2010_m2_mapped / 1e6 + 0.001) + 1),
    log_pop_total_2010 = log(pop_total_2010 + 1),
    log_pop_total_2000 = log(pop_2000 + 1),
    log_area_2000_km2  = log(area_2000_m2 / 1e6 + 0.001),
    g_fora_suscept_slums = coalesce(g_slums_1022 - g_alta_slums_1022, 0),
    pct_area_periph_ext_leap = pct_area_peripheral + pct_area_extension + pct_area_leapfrog,
    regiao = factor(regiao, levels = c("Sudeste", "Sul", "Nordeste", "Norte", "Centro-Oeste")),
    urban_class = factor(urban_class,
                         levels = c("Urban Centers", "Metropolises", "Metropolis Suburbs",
                                    "Regional Centers", "Regional Centers Suburbs"))
  )
}
prep_0010 <- function(df) {
  df %>% mutate(
    pct_area_densif_infill_0010 = pct_area_densif_0010 + pct_area_infill_0010,
    log_dist_densif_0010        = log(pmax(dist_media_m_densif_0010, 1)),
    log_dist_densif_infill_0010 = log(pmax(dist_media_m_densif_infill_0010, 1)),
    pct_area_periph_ext_leap_0010 = pct_area_peripheral_0010 + pct_area_extension_0010 +
                                     pct_area_leapfrog_0010
  )
}

# vcov, exactly as 16_estimate_models.R and table2_and_ed_tables.R define it.
vcov_clust <- function(mod) {
  cl <- attr(mod, "cluster_vec")
  if (!is.null(cl)) sandwich::vcovCL(mod, cluster = cl) else sandwich::vcovHC(mod, type = "HC3")
}
vcov_hc3 <- function(mod) sandwich::vcovHC(mod, type = "HC3")

manifest_lines <- c(
  sprintf("MIN_POP_RISCO_2010 : %s", MIN_POP_RISCO_2010),
  sprintf("trat_compact       : %s", trat_compact),
  sprintf("trat_periph        : %s", trat_periph),
  sprintf("CTRL_ALTA (%d)      : %s", length(CTRL_ALTA), paste(CTRL_ALTA, collapse = ", ")),
  sprintf("CTRL_ALTA_NO_MED (%d): %s", length(CTRL_ALTA_NO_MED), paste(CTRL_ALTA_NO_MED, collapse = ", ")),
  "vcov: municipalities = vcovCL(cluster = attr(mod, 'cluster_vec')); arrangements = vcovHC(HC3)"
)

cat("\n", strrep("-", 70), "\n", sep = "")
cat("CONSISTENCY MANIFEST -- diff against 16_estimate_models.R's source\n")
cat(strrep("-", 70), "\n", sep = "")
cat(paste0(manifest_lines, collapse = "\n"), "\n")
cat(strrep("-", 70), "\n", sep = "")

# =============================================================================
# 5) COEFFICIENT EXTRACTION FROM THE SAVED MODELS
# =============================================================================

model_objects <- NULL
md <- NULL
models_problem <- input_problem("s04_models")
if (is.null(models_problem)) {
  model_objects <- tryCatch(readRDS(inp_path("s04_models")),
                            error = function(e) { models_problem <<- sprintf("unreadable: %s", conditionMessage(e)); NULL })
  if (!is.null(model_objects)) md <- model_objects$metadata
}

# One row per treatment coefficient in a fitted model.
model_terms <- function(mod, vcov_fn, terms_wanted) {
  if (is.null(mod)) return(NULL)
  ct <- tryCatch(lmtest::coeftest(mod, vcov. = vcov_fn(mod)), error = function(e) NULL)
  if (is.null(ct)) return(NULL)
  keep <- intersect(terms_wanted, rownames(ct))
  if (length(keep) == 0) return(NULL)
  data.frame(term = keep,
             estimate = ct[keep, 1], std_error = ct[keep, 2],
             p_value = ct[keep, 4], stringsAsFactors = FALSE)
}
model_n  <- function(mod) if (is.null(mod)) NA_integer_ else tryCatch(stats::nobs(mod), error = function(e) NA_integer_)
model_r2 <- function(mod) if (is.null(mod)) NA_real_ else tryCatch(summary(mod)$r.squared, error = function(e) NA_real_)

# Emits the four treatment coefficients + N + R^2 for a 4-spec model list.
emit_four_specs <- function(section, mods, vcov_fn, july_map = list(), changed_map = list()) {
  for (nm in names(mods)) {
    mod <- mods[[nm]]
    tt  <- model_terms(mod, vcov_fn, TREATMENT_TERMS)
    val <- if (is.null(tt)) NA_character_ else coef_txt(tt$estimate[1], tt$std_error[1], tt$p_value[1])
    add(section, sprintf("%s — treatment coefficient", nm), val, "s04_models",
        status = if (is.null(tt)) "PENDING" else "VERIFIED",
        july = if (!is.null(july_map[[nm]])) july_map[[nm]] else NA_character_,
        changed_by = if (!is.null(changed_map[[nm]])) changed_map[[nm]] else NA_character_,
        note = if (is.null(tt)) "model absent from the .rds or treatment term not in the fit" else
               sprintf("term `%s`", tt$term[1]))
    add(section, sprintf("%s — N", nm), n_fmt(model_n(mod)), "s04_models")
    add(section, sprintf("%s — R²", nm), f3(model_r2(mod)), "s04_models")
  }
}

# =============================================================================
# 6) SECTIONS
# =============================================================================

SEC <- list(
  funnel  = "Sample funnel",
  t1      = "Table 1 — population and exposure by growth type",
  f1      = "Figure 1 — growth-type layers",
  f2      = "Figure 2 — exposure scatter",
  t2      = "Table 2 — main regressions (municipalities)",
  ed2     = "ED Table 2 — with / without housing-market mediators",
  ed3     = "ED Table 3 — functional urban areas",
  ed4     = "ED Table 4 — horse race",
  ed5     = "ED Table 5 — interactions",
  edfig   = "ED Figure — standardized coefficients",
  cover   = "Stage 02 / stage 03 coverage",
  robust  = "Robustness — minimum-baseline sweep"
)

# ---- 6.1 Sample funnel -------------------------------------------------------

count_rows_csv <- function(key, col = NULL) {
  d <- readr::read_csv(inp_path(key), show_col_types = FALSE, progress = FALSE)
  if (is.null(col)) nrow(d) else dplyr::n_distinct(d[[col]])
}

guarded(SEC$funnel, c("s04_amostra_universo"), list("Processing universe (municipalities)"), function() {
  add(SEC$funnel, "Processing universe (municipalities)",
      n_fmt(count_rows_csv("s04_amostra_universo")), "s04_amostra_universo",
      changed_by = "6f.1 (CPRM union removed from stage 03's sample definition)")
})

guarded(SEC$funnel, c("s04_amostra_mun"), list("amostra_mun (tem_susceptibilidade == TRUE)"), function() {
  add(SEC$funnel, "amostra_mun (tem_susceptibilidade == TRUE)",
      n_fmt(count_rows_csv("s04_amostra_mun")), "s04_amostra_mun",
      note = "`01_compose_sample.R:41`")
})

guarded(SEC$funnel, c("s04_mun_isol"), list("Isolated municipalities"), function() {
  add(SEC$funnel, "Isolated municipalities", n_fmt(count_rows_csv("s04_mun_isol")), "s04_mun_isol",
      note = "`01_compose_sample.R:42`")
})

guarded(SEC$funnel, c("s04_amostra_arr"), list("Qualified arrangements (CD_CIDADE)",
                                               "Members of qualified arrangements"), function() {
  d <- readr::read_csv(inp_path("s04_amostra_arr"), show_col_types = FALSE, progress = FALSE)
  add(SEC$funnel, "Qualified arrangements (CD_CIDADE)", n_fmt(dplyr::n_distinct(d$CD_CIDADE)),
      "s04_amostra_arr", note = "`01_compose_sample.R:75–87`")
  add(SEC$funnel, "Members of qualified arrangements", n_fmt(nrow(d)), "s04_amostra_arr")
})

guarded(SEC$funnel, c("s04_amostra_arr", "s04_mun_isol"), list("FUA entities (arrangements + isolated)"), function() {
  a <- readr::read_csv(inp_path("s04_amostra_arr"), show_col_types = FALSE, progress = FALSE)
  i <- readr::read_csv(inp_path("s04_mun_isol"),    show_col_types = FALSE, progress = FALSE)
  add(SEC$funnel, "FUA entities (arrangements + isolated)",
      n_fmt(dplyr::n_distinct(a$CD_CIDADE) + nrow(i)),
      source_label = sprintf("`%s` (%s) + `%s` (%s)",
                             rel_path(inp_path("s04_amostra_arr")), fmt_mtime(inp_mtime("s04_amostra_arr")),
                             rel_path(inp_path("s04_mun_isol")),    fmt_mtime(inp_mtime("s04_mun_isol"))),
      july = "206 (results_used.md L11)",
      changed_by = "6b0, 6f.1 — `01_compose_sample.R:92–93` counts `n_distinct(CD_CIDADE) + nrow(mun_isol)`",
      note = "counting `amostra_arr.csv` alone omits the isolated FUAs")
})

guarded(SEC$funnel, c("s04_ds_mun"), list("dataset_regressao_municipio.csv rows"), function() {
  add(SEC$funnel, "dataset_regressao_municipio.csv rows", n_fmt(count_rows_csv("s04_ds_mun")),
      "s04_ds_mun", july = "387 (results_used.md L11)",
      changed_by = "6b0 — under the common grid every row has a valid `delta_pp_alta`")
})

guarded(SEC$funnel, c("s04_ds_arr"), list("dataset_regressao_arranjo.csv rows"), function() {
  add(SEC$funnel, "dataset_regressao_arranjo.csv rows", n_fmt(count_rows_csv("s04_ds_arr")), "s04_ds_arr")
})

guarded(SEC$funnel, c("s04_ds_mun", "s04_ds_arr"),
        list("After pop_2010_risk_total > MIN_POP_RISCO_2010 (municipalities)",
             "After pop_2010_risk_total > MIN_POP_RISCO_2010 (arrangements)"), function() {
  dm <- readr::read_csv(inp_path("s04_ds_mun"), show_col_types = FALSE, progress = FALSE)
  da <- readr::read_csv(inp_path("s04_ds_arr"), show_col_types = FALSE, progress = FALSE)
  add(SEC$funnel, "After pop_2010_risk_total > MIN_POP_RISCO_2010 (municipalities)",
      n_fmt(sum(dm$pop_2010_risk_total > MIN_POP_RISCO_2010, na.rm = TRUE)), "s04_ds_mun",
      changed_by = sprintf("6c1 revised 2026-09-12; cut = %s", MIN_POP_RISCO_2010))
  add(SEC$funnel, "After pop_2010_risk_total > MIN_POP_RISCO_2010 (arrangements)",
      n_fmt(sum(da$pop_2010_risk_total > MIN_POP_RISCO_2010, na.rm = TRUE)), "s04_ds_arr",
      changed_by = sprintf("6c1 revised 2026-09-12; cut = %s", MIN_POP_RISCO_2010))
})

if (is.null(models_problem) && !is.null(md)) {
  add(SEC$funnel, "MIN_POP_RISCO_2010 applied at estimation", as.character(md$min_pop_risco_2010),
      "s04_models", july = "no cut (results_used.md states none)",
      changed_by = "6c1, decided 2026-09-08 at 1000, revised 2026-09-12 to 200")
  add(SEC$funnel, "Municipalities before the cut (metadata)", n_fmt(md$n_mun_pre_filter), "s04_models")
  add(SEC$funnel, "Municipalities after the cut (metadata)", n_fmt(md$n_mun_post_filter), "s04_models")
  add(SEC$funnel, "Centro-Oeste municipalities dropped (region columns)",
      n_fmt(md$n_centro_oeste_dropped), "s04_models",
      changed_by = "6c2, decided 2026-09-10")
  add(SEC$funnel, "Estimation timestamp (metadata)", format(md$date_estimated), "s04_models")
} else {
  for (it in c("MIN_POP_RISCO_2010 applied at estimation",
               "Municipalities before the cut (metadata)",
               "Municipalities after the cut (metadata)",
               "Centro-Oeste municipalities dropped (region columns)",
               "Estimation timestamp (metadata)"))
    pending(SEC$funnel, it, models_problem %||% "model_objects_table2.rds unavailable")
}

# ---- 6.2 Table 1 -------------------------------------------------------------

JULY_T1 <- list(
  Consolidated = list(pop_2010 = 59138249, pop_2022 = 55634711, risco_2010 = 15627912, risco_2022 = 14632292),
  Compact      = list(pop_2010 = 27367825, pop_2022 = 36107824, risco_2010 =  8625881, risco_2022 = 10779228),
  Sprawl       = list(pop_2010 =  2900879, pop_2022 =  6104483, risco_2010 =   988462, risco_2022 =  1908404),
  Total        = list(pop_2010 = 89406953, pop_2022 = 97847018, risco_2010 = 25242255, risco_2022 = 27319924)
)

t1a_items <- unlist(lapply(names(JULY_T1), function(g)
  paste0(g, c(" — pop_2010", " — pop_2022", " — risco_2010", " — risco_2022",
              " — % at risk 2010", " — % at risk 2022", " — change in risk pop."))))

guarded(SEC$t1, c("s05_tab1a"), as.list(t1a_items), function() {
  d <- readr::read_csv(inp_path("s05_tab1a"), show_col_types = FALSE, progress = FALSE)
  for (g in names(JULY_T1)) {
    r <- d[as.character(d$growth_type) == g, , drop = FALSE]
    if (nrow(r) == 0) {
      for (suffix in c(" — pop_2010", " — pop_2022", " — risco_2010", " — risco_2022",
                       " — % at risk 2010", " — % at risk 2022", " — change in risk pop."))
        pending(SEC$t1, paste0(g, suffix), sprintf("row '%s' absent from the Table 1a CSV", g))
      next
    }
    j <- JULY_T1[[g]]
    add(SEC$t1, paste0(g, " — pop_2010"),   n_fmt(r$pop_2010[1]),   "s05_tab1a",
        july = n_fmt(j$pop_2010),   changed_by = "6b0 (common grid), 6e (exposure weighting), 6f.1/6f.2")
    add(SEC$t1, paste0(g, " — pop_2022"),   n_fmt(r$pop_2022[1]),   "s05_tab1a",
        july = n_fmt(j$pop_2022),   changed_by = "6b0, 6e, 6f.1/6f.2")
    add(SEC$t1, paste0(g, " — risco_2010"), n_fmt(r$risco_2010[1]), "s05_tab1a",
        july = n_fmt(j$risco_2010), changed_by = "6e (area weighting replaces any-overlap)")
    add(SEC$t1, paste0(g, " — risco_2022"), n_fmt(r$risco_2022[1]), "s05_tab1a",
        july = n_fmt(j$risco_2022), changed_by = "6e")
    # results_used.md states the per-group % at risk (L36-38) and Compact's and
    # Sprawl's change in risk population, but not the Total row's % nor
    # Consolidated's or Total's change. Those are computed from its own
    # components here and are labelled, so the column is not read as a quotation.
    pct_quoted    <- g %in% c("Consolidated", "Compact", "Sprawl")
    change_quoted <- g %in% c("Compact", "Sprawl")
    derived_tag   <- function(x, quoted) if (quoted) x else paste(x, "(derived from its components)")
    add(SEC$t1, paste0(g, " — % at risk 2010"), pct1(r$pct_risco_2010[1]), "s05_tab1a",
        july = derived_tag(pct1(100 * j$risco_2010 / j$pop_2010), pct_quoted), changed_by = "6e")
    add(SEC$t1, paste0(g, " — % at risk 2022"), pct1(r$pct_risco_2022[1]), "s05_tab1a",
        july = derived_tag(pct1(100 * j$risco_2022 / j$pop_2022), pct_quoted), changed_by = "6e")
    add(SEC$t1, paste0(g, " — change in risk pop."), n_fmt(r$change_risco[1]), "s05_tab1a",
        july = derived_tag(n_fmt(j$risco_2022 - j$risco_2010), change_quoted), changed_by = "6e")
  }
})

headline_items <- list("Compact — % of new residents going to risk",
                       "Sprawl — % of new residents going to risk",
                       "Compact share of the net increase in at-risk pop. (Compact+Sprawl)",
                       "Aggregate growth — total population",
                       "Aggregate growth — population at risk")

guarded(SEC$t1, c("s05_tab1a"), headline_items, function() {
  d <- readr::read_csv(inp_path("s05_tab1a"), show_col_types = FALSE, progress = FALSE)
  gr <- function(g) d[as.character(d$growth_type) == g, , drop = FALSE]
  cm <- gr("Compact"); sp <- gr("Sprawl"); tt <- gr("Total")
  if (nrow(cm) == 0 || nrow(sp) == 0 || nrow(tt) == 0)
    stop("Table 1a CSV is missing one of the Compact / Sprawl / Total rows")
  net <- cm$change_risco[1] + sp$change_risco[1]
  # Same arithmetic as table1_population_by_growth_type.R's headline block.
  add(SEC$t1, "Compact — % of new residents going to risk",
      pct1(100 * cm$change_risco[1] / (cm$pop_2022[1] - cm$pop_2010[1])), "s05_tab1a",
      july = "25%", changed_by = "6b0, 6e",
      note = "derived from the Table 1a CSV, same arithmetic as `table1_population_by_growth_type.R`")
  add(SEC$t1, "Sprawl — % of new residents going to risk",
      pct1(100 * sp$change_risco[1] / (sp$pop_2022[1] - sp$pop_2010[1])), "s05_tab1a",
      july = "29%", changed_by = "6b0, 6e", note = "derived from the Table 1a CSV")
  add(SEC$t1, "Compact share of the net increase in at-risk pop. (Compact+Sprawl)",
      pct1(100 * cm$change_risco[1] / net), "s05_tab1a",
      july = "70% (2.2M of 3.1M)", changed_by = "6b0, 6e", note = "derived from the Table 1a CSV")
  add(SEC$t1, "Aggregate growth — total population",
      pct1(100 * (tt$pop_2022[1] - tt$pop_2010[1]) / tt$pop_2010[1]), "s05_tab1a",
      july = "+9.4%", changed_by = "6b0", note = "derived from the Table 1a CSV")
  add(SEC$t1, "Aggregate growth — population at risk",
      pct1(100 * (tt$risco_2022[1] - tt$risco_2010[1]) / tt$risco_2010[1]), "s05_tab1a",
      july = "+8.2%", changed_by = "6e", note = "derived from the Table 1a CSV")
})

t1b_items <- as.list(paste0(c("Consolidated", "Compact", "Sprawl"),
                            rep(c(" — change in high susceptibility (M)",
                                  " — change outside high susceptibility (M)",
                                  " — total change (M)"), each = 3)))

guarded(SEC$t1, c("s05_tab1b"), t1b_items, function() {
  d <- readr::read_csv(inp_path("s05_tab1b"), show_col_types = FALSE, progress = FALSE)
  july_high <- c(Consolidated = -1.00, Compact = 2.15, Sprawl = 0.92)
  july_out  <- c(Consolidated = -2.51, Compact = 6.59, Sprawl = 2.28)
  for (g in c("Consolidated", "Compact", "Sprawl")) {
    r <- d[as.character(d$growth_type) == g, , drop = FALSE]
    if (nrow(r) == 0) next
    add(SEC$t1, paste0(g, " — change in high susceptibility (M)"),
        f3(r$pop_change_high_susc_M[1]), "s05_tab1b",
        july = f3(july_high[[g]]), changed_by = "6b0, 6e")
    add(SEC$t1, paste0(g, " — change outside high susceptibility (M)"),
        f3(r$pop_change_outside_susc_M[1]), "s05_tab1b",
        july = f3(july_out[[g]]), changed_by = "6b0, 6e")
    add(SEC$t1, paste0(g, " — total change (M)"),
        f3(r$pop_change_total_M[1]), "s05_tab1b", changed_by = "6b0")
  }
})

# ---- 6.3 Figure 1 (recomputed) ----------------------------------------------
# figure1_growth_type_layers.R prints its crosstabs to console and writes no
# CSV, so they are recomputed here from its OWN OUTPUT LAYER when present
# (figura1_camadas.parquet), falling back to the classified grid it reads.
# Geometry is skipped: only the flag columns are pulled.

read_flags <- function(path, cols) {
  # Preferred path: read the flag columns straight out of the parquet without
  # touching the geometry column, which is the bulk of the file. The schema is
  # read first so a column the layer does not carry is dropped rather than
  # raising -- arrow's all_of() errors on a missing name.
  out <- tryCatch({
    ds <- arrow::open_dataset(path)
    schema_names <- tryCatch(ds$schema$names, error = function(e) names(ds))
    take <- intersect(cols, schema_names)
    if (length(take) == 0) stop("none of the requested columns are in the parquet schema")
    as.data.frame(arrow::read_parquet(path, col_select = dplyr::all_of(take)))
  }, error = function(e) NULL)

  # Fallback: full sf read, then drop geometry. Slower and memory-hungry on the
  # national grid, so only used if the column-selective read failed.
  if (is.null(out) && requireNamespace("sfarrow", quietly = TRUE)) {
    out <- tryCatch({
      g <- sfarrow::st_read_parquet(path)
      as.data.frame(sf::st_drop_geometry(g))[, intersect(cols, names(g)), drop = FALSE]
    }, error = function(e) NULL)
  }
  out
}

fig1_key <- if (is.null(input_problem("s05_fig1_layers"))) "s05_fig1_layers" else
            if (is.null(input_problem("s03_grade_growth"))) "s03_grade_growth" else NA_character_

fig1_items <- list("Total cells", "grupo_3tipos — consolidated", "grupo_3tipos — compact",
                   "grupo_3tipos — sprawl", "grupo_3tipos — NA",
                   "urban 2010 TRUE / 2020 TRUE", "urban 2010 TRUE / 2020 FALSE",
                   "urban 2010 FALSE / 2020 TRUE", "urban 2010 FALSE / 2020 FALSE",
                   "Derived-vs-real disagreement — urbano_2010",
                   "Derived-vs-real disagreement — urbano_2020",
                   "Municipalities flagged em_amostra_regressao")

if (is.na(fig1_key)) {
  for (it in fig1_items)
    pending(SEC$f1, it, sprintf("neither %s nor %s is usable",
                                rel_path(inp_path("s05_fig1_layers")),
                                rel_path(inp_path("s03_grade_growth"))))
} else {
  guarded(SEC$f1, c(fig1_key), fig1_items, function() {
    want <- c("tipo_crescimento", "urbano_2010", "urbano_2020", "cod_mun",
              "grupo_3tipos", "em_amostra_regressao")
    g <- read_flags(inp_path(fig1_key), want)
    if (is.null(g)) stop("could not read the parquet's flag columns (arrow and sfarrow both failed)")
    src_note <- sprintf("recomputed here, not read from an exhibit output; mirrors `figure1_growth_type_layers.R` §2; source layer `%s`",
                        rel_path(inp_path(fig1_key)))

    add(SEC$f1, "Total cells", n_fmt(nrow(g)), fig1_key, note = src_note)

    TIPOS_2010    <- c("consolidated", "densification", "peripheral")
    TIPOS_COMPACT <- c("densification", "infill")
    TIPOS_SPRAWL  <- c("peripheral", "extension", "leapfrog")

    grp <- if ("grupo_3tipos" %in% names(g)) g$grupo_3tipos else
      dplyr::case_when(g$tipo_crescimento == "consolidated" ~ "consolidated",
                       g$tipo_crescimento %in% TIPOS_COMPACT ~ "compact",
                       g$tipo_crescimento %in% TIPOS_SPRAWL  ~ "sprawl",
                       TRUE ~ NA_character_)
    for (lv in c("consolidated", "compact", "sprawl"))
      add(SEC$f1, sprintf("grupo_3tipos — %s", lv), n_fmt(sum(grp == lv, na.rm = TRUE)),
          fig1_key, note = src_note)
    add(SEC$f1, "grupo_3tipos — NA", n_fmt(sum(is.na(grp))), fig1_key, note = src_note)

    if (all(c("urbano_2010", "urbano_2020") %in% names(g))) {
      u10 <- g$urbano_2010; u20 <- g$urbano_2020
      add(SEC$f1, "urban 2010 TRUE / 2020 TRUE",   n_fmt(sum(u10 & u20, na.rm = TRUE)),  fig1_key, note = src_note)
      add(SEC$f1, "urban 2010 TRUE / 2020 FALSE",  n_fmt(sum(u10 & !u20, na.rm = TRUE)), fig1_key, note = src_note)
      add(SEC$f1, "urban 2010 FALSE / 2020 TRUE",  n_fmt(sum(!u10 & u20, na.rm = TRUE)), fig1_key, note = src_note)
      add(SEC$f1, "urban 2010 FALSE / 2020 FALSE", n_fmt(sum(!u10 & !u20, na.rm = TRUE)), fig1_key, note = src_note)
      if ("tipo_crescimento" %in% names(g)) {
        d10 <- g$tipo_crescimento %in% TIPOS_2010
        d20 <- !is.na(g$tipo_crescimento)
        add(SEC$f1, "Derived-vs-real disagreement — urbano_2010", n_fmt(sum(d10 != u10, na.rm = TRUE)),
            fig1_key, note = paste(src_note, "; derived = tipo_crescimento in {consolidated, densification, peripheral}"))
        add(SEC$f1, "Derived-vs-real disagreement — urbano_2020", n_fmt(sum(d20 != u20, na.rm = TRUE)),
            fig1_key, note = paste(src_note, "; derived = !is.na(tipo_crescimento)"))
      }
    } else {
      for (it in fig1_items[6:11]) pending(SEC$f1, it, "urbano_2010/urbano_2020 absent from the layer")
    }

    if ("em_amostra_regressao" %in% names(g) && "cod_mun" %in% names(g)) {
      add(SEC$f1, "Municipalities flagged em_amostra_regressao",
          n_fmt(dplyr::n_distinct(g$cod_mun[which(g$em_amostra_regressao)])), fig1_key, note = src_note)
    } else if (is.null(input_problem("s04_ds_mun"))) {
      dm <- readr::read_csv(inp_path("s04_ds_mun"), show_col_types = FALSE, progress = FALSE)
      add(SEC$f1, "Municipalities flagged em_amostra_regressao", n_fmt(dplyr::n_distinct(dm$cod_mun)),
          "s04_ds_mun", note = "recomputed here from the regression dataset; the flag is its cod_mun set")
    } else {
      pending(SEC$f1, "Municipalities flagged em_amostra_regressao",
              "em_amostra_regressao absent from the layer and dataset_regressao_municipio.csv unusable")
    }
  })
}

# ---- 6.4 Figure 2 (recomputed) ----------------------------------------------
# figure2_exposure_scatter.R prints every statistic below to console and writes
# no CSV. Recomputed here with the same construction, the same two filters in
# the same order, and the same estimators (§3-§5 and §10 of that script).

f2_items <- list("Metrics municipalities (before any filter)",
                 "Filter 1 — after pop_2010_risk_total > MIN_POP_RISCO_2010",
                 "Filter 2 — after positive growth in both types (final N)",
                 "Dropped by filter 2",
                 "Median pct_risk_compact", "Median pct_risk_sprawl",
                 "Median difference (compact − sprawl)",
                 "Share below 45° line (compact > sprawl)",
                 "Wilcoxon signed-rank p", "Pearson correlation", "Spearman correlation",
                 "Fitted slope", "Fitted slope SE", "Fitted intercept", "Fitted R²")

guarded(SEC$f2, c("s03_metricas_mun", "s04_ds_mun"), f2_items, function() {
  met <- readr::read_csv(inp_path("s03_metricas_mun"), show_col_types = FALSE, progress = FALSE)
  reg <- readr::read_csv(inp_path("s04_ds_mun"),       show_col_types = FALSE, progress = FALSE)

  tipos <- c("extension", "leapfrog", "peripheral", "densification", "infill")
  needed <- c(paste0("pop_2022_", tipos), paste0("pop_2010_", tipos),
              paste0("pop_2022_risk_", tipos), paste0("pop_2010_risk_", tipos))
  miss <- setdiff(needed, names(met))
  if (length(miss) > 0) stop(sprintf("metricas_municipio missing: %s", paste(miss, collapse = ", ")))

  src_note <- "recomputed here, not read from an exhibit output; mirrors `figure2_exposure_scatter.R` §3–§5 and §10"

  df <- met %>% mutate(
    delta_sprawl_risk  = (pop_2022_risk_extension - pop_2010_risk_extension) +
                         (pop_2022_risk_leapfrog  - pop_2010_risk_leapfrog) +
                         (pop_2022_risk_peripheral - pop_2010_risk_peripheral),
    delta_sprawl_total = (pop_2022_extension - pop_2010_extension) +
                         (pop_2022_leapfrog  - pop_2010_leapfrog) +
                         (pop_2022_peripheral - pop_2010_peripheral),
    delta_compact_risk = (pop_2022_risk_densification - pop_2010_risk_densification) +
                         (pop_2022_risk_infill        - pop_2010_risk_infill),
    delta_compact_total= (pop_2022_densification - pop_2010_densification) +
                         (pop_2022_infill        - pop_2010_infill),
    pct_risk_sprawl  = delta_sprawl_risk  / delta_sprawl_total,
    pct_risk_compact = delta_compact_risk / delta_compact_total
  )
  n_metrics <- nrow(df)

  # Filter 1: the MIN_POP_RISCO_2010 cut, on the regression dataset's own column.
  reg_small <- reg %>% filter(pop_2010_risk_total > MIN_POP_RISCO_2010) %>%
    select(cod_mun) %>% distinct()
  df1 <- df %>% mutate(cod_mun = as.character(cod_mun)) %>%
    inner_join(reg_small %>% mutate(cod_mun = as.character(cod_mun)), by = "cod_mun")

  # Filter 2: positive growth in BOTH types.
  df2 <- df1 %>% filter(!is.na(delta_sprawl_total),  delta_sprawl_total  > 0,
                        !is.na(delta_compact_total), delta_compact_total > 0)

  two_files <- sprintf("`%s` (%s) + `%s` (%s)",
                       rel_path(inp_path("s03_metricas_mun")), fmt_mtime(inp_mtime("s03_metricas_mun")),
                       rel_path(inp_path("s04_ds_mun")),       fmt_mtime(inp_mtime("s04_ds_mun")))

  add(SEC$f2, "Metrics municipalities (before any filter)", n_fmt(n_metrics),
      source_label = two_files, note = src_note)
  add(SEC$f2, "Filter 1 — after pop_2010_risk_total > MIN_POP_RISCO_2010", n_fmt(nrow(df1)),
      source_label = two_files,
      changed_by = sprintf("6c1 revised 2026-09-12; cut = %s", MIN_POP_RISCO_2010),
      note = paste(src_note, "; `figure2_exposure_scatter.R:86`"))
  add(SEC$f2, "Filter 2 — after positive growth in both types (final N)", n_fmt(nrow(df2)),
      source_label = two_files, july = "341 (results_used.md L50, '43% of 341 cities')",
      changed_by = "6b0, 6c1, 6e", note = paste(src_note, "; this is the N printed in both subtitles"))
  add(SEC$f2, "Dropped by filter 2", n_fmt(nrow(df1) - nrow(df2)),
      source_label = two_files, note = src_note)

  if (nrow(df2) == 0) stop("no rows survive Figure 2's two filters")

  dpair <- df2$pct_risk_compact - df2$pct_risk_sprawl
  add(SEC$f2, "Median pct_risk_compact", pct1(100 * median(df2$pct_risk_compact, na.rm = TRUE)),
      source_label = two_files, july = "18.2%", changed_by = "6b0, 6c1, 6e", note = src_note)
  add(SEC$f2, "Median pct_risk_sprawl", pct1(100 * median(df2$pct_risk_sprawl, na.rm = TRUE)),
      source_label = two_files, july = "20.9%", changed_by = "6b0, 6c1, 6e", note = src_note)
  add(SEC$f2, "Median difference (compact − sprawl)", f3(median(dpair, na.rm = TRUE)),
      source_label = two_files, note = src_note)
  add(SEC$f2, "Share below 45° line (compact > sprawl)", pct1(100 * mean(dpair > 0, na.rm = TRUE)),
      source_label = two_files, july = "43%", changed_by = "6b0, 6c1, 6e", note = src_note)

  wt <- tryCatch(wilcox.test(df2$pct_risk_compact, df2$pct_risk_sprawl, paired = TRUE, exact = FALSE),
                 error = function(e) NULL)
  add(SEC$f2, "Wilcoxon signed-rank p", if (is.null(wt)) NA_character_ else f4(wt$p.value),
      source_label = two_files, status = if (is.null(wt)) "PENDING" else "VERIFIED", note = src_note)

  cp <- tryCatch(cor.test(df2$pct_risk_sprawl, df2$pct_risk_compact, method = "pearson",
                          use = "complete.obs"), error = function(e) NULL)
  cs <- tryCatch(suppressWarnings(cor.test(df2$pct_risk_sprawl, df2$pct_risk_compact,
                                           method = "spearman", use = "complete.obs")),
                 error = function(e) NULL)
  add(SEC$f2, "Pearson correlation",
      if (is.null(cp)) NA_character_ else sprintf("%s (p = %s)", f3(cp$estimate), f4(cp$p.value)),
      source_label = two_files, status = if (is.null(cp)) "PENDING" else "VERIFIED", note = src_note)
  add(SEC$f2, "Spearman correlation",
      if (is.null(cs)) NA_character_ else sprintf("%s (p = %s)", f3(cs$estimate), f4(cs$p.value)),
      source_label = two_files, status = if (is.null(cs)) "PENDING" else "VERIFIED", note = src_note)

  # Slope is fitted on the CLIPPED variables, as the exhibit script does.
  df2 <- df2 %>% mutate(pct_risk_sprawl_cl  = pmin(pmax(pct_risk_sprawl, 0), 1),
                        pct_risk_compact_cl = pmin(pmax(pct_risk_compact, 0), 1))
  lmf <- tryCatch(lm(pct_risk_sprawl_cl ~ pct_risk_compact_cl, data = df2), error = function(e) NULL)
  if (is.null(lmf)) {
    for (it in c("Fitted slope", "Fitted slope SE", "Fitted intercept", "Fitted R²"))
      pending(SEC$f2, it, "linear fit failed")
  } else {
    sm <- summary(lmf)
    add(SEC$f2, "Fitted slope", f3(coef(lmf)[2]), source_label = two_files,
        july = "slope < 45° with positive intercept (no value stated)",
        changed_by = "6b0, 6c1, 6e", note = paste(src_note, "; fitted on the [0,1]-clipped variables"))
    add(SEC$f2, "Fitted slope SE", f3(sm$coefficients[2, 2]), source_label = two_files, note = src_note)
    add(SEC$f2, "Fitted intercept", f3(coef(lmf)[1]), source_label = two_files, note = src_note)
    add(SEC$f2, "Fitted R²", f3(sm$r.squared), source_label = two_files, note = src_note)
  }
})

# ---- 6.5 Table 2 / ED Tables 2-5 --------------------------------------------

JULY_T2 <- list(
  "(1) g_high — Compact"   = "−0.026 n.s.",
  "(2) g_high — Sprawl"    = "+0.103**",
  "(3) Dpp_high — Compact" = "+0.040***",
  "(4) Dpp_high — Sprawl"  = "−0.021*"
)
CHANGED_T2 <- setNames(rep("6b0 (common grid), 6e (exposure weighting), 6c1 (sample cut)",
                           length(JULY_T2)), names(JULY_T2))

if (is.null(models_problem) && !is.null(model_objects)) {
  emit_four_specs(SEC$t2, model_objects$tab_main_mun, vcov_clust, JULY_T2, CHANGED_T2)
  add(SEC$t2, "Comparability note", "not comparable to N = 317", "s04_models",
      note = paste("317 was produced under the any-overlap rule with a cut of 1000, both superseded.",
                   "6e lowered pop_2010_risk_total; the cut moved to 200. The two differences pull in",
                   "opposite directions and do not cancel (MIGRATION_PLAN.md, 'On Table 2's N')."))
  add(SEC$t2, "Listwise deletion rule", "complete.cases over ALL formula variables", "s04_models",
      july = "list-wise deletion on safe available land and steep terrain (results_used.md L11)",
      changed_by = "none — the code never did what results_used.md describes",
      note = paste("`16_estimate_models.R:297–298`, applied per specification and AFTER the",
                   "MIN_POP_RISCO_2010 cut (`:205–207`). This is why N varies by specification;",
                   "results_used.md's Table 2 note names a narrower set than the code uses."))

  # ED Table 2 / 4 / 5: N and R^2 per column; treatment coefficients where a
  # treatment term is in the fit (specs 9-10 of ED Table 2 have none by design).
  for (nm in names(model_objects$tab_mediators_mun)) {
    mod <- model_objects$tab_mediators_mun[[nm]]
    tt  <- model_terms(mod, vcov_clust, TREATMENT_TERMS)
    if (!is.null(tt))
      add(SEC$ed2, sprintf("%s — treatment coefficient", nm),
          coef_txt(tt$estimate[1], tt$std_error[1], tt$p_value[1]), "s04_models",
          note = sprintf("term `%s`", tt$term[1]))
    add(SEC$ed2, sprintf("%s — N", nm), n_fmt(model_n(mod)), "s04_models")
    add(SEC$ed2, sprintf("%s — R²", nm), f3(model_r2(mod)), "s04_models")
  }

  for (nm in names(model_objects$tab_horserace_mun)) {
    mod <- model_objects$tab_horserace_mun[[nm]]
    tt  <- model_terms(mod, vcov_clust, TREATMENT_TERMS)
    if (!is.null(tt)) for (k in seq_len(nrow(tt)))
      add(SEC$ed4, sprintf("%s — %s", nm, tt$term[k]),
          coef_txt(tt$estimate[k], tt$std_error[k], tt$p_value[k]), "s04_models")
    add(SEC$ed4, sprintf("%s — N", nm), n_fmt(model_n(mod)), "s04_models")
    add(SEC$ed4, sprintf("%s — R²", nm), f3(model_r2(mod)), "s04_models")
  }

  for (nm in names(model_objects$tab_interact_mun)) {
    mod <- model_objects$tab_interact_mun[[nm]]
    add(SEC$ed5, sprintf("%s — N", nm), n_fmt(model_n(mod)), "s04_models",
        note = if (grepl("regiao", nm)) "region columns exclude Centro-Oeste (6c2)" else NA_character_)
    add(SEC$ed5, sprintf("%s — R²", nm), f3(model_r2(mod)), "s04_models")
  }

  # ---- ED Table 3: post-6f (computed) and pre-6f (PENDING unless supplied) ----
  # N and R2 only. The treatment coefficient is emitted once, below, as the
  # post-6f half of the pre/post pair -- emitting it here too would list every
  # ED Table 3 coefficient twice under two labels.
  for (nm in names(model_objects$tab_appA_arr)) {
    mod <- model_objects$tab_appA_arr[[nm]]
    add(SEC$ed3, sprintf("%s — N", nm), n_fmt(model_n(mod)), "s04_models")
    add(SEC$ed3, sprintf("%s — R²", nm), f3(model_r2(mod)), "s04_models")
  }

  add(SEC$ed3, "N (reconciliation)",
      n_fmt(model_n(model_objects$tab_appA_arr[[1]])), "s04_models",
      july = "206 (results_used.md L81); CLAUDE.md L151–155 carries 202 from VERIFICATION.md A2",
      changed_by = "6b0, 6c1, 6f.1/6f.2",
      note = paste("results_used.md and CLAUDE.md disagree with each other (206 vs 202) and both",
                   "predate the current pipeline. The value in this row is the one the current",
                   "models carry. Reconcile to it, in results_used.md and CLAUDE.md's Key sample facts."))

  pre6f_problem <- input_problem("pre6f_ed3")
  for (nm in names(model_objects$tab_appA_arr)) {
    post <- model_terms(model_objects$tab_appA_arr[[nm]], vcov_hc3, TREATMENT_TERMS)
    post_txt <- if (is.null(post)) NA_character_ else coef_txt(post$estimate[1], post$std_error[1], post$p_value[1])
    flag <- if (!is.null(post) && grepl("Dpp_high — Sprawl", nm, fixed = TRUE))
      sprintf("SIGNIFICANCE FLAG: post-6f p = %s (stars '%s'); 6f.2's asymmetric arrangement denominator moved this coefficient across the 10%% threshold",
              f4(post$p_value[1]), stars_for(post$p_value[1])) else NA_character_
    add(SEC$ed3, sprintf("%s — post-6f treatment coefficient", nm), post_txt, "s04_models",
        status = if (is.null(post)) "PENDING" else "VERIFIED",
        changed_by = "6f.2 (asymmetric arrangement aggregation)", note = flag)

    if (is.null(pre6f_problem)) {
      pre <- tryCatch(readr::read_csv(inp_path("pre6f_ed3"), show_col_types = FALSE, progress = FALSE),
                      error = function(e) NULL)
      row <- if (is.null(pre)) NULL else pre[as.character(pre$spec) == nm, , drop = FALSE]
      if (!is.null(row) && nrow(row) == 1) {
        add(SEC$ed3, sprintf("%s — pre-6f treatment coefficient", nm),
            coef_txt(row$estimate[1], row$std_error[1], row$p_value[1]), "pre6f_ed3",
            changed_by = "6f.2", note = "read from the supplied archived CSV, not recomputed")
      } else {
        pending(SEC$ed3, sprintf("%s — pre-6f treatment coefficient", nm),
                sprintf("spec '%s' not present in %s", nm, rel_path(inp_path("pre6f_ed3"))))
      }
    } else {
      pending(SEC$ed3, sprintf("%s — pre-6f treatment coefficient", nm),
              paste("not recoverable from the current pipeline: 6f.2 changed stage 03's arrangement",
                    "denominators, so reproducing the pre-6f values means re-running stage 03 under",
                    "the old rule. Supply", rel_path(inp_path("pre6f_ed3")),
                    "with columns spec,estimate,std_error,p_value,n_obs to fill this row"),
              changed_by = "6f.2")
    }
  }
} else {
  reason <- if (is.null(models_problem)) "model_objects_table2.rds unavailable" else models_problem
  for (sec in c(SEC$t2, SEC$ed2, SEC$ed3, SEC$ed4, SEC$ed5))
    pending(sec, "All coefficients, N and R² for this exhibit", reason)
  pending(SEC$t2, "Listwise deletion rule", reason,
          july = "list-wise deletion on safe available land and steep terrain (results_used.md L11)")
  pending(SEC$ed3, "N (reconciliation)", reason,
          july = "206 (results_used.md L81); CLAUDE.md carries 202")
}

# ---- 6.6 ED Figure -----------------------------------------------------------

guarded(SEC$edfig, c("s05_edfig"), list("Standardized betas"), function() {
  d <- readr::read_csv(inp_path("s05_edfig"), show_col_types = FALSE, progress = FALSE)
  add(SEC$edfig, "Rows in the standardized-coefficient CSV", n_fmt(nrow(d)), "s05_edfig")
  if (all(c("spec", "beta_std", "label", "group", "n") %in% names(d))) {
    for (sp in unique(d$spec)) {
      ds <- d[d$spec == sp, , drop = FALSE]
      ds <- ds[order(-abs(ds$beta_std)), , drop = FALSE]
      add(SEC$edfig, sprintf("%s — largest |standardized beta|", sp),
          sprintf("%s = %s (%s)", ds$label[1], f3(ds$beta_std[1]), ds$group[1]), "s05_edfig")
      trt <- ds[ds$group == "Treatment", , drop = FALSE]
      if (nrow(trt) > 0)
        add(SEC$edfig, sprintf("%s — treatment standardized beta", sp),
            sprintf("%s = %s", trt$label[1], f3(trt$beta_std[1])), "s05_edfig")
      add(SEC$edfig, sprintf("%s — N", sp), n_fmt(ds$n[1]), "s05_edfig")
    }
  } else {
    pending(SEC$edfig, "Standardized betas",
            sprintf("unexpected columns in %s: %s", rel_path(inp_path("s05_edfig")),
                    paste(names(d), collapse = ", ")))
  }
})

# ---- 6.7 Coverage ------------------------------------------------------------

guarded(SEC$cover, c("s02_resumo_alta"),
        list("Municipalities in the stage-02 high-susceptibility summary",
             "Exposed population 2010 (stage 02, area-weighted)",
             "Exposed population 2022 (stage 02, area-weighted)"), function() {
  d <- readr::read_csv(inp_path("s02_resumo_alta"), show_col_types = FALSE, progress = FALSE)
  add(SEC$cover, "Municipalities in the stage-02 high-susceptibility summary",
      n_fmt(dplyr::n_distinct(d$cod_mun)), "s02_resumo_alta")
  c10 <- grep("^pop_suscept_alta_2010$", names(d), value = TRUE)
  c22 <- grep("^pop_suscept_alta_2022$", names(d), value = TRUE)
  if (length(c10) == 1)
    add(SEC$cover, "Exposed population 2010 (stage 02, area-weighted)",
        n_fmt(sum(d[[c10]], na.rm = TRUE)), "s02_resumo_alta",
        note = "`pop_suscept = populacao × prop_suscept`, national sum over the summary's municipalities")
  else pending(SEC$cover, "Exposed population 2010 (stage 02, area-weighted)",
               "column pop_suscept_alta_2010 not found in the summary CSV")
  if (length(c22) == 1)
    add(SEC$cover, "Exposed population 2022 (stage 02, area-weighted)",
        n_fmt(sum(d[[c22]], na.rm = TRUE)), "s02_resumo_alta")
  else pending(SEC$cover, "Exposed population 2022 (stage 02, area-weighted)",
               "column pop_suscept_alta_2022 not found in the summary CSV")
})

guarded(SEC$cover, c("s02_resumo_risco"), list("Municipalities with CPRM mapped risk (stage 02)"), function() {
  d <- readr::read_csv(inp_path("s02_resumo_risco"), show_col_types = FALSE, progress = FALSE)
  add(SEC$cover, "Municipalities with CPRM mapped risk (stage 02)", n_fmt(dplyr::n_distinct(d$cod_mun)),
      "s02_resumo_risco", note = "produced by stage 02; no live consumer since 6f.1")
})

guarded(SEC$cover, c("s03_metricas_mun"), list("Municipalities in stage-03 metrics"), function() {
  d <- readr::read_csv(inp_path("s03_metricas_mun"), show_col_types = FALSE, progress = FALSE)
  add(SEC$cover, "Municipalities in stage-03 metrics", n_fmt(nrow(d)), "s03_metricas_mun")
})

guarded(SEC$cover, c("s03_metricas_arr"), list("Arrangements emitted by stage-03 script 07"), function() {
  d <- readr::read_csv(inp_path("s03_metricas_arr"), show_col_types = FALSE, progress = FALSE)
  add(SEC$cover, "Arrangements emitted by stage-03 script 07", n_fmt(nrow(d)), "s03_metricas_arr",
      note = paste("not the stage-04 arrangement count: `13_dependent_variables.R:80–83` filters to the",
                   "qualified CD_CIDADEs and `15_final_dataset.R:123–127` re-adds the isolated ones"))
})

# ---- 6.8 Robustness ----------------------------------------------------------

# Significance tier, as the tables star it: 1%, 5%, 10%, or none.
sig_tier <- function(p) {
  p <- suppressWarnings(as.numeric(p))[1]
  if (is.na(p)) return(NA_character_)
  if (p < 0.01) return("1%"); if (p < 0.05) return("5%")
  if (p < 0.10) return("10%"); "n.s."
}

guarded(SEC$robust, c("rb_sensitivity"), list("Minimum-baseline sweep"), function() {
  d <- readr::read_csv(inp_path("rb_sensitivity"), show_col_types = FALSE, progress = FALSE)
  need <- c("cut", "level", "spec", "estimate", "std_error", "p_value", "n_obs")
  if (!all(need %in% names(d))) stop(sprintf("unexpected columns: %s", paste(names(d), collapse = ", ")))

  # --- one row per (cut, level, spec) -----------------------------------------
  for (i in seq_len(nrow(d)))
    add(SEC$robust, sprintf("cut > %s — %s — %s", d$cut[i], d$level[i], d$spec[i]),
        sprintf("%s, N = %s", coef_txt(d$estimate[i], d$std_error[i], d$p_value[i]), n_fmt(d$n_obs[i])),
        "rb_sensitivity",
        note = if (isTRUE(d$is_pipeline_cut[i])) "pipeline reference cut" else NA_character_)

  # --- stability of each specification ACROSS the cuts -------------------------
  # Thirty-two rows do not say which conclusions depend on where the cut is
  # placed. These rows answer that directly, per (level, spec): does the sign
  # hold, and does the significance tier hold? Both are reported as facts about
  # the sweep -- whether a given change matters is not decided here.
  n_sign_changes <- 0L
  n_sig_changes  <- 0L

  for (lv in unique(d$level)) {
    for (sp in unique(d$spec[d$level == lv])) {
      g <- d[d$level == lv & d$spec == sp, , drop = FALSE]
      g <- g[order(g$cut), , drop = FALSE]
      if (nrow(g) == 0) next

      tiers  <- vapply(g$p_value, sig_tier, character(1))
      signs  <- ifelse(is.na(g$estimate), NA_character_, ifelse(g$estimate < 0, "−", "+"))
      per_cut <- paste(sprintf("%s: %s %s", g$cut, f4(g$estimate), tiers), collapse = "; ")

      sign_stable <- length(unique(na.omit(signs))) <= 1L
      sig_stable  <- length(unique(na.omit(tiers))) <= 1L
      if (!sign_stable) n_sign_changes <- n_sign_changes + 1L
      if (!sig_stable)  n_sig_changes  <- n_sig_changes  + 1L

      verdict <- paste0(
        if (sign_stable) sprintf("sign STABLE (%s)", unique(na.omit(signs))[1]) else "sign CHANGES",
        "; ",
        if (sig_stable) sprintf("significance STABLE (%s at every cut)", unique(na.omit(tiers))[1])
        else sprintf("significance CHANGES (%s)", paste(unique(na.omit(tiers)), collapse = " / "))
      )

      add(SEC$robust, sprintf("STABILITY — %s — %s", lv, sp), verdict, "rb_sensitivity",
          note = sprintf("per cut — %s. Estimate range %s to %s across cuts %s.",
                         per_cut, f4(min(g$estimate, na.rm = TRUE)), f4(max(g$estimate, na.rm = TRUE)),
                         paste(range(g$cut), collapse = "–")))
    }
  }

  n_specs <- nrow(unique(d[, c("level", "spec")]))
  add(SEC$robust, "Specifications whose SIGN changes across the sweep",
      sprintf("%d of %d", n_sign_changes, n_specs), "rb_sensitivity",
      note = sprintf("cuts swept: %s", paste(sort(unique(d$cut)), collapse = ", ")))
  add(SEC$robust, "Specifications whose SIGNIFICANCE TIER changes across the sweep",
      sprintf("%d of %d", n_sig_changes, n_specs), "rb_sensitivity",
      note = paste("tier = the star the tables print (1%, 5%, 10%, n.s.).",
                   "A tier change can be a precision effect rather than an estimate moving --",
                   "the per-cut estimates are in the STABILITY rows above."))
})

guarded(SEC$robust, c("rb_sens_sizes"), list("Sweep sample sizes"), function() {
  d <- readr::read_csv(inp_path("rb_sens_sizes"), show_col_types = FALSE, progress = FALSE)
  for (i in seq_len(nrow(d)))
    add(SEC$robust, sprintf("cut > %s — sample retained", d$cut[i]),
        sprintf("municipalities %s, arrangements %s", n_fmt(d$n_mun_after[i]), n_fmt(d$n_arr_after[i])),
        "rb_sens_sizes")
})

# =============================================================================
# 7) RENDER
# =============================================================================

md_escape <- function(x) gsub("|", "\\|", x, fixed = TRUE)

lines <- c(
  "# results_targets_v2.md — values, provenance, status",
  "",
  "**GENERATED FILE. Do not edit by hand.** Produced by `05_exhibits/build_results_targets.R`;",
  "every run overwrites it. Hand edits are lost. To change a value, change the pipeline and re-run.",
  "",
  "This file holds values, their provenance and their status. It contains no interpretation.",
  "",
  "## Run header",
  "",
  sprintf("- Generated: **%s**", format(RUN_TIME, "%Y-%m-%d %H:%M:%S %Z")),
  sprintf("- Repository commit: **%s**%s", repo_commit,
          if (isTRUE(repo_dirty)) " — working tree has uncommitted changes" else ""),
  sprintf("- Stage-04 reference clock: **%s**%s", fmt_mtime(STAGE04_REF_TIME),
          if (is.na(ref_key)) " — NOT FOUND" else sprintf(" (`%s`)", rel_path(inp_path(ref_key)))),
  sprintf("- Staleness tolerance: %d seconds", STALE_TOLERANCE_SECS),
  sprintf("- `MIN_POP_RISCO_2010` (from `00_setup.R`): **%s**", MIN_POP_RISCO_2010),
  "",
  "### Input manifest",
  "",
  "| Input | Path | mtime | Position | State |",
  "|---|---|---|---|---|"
)

for (k in sort(ls(envir = INPUTS))) {
  p <- input_problem(k)
  state <- if (!inp_exists(k)) "MISSING" else if (!is.null(p) && grepl("^STALE", p)) "STALE" else "ok"
  lines <- c(lines, sprintf("| %s | `%s` | %s | %s | %s |",
                            md_escape(inp(k)$what), rel_path(inp_path(k)), fmt_mtime(inp_mtime(k)),
                            inp(k)$rank %||% "upstream", state))
}

n_pending <- sum(vapply(ENTRIES, function(e) e$status == "PENDING", logical(1)))
lines <- c(lines, "",
  sprintf("**Entries: %d total, %d VERIFIED, %d PENDING.**",
          length(ENTRIES), length(ENTRIES) - n_pending, n_pending),
  "",
  "### Consistency manifest",
  "",
  "Model-building constants copied from `16_estimate_models.R`; diff this block against that source.",
  "", "```", manifest_lines, "```", "")

for (sec in unlist(SEC, use.names = FALSE)) {
  es <- Filter(function(e) e$section == sec, ENTRIES)
  if (length(es) == 0) next
  lines <- c(lines, "", sprintf("## %s", sec), "",
             "| Item | Value | Status | Source (file, mtime) | results_used.md (July) | Changed by | Note |",
             "|---|---|---|---|---|---|---|")
  for (e in es)
    lines <- c(lines, sprintf("| %s | %s | %s | %s | %s | %s | %s |",
                              md_escape(e$item), md_escape(e$value), e$status,
                              md_escape(e$source), md_escape(e$july),
                              md_escape(e$changed_by), md_escape(e$note)))
}

lines <- c(lines, "", "---", "",
  sprintf("Regenerate: `Rscript 05_exhibits/build_results_targets.R` (commit %s).", repo_commit))

writeLines(lines, OUT_MD)

cat(sprintf("\nWrote: %s\n", rel_path(OUT_MD)))
cat(sprintf("Entries: %d total, %d VERIFIED, %d PENDING\n",
            length(ENTRIES), length(ENTRIES) - n_pending, n_pending))
if (n_pending > 0) {
  cat("\nPENDING entries:\n")
  for (e in Filter(function(x) x$status == "PENDING", ENTRIES))
    cat(sprintf("  [%s] %s — %s\n", e$section, e$item, e$note))
}
cat("\nDone.\n")
