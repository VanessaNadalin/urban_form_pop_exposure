# =============================================================================
# diagnostics/table2_with_1022_growth_shares.R
#
# DIAGNOSTIC -- not part of the pipeline (not in 00_run_all.R).
#
# What this answers: the paper's actual Table 2 treatment is the 2000-2010
# pre-period compact/sprawl share (pct_area_densif_infill_0010 /
# pct_area_periph_ext_leap_0010, from 06_classify_growth_types_2000_2010.R --
# untouched by the Test A/B population-proxy check, since that check only
# ever modified the 2010-2022 window, scripts 04/05/07). This script asks a
# DIFFERENT question: if compact/sprawl are instead measured over the SAME
# window as the outcome (2010-2022, the window Table 1 and the legacy-proxy
# check are both about), does Table 2's compact/sprawl coefficient survive,
# and does it matter which population proxy built that 2010-2022
# classification (baseline vs. Test B, the one that reproduces the
# manuscript's original Table 1 numbers)?
#
# Three treatment variants, all re-estimated with the IDENTICAL Y, controls,
# clustering and complete.cases handling as 16_estimate_models.R's main
# table (y_high) -- only the treatment columns differ:
#
#   orig_0010     : pct_area_densif_infill_0010 / pct_area_periph_ext_leap_0010
#                   -- already in dataset_regressao_municipio.csv, the actual
#                   Table 2 treatment. Included as the reference point.
#   baseline_1022 : same construction (pct_area_densif + pct_area_infill;
#                   pct_area_peripheral + pct_area_extension + pct_area_leapfrog),
#                   but from the 2010-2022 window's validated common-grid
#                   classification (metricas_municipio_2010_2022.csv).
#   testB_1022    : identical construction, from the Test B legacy-proxy
#                   variant (metricas_municipio_2010_2022_testB.csv). The
#                   migration-era diagnostic that produced that file is not
#                   part of this repository, so this variant is normally
#                   skipped with a warning; the other two are unaffected.
#
# pct_area_densif/_peripheral/_extension/_leapfrog (2010-2022, no _0010
# suffix) mirror 13_dependent_variables.R's vars_forma() exactly
# (100 * area_m2_<type> / pmax(area_urban_2022_m2, 1)); pct_area_infill
# (2010-2022) is the same formula for the infill type, which vars_forma()
# does not itself compute (13_dependent_variables.R never needed a 2010-2022
# "compact" share on its own -- only 16_estimate_models.R's prep() computes
# the sprawl side, pct_area_periph_ext_leap, for an unused robustness column).
#
# Requires:
#   data/processed_data/04_regression/tables/dataset_regressao_municipio.csv  (script 15)
#   data/processed_data/03_urban_footprint/metricas/metricas_municipio_2010_2022.csv       (stage 03 script 07)
#   data/processed_data/03_urban_footprint/metricas/metricas_municipio_2010_2022_testB.csv  (OPTIONAL; not reproducible here -- see above)
#
# Run from the repository root:
#   source("04_regression_dataset_and_models/diagnostics/table2_with_1022_growth_shares.R")
# =============================================================================

source("04_regression_dataset_and_models/00_setup.R")

for (pkg in c("lmtest", "sandwich")) {
  if (!requireNamespace(pkg, quietly = TRUE)) install.packages(pkg)
  library(pkg, character.only = TRUE)
}

cat("\n", strrep("=", 70), "\n")
cat("TABLE 2 DIAGNOSTIC: compact/sprawl treatment, 2000-2010 vs. 2010-2022\n")
cat(strrep("=", 70), "\n")

# --- 1) Load the regression dataset (script 15's output, unmodified) --------

path_mun <- file.path(tables_dir, "dataset_regressao_municipio.csv")
if (!file.exists(path_mun))
  stop("dataset_regressao_municipio.csv not found -- run stage 04 through script 15 first.\n  Path: ", path_mun)

ds_base <- read_csv(path_mun, show_col_types = FALSE) |>
  mutate(cod_mun = as.character(as.integer(cod_mun)))
cat(sprintf("\ndataset_regressao_municipio.csv: %d municipalities (%s)\n", nrow(ds_base), path_mun))

# Same derived variables 16_estimate_models.R's prep()/prep_0010() compute,
# needed by CTRL_ALTA/CTRL_DELTA and the _0010 treatment -- copied verbatim
# except for pct_area_periph_ext_leap (that script's own 2010-2022 sprawl
# share, superseded here by the per-variant construction below).
ds_base <- ds_base |>
  mutate(
    pop_growth           = (pop_urbana_2022 - pop_urbana_2010_cg) / pop_urbana_2010_cg,
    log_pop_2010         = log(pop_urbana_2010_cg + 1),
    log_pib_pc           = log(pib_pc_2010        + 1),
    log_area_2010_km2    = log(area_urbana_2010_m2 / 1e6 + 0.001),
    log_density_2010     = log(pop_urbana_2010_cg / (area_urbana_2010_m2 / 1e6 + 0.001) + 1),
    log_pop_total_2010   = log(pop_total_2010 + 1),
    log_pop_total_2000   = log(pop_2000       + 1),
    log_area_2000_km2    = log(area_2000_m2 / 1e6 + 0.001),
    g_fora_suscept_slums = coalesce(g_slums_1022 - g_alta_slums_1022, 0),
    regiao      = factor(regiao, levels = c("Sudeste", "Sul", "Nordeste", "Norte", "Centro-Oeste")),
    urban_class = factor(urban_class, levels = c("Urban Centers", "Metropolises",
                                                  "Metropolis Suburbs", "Regional Centers",
                                                  "Regional Centers Suburbs")),
    pct_area_densif_infill_0010   = pct_area_densif_0010 + pct_area_infill_0010,
    pct_area_periph_ext_leap_0010 = pct_area_peripheral_0010 + pct_area_extension_0010 + pct_area_leapfrog_0010
  )

# --- 2) Build the 2010-2022 compact/sprawl shares for a given metricas file --

build_1022_shares <- function(metricas_path, variant_label) {
  if (!file.exists(metricas_path)) {
    cat(sprintf("\nWARNING: %s not found -- skipping variant '%s'.\n", metricas_path, variant_label))
    return(NULL)
  }
  read_csv(metricas_path, show_col_types = FALSE) |>
    mutate(cod_mun = as.character(as.integer(cod_mun))) |>
    transmute(
      cod_mun,
      !!paste0("pct_area_densif_infill_", variant_label) :=
        100 * (area_m2_densification + area_m2_infill) / pmax(area_urban_2022_m2, 1),
      !!paste0("pct_area_periph_ext_leap_", variant_label) :=
        100 * (area_m2_peripheral + area_m2_extension + area_m2_leapfrog) / pmax(area_urban_2022_m2, 1)
    )
}

stage03_metricas_dir <- file.path(stage03_data_dir, "metricas")
shares_baseline <- build_1022_shares(
  file.path(stage03_metricas_dir, "metricas_municipio_2010_2022.csv"), "baseline")
shares_testB <- build_1022_shares(
  file.path(stage03_metricas_dir, "metricas_municipio_2010_2022_testB.csv"), "testB")

ds <- ds_base
if (!is.null(shares_baseline)) ds <- ds |> left_join(shares_baseline, by = "cod_mun")
if (!is.null(shares_testB))    ds <- ds |> left_join(shares_testB,    by = "cod_mun")

cat(sprintf("After joining 2010-2022 shares: %d rows (should be unchanged: %d)\n",
            nrow(ds), nrow(ds_base)))

# --- 3) Same controls, formula builder, and fit_safe() as 16_estimate_models.R --

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
CTRL_DELTA <- CTRL_ALTA

make_f <- function(y, trat, ctrl) as.formula(paste(y, "~", paste(c(trat, ctrl), collapse = " + ")))

fit_safe <- function(f, data, label, cluster_col = "NM_CIDADE") {
  vars <- all.vars(f)
  dat  <- data[complete.cases(data[, intersect(vars, names(data))]), ]
  tryCatch({
    mod <- lm(f, data = dat)
    if (!is.null(cluster_col) && cluster_col %in% names(dat))
      attr(mod, "cluster_vec") <- dat[[cluster_col]]
    attr(mod, "n") <- nrow(dat)
    mod
  }, error = function(e) { message("    ERROR in ", label, ": ", e$message); NULL })
}

vcov_clust <- function(mod) {
  cl <- attr(mod, "cluster_vec")
  if (!is.null(cl)) vcovCL(mod, cluster = cl) else vcovHC(mod, type = "HC3")
}

# --- 4) Estimate the 4 main-table specs for each variant --------------------

variants <- list(
  orig_0010     = list(compact = "pct_area_densif_infill_0010",
                        sprawl  = "pct_area_periph_ext_leap_0010"),
  baseline_1022 = list(compact = "pct_area_densif_infill_baseline",
                        sprawl  = "pct_area_periph_ext_leap_baseline"),
  testB_1022    = list(compact = "pct_area_densif_infill_testB",
                        sprawl  = "pct_area_periph_ext_leap_testB")
)
variants <- variants[sapply(variants, function(v) all(c(v$compact, v$sprawl) %in% names(ds)))]
cat(sprintf("\nVariants available: %s\n", paste(names(variants), collapse = ", ")))

specs_for <- function(trat_compact, trat_periph) list(
  "g_high — Compact"    = list(y = "g_alta",        trat = trat_compact, ctrl = c(CTRL_ALTA,  "g_fora_alta")),
  "g_high — Sprawl"     = list(y = "g_alta",        trat = trat_periph,  ctrl = c(CTRL_ALTA,  "g_fora_alta")),
  "Dpp_high — Compact"  = list(y = "delta_pp_alta", trat = trat_compact, ctrl = CTRL_DELTA),
  "Dpp_high — Sprawl"   = list(y = "delta_pp_alta", trat = trat_periph,  ctrl = CTRL_DELTA)
)

results <- purrr::imap_dfr(variants, function(v, variant_name) {
  specs <- specs_for(v$compact, v$sprawl)
  purrr::imap_dfr(specs, function(s, spec_name) {
    mod <- fit_safe(make_f(s$y, s$trat, s$ctrl), ds, paste(variant_name, spec_name))
    if (is.null(mod)) return(tibble::tibble())
    vc    <- vcov_clust(mod)
    coefs <- lmtest::coeftest(mod, vcov = vc)
    trat  <- s$trat
    if (!trat %in% rownames(coefs)) return(tibble::tibble())
    tibble::tibble(
      variant     = variant_name,
      spec        = spec_name,
      treatment   = trat,
      y           = s$y,
      estimate    = coefs[trat, "Estimate"],
      se          = coefs[trat, "Std. Error"],
      p_value     = coefs[trat, "Pr(>|t|)"],
      n           = attr(mod, "n"),
      r_squared   = summary(mod)$r.squared
    )
  })
})

cat("\n", strrep("=", 70), "\n")
cat("RESULTS: treatment coefficient by variant and spec\n")
cat(strrep("=", 70), "\n")
options(width = 160, pillar.sigfig = 6)
print(results |>
        mutate(sig = case_when(p_value < 0.01 ~ "***", p_value < 0.05 ~ "**",
                                p_value < 0.10 ~ "*", TRUE ~ "")) |>
        arrange(spec, factor(variant, levels = names(variants))),
      n = Inf, width = Inf)

out_path <- file.path(tables_dir, "diagnostics", "table2_1022_growth_shares_comparison.csv")
dir.create(dirname(out_path), showWarnings = FALSE)
write_csv(results, out_path)
cat(sprintf("\nSaved: %s\n", out_path))

cat("\nHow to read this:\n")
cat("  - orig_0010 is the actual Table 2 in results_used.md -- same numbers\n")
cat("    16_estimate_models.R produces for columns (1)-(4) of the main table.\n")
cat("  - baseline_1022 vs. testB_1022: same question as the Table 1 check, now\n")
cat("    asked of the regression coefficient instead of the descriptive table --\n")
cat("    does the compact/sprawl coefficient's sign/magnitude/significance\n")
cat("    depend on which population proxy built the 2010-2022 classification?\n")
cat("  - Note this is a genuinely different treatment window (2010-2022, same\n")
cat("    period as the outcome) than the paper's actual pre-period (2000-2010)\n")
cat("    design -- orig_0010 vs. the two _1022 variants is not itself a\n")
cat("    robustness check of the same specification, just a useful anchor.\n")
