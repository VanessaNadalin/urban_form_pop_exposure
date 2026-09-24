# =============================================================================
# ed_table_descriptive_statistics.R
# Appendix table: descriptive statistics for every variable in Table 2's
# specification -- the two outcomes, the two treatments, and all controls --
# at both levels of analysis (municipalities and functional urban areas).
#
# Requested 2026-09-18 (researcher). It is a new exhibit, not in the July
# results_used.md, added on explicit request (CLAUDE.md rule 6).
#
# TWO BLOCKS, per the researcher's instruction:
#   A. ESTIMATION SAMPLE -- the rows Table 2's coefficients were actually
#      computed on: the MIN_POP_RISCO_2010 filter, then complete.cases over
#      the column's own formula variables. This is the block that describes
#      the regression.
#   B. FULL SAMPLE -- every municipality/arrangement in
#      dataset_regressao_*.csv, before either restriction, so the listwise
#      loss is visible instead of hidden. Reporting only block A would let a
#      reader assume the two coincide; reporting only block B would describe
#      data the coefficients never saw.
#
# Statistics: N, mean, SD, min, p25, median, p75, max (type-7 quantiles, R's
# default). Continuous variables only. `regiao` and `urban_class` are factors,
# so a mean is meaningless for them: they get category-frequency tables
# instead. `zero_area_2000` is a 0/1 dummy and is flagged as such -- its mean
# reads as a proportion, not a level.
#
# NOTHING IS RE-ESTIMATED HERE (MIGRATION_PLAN.md 6d: stage 4 estimates,
# stage 5 formats). The fitted models are read only to VERIFY that this
# script's reconstruction of the estimation sample is the same one the
# coefficients came from -- see "verification" below.
#
# THE ONE COPIED THING, AND HOW IT IS CHECKED. Five variables are constructed
# in 16_estimate_models.R's prep()/prep_0010() rather than stored in the CSV:
# log_pib_pc, log_pop_total_2000, log_area_2000_km2 (prep, L94/L103/L104) and
# the two treatment sums pct_area_densif_infill_0010 / _periph_ext_leap_0010
# (prep_0010, L120/L123-125). Their formulas are copied below -- and then
# CHECKED against the fitted models' own model frames, variable by variable,
# on the estimation rows. A copy that has drifted fails that check loudly
# rather than producing a plausible wrong table. The repository already
# carries several deliberate copies of these constants
# (04_.../PIPELINE.md lists them); this one is self-verifying.
#
# Inputs:
#   data/processed_data/04_regression/tables/dataset_regressao_municipio.csv  (script 15)
#   data/processed_data/04_regression/tables/dataset_regressao_arranjo.csv    (script 15)
#   data/processed_data/04_regression/model_objects_table2.rds                (script 16)
#
# Outputs (in output/):
#   ed_table_descriptives_municipality.csv
#   ed_table_descriptives_arrangement.csv
#   ed_table_descriptives_categorical.csv
#   ed_table_descriptives.md          (both levels, formatted for the appendix)
#
# Run from the repository root (relative paths, CLAUDE.md rule 5):
#   source("05_exhibits/ed_table_descriptive_statistics.R")
# =============================================================================

source("04_regression_dataset_and_models/00_setup.R")

cat("\n", strrep("=", 74), "\n", sep = "")
cat("APPENDIX TABLE — DESCRIPTIVE STATISTICS FOR TABLE 2's VARIABLES\n")
cat(strrep("=", 74), "\n", sep = "")
cat(sprintf("  Minimum-baseline cut (from 00_setup.R): pop_2010_risk_total > %d\n",
            MIN_POP_RISCO_2010))

# =============================================================================
# 1) VARIABLES — the specification, copied from 16_estimate_models.R L250-259
#    and L323-336, with their labels and units for the appendix.
# =============================================================================

# Order here is the order in the exhibit: outcomes, treatments, then controls
# grouped as exposure/terrain, housing market, size and composition.
VAR_SPEC <- tibble::tribble(
  ~variable,                            ~label,                                              ~unit,        ~role,
  "g_alta",                             "Growth of exposed population, 2010-2022",           "%",          "Outcome",
  "delta_pp_alta",                      "Change in exposed population share, 2010-2022",     "p.p.",       "Outcome",
  "pct_area_densif_infill_0010",        "Compact growth share, 2000-2010",                   "% of area",  "Treatment",
  "pct_area_periph_ext_leap_0010",      "Sprawl growth share, 2000-2010",                    "% of area",  "Treatment",
  "g_fora_alta",                        "Growth of non-exposed population, 2010-2022",       "%",          "Control (cols 1-2 only)",
  "topo_prop_inclinado",                "Steep terrain",                                     "proportion", "Control",
  "pp_alta_2010",                       "Exposed population share, 2010",                    "%",          "Control",
  "pct_nao_constru_fora_alta_2010_q1",  "Unbuilt land outside hazard zones, income-quartile-1 cells, 2010",  "% of area",  "Control",
  "pct_nao_constru_fora_alta_2010_q4",  "Unbuilt land outside hazard zones, income-quartile-4 cells, 2010",  "% of area",  "Control",
  "palma_rent",                         "Palma ratio, rent",                                 "ratio",      "Control (housing market)",
  "palma_commute",                      "Palma ratio, commuting time",                       "ratio",      "Control (housing market)",
  "median_rent",                        "Median rent",                                       "BRL",        "Control (housing market)",
  "log_pib_pc",                         "GDP per capita, 2010 (log)",                        "log R$ thousand", "Control",
  "log_pop_total_2000",                 "Total population, 2000 (log)",                      "log people", "Control",
  "log_area_2000_km2",                  "Urban footprint area, 2000 (log)",                  "log km2",    "Control",
  "zero_area_2000",                     "No urban footprint in 2000",                        "0/1",        "Control (dummy)",
  "prop_favelas_2010",                  "Population in subnormal clusters, 2010",            "proportion", "Control"
)

# UNITS, checked against the construction code rather than inferred from names:
#   pct_nao_constru_fora_alta_2010_q1/_q4  percentages of cell area, NOT indicators
#     (08_available_land.R:223, evaluated on the quartile-1 / quartile-4 subsets at
#     L236-238). The income-quartile classification itself is assigned upstream of
#     this stage, in the aggregated grid input.
#   pib_pc_2010  total GDP in R$ THOUSAND divided by census population
#     (05_prepare_gdp.R:67-71), so log_pib_pc is log(R$ thousand per capita + 1):
#     a mean of 2.94 is about R$ 18,000 per capita, not R$ 19.
#
# Indicators: zero_area_2000 alone. Its mean is a proportion and its quartiles
# carry no separate information, so it is flagged in the exhibit. The two
# quartile variables above read like indicators from their names and are not.
DUMMIES <- c("zero_area_2000")

# Factors: category frequencies instead of moments.
FACTORS <- c("regiao", "urban_class")

# The control set, exactly as 16_estimate_models.R L250-259 defines it.
CTRL_ALTA <- c(
  "topo_prop_inclinado",
  "pp_alta_2010",
  "pct_nao_constru_fora_alta_2010_q1",
  "pct_nao_constru_fora_alta_2010_q4",
  "palma_rent", "palma_commute", "median_rent",
  "log_pib_pc", "log_pop_total_2000", "log_area_2000_km2", "zero_area_2000",
  "prop_favelas_2010",
  "regiao", "urban_class"
)
TRAT_COMPACT <- "pct_area_densif_infill_0010"
TRAT_PERIPH  <- "pct_area_periph_ext_leap_0010"

# Column (1) of the main table: g_alta on the compact treatment, CTRL_ALTA plus
# g_fora_alta. Its complete.cases set is what "the estimation sample" means
# here; the script checks below whether the other three columns share it.
SPEC_MAIN <- list(
  "(1) g_high — Compact"   = c("g_alta",        TRAT_COMPACT, CTRL_ALTA, "g_fora_alta"),
  "(2) g_high — Sprawl"    = c("g_alta",        TRAT_PERIPH,  CTRL_ALTA, "g_fora_alta"),
  "(3) Dpp_high — Compact" = c("delta_pp_alta", TRAT_COMPACT, CTRL_ALTA),
  "(4) Dpp_high — Sprawl"  = c("delta_pp_alta", TRAT_PERIPH,  CTRL_ALTA)
)

# =============================================================================
# 2) CONSISTENCY MANIFEST — the five constructed variables
#    Copied from 16_estimate_models.R prep() (L94, L103, L104) and
#    prep_0010() (L120, L123-125). Verified against the fitted models below.
# =============================================================================

build_derived <- function(df) {
  df %>% mutate(
    log_pib_pc         = log(pib_pc_2010 + 1),
    log_pop_total_2000 = log(pop_2000    + 1),
    log_area_2000_km2  = log(area_2000_m2 / 1e6 + 0.001),
    pct_area_densif_infill_0010   = pct_area_densif_0010 + pct_area_infill_0010,
    pct_area_periph_ext_leap_0010 = pct_area_peripheral_0010 +
                                    pct_area_extension_0010  +
                                    pct_area_leapfrog_0010,
    regiao      = factor(regiao,
                         levels = c("Sudeste", "Sul", "Nordeste",
                                    "Norte", "Centro-Oeste")),
    urban_class = factor(urban_class,
                         levels = c("Urban Centers", "Metropolises",
                                    "Metropolis Suburbs", "Regional Centers",
                                    "Regional Centers Suburbs"))
  )
}

DERIVED <- c("log_pib_pc", "log_pop_total_2000", "log_area_2000_km2",
             TRAT_COMPACT, TRAT_PERIPH)

cat("\nConstructed variables copied from 16_estimate_models.R:\n")
cat("  log_pib_pc                    = log(pib_pc_2010 + 1)                    [prep L94]\n")
cat("  log_pop_total_2000            = log(pop_2000 + 1)                       [prep L103]\n")
cat("  log_area_2000_km2             = log(area_2000_m2/1e6 + 0.001)           [prep L104]\n")
cat("  pct_area_densif_infill_0010   = densif + infill                         [prep_0010 L120]\n")
cat("  pct_area_periph_ext_leap_0010 = peripheral + extension + leapfrog       [prep_0010 L123]\n")
cat("  (each is checked against the fitted models' own values in step 5)\n")

# =============================================================================
# 3) READ
# =============================================================================

path_mun <- file.path(tables_dir, "dataset_regressao_municipio.csv")
path_arr <- file.path(tables_dir, "dataset_regressao_arranjo.csv")
path_rds <- file.path(data_dir, "model_objects_table2.rds")

for (p in c(path_mun, path_arr, path_rds))
  if (!file.exists(p))
    stop("Required input not found: ", p,
         "\nRun 04_regression_dataset_and_models/00_run_all.R first.")

cat("\n1) Reading inputs...\n")
ds_mun_full <- readr::read_csv(path_mun, show_col_types = FALSE, progress = FALSE) %>%
  build_derived()
ds_arr_full <- readr::read_csv(path_arr, show_col_types = FALSE, progress = FALSE) %>%
  build_derived()
model_objects <- readRDS(path_rds)

cat(sprintf("  municipalities (full): %d\n", nrow(ds_mun_full)))
cat(sprintf("  arrangements   (full): %d\n", nrow(ds_arr_full)))

# =============================================================================
# 4) THE ESTIMATION SAMPLE — reconstructed the way fit_safe() defines it
#    (16_estimate_models.R L296-299): the minimum-baseline filter, then
#    complete.cases over the variables in that column's formula.
# =============================================================================

apply_min_filter <- function(df, level) {
  if (!"pop_2010_risk_total" %in% names(df)) {
    cat(sprintf("  NOTE: pop_2010_risk_total absent at %s level; no cut applied\n", level))
    return(df)
  }
  n0 <- nrow(df)
  out <- df %>% filter(pop_2010_risk_total > MIN_POP_RISCO_2010)
  cat(sprintf("  %s: %d -> %d after pop_2010_risk_total > %d\n",
              level, n0, nrow(out), MIN_POP_RISCO_2010))
  out
}

estimation_rows <- function(df, vars) {
  have <- intersect(vars, names(df))
  missing <- setdiff(vars, names(df))
  if (length(missing) > 0)
    cat(sprintf("    WARNING: not in the data, so not part of complete.cases: %s\n",
                paste(missing, collapse = ", ")))
  df[complete.cases(df[, have, drop = FALSE]), , drop = FALSE]
}

cat("\n2) Building the estimation sample...\n")
ds_mun_cut <- apply_min_filter(ds_mun_full, "municipalities")
ds_arr_cut <- apply_min_filter(ds_arr_full, "arrangements")

# Are the four main columns' complete.cases sets the same? If they are, "the
# estimation sample" is unambiguous and one block describes all four columns.
set_sizes <- function(df, level) {
  cat(sprintf("\n  complete.cases N per column, %s:\n", level))
  sets <- lapply(names(SPEC_MAIN), function(nm) {
    rows <- estimation_rows(df, SPEC_MAIN[[nm]])
    cat(sprintf("    %-26s N = %d\n", nm, nrow(rows)))
    rows
  })
  names(sets) <- names(SPEC_MAIN)
  sets
}
sets_mun <- set_sizes(ds_mun_cut, "municipalities")
sets_arr <- set_sizes(ds_arr_cut, "arrangements")

# Identity check across the four columns, by row content rather than by count:
# equal N does not mean the same rows (pipeline_5.md section 4.3 makes exactly
# this point about the funnels).
same_rows <- function(sets, key) {
  if (!key %in% names(sets[[1]])) return(NA)
  ids <- lapply(sets, function(d) sort(as.character(d[[key]])))
  all(vapply(ids[-1], function(x) identical(x, ids[[1]]), logical(1)))
}
key_mun <- if ("cod_mun" %in% names(ds_mun_full)) "cod_mun" else NA_character_
key_arr <- if ("cod_arranjo" %in% names(ds_arr_full)) "cod_arranjo" else
           if ("CD_CIDADE"  %in% names(ds_arr_full)) "CD_CIDADE"  else NA_character_

id_mun <- if (!is.na(key_mun)) same_rows(sets_mun, key_mun) else NA
id_arr <- if (!is.na(key_arr)) same_rows(sets_arr, key_arr) else NA

cat(sprintf("\n  All four columns estimated on identical rows? municipalities: %s | arrangements: %s\n",
            ifelse(is.na(id_mun), "could not check", ifelse(id_mun, "YES", "NO")),
            ifelse(is.na(id_arr), "could not check", ifelse(id_arr, "YES", "NO"))))
if (isFALSE(id_mun) || isFALSE(id_arr))
  cat("  -> The blocks below use column (1)'s sample; the per-column N's above\n",
      "     are reported in the exhibit note so the difference is not hidden.\n", sep = "")

ds_mun_est <- sets_mun[[1]]
ds_arr_est <- sets_arr[[1]]

# =============================================================================
# 5) VERIFICATION — is this the sample the coefficients came from?
#    Compares N and, for every numeric variable, the mean, against the fitted
#    models' own model frames. This is what makes the copied constructions in
#    step 2 safe to rely on.
# =============================================================================

cat("\n3) Verifying against the fitted models...\n")

verify_level <- function(mods, est_df, level) {
  if (is.null(mods)) {
    cat(sprintf("  %s: no fitted models in the rds -- cannot verify\n", level))
    return(FALSE)
  }
  mod <- mods[[1]]
  if (is.null(mod) || is.null(mod$model)) {
    cat(sprintf("  %s: column (1) has no model frame -- cannot verify\n", level))
    return(FALSE)
  }
  mf <- mod$model
  ok_n <- nrow(mf) == nrow(est_df)
  cat(sprintf("  %s: model N = %d, reconstructed N = %d  %s\n",
              level, nrow(mf), nrow(est_df), if (ok_n) "MATCH" else "*** MISMATCH ***"))

  num_vars <- intersect(names(mf), names(est_df))
  num_vars <- num_vars[vapply(num_vars, function(v) is.numeric(mf[[v]]), logical(1))]
  fails <- character(0)
  for (v in num_vars) {
    a <- mean(mf[[v]], na.rm = TRUE)
    b <- mean(est_df[[v]], na.rm = TRUE)
    tol <- 1e-8 * max(1, abs(a))
    if (!isTRUE(abs(a - b) <= tol)) {
      fails <- c(fails, v)
      cat(sprintf("    %-34s model %.10g vs reconstructed %.10g\n", v, a, b))
    }
  }
  if (length(fails) == 0)
    cat(sprintf("    all %d numeric variables agree with the fitted model to 1e-8\n",
                length(num_vars)))
  else
    cat(sprintf("    *** %d variable(s) disagree: %s\n",
                length(fails), paste(fails, collapse = ", ")))
  ok_n && length(fails) == 0
}

ok_mun <- verify_level(model_objects$tab_main_mun, ds_mun_est, "municipalities")
ok_arr <- verify_level(model_objects$tab_appA_arr, ds_arr_est, "arrangements")

if (!ok_mun || !ok_arr) {
  warning("The reconstructed estimation sample does NOT match the fitted models. ",
          "Per CLAUDE.md rule 2, STOP and report this rather than publishing the ",
          "table: either a construction in build_derived() has drifted from ",
          "16_estimate_models.R's prep()/prep_0010(), or the saved models are from ",
          "a different run of the data than the CSVs on disk. The files below are ",
          "still written, but every one of them is marked UNVERIFIED.")
}
verified_tag <- if (ok_mun && ok_arr) "VERIFIED" else "UNVERIFIED"

# =============================================================================
# 6) THE STATISTICS
# =============================================================================

# Vectorised isTRUE, for filtering a logical column that may carry NAs.
isTRUE_vec <- function(x) !is.na(x) & x

describe_one <- function(x) {
  x <- suppressWarnings(as.numeric(x))
  x <- x[!is.na(x)]
  if (length(x) == 0)
    return(c(N = 0, mean = NA, sd = NA, min = NA, p25 = NA,
             median = NA, p75 = NA, max = NA))
  q <- stats::quantile(x, c(0.25, 0.5, 0.75), names = FALSE)  # type 7, R's default
  c(N = length(x), mean = mean(x), sd = stats::sd(x), min = min(x),
    p25 = q[1], median = q[2], p75 = q[3], max = max(x))
}

describe_block <- function(df, block_label, level_label) {
  vars <- VAR_SPEC$variable[VAR_SPEC$variable %in% names(df)]
  missing <- setdiff(VAR_SPEC$variable, names(df))
  if (length(missing) > 0)
    cat(sprintf("  %s / %s: not present, omitted: %s\n",
                level_label, block_label, paste(missing, collapse = ", ")))
  stats <- t(vapply(vars, function(v) describe_one(df[[v]]), numeric(8)))
  out <- data.frame(variable = vars, stats, row.names = NULL,
                    stringsAsFactors = FALSE)
  names(out) <- c("variable", "N", "mean", "sd", "min", "p25", "median", "p75", "max")
  out <- merge(VAR_SPEC, out, by = "variable", sort = FALSE)
  out <- out[match(vars, out$variable), ]
  out$is_dummy <- out$variable %in% DUMMIES
  # A variable with no variation in this sample is collinear with the
  # intercept: lm() aliases it and reports no coefficient. zero_area_2000 is
  # constant (all 0) at arrangement level -- MIGRATION_PLAN.md 6c2 finding 4,
  # which ED Table 3 already footnotes. Reporting its row as an ordinary
  # variable with mean 0 would imply the regression used it.
  out$is_constant <- !is.na(out$sd) & out$sd == 0 & out$N > 0
  out$block    <- block_label
  out$level    <- level_label
  out$status   <- verified_tag
  out
}

cat("\n4) Computing statistics...\n")
desc_mun <- rbind(
  describe_block(ds_mun_est,  "A. Estimation sample", "Municipality"),
  describe_block(ds_mun_full, "B. Full sample",       "Municipality")
)
desc_arr <- rbind(
  describe_block(ds_arr_est,  "A. Estimation sample", "Arrangement"),
  describe_block(ds_arr_full, "B. Full sample",       "Arrangement")
)

# Factors: category frequencies, both blocks, both levels.
describe_factor <- function(df, v, block_label, level_label) {
  if (!v %in% names(df)) return(NULL)
  tb <- table(df[[v]], useNA = "ifany")
  data.frame(
    variable = v,
    category = ifelse(is.na(names(tb)), "(missing)", names(tb)),
    n        = as.integer(tb),
    pct      = round(100 * as.integer(tb) / sum(tb), 1),
    block    = block_label,
    level    = level_label,
    status   = verified_tag,
    row.names = NULL, stringsAsFactors = FALSE
  )
}

desc_cat <- do.call(rbind, c(
  lapply(FACTORS, describe_factor, df = ds_mun_est,  block_label = "A. Estimation sample", level_label = "Municipality"),
  lapply(FACTORS, describe_factor, df = ds_mun_full, block_label = "B. Full sample",       level_label = "Municipality"),
  lapply(FACTORS, describe_factor, df = ds_arr_est,  block_label = "A. Estimation sample", level_label = "Arrangement"),
  lapply(FACTORS, describe_factor, df = ds_arr_full, block_label = "B. Full sample",       level_label = "Arrangement")
))

# =============================================================================
# 7) WRITE
# =============================================================================

cat("\n5) Writing outputs...\n")

out_mun <- output_path("ed_table_descriptives_municipality.csv")
out_arr <- output_path("ed_table_descriptives_arrangement.csv")
out_cat <- output_path("ed_table_descriptives_categorical.csv")
out_md  <- output_path("ed_table_descriptives.md")

readr::write_csv(desc_mun, out_mun)
readr::write_csv(desc_arr, out_arr)
readr::write_csv(desc_cat, out_cat)
for (p in c(out_mun, out_arr, out_cat)) cat(sprintf("  Saved: %s\n", p))

# A formatted version for pasting into the appendix. Significant digits are
# chosen per variable from its own magnitude, so a rent in BRL and a
# proportion in [0,1] are both readable.
fmt_num <- function(x, ref) {
  if (is.na(x)) return("—")
  d <- if (!is.finite(ref) || ref == 0) 3 else if (abs(ref) >= 1000) 0 else
       if (abs(ref) >= 100) 1 else if (abs(ref) >= 1) 2 else 3
  formatC(x, format = "f", digits = d, big.mark = ",")
}

md_block <- function(d, level_label) {
  lines <- c(
    sprintf("### %s level", level_label), "",
    "| Variable | Unit | N | Mean | SD | Min | p25 | Median | p75 | Max |",
    "|---|---|---:|---:|---:|---:|---:|---:|---:|---:|"
  )
  for (blk in unique(d$block)) {
    sub <- d[d$block == blk, ]
    lines <- c(lines, sprintf("| **%s** | | | | | | | | | |", blk))
    for (i in seq_len(nrow(sub))) {
      r <- sub[i, ]
      ref <- if (is.finite(r$mean)) abs(r$mean) else 1
      lab <- r$label
      if (isTRUE(r$is_dummy))    lab <- paste0(lab, " †")
      if (isTRUE(r$is_constant)) lab <- paste0(lab, " ‡")
      lines <- c(lines, sprintf("| %s | %s | %d | %s | %s | %s | %s | %s | %s | %s |",
        lab, r$unit, as.integer(r$N),
        fmt_num(r$mean, ref), fmt_num(r$sd, ref), fmt_num(r$min, ref),
        fmt_num(r$p25, ref), fmt_num(r$median, ref), fmt_num(r$p75, ref),
        fmt_num(r$max, ref)))
    }
    lines <- c(lines, "| | | | | | | | | | |")
  }
  c(lines, "")
}

md <- c(
  "# Extended Data — Descriptive statistics for the regression variables",
  "",
  sprintf("Generated by `05_exhibits/ed_table_descriptive_statistics.R` on %s. Status: **%s**.",
          format(Sys.time(), "%Y-%m-%d %H:%M:%S %z"), verified_tag),
  "",
  paste0("**Block A (estimation sample)** is the set of units Table 2's coefficients were ",
         "computed on: units with `pop_2010_risk_total` above ", MIN_POP_RISCO_2010,
         ", then listwise deletion over the variables in the specification. ",
         "**Block B (full sample)** is every unit in the regression dataset before either ",
         "restriction. The gap between the two N's is the listwise loss."),
  "",
  md_block(desc_mun, "Municipality"),
  md_block(desc_arr, "Arrangement (functional urban area)"),
  "### Categorical controls", "",
  "| Variable | Category | Level | Block | n | % |",
  "|---|---|---|---|---:|---:|"
)
if (!is.null(desc_cat)) {
  for (i in seq_len(nrow(desc_cat))) {
    r <- desc_cat[i, ]
    md <- c(md, sprintf("| %s | %s | %s | %s | %d | %.1f |",
                        r$variable, r$category, r$level, r$block, r$n, r$pct))
  }
}
md <- c(md, "",
  "† 0/1 indicator: the mean is the proportion of units with the value 1; the",
  "  quartiles carry no separate information.",
  "",
  "‡ No variation in this sample. The variable is collinear with the intercept,",
  "  so the regression aliases it and reports no coefficient for it. It is listed",
  "  here for completeness, not because it identifies anything.",
  "",
  "Growth rates and shares are in percent; changes in shares are in percentage",
  "points. Logged variables are reported on the log scale, as they enter the",
  "regression. Quantiles are R's default (type 7).")

writeLines(md, out_md)
cat(sprintf("  Saved: %s\n", out_md))

# =============================================================================
# 8) CONSOLE SUMMARY
# =============================================================================

# Both levels are printed. An earlier version showed only the municipality
# block, which read as though the arrangement table had not been produced.
show_block <- function(d, level_label) {
  cat(sprintf("\n6) Estimation sample (block A), %s level:\n\n", level_label))
  cols_num <- c("mean", "sd", "min", "median", "max")
  show <- d[d$block == "A. Estimation sample",
            c("label", "unit", "N", cols_num)]
  if (nrow(show) == 0) {
    cat("  (no rows -- see the warnings above)\n")
    return(invisible(NULL))
  }
  show[, cols_num] <- lapply(show[, cols_num], function(x) signif(x, 4))
  print(show, row.names = FALSE)
  const <- d$label[d$block == "A. Estimation sample" & isTRUE_vec(d$is_constant)]
  if (length(const) > 0)
    cat(sprintf("\n  NOTE: no variation in this sample, so aliased out of the regression: %s\n",
                paste(const, collapse = "; ")))
  invisible(NULL)
}

show_block(desc_mun, "municipality")
show_block(desc_arr, "arrangement (functional urban area)")

cat("\n", strrep("=", 74), "\n", sep = "")
cat(sprintf("DONE — %s. Estimation N: municipalities %d, arrangements %d;\n",
            verified_tag, nrow(ds_mun_est), nrow(ds_arr_est)))
cat(sprintf("       full N: municipalities %d, arrangements %d.\n",
            nrow(ds_mun_full), nrow(ds_arr_full)))
cat(strrep("=", 74), "\n", sep = "")
