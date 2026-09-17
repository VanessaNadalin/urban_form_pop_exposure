# =============================================================================
# diagnostics/g_alta_outlier_check.R
#
# DIAGNOSTIC -- not part of the pipeline (not in 00_run_all.R).
#
# Why: Table 2's main table, re-run after this session's fixes, moved far
# more on columns (1)-(2) (g_alta, a growth RATE) than on (3)-(4)
# (delta_pp_alta, a percentage-POINT change) -- e.g. Compact went from -0.026
# (n.s., results_used.md target) to -1.860, Sprawl from +0.103** to +2.943.
# delta_pp_alta stayed close to target (0.038** vs. 0.040***; -0.017 vs.
# -0.021*). That asymmetry points at g_alta's own definition
# (13_dependent_variables.R):
#   g_alta = 100 * (pop_2022_risk_total - pop_2010_risk_total) /
#            pmax(pop_2010_risk_total, 1)
# A municipality with a small but nonzero pop_2010_risk_total (a handful of
# people) can produce an enormous g_alta (a few hundred people of absolute
# change over a denominator of 2-10 is a growth rate in the thousands of
# percent) -- invisible in the NATIONAL total (these municipalities are tiny,
# so they barely move the sum used for Table 1), but potentially dominant in
# an unweighted OLS regression where g_alta is the dependent variable. The
# regression sample grew this session (387 -> 395 municipalities, N=341 ->
# ~351 in the main table) -- plausibly including some of these small,
# volatile denominators that were previously excluded for missing data.
#
# This script:
#   1. Reports g_alta's distribution in the current regression sample and
#      flags the most extreme observations (by |g_alta|), with their
#      pop_2010_risk_total / pop_2022_risk_total.
#   2. Re-fits the two growth-rate main-table specs (g_alta ~ Compact / ~
#      Sprawl, identical Y/controls/clustering to 16_estimate_models.R)
#      three ways: full sample, excluding a fixed |g_alta| threshold, and
#      excluding the top/bottom 1% by g_alta -- to see whether the
#      coefficients move back toward the original target once the extreme
#      denominators are set aside.
#
# This does NOT decide how the final pipeline should handle this (winsorize,
# trim, a different functional form, population-weighted least squares) --
# it only checks whether outliers ARE the mechanism, so that decision can be
# made on evidence.
#
# Run from the repository root:
#   source("04_regression_dataset_and_models/diagnostics/g_alta_outlier_check.R")
# =============================================================================

source("04_regression_dataset_and_models/00_setup.R")

for (pkg in c("lmtest", "sandwich")) {
  if (!requireNamespace(pkg, quietly = TRUE)) install.packages(pkg)
  library(pkg, character.only = TRUE)
}

cat("\n", strrep("=", 70), "\n")
cat("g_alta OUTLIER CHECK\n")
cat(strrep("=", 70), "\n")

# --- 1) Load the regression dataset, same as 16_estimate_models.R -----------

path_mun <- file.path(tables_dir, "dataset_regressao_municipio.csv")
if (!file.exists(path_mun))
  stop("dataset_regressao_municipio.csv not found -- run stage 04 through script 15 first.\n  Path: ", path_mun)

ds <- read_csv(path_mun, show_col_types = FALSE) |>
  mutate(cod_mun = as.character(as.integer(cod_mun)))
cat(sprintf("\ndataset_regressao_municipio.csv: %d municipalities\n", nrow(ds)))

if (!all(c("g_alta", "pop_2010_risk_total", "pop_2022_risk_total") %in% names(ds))) {
  missing <- setdiff(c("g_alta", "pop_2010_risk_total", "pop_2022_risk_total"), names(ds))
  stop("Missing column(s) needed for this check: ", paste(missing, collapse = ", "),
       " -- were they dropped by 15_final_dataset.R's column trim? If so this",
       " diagnostic needs to read dataset_completo_municipio.csv instead.")
}

# --- 2) Distribution and extremes -------------------------------------------

cat("\n--- g_alta distribution (all rows with a valid Y) ---\n")
g_summary <- summary(ds$g_alta)
print(g_summary)
cat(sprintf("SD: %.2f | N valid: %d\n", sd(ds$g_alta, na.rm = TRUE), sum(!is.na(ds$g_alta))))

cat("\n--- Top 15 by |g_alta| ---\n")
extremos <- ds |>
  filter(!is.na(g_alta)) |>
  mutate(abs_g_alta = abs(g_alta)) |>
  arrange(desc(abs_g_alta)) |>
  select(cod_mun, g_alta, pop_2010_risk_total, pop_2022_risk_total,
         any_of(c("pop_2010_total", "pop_2022_total", "zero_area_2000", "area_2000_m2"))) |>
  head(15)
print(extremos, n = Inf, width = Inf)

# Does the existing zero_area_2000 control (already in CTRL_ALTA, unchanged
# from regression2/12_regressao_preperiodo.R on main -- "no urban footprint
# in 2000 dummy") happen to flag these? It shouldn't: zero_area_2000 is about
# TOTAL urban footprint area in 2000 (the 2000-2010 treatment window), while
# g_alta's blow-up comes from pop_2010_risk_total == 0 (population WITHIN
# high-susceptibility zones in 2010, the 2010-2022 outcome window) -- a
# municipality can have plenty of urban footprint in 2000 and still have zero
# of it overlapping a mapped susceptibility zone. Checking directly rather
# than assuming:
if ("zero_area_2000" %in% names(extremos)) {
  cat(sprintf("\nOf the top 15 by |g_alta|, zero_area_2000 == 1 for: %d / 15\n",
              sum(extremos$zero_area_2000 == 1, na.rm = TRUE)))
  cat("(if 0, the existing dummy does not flag these observations at all --\n")
  cat(" it controls for a different zero-baseline problem, not this one)\n")
}

out_extremos <- file.path(tables_dir, "diagnostics", "g_alta_extremes.csv")
dir.create(dirname(out_extremos), showWarnings = FALSE)
write_csv(extremos, out_extremos)
cat(sprintf("\nSaved: %s\n", out_extremos))

# --- 3) Re-fit the growth-rate specs: full sample vs. two outlier cuts ------

CTRL_ALTA <- c(
  "topo_prop_inclinado", "pp_alta_2010",
  "pct_nao_constru_fora_alta_2010_q1", "pct_nao_constru_fora_alta_2010_q4",
  "palma_rent", "palma_commute", "median_rent",
  "log_pib_pc", "log_pop_total_2000", "log_area_2000_km2", "zero_area_2000",
  "prop_favelas_2010", "regiao", "urban_class"
)

ds <- ds |>
  mutate(
    log_pib_pc         = log(pib_pc_2010 + 1),
    log_pop_total_2000 = log(pop_2000 + 1),
    log_area_2000_km2  = log(area_2000_m2 / 1e6 + 0.001),
    regiao      = factor(regiao, levels = c("Sudeste", "Sul", "Nordeste", "Norte", "Centro-Oeste")),
    urban_class = factor(urban_class, levels = c("Urban Centers", "Metropolises",
                                                  "Metropolis Suburbs", "Regional Centers",
                                                  "Regional Centers Suburbs")),
    pct_area_densif_infill_0010   = pct_area_densif_0010 + pct_area_infill_0010,
    pct_area_periph_ext_leap_0010 = pct_area_peripheral_0010 + pct_area_extension_0010 + pct_area_leapfrog_0010
  )

make_f <- function(y, trat, ctrl) as.formula(paste(y, "~", paste(c(trat, ctrl), collapse = " + ")))

fit_safe <- function(f, data, cluster_col = "NM_CIDADE") {
  vars <- all.vars(f)
  dat  <- data[complete.cases(data[, intersect(vars, names(data))]), ]
  tryCatch({
    mod <- lm(f, data = dat)
    if (!is.null(cluster_col) && cluster_col %in% names(dat))
      attr(mod, "cluster_vec") <- dat[[cluster_col]]
    attr(mod, "n") <- nrow(dat)
    mod
  }, error = function(e) { message("    ERROR: ", e$message); NULL })
}

vcov_clust <- function(mod) {
  cl <- attr(mod, "cluster_vec")
  if (!is.null(cl)) vcovCL(mod, cluster = cl) else vcovHC(mod, type = "HC3")
}

specs <- list(
  "g_high — Compact" = list(trat = "pct_area_densif_infill_0010",
                             ctrl = c(CTRL_ALTA, "g_fora_alta")),
  "g_high — Sprawl"  = list(trat = "pct_area_periph_ext_leap_0010",
                             ctrl = c(CTRL_ALTA, "g_fora_alta"))
)

# Three samples: full; a fixed |g_alta| cutoff (500pp -- a 6x change in the
# risk population from its 2010 baseline, well beyond plausible organic
# growth); and trimming the top/bottom 1% by g_alta.
threshold_fixed <- 500
q_low  <- quantile(ds$g_alta, 0.01, na.rm = TRUE)
q_high <- quantile(ds$g_alta, 0.99, na.rm = TRUE)

# Minimum-baseline-population cuts (researcher's proposed fix: restrict on
# pop_2010_risk_total rather than on g_alta itself). 100 is the value under
# discussion; 500/1000 are what the old 12a_diagnostico_outliers.R script
# itself suggested ("Adicionar filtro de base minima (pop_risco_2010 > 500
# ou 1000)") -- included so the comparison isn't just this session's guess.
min_pop_cuts <- c(100, 250, 500, 1000)
min_pop_samples <- setNames(
  lapply(min_pop_cuts, function(th) ds |> filter(pop_2010_risk_total > th)),
  paste0("min_pop_risco_", min_pop_cuts)
)

samples <- c(
  list(
    full                  = ds,
    cut_500pp             = ds |> filter(abs(g_alta) <= threshold_fixed | is.na(g_alta)),
    trim_top_bottom_1pct  = ds |> filter((g_alta >= q_low & g_alta <= q_high) | is.na(g_alta))
  ),
  min_pop_samples
)
cat(sprintf("\nSample sizes -- full: %d | |g_alta|<=%d: %d | trimmed 1%%/99%%: %d\n",
            nrow(samples$full), threshold_fixed, nrow(samples$cut_500pp),
            nrow(samples$trim_top_bottom_1pct)))
cat(sprintf("1st/99th percentile of g_alta: %.1f / %.1f\n", q_low, q_high))
cat("Minimum-baseline-population cuts (pop_2010_risk_total > threshold):\n")
for (nm in names(min_pop_samples))
  cat(sprintf("  %-22s N = %d\n", nm, nrow(min_pop_samples[[nm]])))

results <- purrr::imap_dfr(samples, function(dat, sample_name) {
  purrr::imap_dfr(specs, function(s, spec_name) {
    mod <- fit_safe(make_f("g_alta", s$trat, s$ctrl), dat)
    if (is.null(mod)) return(tibble::tibble())
    coefs <- lmtest::coeftest(mod, vcov = vcov_clust(mod))
    if (!s$trat %in% rownames(coefs)) return(tibble::tibble())
    tibble::tibble(
      sample    = sample_name,
      spec      = spec_name,
      estimate  = coefs[s$trat, "Estimate"],
      se        = coefs[s$trat, "Std. Error"],
      p_value   = coefs[s$trat, "Pr(>|t|)"],
      n         = attr(mod, "n")
    )
  })
})

cat("\n", strrep("=", 70), "\n")
cat("RESULTS: g_alta ~ Compact/Sprawl, full vs. outlier-trimmed\n")
cat(strrep("=", 70), "\n")
cat("results_used.md targets: Compact -0.026 (n.s.) | Sprawl +0.103**\n\n")
options(width = 160, pillar.sigfig = 6)
print(results |>
        mutate(sig = case_when(p_value < 0.01 ~ "***", p_value < 0.05 ~ "**",
                                p_value < 0.10 ~ "*", TRUE ~ "")) |>
        arrange(spec, factor(sample, levels = names(samples))),
      n = Inf, width = Inf)

out_path <- file.path(tables_dir, "diagnostics", "g_alta_outlier_refits.csv")
write_csv(results, out_path)
cat(sprintf("\nSaved: %s\n", out_path))

cat("\nHow to read this:\n")
cat("  - If 'full' matches this session's new Table 2 (Compact ~-1.86, Sprawl\n")
cat("    ~+2.94) and the trimmed samples move back toward the target\n")
cat("    (-0.026 / +0.103), outliers in g_alta's denominator are confirmed as\n")
cat("    the mechanism -- a functional-form/robustness decision (winsorize,\n")
cat("    trim, or a different Y) is needed before trusting columns (1)-(2).\n")
cat("  - If the trimmed samples barely move, look elsewhere (e.g. the g_alta\n")
cat("    formula's pop_2010_risk_total may need a higher floor than pmax(.,1),\n")
cat("    or the coefficient shift has some other source).\n")
cat("  - min_pop_risco_100 is the threshold under discussion -- compare it\n")
cat("    against min_pop_risco_500/1000 (the old 12a_diagnostico_outliers.R\n")
cat("    script's own suggestion) to see whether 100 is high enough, given\n")
cat("    several of the known extremes (e.g. cod_mun 3507001, 5107909,\n")
cat("    3526605, 1502152) have pop_2010_risk_total in the hundreds --\n")
cat("    comfortably above 100 -- while still producing g_alta in the\n")
cat("    hundreds of percent.\n")
