# =============================================================================
# 07_aggregate_municipality_metrics.R
# Aggregate cell-level growth classifications into municipality and
# population-arrangement metrics, on the single 2010-2022 common grid.
#
# Per MIGRATION_PLAN.md 6b0 (common-grid unification, decided 2026-08-28):
# the pre-unification M2-M8 "M-family" taxonomy is retired. It existed to
# name competing answers computed on two different grids (a same-year
# population share computed on the grid's own native geometry, vs. a
# cross-grid re-aggregation to compare years); with one grid and one
# tipo_crescimento classification, those are now the same computation, run
# once. Output is a single, clean schema per growth type -- no M-family
# prefixes, no parallel column sets:
#
#   n_cel_<type>, area_m2_<type>          - cells / area (2022 urban extent)
#   pop_2022_<type>, pop_2010_<type>      - population by growth type, both years
#   pop_2022_risk_<type>, pop_2010_risk_<type>  - same, AREA-WEIGHTED into high
#                                                  susceptibility (x prop_suscept_total)
#
# Exposure weighting (MIGRATION_PLAN.md 6e, decided 2026-09-11): population in
# high susceptibility is sum(pop x prop_suscept_total) over the same cells the
# other columns use -- NOT the full population of every cell the hazard layer
# happens to touch. The previous rule (LIMIAR_SUSCEPT <- 0, "any overlap":
# filter prop_suscept_total > 0, then sum the whole cell population) is retired
# here; it was never a decided methodology, it conflicts with the manuscript's
# Methods, and it disagreed with stage 02's own rule
# (03_cross_grid_high_susceptibility.py: populacao x prop_suscept) by roughly a
# factor of 2.4 nationally. No threshold replaces it: under weighting a cell
# with prop_suscept_total == 0 contributes exactly 0 by construction.
#
# Column names are unchanged (rule 4 protects consumers reading existing files
# by name; these columns are regenerated on every run and every downstream
# consumer reads them by name). What they contain changes -- that is the point
# of the correction.
#
# plus municipal/arrangement totals across the 6 types, and area_urban_2022_m2 /
# pct_urban_growth (share of the 2022 urban footprint that is new).
#
# M6 (population in CPRM-mapped geological risk zones) and M7 (population in
# AGSN intersect risk) are dropped from this script -- confirmed against
# results_used.md that neither feeds any published exhibit, consistent with
# this repository's "pipeline should contain only the analyses used in the
# final paper" scope (decided with the researcher during the 6b0 rework).
#
# 2000-2010 pre-period metrics (06_classify_growth_types_2000_2010.R) are
# entirely separate -- not touched by this script.
#
# Inputs:
#   - grade_growth_types_2010_2022.parquet   (script 05)
#   - amostra_municipios.rds                 (script 01)
#
# Outputs (in data_processed/metricas/):
#   - metricas_municipio_2010_2022.csv
#   - metricas_arranjo_2010_2022.csv
# =============================================================================

source("03_urban_footprint_and_growth_types/00_setup.R")

library(sfarrow)
library(readr)

# =============================================================================
# PARAMETERS
# =============================================================================

# No susceptibility threshold: the at-risk restriction is an area weighting
# (x prop_suscept_total), not a filter. See the header note and
# MIGRATION_PLAN.md 6e.

FILTRO_UF <- NULL     # "PR" = Parana, NULL = all of Brazil

cat("\n", strrep("=", 60), "\n")
cat("07_AGGREGATE_MUNICIPALITY_METRICS.R\n")
cat(strrep("=", 60), "\n")
cat("  Exposure weighting: population x prop_suscept_total (MIGRATION_PLAN.md 6e)\n")
if (!is.null(FILTRO_UF)) {
  cat(sprintf("  *** TEST MODE: UF = %s ***\n", FILTRO_UF))
}

# =============================================================================
# 1) LOAD DATA
# =============================================================================

cat("\n", strrep("=", 60), "\n")
cat("1) LOADING DATA\n")
cat(strrep("=", 60), "\n")

sufixo <- if (!is.null(FILTRO_UF)) paste0("_", FILTRO_UF) else ""
cresc_dir <- file.path(processed_data_dir, "crescimento_urbano")

cat("\nLoading the common grid with growth classification...\n")
t0 <- Sys.time()
grade <- sfarrow::st_read_parquet(
  file.path(cresc_dir, paste0("grade_growth_types_2010_2022", sufixo, ".parquet"))
)
cat(sprintf("  %s cells (%.1f min)\n",
            fmt(nrow(grade)),
            as.numeric(difftime(Sys.time(), t0, units = "mins"))))

sample_df <- readRDS(file.path(processed_data_dir, "amostra_municipios.rds"))

if (!is.null(FILTRO_UF)) {
  uf_codes <- list(
    "RO" = "11", "AC" = "12", "AM" = "13", "RR" = "14", "PA" = "15",
    "AP" = "16", "TO" = "17", "MA" = "21", "PI" = "22", "CE" = "23",
    "RN" = "24", "PB" = "25", "PE" = "26", "AL" = "27", "SE" = "28",
    "BA" = "29", "MG" = "31", "ES" = "32", "RJ" = "33", "SP" = "35",
    "PR" = "41", "SC" = "42", "RS" = "43", "MS" = "50", "MT" = "51",
    "GO" = "52", "DF" = "53"
  )
  cod_uf <- uf_codes[[FILTRO_UF]]
  sample_df <- sample_df %>% filter(substr(cod_mun, 1, 2) == cod_uf)
}

cat(sprintf("Municipalities in the sample: %d\n", nrow(sample_df)))

df <- st_drop_geometry(grade)
rm(grade); gc()

# =============================================================================
# 1b) VALIDATE THE WEIGHT COLUMN
# =============================================================================
# prop_suscept_total is about to be used as a multiplicative weight, so the two
# assumptions that makes are checked here rather than assumed (MIGRATION_PLAN.md
# 6e):
#
#   (i)  it is a proportion in [0, 1] on every cell, with no NAs. Script 03
#        (03_integrate_grid_with_ghsl.R L218-222) already replace_na()s it to 0
#        before script 05 carries it, so an NA or an out-of-range value here
#        means the grid was built by something other than the current chain.
#   (ii) it equals prop_suscept_alta. Since the medium-susceptibility branch was
#        retired (rule 9 / Task 1), prop_suscept_total is a straight alias of
#        prop_suscept_alta -- assigned as `prop_suscept_total = prop_suscept_alta`
#        in BOTH places that build it (03_integrate_grid_with_ghsl.R L221 and
#        05_classify_growth_types.R L153). It is NOT a sum with a medium term
#        and never has been in this chain: read_susceptibility()'s
#        "prop_suscept_medio" branch (03_..._ghsl.R L183) is dead code, called
#        only with sufixo = "alta" (L211).
#        If this check ever fails, prop_suscept_total has stopped being that
#        alias -- STOP and find out what is being added to it before trusting
#        any exposure number below, because a sum of two overlapping
#        susceptibility classes can exceed 1 and would inflate every weighted
#        total.

cat("\nValidating prop_suscept_total as a weight...\n")

n_na_suscept <- sum(is.na(df$prop_suscept_total))
cat(sprintf("  NAs: %s; range: [%.6f, %.6f]\n",
            fmt(n_na_suscept),
            min(df$prop_suscept_total, na.rm = TRUE),
            max(df$prop_suscept_total, na.rm = TRUE)))

# TOL absorbs floating-point noise from stage 02's area ratios (a proportion
# computed as intersection/cell area can land on 1 + 1e-16). It is far too
# small to mask the failure this check exists for: a medium term summed into
# prop_suscept_total would push values toward 2, not past 1 by a rounding unit.
TOL_PROP <- 1e-9

stopifnot(
  "prop_suscept_total has NAs -- it is used as a multiplicative weight" =
    n_na_suscept == 0,
  "prop_suscept_total is outside [0, 1] -- not a proportion" =
    all(df$prop_suscept_total >= -TOL_PROP & df$prop_suscept_total <= 1 + TOL_PROP)
)

if ("prop_suscept_alta" %in% names(df)) {
  max_gap <- max(abs(df$prop_suscept_total - df$prop_suscept_alta), na.rm = TRUE)
  cat(sprintf("  max |prop_suscept_total - prop_suscept_alta|: %.3g\n", max_gap))
  stopifnot(
    "prop_suscept_total != prop_suscept_alta -- see the note above: is a medium term being summed in?" =
      max_gap < 1e-12
  )
  cat("  OK: high-susceptibility only, no medium term.\n")
} else {
  # Not fatal: the alias check is a guard against a medium term reappearing,
  # and the column is absent only if script 05's output schema changed.
  warning("prop_suscept_alta not on the grid -- could not check prop_suscept_total ",
          "against it (MIGRATION_PLAN.md 6e). Verify no medium-susceptibility term ",
          "is being summed into prop_suscept_total before trusting the exposure columns.")
}

# Municipal population totals, both years, ALL cells (urban and non-urban --
# distinct from the growth-type-restricted totals computed below).
pop_mun <- df %>%
  group_by(cod_mun) %>%
  summarise(
    pop_mun_2010 = sum(pop_2010_alocada, na.rm = TRUE),
    pop_mun_2022 = sum(populacao,        na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(delta_pop_mun = pop_mun_2022 - pop_mun_2010)

cat(sprintf("Municipal population available for %d municipalities\n", nrow(pop_mun)))

# =============================================================================
# 2) GROWTH TYPES
# =============================================================================

TIPOS <- c("consolidated", "densification", "infill", "extension", "leapfrog", "peripheral")

# =============================================================================
# 3) MUNICIPALITY-LEVEL METRICS
# =============================================================================

cat("\n", strrep("=", 60), "\n")
cat("3) COMPUTING METRICS\n")
cat(strrep("=", 60), "\n")

# One row per municipality x growth type, filtered to cells urban at the
# given year (col_urbano) and with a valid tipo_crescimento, summing the
# given population column (pop_col). Used identically for the 2022 pass
# (col_urbano = "urbano_2020", pop_col = "populacao") and the 2010 pass
# (col_urbano = "urbano_2010", pop_col = "pop_2010_alocada") -- these two
# passes are the entirety of what the old M2/M4 (population by type) and
# M3/M5 (population by type, in susceptibility) split into, before the
# unification made them the same computation on the same tipo_crescimento.
#
# weight_suscept = TRUE multiplies each cell's population by
# prop_suscept_total before summing (MIGRATION_PLAN.md 6e), giving the
# population living in the high-susceptibility fraction of the cell. The
# cell set is NOT narrowed: the urban and tipo filters are identical in both
# passes, and a cell with prop_suscept_total == 0 contributes 0 on its own.
# This replaces the retired any-overlap rule, which filtered to
# prop_suscept_total > 0 and then summed the cells' FULL population.
agg_pop_by_type <- function(df, col_urbano, pop_col, suffix,
                            weight_suscept = FALSE) {
  d <- df %>% filter(.data[[col_urbano]] == TRUE, tipo_crescimento %in% TIPOS)

  d <- d %>%
    mutate(valor_celula = if (weight_suscept) {
      .data[[pop_col]] * prop_suscept_total
    } else {
      .data[[pop_col]]
    })

  wide <- d %>%
    group_by(cod_mun, tipo_crescimento) %>%
    summarise(valor = sum(valor_celula, na.rm = TRUE), .groups = "drop") %>%
    pivot_wider(
      id_cols     = cod_mun,
      names_from  = tipo_crescimento,
      names_glue  = paste0("pop", suffix, "_{tipo_crescimento}"),
      values_from = valor,
      values_fill = 0
    )

  # ensure every type's column exists even if absent from the data
  faltando <- setdiff(paste0("pop", suffix, "_", TIPOS), names(wide))
  for (col in faltando) wide[[col]] <- 0

  wide
}

# --- n_cel / area_m2 (2022 urban extent only -- unchanged single-grid metric) ---

base_area <- df %>%
  filter(urbano_2020 == TRUE, tipo_crescimento %in% TIPOS) %>%
  group_by(cod_mun, tipo_crescimento) %>%
  summarise(n_cel = n(), area_m2 = sum(area_total, na.rm = TRUE), .groups = "drop") %>%
  pivot_wider(
    id_cols     = cod_mun,
    names_from  = tipo_crescimento,
    values_from = c(n_cel, area_m2),
    values_fill = 0
  )

for (tipo in TIPOS) {
  for (pref in c("n_cel", "area_m2")) {
    col <- paste0(pref, "_", tipo)
    if (!col %in% names(base_area)) base_area[[col]] <- 0
  }
}

# --- pop_2022_<tipo> / pop_2010_<tipo> ---

pop_2022_wide <- agg_pop_by_type(df, "urbano_2020", "populacao",        "_2022")
pop_2010_wide <- agg_pop_by_type(df, "urbano_2010", "pop_2010_alocada", "_2010")

# --- pop_2022_risk_<tipo> / pop_2010_risk_<tipo> (high susceptibility) ---
# Area-weighted: sum(pop x prop_suscept_total). See agg_pop_by_type() above
# and MIGRATION_PLAN.md 6e.

pop_2022_risk_wide <- agg_pop_by_type(df, "urbano_2020", "populacao",        "_2022_risk",
                                      weight_suscept = TRUE)
pop_2010_risk_wide <- agg_pop_by_type(df, "urbano_2010", "pop_2010_alocada", "_2010_risk",
                                      weight_suscept = TRUE)

# --- Join everything ---

metricas <- base_area %>%
  full_join(pop_2022_wide,      by = "cod_mun") %>%
  full_join(pop_2010_wide,      by = "cod_mun") %>%
  full_join(pop_2022_risk_wide, by = "cod_mun") %>%
  full_join(pop_2010_risk_wide, by = "cod_mun") %>%
  left_join(pop_mun, by = "cod_mun")

# Fill NAs introduced by the full_joins (municipality present in one pass,
# absent from another -- e.g. no cells classified in 2010 vs. 2022) with 0
cols_fill <- grep("^(n_cel_|area_m2_|pop_2022_|pop_2010_)", names(metricas), value = TRUE)
for (col in cols_fill) metricas[[col]] <- replace_na(metricas[[col]], 0)

# --- Totals across the 6 types + urban growth share ---

metricas <- metricas %>%
  mutate(
    area_urban_2022_m2 = area_m2_consolidated + area_m2_densification +
                         area_m2_infill + area_m2_extension +
                         area_m2_leapfrog + area_m2_peripheral,
    pct_urban_growth = ifelse(area_urban_2022_m2 > 0,
                              (area_m2_infill + area_m2_extension + area_m2_leapfrog) /
                                area_urban_2022_m2,
                              NA_real_),

    pop_2022_total      = pop_2022_consolidated + pop_2022_densification +
                          pop_2022_infill + pop_2022_extension +
                          pop_2022_leapfrog + pop_2022_peripheral,
    pop_2010_total      = pop_2010_consolidated + pop_2010_densification +
                          pop_2010_infill + pop_2010_extension +
                          pop_2010_leapfrog + pop_2010_peripheral,
    pop_2022_risk_total = pop_2022_risk_consolidated + pop_2022_risk_densification +
                          pop_2022_risk_infill + pop_2022_risk_extension +
                          pop_2022_risk_leapfrog + pop_2022_risk_peripheral,
    pop_2010_risk_total = pop_2010_risk_consolidated + pop_2010_risk_densification +
                          pop_2010_risk_infill + pop_2010_risk_extension +
                          pop_2010_risk_leapfrog + pop_2010_risk_peripheral,

    delta_pop_total      = pop_2022_total      - pop_2010_total,
    delta_pop_risk_total = pop_2022_risk_total - pop_2010_risk_total,
    pct_growth_pop_risk  = ifelse(pop_2010_risk_total > 0,
                                  100 * delta_pop_risk_total / pop_2010_risk_total,
                                  NA_real_)
  )

cat(sprintf("  Municipalities with metrics: %d\n", nrow(metricas)))
cat(sprintf("  Municipalities with non-zero at-risk population (2022): %d\n",
            sum(metricas$pop_2022_risk_total > 0, na.rm = TRUE)))
cat(sprintf("  Total pop_2022 : %s\n", fmt(sum(metricas$pop_2022_total, na.rm = TRUE))))
cat(sprintf("  Total pop_2010 : %s\n", fmt(sum(metricas$pop_2010_total, na.rm = TRUE))))
cat(sprintf("  Total pop_2022_risk : %s\n", fmt(sum(metricas$pop_2022_risk_total, na.rm = TRUE))))
cat(sprintf("  Total pop_2010_risk : %s\n", fmt(sum(metricas$pop_2010_risk_total, na.rm = TRUE))))

# =============================================================================
# 4) AGGREGATE TO POPULATION ARRANGEMENTS
# =============================================================================

cat("\n", strrep("=", 60), "\n")
cat("4) AGGREGATING TO ARRANGEMENTS\n")
cat(strrep("=", 60), "\n")

# The arrangement rule is ASYMMETRIC, deliberately (MIGRATION_PLAN.md 6f.2,
# decided 2026-09-13). The two column groups aggregate over different member
# sets, and the split is stated here rather than left implicit in the join:
#
#   COLS_FORM  -- urban-form metrics, summed over ALL member municipalities.
#                 The footprint is metropolitan: an unmapped member's built-up
#                 area is still part of the arrangement's urban form.
#
#   COLS_POP   -- population and exposure totals, summed over members with
#                 MAPPED SUSCEPTIBILITY ONLY. An unmapped member contributes
#                 zero to the numerator by construction (no susceptibility
#                 layer exists there), so counting it in the denominator
#                 dilutes the share instead of measuring anything.
#
# Everything derived below inherits its group from its inputs: area_urban_2022_m2
# and pct_urban_growth are form; pop_*_total, pop_*_risk_total, delta_pop_*,
# pct_growth_pop_risk are population -- as are the downstream pp_alta_*,
# delta_pp_alta, g_alta, pop_fora_alta_* and g_fora_alta in stage 04.
#
# pop_mun_* is classified as population (it is municipal population over all
# cells). See 6f.2 for the two items flagged rather than silently classified:
# pop_mun_* itself, and the cross-group density control that this rule
# necessarily creates for mixed arrangements (mapped-only pop_urbana_2010_cg
# over an all-members area_urbana_2010_m2 in stage 04's prep()).
COLS_FORM <- grep("^(n_cel_|area_m2_)", names(metricas), value = TRUE)
COLS_POP  <- grep("^(pop_2022_|pop_2010_|pop_mun_)", names(metricas), value = TRUE)

unclassified <- setdiff(
  grep("^(n_cel_|area_m2_|pop_2022_|pop_2010_|pop_mun_)", names(metricas), value = TRUE),
  c(COLS_FORM, COLS_POP)
)
if (length(unclassified) > 0)
  stop("Columns matched the aggregate set but fall in neither group -- classify them ",
       "explicitly rather than letting them default:\n  ",
       paste(unclassified, collapse = ", "))

cat(sprintf("\n  Urban-form columns (ALL members)          : %d\n", length(COLS_FORM)))
cat(sprintf("  Population/exposure columns (mapped only): %d\n", length(COLS_POP)))

arr_base <- metricas %>%
  left_join(
    sample_df %>% select(cod_mun, CD_CIDADE, tem_susceptibilidade) %>% distinct(),
    by = "cod_mun"
  ) %>%
  mutate(
    cod_mun_d = as.double(cod_mun),
    CD_CIDADE = if_else(is.na(CD_CIDADE), cod_mun_d, CD_CIDADE),
    mapped    = coalesce(tem_susceptibilidade, FALSE)
  ) %>%
  select(-cod_mun_d)

n_unmapped_members <- sum(!arr_base$mapped)
cat(sprintf("  Member municipalities without mapped susceptibility: %d of %d\n",
            n_unmapped_members, nrow(arr_base)))

# A municipality present in metricas but absent from sample_df has no
# tem_susceptibilidade value at all -- it is unclassifiable, not unmapped, and
# coalesce() above would silently drop its population from every arrangement
# total. Report it rather than let that happen quietly. Expected to be empty:
# the grid is built from the sample.
sem_registro <- arr_base %>% filter(is.na(tem_susceptibilidade))
if (nrow(sem_registro) > 0) {
  cat(sprintf("\n  *** %d municipality(ies) in metricas are absent from sample_df, so they\n",
              nrow(sem_registro)))
  cat("      carry no tem_susceptibilidade value. They are treated as UNMAPPED below,\n")
  cat("      which removes their population from their arrangement's totals. Verify\n")
  cat("      this is intended before trusting the arrangement file:\n")
  print(sem_registro %>%
          select(any_of(c("cod_mun", "CD_CIDADE", "pop_mun_2010", "pop_mun_2022",
                          "pop_2010_total", "pop_2022_total"))), n = 50)
}

metricas_arr <- arr_base %>%
  group_by(CD_CIDADE) %>%
  summarise(
    n_members  = n(),
    n_unmapped = sum(!mapped),
    # urban form: ALL members
    across(all_of(COLS_FORM), ~ sum(.x, na.rm = TRUE)),
    # population / exposure: mapped members only
    across(all_of(COLS_POP),  ~ sum(.x[mapped], na.rm = TRUE)),
    # Density denominator, mapped members only (6f.2, decided 2026-09-14).
    # area_m2_* themselves stay all-members -- they are urban form, and the
    # pct_area_* shares built from them must describe the whole metropolitan
    # footprint. But the density control pairs an area with a POPULATION, and
    # that population is now mapped-only, so its denominator has to match or
    # the ratio spans the two groups. This is an ADDITIONAL column: nothing
    # that already existed changes, so the all-members footprint metrics and
    # the municipality-level file are untouched.
    area_urbana_2010_m2_mapped =
      sum(area_m2_consolidated[mapped],  na.rm = TRUE) +
      sum(area_m2_densification[mapped], na.rm = TRUE) +
      sum(area_m2_peripheral[mapped],    na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(
    delta_pop_mun = pop_mun_2022 - pop_mun_2010,

    area_urban_2022_m2 = area_m2_consolidated + area_m2_densification +
                         area_m2_infill + area_m2_extension +
                         area_m2_leapfrog + area_m2_peripheral,
    pct_urban_growth = ifelse(area_urban_2022_m2 > 0,
                              (area_m2_infill + area_m2_extension + area_m2_leapfrog) /
                                area_urban_2022_m2,
                              NA_real_),

    pop_2022_total      = pop_2022_consolidated + pop_2022_densification +
                          pop_2022_infill + pop_2022_extension +
                          pop_2022_leapfrog + pop_2022_peripheral,
    pop_2010_total      = pop_2010_consolidated + pop_2010_densification +
                          pop_2010_infill + pop_2010_extension +
                          pop_2010_leapfrog + pop_2010_peripheral,
    pop_2022_risk_total = pop_2022_risk_consolidated + pop_2022_risk_densification +
                          pop_2022_risk_infill + pop_2022_risk_extension +
                          pop_2022_risk_leapfrog + pop_2022_risk_peripheral,
    pop_2010_risk_total = pop_2010_risk_consolidated + pop_2010_risk_densification +
                          pop_2010_risk_infill + pop_2010_risk_extension +
                          pop_2010_risk_leapfrog + pop_2010_risk_peripheral,

    delta_pop_total      = pop_2022_total      - pop_2010_total,
    delta_pop_risk_total = pop_2022_risk_total - pop_2010_risk_total,
    pct_growth_pop_risk  = ifelse(pop_2010_risk_total > 0,
                                  100 * delta_pop_risk_total / pop_2010_risk_total,
                                  NA_real_)
  )

cat(sprintf("  Arrangements with metrics: %d\n", nrow(metricas_arr)))

# =============================================================================
# 5) SAVE
# =============================================================================

cat("\n", strrep("=", 60), "\n")
cat("5) SAVING\n")
cat(strrep("=", 60), "\n")

dir_metr <- file.path(processed_data_dir, "metricas")
dir.create(dir_metr, recursive = TRUE, showWarnings = FALSE)

mun_path <- file.path(dir_metr, paste0("metricas_municipio_2010_2022", sufixo, ".csv"))
write_csv(metricas, mun_path)
cat(sprintf("  - %s  (%d rows x %d cols)\n", basename(mun_path), nrow(metricas), ncol(metricas)))

arr_path <- file.path(dir_metr, paste0("metricas_arranjo_2010_2022", sufixo, ".csv"))
write_csv(metricas_arr, arr_path)
cat(sprintf("  - %s  (%d rows x %d cols)\n", basename(arr_path), nrow(metricas_arr), ncol(metricas_arr)))

cat("\n", strrep("=", 60), "\n")
cat("DONE\n")
cat(strrep("=", 60), "\n")
cat("\nSchema (per growth type: consolidated/densification/infill/extension/leapfrog/peripheral):\n")
cat("  n_cel_<type>, area_m2_<type>              : cells / area, 2022 urban extent\n")
cat("  pop_2022_<type>, pop_2010_<type>           : population by type, both years\n")
cat("  pop_2022_risk_<type>, pop_2010_risk_<type> : same, x prop_suscept_total (6e)\n")
cat("  pop_2022_total, pop_2010_total, pop_2022_risk_total, pop_2010_risk_total\n")
cat("  delta_pop_total, delta_pop_risk_total, pct_growth_pop_risk\n")
cat("  pct_urban_growth, area_urban_2022_m2\n")
cat("\nFiles ready for 13_dependent_variables.R\n")
