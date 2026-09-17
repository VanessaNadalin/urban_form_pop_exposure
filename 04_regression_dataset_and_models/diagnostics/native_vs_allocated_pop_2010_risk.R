# =============================================================================
# diagnostics/native_vs_allocated_pop_2010_risk.R
#
# DIAGNOSTIC -- not part of the pipeline (not in 00_run_all.R). Read-only with
# respect to the pipeline: it writes only under
# data/processed_data/04_regression/diagnostics/ and never overwrites anything
# 13/15/16_*.R produce. It does not update any target or manuscript number.
#
# QUESTION
# --------
# Stage 03 builds pop_2010_risk_total from pop_2010_alocada -- the 2010 census
# population allocated onto the 2022 grid in proportion to GHSL 2010 built-up.
# Stage 02 already computes a 2010 at-risk population directly on the NATIVE
# 2010 statistical grid (pop_suscept_alta_2010 in
# resumo_municipal_suscept_alta_agsn.csv). This script asks:
#   (a) how far apart the two are, per municipality and where;
#   (b) which of the two the pre-Migrate regression dataset used;
#   (c) what Table 2 looks like if the 2010 side of the dependent variables
#       comes from the native grid instead of the allocation.
#
# The hypothesis under test is directional: if GHSL 2010 under-detects built-up
# where exposure actually concentrates (informal, steep, vegetated), the
# allocation moves 2010 population OUT of susceptibility zones, so the
# allocated series should sit BELOW the native one, and the gap should widen
# with slum share and steep terrain. The script therefore reports the SIGN of
# the difference everywhere, never just its magnitude.
#
# STEP 0 -- DEFINITIONS, ESTABLISHED FROM THE SOURCE BEFORE ANY COMPARISON
# -----------------------------------------------------------------------
# These were read off the two scripts (line numbers as of this commit) and are
# re-printed at run time by report_definitions() below. They matter because the
# two published columns are NOT the same estimand, so differencing them
# directly measures three things at once, not one.
#
# Stage 03 -- 03_urban_footprint_and_growth_types/07_aggregate_municipality_metrics.R
#   *** As of 2026-09-11 (MIGRATION_PLAN.md 6e) script 07 no longer works this
#       way: it now computes sum(pop x prop_suscept_total) and LIMIAR_SUSCEPT is
#       gone. The description below is the rule as it stood when this diagnostic
#       was written, and is what the July draft's published numbers were
#       computed under -- which is exactly why steps 1-3 still reconstruct it.
#       Step 0W (added 2026-09-12) checks the CORRECTED script 07 against an
#       independent reconstruction of the new rule, risk_C_weighted. ***
#   * L51   LIMIAR_SUSCEPT <- 0, commented "> 0 = any overlap".
#   * L140-147 agg_pop_by_type(): filters cells to
#       .data[[col_urbano]] == TRUE AND tipo_crescimento %in% TIPOS, then
#       (restrict_suscept = TRUE) to prop_suscept_total > 0, and SUMS THE FULL
#       CELL POPULATION -- sum(.data[[pop_col]]). There is no multiplication by
#       prop_suscept_total anywhere.
#     => UNWEIGHTED: every person in a cell with ANY susceptibility overlap
#        counts in full. NOT population x prop_suscept.
#   * L186-193 the 2010 pass uses col_urbano = "urbano_2010" and
#       pop_col = "pop_2010_alocada"; the 2022 pass uses "urbano_2020" and
#       "populacao".
#     => the 2010 side is restricted to cells urban in 2010, NOT in 2022; each
#        year is filtered by its own urban extent. Both sides additionally
#        require a non-NA tipo_crescimento among the 6 TIPOS.
#   * L224/L230 pop_2010_total and pop_2010_risk_total are both sums over those
#       same 6 growth types, so the pipeline's pp_alta_2010 (13_dependent_
#       variables.R L96) has an urban-restricted numerator AND denominator.
#       Note pop_2010_total is NOT the municipal total pop_mun_2010 of L108.
#
# Stage 02 -- 02_population_in_hazard_zones/03_cross_grid_high_susceptibility.py
#   * L391/L403 resumo_municipal(): pop_suscept = populacao * prop_suscept,
#       summed by cod_mun_suscept.
#     => AREA-WEIGHTED: population times the fraction of the cell covered by
#        high susceptibility.
#   * L383 the only row filter is a non-empty cod_mun_suscept. There is no
#       urban filter and no growth-type filter.
#   * L336/L256-258 montar_grade() keeps every cell of each municipality
#       (celulas_mun_*), with prop_suscept = 0 off the hazard layer, so
#       pop_total_alta_2010 in the resumo is the WHOLE-MUNICIPALITY population
#       on the native 2010 grid, urban and rural alike.
#
# So the two published columns differ in THREE ways at once:
#   (1) weighting     -- x prop_suscept (stage 02) vs. full cell (stage 03);
#   (2) urban filter  -- none (stage 02) vs. urbano_<year> & tipo_crescimento
#                        (stage 03);
#   (3) grid          -- native 2010 grid vs. allocation onto the 2022 grid.
# (1) makes stage 03 LARGER and (2) makes it SMALLER, so they partly cancel and
# a raw difference of the two published columns is uninterpretable. Only (3) is
# the question asked. This script therefore rebuilds BOTH sides from the
# cell-level files under matched definitions, so that (3) is the only surviving
# difference, and reports (1) and (2) separately as a decomposition.
#
# Like-for-like variants built below, each computed on BOTH sides:
#   A_weighted_all  : sum(pop * prop_suscept), all cells        -- stage 02's rule
#   B_anyoverlap_all: sum(pop) where prop_suscept > 0, all cells -- stage 03's
#                     weighting rule, without stage 03's urban filter
#   C_pipeline      : stage 03's published definition (urban + tipo filtered);
#                     has no native counterpart, since the native 2010 grid
#                     carries no urban classification and no tipo_crescimento
#                     (those live only on the 2022 common grid). Reported as
#                     the pipeline's own number and used to size filter effect
#                     (2) as C vs. B on the allocated side.
#
# CONTROL: the same variants on the 2022 side. Stage 03's common grid IS the
# 2022 geometry and its "populacao" IS the native 2022 census population, so
# A and B must agree between stage 02 and stage 03 in 2022 to within rounding/
# coverage. If the 2022 control does NOT line up, the 2010 comparison below is
# not trustworthy and the run says so rather than reporting a difference.
#
# Requires:
#   data/processed_data/02_hazard_zones/resumo_municipal_suscept_alta_agsn.csv
#   data/processed_data/02_hazard_zones/grade_2010_BR_com_suscept_alta_agsn.gpkg
#   data/processed_data/02_hazard_zones/grade_2022_BR_com_suscept_alta_agsn.gpkg
#   data/processed_data/03_urban_footprint/crescimento_urbano/
#       grade_growth_types_2010_2022.parquet
#   data/processed_data/04_regression/tables/dataset_regressao_municipio.csv
#   regression2/data/tabelas/dataset_regressao_municipio.csv   (step 2, optional)
#
# Run from the repository root:
#   source("04_regression_dataset_and_models/diagnostics/native_vs_allocated_pop_2010_risk.R")
# =============================================================================

source("04_regression_dataset_and_models/00_setup.R")

for (pkg in c("lmtest", "sandwich", "purrr", "tibble")) {
  if (!requireNamespace(pkg, quietly = TRUE)) install.packages(pkg)
  library(pkg, character.only = TRUE)
}

options(width = 200, pillar.sigfig = 6)

# Outputs live in their own diagnostics/ folder under this stage's processed
# data, per the brief -- NOT in tables/, so nothing here can be mistaken for a
# pipeline table.
diag_dir <- file.path(data_dir, "diagnostics")
dir.create(diag_dir, recursive = TRUE, showWarnings = FALSE)

save_csv <- function(df, name) {
  path <- file.path(diag_dir, name)
  write_csv(df, path)
  cat(sprintf("  saved: %s\n", path))
  invisible(path)
}

cat("\n", strrep("=", 78), "\n")
cat("NATIVE 2010 GRID vs. ALLOCATED-ONTO-2022 GRID -- 2010 AT-RISK POPULATION\n")
cat(strrep("=", 78), "\n")

# =============================================================================
# STEP 0 -- DEFINITIONS
# =============================================================================

report_definitions <- function() {
  cat("\n", strrep("=", 78), "\n")
  cat("STEP 0 -- DEFINITIONS READ FROM SOURCE (see header for line references)\n")
  cat(strrep("=", 78), "\n")
  cat("
Stage 03  pop_2010_risk_total / pop_2022_risk_total
  weighting : AREA-WEIGHTED since 2026-09-11 -- sum(pop x prop_suscept_total),
              the same convention as stage 02 below (MIGRATION_PLAN.md 6e).
              LIMIAR_SUSCEPT no longer exists in script 07.
              *** Until 2026-09-11 it was UNWEIGHTED: the full population of
              every cell with prop_suscept_total > 0. Steps 1-3 of this script
              reconstruct THAT rule (variants B and C_anyoverlap), because the
              question they answer -- native vs. allocated in the July draft's
              numbers -- is a question about the draft, which was computed
              under it. Step 0W checks the CURRENT rule instead. ***
  urban     : cells urban IN THEIR OWN YEAR -- urbano_2010 for the 2010 side,
              urbano_2020 for the 2022 side -- AND tipo_crescimento among the
              6 TIPOS (L140, L186-193)
  pop col   : pop_2010_alocada (2010 side) / populacao (2022 side)
  denominator for pp_alta_2010: pop_2010_total, the SAME urban+tipo restricted
              sum (L224), not the municipal total pop_mun_2010 (L108)

Stage 02  pop_suscept_alta_2010 / pop_suscept_alta_2022 (resumo CSV)
  weighting : AREA-WEIGHTED, populacao * prop_suscept
              (03_cross_grid_high_susceptibility.py L391, L401-403)
  urban     : NONE. No growth-type filter either.
  scope     : the WHOLE municipality -- montar_grade() keeps every cell of each
              municipality with prop_suscept = 0 off the hazard layer
              (L336, L256-258); the only row filter is a non-empty
              cod_mun_suscept (L383)

=> Three differences at once: weighting, urban filter, and grid. Weighting
   pushes stage 03 UP; the urban filter pushes it DOWN; they partly cancel.
   Differencing the two published columns therefore does NOT measure the grid
   question. Variants A/B below match definitions so the grid is the only
   remaining difference; C_anyoverlap is stage 03's rule AS OF THE DRAFT.

*** READ THIS BEFORE STEPS 1-3 (6e, 2026-09-11) ***
   Steps 1-3 were written when the live pipeline was any-overlap, and they
   read pop_2010_risk_total straight from dataset_regressao_municipio.csv.
   That column is now AREA-WEIGHTED, while C_native is still the any-overlap
   reconstruction. So wherever steps 1-3 place the live column beside
   C_native -- the "dropped by the > 1000 cut" table, the g_alta extremes
   comparison, and step 3's C_native variant -- the two sides now differ in
   BOTH weighting and grid, and the difference can no longer be read as the
   allocation's doing. Those specific comparisons are NOT like-for-like until
   a weighted native counterpart is built. The native-vs-allocated conclusion
   itself is unaffected: variant A is weighted on both sides and puts the
   grid effect at -0.16% on the 395 both-grids municipalities.
   Step 0W is self-contained -- both its sides are weighted -- and stands.
")
}
report_definitions()

# --- Cell-level readers ------------------------------------------------------

# Native grids: read only the flat columns needed, via an OGR SQL query, so
# GDAL never parses the national grid's polygon geometry -- the same idiom
# 12_slum_growth.R uses. st_read() returns a plain data.frame (no sf class)
# whenever the query's column list omits the geometry column.
read_native_grid <- function(path) {
  layer <- sf::st_layers(path)$name[1]
  query <- sprintf(
    'SELECT "cod_mun_suscept" AS cod_mun, "populacao" AS populacao, "prop_suscept" AS prop_suscept FROM "%s"',
    layer
  )
  sf::st_read(path, query = query, quiet = TRUE) %>%
    filter(!is.na(cod_mun), cod_mun != "") %>%
    mutate(
      cod_mun      = as.double(cod_mun),
      populacao    = as.numeric(populacao),
      prop_suscept = coalesce(as.numeric(prop_suscept), 0)
    )
}

# Common grid: the parquet is a geoparquet written by sfarrow, but the flat
# columns can be pulled with arrow::read_parquet(col_select = ...) without
# materialising the geometry -- same motivation as the OGR query above.
read_common_grid <- function(path) {
  arrow::read_parquet(
    path,
    col_select = all_of(c("cod_mun", "populacao", "pop_2010_alocada",
                          "prop_suscept_total", "urbano_2010", "urbano_2020",
                          "tipo_crescimento"))
  ) %>%
    mutate(
      cod_mun            = as.double(cod_mun),
      populacao          = coalesce(as.numeric(populacao), 0),
      pop_2010_alocada   = coalesce(as.numeric(pop_2010_alocada), 0),
      prop_suscept_total = coalesce(as.numeric(prop_suscept_total), 0)
    )
}

# TIPOS must match 07_aggregate_municipality_metrics.R L120 exactly.
TIPOS <- c("consolidated", "densification", "infill", "extension", "leapfrog",
           "peripheral")
# The RETIRED any-overlap threshold. Until 2026-09-11 this mirrored
# 07_aggregate_municipality_metrics.R's own LIMIAR_SUSCEPT; script 07 no longer
# has one (MIGRATION_PLAN.md 6e removed it in favour of area weighting). It is
# kept here on purpose: variants B and C_anyoverlap reconstruct the rule the
# July draft's numbers were computed under, which is what steps 1-3 study.
# Do NOT read it as the pipeline's current rule -- risk_C_weighted is that.
LIMIAR_SUSCEPT <- 0

path_native_10 <- file.path(stage02_data_dir, "grade_2010_BR_com_suscept_alta_agsn.gpkg")
path_native_22 <- file.path(stage02_data_dir, "grade_2022_BR_com_suscept_alta_agsn.gpkg")
path_resumo    <- file.path(stage02_data_dir, "resumo_municipal_suscept_alta_agsn.csv")
path_common    <- file.path(stage03_data_dir, "crescimento_urbano",
                            "grade_growth_types_2010_2022.parquet")
# Native 2010 grid with its own census population, GHSL 2010 built-up and cell
# area -- script 03's output, unchanged by the 6b0 rework. This is what makes a
# native counterpart of definition C reconstructible.
path_ibge_2010 <- file.path(stage03_data_dir, "grade_ibge_2010.parquet")
# Script 04's output, carrying the authoritative urbano_2010 column. Used only
# to verify that the urban rule reconstructed below reproduces it exactly.
path_urbform   <- file.path(stage03_data_dir, "grade_urban_form_2010_2022.parquet")
path_new_ds    <- file.path(tables_dir, "dataset_regressao_municipio.csv")

# --- Aggregate cache ---------------------------------------------------------
# Reading the three cell-level grids takes minutes (10M+ cells) and steps 1-3
# only ever need the per-municipality aggregates. Those are cached on the first
# run and reused afterwards, so a fix anywhere downstream can be re-run in
# seconds. To force a fresh read of the grids, either delete the two cache
# files below or set options(nva.force_reread = TRUE) before sourcing.
cache_cmp10 <- file.path(diag_dir, "municipality_native_vs_allocated_2010.csv")
cache_nat22 <- file.path(diag_dir, "cache_native_2022_series.csv")
cache_checks <- file.path(diag_dir, "cache_c_native_checks.csv")
# Added 2026-09-12 with risk_C_weighted (step 0W): per-municipality C series for
# BOTH years on the allocated side. Listing it in USE_CACHE self-invalidates any
# cache written before step 0W existed -- those files have no C_weighted column,
# so a stale cache silently skipping the new check is not possible.
cache_cw    <- file.path(diag_dir, "cache_allocated_c_series.csv")
USE_CACHE   <- file.exists(cache_cmp10) && file.exists(cache_nat22) &&
  file.exists(cache_checks) && file.exists(cache_cw) &&
  !isTRUE(getOption("nva.force_reread"))

# The regression dataset is needed either way; the grids only on a fresh read.
needed <- path_new_ds
if (!USE_CACHE)
  needed <- c(path_native_10, path_native_22, path_resumo, path_common,
              path_ibge_2010, path_urbform, path_new_ds)
missing <- needed[!file.exists(needed)]
if (length(missing) > 0) {
  for (f in missing) cat(sprintf("  MISSING: %s\n", f))
  stop("Required inputs not found -- see the Requires block in this script's header.")
}

if (!USE_CACHE) {

cat("\nReading cell-level grids (this is the slow part)...\n")
native_10 <- read_native_grid(path_native_10)
cat(sprintf("  native 2010 grid: %s cells\n", fmt(nrow(native_10))))
native_22 <- read_native_grid(path_native_22)
cat(sprintf("  native 2022 grid: %s cells\n", fmt(nrow(native_22))))
common <- read_common_grid(path_common)
cat(sprintf("  common grid     : %s cells\n", fmt(nrow(common))))

# --- Variant builders --------------------------------------------------------

# A and B on the native side, for one year.
agg_native <- function(df) {
  df %>%
    group_by(cod_mun) %>%
    summarise(
      risk_A_weighted   = sum(populacao * prop_suscept, na.rm = TRUE),
      risk_B_anyoverlap = sum(populacao * (prop_suscept > LIMIAR_SUSCEPT), na.rm = TRUE),
      total_all_cells   = sum(populacao, na.rm = TRUE),
      .groups = "drop"
    )
}

# A, B and C on the common-grid (allocated) side, for one year. pop_col and
# col_urbano are the year's own columns, matching stage 03's two passes.
agg_common <- function(df, pop_col, col_urbano) {
  all_cells <- df %>%
    group_by(cod_mun) %>%
    summarise(
      risk_A_weighted   = sum(.data[[pop_col]] * prop_suscept_total, na.rm = TRUE),
      risk_B_anyoverlap = sum(.data[[pop_col]] * (prop_suscept_total > LIMIAR_SUSCEPT),
                              na.rm = TRUE),
      total_all_cells   = sum(.data[[pop_col]], na.rm = TRUE),
      .groups = "drop"
    )

  # C: stage 03's definition, rebuilt here rather than read from
  # metricas_municipio_2010_2022.csv, so the urban-filter effect (C vs B) is
  # measured on exactly the same cells as A and B.
  #
  # TWO C series, same cell set, differing only in the weighting:
  #   risk_C_anyoverlap -- the RETIRED rule (full cell population wherever
  #                        prop_suscept_total > 0). Kept because steps 1-3 of
  #                        this script are a native-vs-allocated study of the
  #                        numbers as they stood in the July draft, which were
  #                        computed under it (MIGRATION_PLAN.md 6e provenance).
  #   risk_C_weighted   -- the CURRENT rule (sum(pop x prop_suscept_total)),
  #                        added 2026-09-12 as an INDEPENDENT reconstruction of
  #                        what 07_aggregate_municipality_metrics.R now
  #                        computes. It shares no code with script 07: same
  #                        definition, arrived at separately, from the
  #                        cell-level parquet, in this script's own idiom.
  #                        Step 0W below checks the two against each other.
  pipeline <- df %>%
    filter(.data[[col_urbano]] == TRUE, tipo_crescimento %in% TIPOS) %>%
    group_by(cod_mun) %>%
    summarise(
      risk_C_pipeline  = sum(.data[[pop_col]] * (prop_suscept_total > LIMIAR_SUSCEPT),
                             na.rm = TRUE),
      risk_C_weighted  = sum(.data[[pop_col]] * prop_suscept_total, na.rm = TRUE),
      total_C_pipeline = sum(.data[[pop_col]], na.rm = TRUE),
      .groups = "drop"
    )

  all_cells %>% full_join(pipeline, by = "cod_mun") %>%
    mutate(across(where(is.numeric), ~coalesce(., 0)))
}

# on_native / on_common record COVERAGE -- whether the municipality appears on
# that grid at all. Without them the full_join below turns "this municipality is
# not on the common grid" into an allocated value of 0, which then reads as a
# -100% grid effect. That is a coverage difference, not an allocation effect,
# and the two must not be added together.
# =============================================================================
# C_native -- a native-grid counterpart of stage 03's published definition
# =============================================================================
# Definition C (unweighted, prop_suscept_total > 0, restricted to cells urban in
# the year and carrying a tipo_crescimento label) has no native counterpart in
# the files as they stand, because the native 2010 grid carries no urban
# classification. It is reconstructible: grade_ibge_2010.parquet carries native
# 2010 populacao, built_pct_2010, area_total and the susceptibility columns, so
# script 04's urban rule can be re-applied to it.
#
# The rule is copied from 03_urban_footprint_and_growth_types/04_delimit_urban_extent.R:
#   LIMIAR_BUILT <- 10   (L49)  -- built-up % of the cell
#   LIMIAR_DENS  <- 300  (L54)  -- inhabitants / km2
#   classificar_urbano(built_pct, populacao, area_total_m2, lim_built, lim_dens)
#                        (L60-68): dens <- populacao / (area_total_m2 / 1e6);
#                        urban = built_pct >= lim_built AND dens >= lim_dens,
#                        with NA in either treated as not urban.
#   applied at L95 (urbano_2010, from built_pct_2010 + pop_2010_alocada).
# Density is per cell and per km2, so the 2010 grid's mixed 200m / 1km cell
# sizes are handled exactly as script 04 handles the common grid's.
LIMIAR_BUILT <- 10   # 04_delimit_urban_extent.R L49
LIMIAR_DENS  <- 300  # 04_delimit_urban_extent.R L54

classificar_urbano <- function(built_pct, populacao, area_total_m2,
                               lim_built, lim_dens) {
  dens <- populacao / (area_total_m2 / 1e6)
  !is.na(built_pct) & built_pct >= lim_built &
    !is.na(dens) & dens >= lim_dens
}

nat10 <- agg_native(native_10) %>% rename_with(~paste0(., "_nat"), -cod_mun) %>%
  mutate(on_native = TRUE)
nat22 <- agg_native(native_22) %>% rename_with(~paste0(., "_nat"), -cod_mun)
alo10 <- agg_common(common, "pop_2010_alocada", "urbano_2010") %>%
  rename_with(~paste0(., "_alo"), -cod_mun) %>%
  mutate(on_common = TRUE)
alo22 <- agg_common(common, "populacao", "urbano_2020") %>%
  rename_with(~paste0(., "_alo"), -cod_mun)

# --- VERIFICATION 1: does the reconstructed urban rule reproduce urbano_2010? -
# Re-apply classificar_urbano() to the SAME inputs script 04 used, on the same
# common grid, and compare against the stored column. Same rule and same inputs,
# so it must match exactly. A mismatch means the reconstruction is wrong and
# C_native must not be reported.

cat("\n", strrep("=", 78), "\n")
cat("C_NATIVE VERIFICATION 1 -- urban rule reconstruction\n")
cat(strrep("=", 78), "\n")

urbform <- arrow::read_parquet(
  path_urbform,
  col_select = all_of(c("cod_mun", "pop_2010_alocada", "area_total",
                        "built_pct_2010", "urbano_2010"))
)
urbform <- urbform %>%
  mutate(urbano_2010_recomputed = classificar_urbano(built_pct_2010,
                                                     pop_2010_alocada,
                                                     area_total,
                                                     LIMIAR_BUILT, LIMIAR_DENS),
         urbano_2010_stored = as.logical(urbano_2010))

n_mismatch <- sum(urbform$urbano_2010_recomputed != urbform$urbano_2010_stored, na.rm = TRUE)
n_na_cmp   <- sum(is.na(urbform$urbano_2010_stored))
cat(sprintf("Cells compared        : %s\n", fmt(nrow(urbform))))
cat(sprintf("Stored urbano_2010 NA : %s\n", fmt(n_na_cmp)))
cat(sprintf("Mismatching cells     : %s (%.6f%%)\n",
            fmt(n_mismatch), 100 * n_mismatch / pmax(nrow(urbform), 1)))

URBAN_RULE_OK <- (n_mismatch == 0)
if (URBAN_RULE_OK) {
  cat("MATCH: the reconstruction reproduces urbano_2010 exactly. C_native is valid.\n")
} else {
  cat("*** MISMATCH: the reconstructed rule does NOT reproduce urbano_2010.\n")
  cat("    C_native is NOT reported below -- the reconstruction is wrong, and any\n")
  cat("    C_allocated vs C_native gap would be an artifact of that, not a grid effect.\n")
}
rm(urbform); gc()

# --- VERIFICATION 2: is the tipo_crescimento filter binding on the 2010 side? -
# Definition C filters on urbano_2010 AND a non-NA tipo_crescimento. C_native
# can only reproduce the urban half (the native grid has no growth types), so
# the second filter has to be shown non-binding before C_native can be called a
# true counterpart of C_allocated.

cat("\n", strrep("=", 78), "\n")
cat("C_NATIVE VERIFICATION 2 -- is the tipo_crescimento filter binding in 2010?\n")
cat(strrep("=", 78), "\n")

urb10 <- common %>% filter(urbano_2010 == TRUE)
no_tipo <- urb10 %>% filter(is.na(tipo_crescimento) | !(tipo_crescimento %in% TIPOS))
share_cells <- nrow(no_tipo) / pmax(nrow(urb10), 1)
share_pop   <- sum(no_tipo$pop_2010_alocada, na.rm = TRUE) /
  pmax(sum(urb10$pop_2010_alocada, na.rm = TRUE), 1)

cat(sprintf("Urban-2010 cells                        : %s\n", fmt(nrow(urb10))))
cat(sprintf("  of which without a growth-type label  : %s (%.4f%% of cells)\n",
            fmt(nrow(no_tipo)), 100 * share_cells))
cat(sprintf("Urban-2010 population                   : %s\n",
            fmt(round(sum(urb10$pop_2010_alocada, na.rm = TRUE)))))
cat(sprintf("  of which without a growth-type label  : %s (%.4f%% of population)\n",
            fmt(round(sum(no_tipo$pop_2010_alocada, na.rm = TRUE))), 100 * share_pop))

tipo_by_mun <- urb10 %>%
  group_by(cod_mun) %>%
  summarise(
    pop_urb10        = sum(pop_2010_alocada, na.rm = TRUE),
    pop_urb10_notipo = sum(pop_2010_alocada[is.na(tipo_crescimento) |
                                              !(tipo_crescimento %in% TIPOS)], na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(share_notipo = pop_urb10_notipo / pmax(pop_urb10, 1))

cat("\nPer-municipality share of urban-2010 population without a growth type:\n")
print(round(quantile(tipo_by_mun$share_notipo, c(0.5, 0.9, 0.95, 0.99, 1), na.rm = TRUE), 6))
cat(sprintf("Municipalities where it exceeds 1%%: %d of %d\n",
            sum(tipo_by_mun$share_notipo > 0.01, na.rm = TRUE), nrow(tipo_by_mun)))

TIPO_NEGLIGIBLE <- (share_pop < 0.005)
if (TIPO_NEGLIGIBLE) {
  cat("\nNEGLIGIBLE (< 0.5% of urban-2010 population): the growth-type filter is\n")
  cat("effectively non-binding on the 2010 side, so C_native -- urban-filtered\n")
  cat("only -- is a true counterpart of C_allocated.\n")
} else {
  cat("\n*** NOT NEGLIGIBLE: the growth-type filter removes a non-trivial share of\n")
  cat("the 2010 urban population. C_native is urban-filtered ONLY, and the share\n")
  cat("printed above is the residual definitional difference -- it must not be\n")
  cat("read as a grid effect. Labelled C_native (urban-filtered only) throughout.\n")
}
save_csv(tipo_by_mun, "c_native_tipo_filter_by_municipality.csv")

# --- Build C_native on the native 2010 grid ---------------------------------

cat("\nBuilding C_native from grade_ibge_2010.parquet...\n")
ibge10 <- arrow::read_parquet(
  path_ibge_2010,
  col_select = all_of(c("cod_mun", "populacao", "area_total",
                        "prop_suscept_total", "built_pct_2010"))
) %>%
  mutate(cod_mun            = as.double(cod_mun),
         populacao          = coalesce(as.numeric(populacao), 0),
         area_total         = as.numeric(area_total),
         prop_suscept_total = coalesce(as.numeric(prop_suscept_total), 0),
         built_pct_2010     = as.numeric(built_pct_2010),
         urbano_2010_native = classificar_urbano(built_pct_2010, populacao,
                                                 area_total,
                                                 LIMIAR_BUILT, LIMIAR_DENS))
cat(sprintf("  native 2010 grid (script 03): %s cells, %s urban in 2010\n",
            fmt(nrow(ibge10)), fmt(sum(ibge10$urbano_2010_native))))

# Stage 03's weighting rule (unweighted, any overlap) on urban-2010 cells; the
# denominator is the urban-restricted sum, the counterpart of pop_2010_total.
cnat10 <- ibge10 %>%
  filter(urbano_2010_native) %>%
  group_by(cod_mun) %>%
  summarise(
    risk_C_native  = sum(populacao * (prop_suscept_total > LIMIAR_SUSCEPT), na.rm = TRUE),
    total_C_native = sum(populacao, na.rm = TRUE),
    .groups = "drop"
  )
rm(ibge10); gc()

# --- 2022 CONTROL ------------------------------------------------------------
# Both sides are the 2022 grid, so A and B must agree. This validates the
# alignment before any 2010 number is believed.

cat("\n", strrep("=", 78), "\n")
cat("STEP 0 CONTROL -- 2022 SIDE (both from the 2022 grid; must agree)\n")
cat(strrep("=", 78), "\n")

ctrl22 <- nat22 %>% inner_join(alo22, by = "cod_mun")
ctrl_summary <- tibble::tibble(
  variant = c("A_weighted", "B_anyoverlap", "total_all_cells"),
  native    = c(sum(ctrl22$risk_A_weighted_nat),   sum(ctrl22$risk_B_anyoverlap_nat),
                sum(ctrl22$total_all_cells_nat)),
  allocated = c(sum(ctrl22$risk_A_weighted_alo),   sum(ctrl22$risk_B_anyoverlap_alo),
                sum(ctrl22$total_all_cells_alo))
) %>%
  mutate(diff = allocated - native,
         pct_diff = 100 * diff / pmax(native, 1))

cat(sprintf("Municipalities in both 2022 aggregations: %d\n", nrow(ctrl22)))
print(ctrl_summary, width = Inf)

ctrl22 <- ctrl22 %>%
  mutate(rel_gap_A = (risk_A_weighted_alo - risk_A_weighted_nat) /
                      pmax(risk_A_weighted_nat, 1))
cat(sprintf("\nPer-municipality relative gap on variant A (2022): median %.5f, ",
            median(ctrl22$rel_gap_A, na.rm = TRUE)))
cat(sprintf("p95 %.5f, max |gap| %.5f\n",
            quantile(abs(ctrl22$rel_gap_A), 0.95, na.rm = TRUE),
            max(abs(ctrl22$rel_gap_A), na.rm = TRUE)))

control_ok <- abs(ctrl_summary$pct_diff[ctrl_summary$variant == "A_weighted"]) < 1
if (!control_ok) {
  cat("\n*** CONTROL FAILED: the 2022 sides do not agree within 1%.\n")
  cat("    The 2010 comparison below is NOT trustworthy as a native-vs-allocated\n")
  cat("    measurement -- some definitional difference survives the alignment\n")
  cat("    (candidates: grid coverage/municipality assignment, cod_mun mismatch,\n")
  cat("    subcell splitting on the common grid). Read the 2010 numbers as\n")
  cat("    provisional and reconcile this first.\n")
} else {
  cat("\nControl OK: the 2022 sides agree within 1% on variant A.\n")
}
save_csv(ctrl_summary, "control_2022_alignment.csv")

# --- 2010 COMPARISON + DECOMPOSITION -----------------------------------------

cat("\n", strrep("=", 78), "\n")
cat("STEP 0 -- 2010 SIDE, LIKE-FOR-LIKE, AND THE THREE-WAY DECOMPOSITION\n")
cat(strrep("=", 78), "\n")

cmp10 <- nat10 %>%
  full_join(alo10, by = "cod_mun") %>%
  full_join(cnat10, by = "cod_mun") %>%
  mutate(on_native = coalesce(on_native, FALSE),
         on_common = coalesce(on_common, FALSE),
         both_grids = on_native & on_common) %>%
  mutate(across(where(is.numeric), ~coalesce(., 0))) %>%
  mutate(
    # The grid question, definitions matched (two weighting conventions)
    diff_A  = risk_A_weighted_alo   - risk_A_weighted_nat,
    ratio_A = risk_A_weighted_alo   / pmax(risk_A_weighted_nat, 1e-9),
    diff_B  = risk_B_anyoverlap_alo - risk_B_anyoverlap_nat,
    ratio_B = risk_B_anyoverlap_alo / pmax(risk_B_anyoverlap_nat, 1e-9),
    # The headline: definition C on both sides. This is the only like-for-like
    # comparison of the quantity the regression variables are actually built on.
    diff_C  = risk_C_pipeline_alo - risk_C_native,
    ratio_C = risk_C_pipeline_alo / pmax(risk_C_native, 1e-9),
    # Decomposition, all on the allocated side
    effect_weighting = risk_B_anyoverlap_alo - risk_A_weighted_alo,
    effect_urbanfilt = risk_C_pipeline_alo   - risk_B_anyoverlap_alo,
    # pp versions (risk / total), each on its own consistent denominator
    pp_nat_A = 100 * risk_A_weighted_nat   / pmax(total_all_cells_nat, 1),
    pp_alo_A = 100 * risk_A_weighted_alo   / pmax(total_all_cells_alo, 1),
    pp_nat_B = 100 * risk_B_anyoverlap_nat / pmax(total_all_cells_nat, 1),
    pp_alo_B = 100 * risk_B_anyoverlap_alo / pmax(total_all_cells_alo, 1),
    pp_alo_C = 100 * risk_C_pipeline_alo   / pmax(total_C_pipeline_alo, 1),
    pp_nat_C = 100 * risk_C_native         / pmax(total_C_native, 1)
  )

save_csv(cmp10, "municipality_native_vs_allocated_2010.csv")
save_csv(nat22, "cache_native_2022_series.csv")

# Both years' C series on the allocated side, for step 0W. cmp10 already carries
# the 2010 ones (suffixed _alo); 2022's live only in alo22, which nothing else
# caches, so the two are written together here in one tidy file.
c_series_alo <- alo10 %>%
  select(cod_mun,
         c_weighted_2010   = risk_C_weighted_alo,
         c_anyoverlap_2010 = risk_C_pipeline_alo,
         a_weighted_2010   = risk_A_weighted_alo) %>%
  full_join(
    alo22 %>% select(cod_mun,
                     c_weighted_2022   = risk_C_weighted_alo,
                     c_anyoverlap_2022 = risk_C_pipeline_alo,
                     a_weighted_2022   = risk_A_weighted_alo),
    by = "cod_mun"
  ) %>%
  mutate(across(where(is.numeric), ~coalesce(., 0)))
save_csv(c_series_alo, "cache_allocated_c_series.csv")
save_csv(tibble::tibble(urban_rule_ok = URBAN_RULE_OK,
                        urban_rule_mismatched_cells = n_mismatch,
                        tipo_negligible = TIPO_NEGLIGIBLE,
                        tipo_share_of_urban2010_pop = share_pop,
                        tipo_share_of_urban2010_cells = share_cells,
                        limiar_built = LIMIAR_BUILT, limiar_dens = LIMIAR_DENS),
         "cache_c_native_checks.csv")

} else {

cat("\n*** Using cached municipality aggregates -- the cell-level grids were NOT\n")
cat(sprintf("    re-read. Cache: %s\n", cache_cmp10))
cat("    Delete the cache files or set options(nva.force_reread = TRUE) to redo\n")
cat("    the grid reads. The 2022 control is not re-run here; its result is in\n")
cat("    control_2022_alignment.csv from the run that built the cache.\n")
cmp10 <- read_csv(cache_cmp10, show_col_types = FALSE)
nat22 <- read_csv(cache_nat22, show_col_types = FALSE)
c_series_alo <- read_csv(cache_cw, show_col_types = FALSE)
chk   <- read_csv(file.path(diag_dir, "cache_c_native_checks.csv"),
                  show_col_types = FALSE)
URBAN_RULE_OK   <- isTRUE(chk$urban_rule_ok[1])
TIPO_NEGLIGIBLE <- isTRUE(chk$tipo_negligible[1])
share_pop       <- chk$tipo_share_of_urban2010_pop[1]
cat(sprintf("    C_native checks from cache: urban rule reproduced = %s (%s mismatching cells);\n",
            URBAN_RULE_OK, fmt(chk$urban_rule_mismatched_cells[1])))
cat(sprintf("    growth-type filter negligible = %s (%.4f%% of urban-2010 population)\n",
            TIPO_NEGLIGIBLE, 100 * share_pop))

}

# =============================================================================
# STEP 0W -- INDEPENDENT CHECK OF THE CORRECTED SCRIPT 07 (added 2026-09-12)
# =============================================================================
# Why this exists. Table 1's own gating check compares its output against the
# archived baseline variant (produced by a migration-era diagnostic that is not
# deposited here). Both sides of that comparison descend from
# 07_aggregate_municipality_metrics.R and its diagnostic copy, which were
# corrected together under MIGRATION_PLAN.md 6e --
# so it tests that the two were changed CONSISTENTLY, not that the weighting
# itself is right. A consistent mistake would pass it.
#
# risk_C_weighted (agg_common() above) is an independent reconstruction: the
# same definition -- sum(pop x prop_suscept_total) over cells urban in the year
# and carrying a tipo_crescimento label -- reached separately, from the
# cell-level parquet, in this script's own idiom, sharing no code with script
# 07. If script 07's output matches it per municipality, the weighting is right
# for a reason that does not depend on script 07 being right.
#
# Two things are checked:
#   (1) EQUALITY. metricas_municipio_2010_2022.csv's pop_2010_risk_total and
#       pop_2022_risk_total must equal c_weighted_2010 / c_weighted_2022 per
#       municipality. Script 07 sums six per-type columns and adds them; this
#       sums the same cells in one pass. Identical in exact arithmetic, so only
#       floating-point summation order should separate them -- hence a relative
#       tolerance, not bit equality.
#   (2) MONOTONICITY. C_weighted <= A_weighted must hold everywhere, both years.
#       A is the same weighting over ALL cells; C adds the urban + tipo filter,
#       and a filter over non-negative terms can only remove. This is a sanity
#       bound that does not depend on script 07 at all: if a national risk total
#       ever exceeds its variant-A total, the urban filter is not doing what it
#       is documented to do.

cat("\n", strrep("=", 78), "\n")
cat("STEP 0W -- CORRECTED SCRIPT 07 vs. INDEPENDENT C_weighted (6e)\n")
cat(strrep("=", 78), "\n")

path_metricas <- file.path(metricas_dir, "metricas_municipio_2010_2022.csv")

# Reference national variant-A totals on the allocated side, quoted from this
# script's own earlier full run (see native_vs_allocated_pop_2010_risk.md).
# Printed for continuity only -- the bound actually tested below uses the A
# totals THIS run computes, so the check stands on its own if coverage differs.
REF_A_2010_ALLOCATED <- 12375919
REF_A_2022_ALLOCATED <- 13216182

if (!file.exists(path_metricas)) {
  cat("\n  SKIPPED: metricas_municipio_2010_2022.csv not found.\n")
  cat(sprintf("    Expected at: %s\n", path_metricas))
  cat("    Run 03_urban_footprint_and_growth_types/07_aggregate_municipality_metrics.R\n")
  cat("    first, then re-source this script (the cache makes it seconds).\n")
} else {

metr <- read_csv(path_metricas, show_col_types = FALSE) %>%
  mutate(cod_mun = as.double(cod_mun)) %>%
  select(cod_mun, pop_2010_risk_total, pop_2022_risk_total)

cat(sprintf("\n  metricas file: %s municipalities\n", fmt(nrow(metr))))
cat(sprintf("  C_weighted series: %s municipalities\n", fmt(nrow(c_series_alo))))

# Coverage: both sides come from the same parquet, so the sets should be equal.
only_metr <- setdiff(metr$cod_mun, c_series_alo$cod_mun)
only_diag <- setdiff(c_series_alo$cod_mun, metr$cod_mun)
if (length(only_metr) > 0 || length(only_diag) > 0) {
  cat(sprintf("  *** COVERAGE MISMATCH: %d only in metricas, %d only in the diagnostic.\n",
              length(only_metr), length(only_diag)))
  cat("      Both are built from grade_growth_types_2010_2022.parquet, so they\n")
  cat("      should be identical. If the cache predates the stage-3 rerun, set\n")
  cat("      options(nva.force_reread = TRUE) and re-source.\n")
} else {
  cat("  Coverage OK: identical municipality sets.\n")
}

chk0w <- metr %>%
  inner_join(c_series_alo, by = "cod_mun") %>%
  mutate(
    abs_2010 = abs(pop_2010_risk_total - c_weighted_2010),
    abs_2022 = abs(pop_2022_risk_total - c_weighted_2022),
    # Relative gap on a non-trivial base only: a municipality with ~0 exposed
    # population would otherwise show a huge relative gap on a rounding unit.
    rel_2010 = ifelse(c_weighted_2010 > 1, abs_2010 / c_weighted_2010, NA_real_),
    rel_2022 = ifelse(c_weighted_2022 > 1, abs_2022 / c_weighted_2022, NA_real_)
  )

TOL_REL <- 1e-6   # generous next to float64 summation noise (~1e-15 relative)
TOL_ABS <- 1e-3   # one thousandth of a person

gaps <- tibble::tibble(
  year          = c(2010, 2022),
  # c(0, .) so an all-NA relative column (no municipality above the base
  # threshold) degrades to 0 rather than -Inf with a warning.
  max_abs_gap   = c(max(c(0, chk0w$abs_2010), na.rm = TRUE),
                    max(c(0, chk0w$abs_2022), na.rm = TRUE)),
  max_rel_gap   = c(max(c(0, chk0w$rel_2010), na.rm = TRUE),
                    max(c(0, chk0w$rel_2022), na.rm = TRUE)),
  n_over_tol    = c(sum(chk0w$abs_2010 > TOL_ABS & coalesce(chk0w$rel_2010, 0) > TOL_REL),
                    sum(chk0w$abs_2022 > TOL_ABS & coalesce(chk0w$rel_2022, 0) > TOL_REL)),
  total_script07 = c(sum(chk0w$pop_2010_risk_total, na.rm = TRUE),
                     sum(chk0w$pop_2022_risk_total, na.rm = TRUE)),
  total_C_weighted = c(sum(chk0w$c_weighted_2010, na.rm = TRUE),
                       sum(chk0w$c_weighted_2022, na.rm = TRUE))
) %>%
  mutate(total_diff = total_script07 - total_C_weighted)

cat("\n--- (1) EQUALITY: script 07 vs. independent C_weighted, per municipality ---\n")
print(gaps, width = Inf)

EQUALITY_OK <- all(gaps$n_over_tol == 0)
if (EQUALITY_OK) {
  cat("\n  PASS: script 07's risk totals reproduce C_weighted to within floating-point\n")
  cat("        summation noise, for every municipality, both years. The weighting is\n")
  cat("        confirmed against code that shares nothing with script 07.\n")
} else {
  cat("\n  *** FAIL: script 07 and C_weighted disagree beyond tolerance.\n")
  cat("      This is NOT a methodology difference -- the two compute the same\n")
  cat("      definition. One of them has a bug. Worst offenders:\n")
  chk0w %>%
    mutate(worst = pmax(coalesce(rel_2010, 0), coalesce(rel_2022, 0))) %>%
    arrange(desc(worst)) %>%
    select(cod_mun, pop_2010_risk_total, c_weighted_2010, abs_2010, rel_2010,
           pop_2022_risk_total, c_weighted_2022, abs_2022, rel_2022) %>%
    head(15) %>% print(width = Inf)
}

cat("\n--- (2) MONOTONICITY: C_weighted <= A_weighted (the urban filter only removes) ---\n")

mono <- tibble::tibble(
  year              = c(2010, 2022),
  total_A_weighted  = c(sum(c_series_alo$a_weighted_2010),
                        sum(c_series_alo$a_weighted_2022)),
  total_C_weighted  = c(sum(c_series_alo$c_weighted_2010),
                        sum(c_series_alo$c_weighted_2022)),
  reference_A_total = c(REF_A_2010_ALLOCATED, REF_A_2022_ALLOCATED),
  n_violations      = c(sum(c_series_alo$c_weighted_2010 >
                              c_series_alo$a_weighted_2010 + TOL_ABS),
                        sum(c_series_alo$c_weighted_2022 >
                              c_series_alo$a_weighted_2022 + TOL_ABS))
) %>%
  mutate(
    C_below_A       = total_C_weighted < total_A_weighted,
    pct_of_A        = 100 * total_C_weighted / total_A_weighted,
    A_vs_reference  = total_A_weighted - reference_A_total
  )
print(mono, width = Inf)

if (all(mono$n_violations == 0) && all(mono$C_below_A)) {
  cat("\n  PASS: the national risk totals fall below the variant-A totals in both\n")
  cat("        years, with no municipality violating the bound. The difference is\n")
  cat("        the urban + tipo filter, which is what it should be.\n")
} else {
  cat("\n  *** FAIL: a risk total exceeds its variant-A total. Since C is A plus a\n")
  cat("      filter over non-negative terms, this is arithmetically impossible\n")
  cat("      unless the two are not on the same cells or the same weight column.\n")
}

cat("\n  (reference_A_total is this script's earlier full-run value, for continuity;\n")
cat("   A_vs_reference is how far THIS run's A total sits from it. A non-zero gap\n")
cat("   is a coverage or upstream-data difference, not a failure of the bound above,\n")
cat("   which is tested against this run's own A totals.)\n")

save_csv(chk0w, "step0w_script07_vs_c_weighted.csv")
save_csv(gaps,  "step0w_equality_summary.csv")
save_csv(mono,  "step0w_monotonicity_summary.csv")

}

nat_tot <- tibble::tibble(
  quantity = c("A_weighted", "B_anyoverlap", "C_pipeline (allocated only)",
               "total_all_cells"),
  native    = c(sum(cmp10$risk_A_weighted_nat), sum(cmp10$risk_B_anyoverlap_nat),
                NA_real_, sum(cmp10$total_all_cells_nat)),
  allocated = c(sum(cmp10$risk_A_weighted_alo), sum(cmp10$risk_B_anyoverlap_alo),
                sum(cmp10$risk_C_pipeline_alo), sum(cmp10$total_all_cells_alo))
) %>%
  mutate(diff = allocated - native,
         pct_diff = 100 * diff / pmax(native, 1))

cat("\nNational totals, 2010 (every municipality on either grid):\n")
print(nat_tot, width = Inf)

# Coverage first: a municipality absent from one grid contributes its whole
# value as a "difference" if this is not separated out.
cat("\nCOVERAGE -- which grid each municipality appears on:\n")
cat(sprintf("  on both grids            : %d\n", sum(cmp10$both_grids)))
cat(sprintf("  native grid only         : %d\n", sum(cmp10$on_native & !cmp10$on_common)))
cat(sprintf("  common grid only         : %d\n", sum(!cmp10$on_native & cmp10$on_common)))
cat(sprintf("\n  Native-side population sitting in native-only municipalities: %s (%.2f%% of the native total)\n",
            fmt(round(sum(cmp10$risk_A_weighted_nat[cmp10$on_native & !cmp10$on_common]))),
            100 * sum(cmp10$risk_A_weighted_nat[cmp10$on_native & !cmp10$on_common]) /
              pmax(sum(cmp10$risk_A_weighted_nat), 1)))
cat("  That share is a COVERAGE difference (the common grid does not carry those\n")
cat("  municipalities at all), not the allocation moving anyone. Totals above\n")
cat("  include it; the both-grids totals below exclude it.\n")

both <- cmp10 %>% filter(both_grids)
cat(sprintf("\nTotals restricted to the %d municipalities on BOTH grids:\n", nrow(both)))
cat(sprintf("  A_weighted  : native %s -> allocated %s (%+.2f%%)\n",
            fmt(round(sum(both$risk_A_weighted_nat))),
            fmt(round(sum(both$risk_A_weighted_alo))),
            100 * (sum(both$risk_A_weighted_alo) - sum(both$risk_A_weighted_nat)) /
              pmax(sum(both$risk_A_weighted_nat), 1)))
cat(sprintf("  B_anyoverlap: native %s -> allocated %s (%+.2f%%)\n",
            fmt(round(sum(both$risk_B_anyoverlap_nat))),
            fmt(round(sum(both$risk_B_anyoverlap_alo))),
            100 * (sum(both$risk_B_anyoverlap_alo) - sum(both$risk_B_anyoverlap_nat)) /
              pmax(sum(both$risk_B_anyoverlap_nat), 1)))

cat("\nDecomposition of the published stage-03 column vs. the native series:\n")
cat(sprintf("  native, stage-02 rule      (A, weighted)       : %s\n",
            fmt(round(sum(cmp10$risk_A_weighted_nat)))))
cat(sprintf("  + weighting -> any-overlap  (A -> B, native)    : %s\n",
            fmt(round(sum(cmp10$risk_B_anyoverlap_nat)))))
cat(sprintf("  allocated, any-overlap      (B, allocated)      : %s\n",
            fmt(round(sum(cmp10$risk_B_anyoverlap_alo)))))
cat(sprintf("  + urban/tipo filter         (B -> C, allocated) : %s\n",
            fmt(round(sum(cmp10$risk_C_pipeline_alo)))))
cat("\n  Grid effect, isolated (allocated - native, same definition):\n")
cat(sprintf("    under A (weighted)    : %+.0f  (%+.2f%%)\n",
            sum(cmp10$diff_A), 100 * sum(cmp10$diff_A) / pmax(sum(cmp10$risk_A_weighted_nat), 1)))
cat(sprintf("    under B (any overlap) : %+.0f  (%+.2f%%)\n",
            sum(cmp10$diff_B), 100 * sum(cmp10$diff_B) / pmax(sum(cmp10$risk_B_anyoverlap_nat), 1)))
cat("\n  SIGN: a NEGATIVE grid effect means the allocation moves 2010 population\n")
cat("  OUT of high-susceptibility cells relative to the native grid -- the\n")
cat("  direction the GHSL under-detection hypothesis predicts.\n")

save_csv(nat_tot, "national_totals_2010.csv")

# =============================================================================
# STEP 1 -- MUNICIPALITY-LEVEL COMPARISON
# =============================================================================

cat("\n", strrep("=", 78), "\n")
cat("STEP 1 -- MUNICIPALITY-LEVEL COMPARISON\n")
cat(strrep("=", 78), "\n")

ds_new <- read_csv(path_new_ds, show_col_types = FALSE) %>%
  mutate(cod_mun = as.double(cod_mun))
cat(sprintf("\nRegression dataset: %d rows\n", nrow(ds_new)))

# UF from the IBGE municipality code's first two digits -- deterministic, so
# no extra lookup file is needed.
UF_BY_CODE <- c("11"="RO","12"="AC","13"="AM","14"="RR","15"="PA","16"="AP",
                "17"="TO","21"="MA","22"="PI","23"="CE","24"="RN","25"="PB",
                "26"="PE","27"="AL","28"="SE","29"="BA","31"="MG","32"="ES",
                "33"="RJ","35"="SP","41"="PR","42"="SC","43"="RS","50"="MS",
                "51"="MT","52"="GO","53"="DF")

# Municipality name: the regression dataset carries NM_CIDADE (the functional
# urban area's name, also the cluster variable), not a municipality name
# column. Use whichever identifying name column is actually present rather
# than assuming one -- and never rename the source column itself.
name_col <- intersect(c("nome_mun", "NM_MUN", "name_muni", "NM_CIDADE"),
                      names(ds_new))[1]
if (is.na(name_col)) {
  cat("  NOTE: no municipality-name column found in the dataset; reporting cod_mun only.\n")
} else if (name_col == "NM_CIDADE") {
  cat("  NOTE: no municipality-name column in the dataset; using NM_CIDADE\n")
  cat("        (functional urban area name) as the label.\n")
}

add_labels <- function(df) {
  out <- df %>%
    mutate(uf = unname(UF_BY_CODE[substr(sprintf("%07d", as.integer(cod_mun)), 1, 2)]))
  if (!is.na(name_col)) {
    out <- out %>%
      left_join(ds_new %>% select(cod_mun, mun_label = all_of(name_col)),
                by = "cod_mun")
  } else {
    out <- out %>% mutate(mun_label = NA_character_)
  }
  out
}

# The comparison frame. The HEADLINE columns (native_2010 / allocated_2010 /
# diff_2010 / ratio_2010 / log_ratio) are definition C on both sides -- the only
# like-for-like comparison of the quantity the regression variables are built
# on. A and B ride alongside as the weighting/urban-filter decomposition; they
# are not dropped, and every block below reports them too.
comp <- cmp10 %>%
  transmute(
    cod_mun,
    on_native, on_common, both_grids,
    # headline: definition C, both sides
    native_2010    = risk_C_native,
    allocated_2010 = risk_C_pipeline_alo,
    diff_2010      = diff_C,
    ratio_2010     = ratio_C,
    pp_native_2010    = pp_nat_C,
    pp_allocated_2010 = pp_alo_C,
    pp_diff_2010      = pp_alo_C - pp_nat_C,
    pp_ratio_2010     = pp_alo_C / pmax(pp_nat_C, 1e-9),
    total_C_native, total_C_pipeline_alo,
    # decomposition: A (stage 02's weighting) and B (any overlap, no urban filter)
    native_2010_A    = risk_A_weighted_nat,
    allocated_2010_A = risk_A_weighted_alo,
    ratio_2010_A     = ratio_A,
    native_2010_B    = risk_B_anyoverlap_nat,
    allocated_2010_B = risk_B_anyoverlap_alo,
    ratio_2010_B     = ratio_B
  ) %>%
  mutate(
    log_ratio   = ifelse(native_2010 > 0 & allocated_2010 > 0,
                         log(ratio_2010), NA_real_),
    abs_dev_pct = 100 * abs(diff_2010) / pmax(native_2010, 1)
  ) %>%
  add_labels()

comp <- comp %>%
  left_join(
    ds_new %>% select(cod_mun, any_of(c("pop_2010_risk_total", "pp_alta_2010",
                                        "prop_favelas_2010", "topo_prop_inclinado",
                                        "pop_total_2010", "NM_CIDADE"))),
    by = "cod_mun"
  ) %>%
  mutate(in_regression_sample = cod_mun %in% ds_new$cod_mun)

cat(sprintf("\nMunicipalities in the comparison: %d total, %d of them in the regression dataset\n",
            nrow(comp), sum(comp$in_regression_sample)))

# C_native is only reported if its urban-rule reconstruction verified. On a
# mismatch the headline C columns are blanked -- every C statistic below then
# prints as NA rather than as a number that would be an artifact of a wrong
# reconstruction. A and B are unaffected and still report.
if (!URBAN_RULE_OK) {
  cat("\n*** C_NATIVE WITHHELD: the urban-rule reconstruction did not reproduce\n")
  cat("    urbano_2010 exactly, so every C_allocated vs C_native statistic below\n")
  cat("    is blanked (NA). The A and B decomposition is unaffected.\n")
  comp <- comp %>%
    mutate(across(c(native_2010, allocated_2010, diff_2010, ratio_2010,
                    pp_native_2010, pp_allocated_2010, pp_diff_2010, pp_ratio_2010),
                  ~NA_real_))
} else if (!TIPO_NEGLIGIBLE) {
  cat(sprintf("\nNOTE: C_native is URBAN-FILTERED ONLY. The growth-type filter, which\n"))
  cat(sprintf("C_allocated also applies, covers %.4f%% of urban-2010 population; that\n",
              100 * share_pop))
  cat("residual is definitional and must not be read as a grid effect.\n")
}

# --- Reporting function, run twice: regression sample and full universe ------

report_block <- function(df, label) {
  cat("\n", strrep("-", 78), "\n")
  cat(sprintf("%s  (n = %d)\n", label, nrow(df)))
  cat(strrep("-", 78), "\n")

  cat("\nNational totals (2010, HEADLINE = definition C on both sides):\n")
  cat(sprintf("  native    : %s\n", fmt(round(sum(df$native_2010, na.rm = TRUE)))))
  cat(sprintf("  allocated : %s\n", fmt(round(sum(df$allocated_2010, na.rm = TRUE)))))
  cat(sprintf("  difference: %s  (%+.2f%%)\n",
              fmt(round(sum(df$diff_2010, na.rm = TRUE))),
              100 * sum(df$diff_2010, na.rm = TRUE) /
                pmax(sum(df$native_2010, na.rm = TRUE), 1)))
  cat("\n  Decomposition (kept alongside, not the headline):\n")
  cat(sprintf("    variant A (weighted, no urban filter) : native %s -> allocated %s (%+.2f%%)\n",
              fmt(round(sum(df$native_2010_A, na.rm = TRUE))),
              fmt(round(sum(df$allocated_2010_A, na.rm = TRUE))),
              100 * (sum(df$allocated_2010_A, na.rm = TRUE) -
                       sum(df$native_2010_A, na.rm = TRUE)) /
                pmax(sum(df$native_2010_A, na.rm = TRUE), 1)))
  cat(sprintf("    variant B (any overlap, no urban filter): native %s -> allocated %s (%+.2f%%)\n",
              fmt(round(sum(df$native_2010_B, na.rm = TRUE))),
              fmt(round(sum(df$allocated_2010_B, na.rm = TRUE))),
              100 * (sum(df$allocated_2010_B, na.rm = TRUE) -
                       sum(df$native_2010_B, na.rm = TRUE)) /
                pmax(sum(df$native_2010_B, na.rm = TRUE), 1)))

  cat("\nSIGN of the per-municipality difference (allocated - native):\n")
  cat(sprintf("  negative (allocation moves population OUT of hazard cells): %d (%.1f%%)\n",
              sum(df$diff_2010 < 0, na.rm = TRUE),
              100 * mean(df$diff_2010 < 0, na.rm = TRUE)))
  cat(sprintf("  positive                                                  : %d (%.1f%%)\n",
              sum(df$diff_2010 > 0, na.rm = TRUE),
              100 * mean(df$diff_2010 > 0, na.rm = TRUE)))
  cat(sprintf("  exactly zero                                              : %d\n",
              sum(df$diff_2010 == 0, na.rm = TRUE)))

  qs <- c(0.01, 0.05, 0.10, 0.25, 0.50, 0.75, 0.90, 0.95, 0.99)
  cat("\nDistribution of ratio C_allocated / C_native (HEADLINE):\n")
  print(round(quantile(df$ratio_2010, qs, na.rm = TRUE), 4))
  cat("\nDistribution of the same ratio under variant A (decomposition):\n")
  print(round(quantile(df$ratio_2010_A, qs, na.rm = TRUE), 4))
  cat("\nDistribution of the same ratio under variant B (decomposition):\n")
  print(round(quantile(df$ratio_2010_B, qs, na.rm = TRUE), 4))
  cat("\nDistribution of the pp ratio (pp allocated / pp native):\n")
  print(round(quantile(df$pp_ratio_2010, qs, na.rm = TRUE), 4))

  cat("\nShare of municipalities by size of the deviation (|allocated-native|/native):\n")
  cat(sprintf("  > 10%%: %d (%.1f%%)\n", sum(df$abs_dev_pct > 10, na.rm = TRUE),
              100 * mean(df$abs_dev_pct > 10, na.rm = TRUE)))
  cat(sprintf("  > 25%%: %d (%.1f%%)\n", sum(df$abs_dev_pct > 25, na.rm = TRUE),
              100 * mean(df$abs_dev_pct > 25, na.rm = TRUE)))

  show_cols <- c("cod_mun", "mun_label", "uf", "native_2010", "allocated_2010",
                 "diff_2010", "ratio_2010", "pop_2010_risk_total", "pp_alta_2010")

  cat("\n--- 20 largest ABSOLUTE deviations ---\n")
  top_abs <- df %>% arrange(desc(abs(diff_2010))) %>%
    select(any_of(show_cols)) %>% head(20)
  print(top_abs, n = Inf, width = Inf)

  cat("\n--- 20 largest RELATIVE deviations (among municipalities with native > 0) ---\n")
  top_rel <- df %>% filter(native_2010 > 0) %>%
    arrange(desc(abs_dev_pct)) %>%
    select(any_of(c(show_cols, "abs_dev_pct"))) %>% head(20)
  print(top_rel, n = Inf, width = Inf)

  # Correlations of the LOG ratio with the hypothesised drivers. Log so that a
  # halving and a doubling weigh the same; negative correlation with slum share
  # / steep terrain is the signature the hypothesis predicts.
  corr_vars <- intersect(c("prop_favelas_2010", "topo_prop_inclinado",
                           "pp_alta_2010", "pop_total_2010"),
                         names(df))
  if (length(corr_vars) > 0 && sum(!is.na(df$log_ratio)) > 3) {
    cat("\nCorrelation of log(allocated/native) with:\n")
    corr_tbl <- purrr::map_dfr(corr_vars, function(v) {
      x <- if (v == "pop_total_2010") log(df[[v]] + 1) else df[[v]]
      nm <- if (v == "pop_total_2010") "log_pop_total_2010" else v
      ok <- is.finite(x) & is.finite(df$log_ratio)
      if (sum(ok) < 4) return(tibble::tibble(variable = nm, n = sum(ok),
                                             pearson = NA_real_, spearman = NA_real_))
      tibble::tibble(
        variable = nm, n = sum(ok),
        pearson  = cor(x[ok], df$log_ratio[ok], method = "pearson"),
        spearman = cor(x[ok], df$log_ratio[ok], method = "spearman")
      )
    })
    print(corr_tbl, width = Inf)
    cat("  (negative = the allocated series falls further below the native one\n")
    cat("   as that variable rises -- the GHSL under-detection signature)\n")
  } else {
    cat("\nCorrelations skipped: driver columns or log-ratio observations unavailable.\n")
  }

  invisible(list(top_abs = top_abs, top_rel = top_rel))
}

comp_sample <- comp %>% filter(in_regression_sample)
res_sample  <- report_block(comp_sample, "REGRESSION SAMPLE (dataset_regressao_municipio.csv)")
res_universe <- report_block(comp, "FULL PROCESSING UNIVERSE (every municipality on either grid)")
cat("\nNOTE: the block above mixes two different things -- the allocation moving\n")
cat("population, and municipalities the common grid does not cover at all (which\n")
cat("enter as allocated = 0, ratio 0, -100%). The block below drops the\n")
cat("uncovered ones, so it measures the grid question alone.\n")
res_both <- report_block(comp %>% filter(both_grids),
                         "FULL UNIVERSE -- municipalities on BOTH grids only")

save_csv(comp, "step1_municipality_comparison_full_universe.csv")
save_csv(comp %>% filter(both_grids), "step1_municipality_comparison_both_grids.csv")
save_csv(comp_sample, "step1_municipality_comparison_regression_sample.csv")
save_csv(res_sample$top_abs, "step1_top20_absolute_regression_sample.csv")
save_csv(res_sample$top_rel, "step1_top20_relative_regression_sample.csv")

# --- Municipalities dropped by the pop_2010_risk_total > 1000 restriction ----

MIN_POP_RISCO_2010 <- 200  # must match 16_estimate_models.R exactly (revised 2026-09-12, was 1000)

cat("\n", strrep("-", 78), "\n")
cat("FLAGGED SUBSET -- municipalities dropped by pop_2010_risk_total > 1000\n")
cat(strrep("-", 78), "\n")

dropped <- comp_sample %>%
  filter(!is.na(pop_2010_risk_total), pop_2010_risk_total <= MIN_POP_RISCO_2010)

cat(sprintf("\nDropped under the CURRENT (allocated) series: %d municipalities\n",
            nrow(dropped)))
cat("\n  *** CROSS-RULE WARNING (6e): pop_2010_risk_total is now AREA-WEIGHTED,\n")
cat("      while all three native series below are the RETIRED any-overlap rule.\n")
cat("      The counts that follow therefore mix the weighting change with the\n")
cat("      grid change and must NOT be read as 'the allocation dropped these\n")
cat("      municipalities'. Before 6e this comparison was like-for-like on the\n")
cat("      C_native row; it is not any more. ***\n")
cat(sprintf("Of those, how many would SURVIVE the same cut on the native series:\n"))
cat(sprintf("  C_native (any-overlap -- NOT like-for-like since 6e) > 1000 : %d\n",
            sum(dropped$native_2010 > MIN_POP_RISCO_2010, na.rm = TRUE)))
cat(sprintf("  A native (no urban filter) > 1000 : %d\n",
            sum(dropped$native_2010_A > MIN_POP_RISCO_2010, na.rm = TRUE)))
cat(sprintf("  B native (no urban filter) > 1000 : %d\n",
            sum(dropped$native_2010_B > MIN_POP_RISCO_2010, na.rm = TRUE)))
cat("  (A and B have no urban filter and count rural population too, so they are\n")
cat("   larger by construction -- only the C_native count is like-for-like.)\n")
cat("\n  A municipality dropped under the allocated series but surviving under\n")
cat("  the native one is a case where the allocation, not the underlying data,\n")
cat("  removed it from the regression.\n\n")
print(dropped %>%
        select(any_of(c("cod_mun", "mun_label", "uf", "pop_2010_risk_total",
                        "native_2010", "allocated_2010", "ratio_2010",
                        "native_2010_A", "native_2010_B", "pp_alta_2010",
                        "pp_native_2010"))) %>%
        arrange(desc(native_2010)),
      n = Inf, width = Inf)

save_csv(dropped, "step1_dropped_by_1000_cut.csv")

# =============================================================================
# STEP 2 -- PROVENANCE OF THE PRE-MIGRATE NUMBERS
# =============================================================================

cat("\n", strrep("=", 78), "\n")
cat("STEP 2 -- WHICH SERIES DID THE PRE-MIGRATE DATASET USE?\n")
cat(strrep("=", 78), "\n")

old_path <- file.path(here::here(), "regression2", "data", "tabelas",
                      "dataset_regressao_municipio.csv")

if (!file.exists(old_path)) {
  cat(sprintf("\nOld file NOT present on this machine:\n  %s\n", old_path))
  cat("Step 2 skipped. (It is untracked and pre-Migrate, so its absence here is\n")
  cat("expected on a fresh clone -- run this script on the researcher's machine\n")
  cat("to get the provenance answer.)\n")
  step2_done <- FALSE
} else {
  step2_done <- TRUE
  old <- read_csv(old_path, show_col_types = FALSE) %>%
    mutate(cod_mun = as.double(cod_mun))
  cat(sprintf("\nOld file: %d rows, %d columns\n", nrow(old), ncol(old)))

  # The 2010 risk-population column's name changed across versions; find it
  # rather than assuming. Never rename it in the source file.
  # Confirmed against the real 387-row file: the column is pop10e_risco_alta_total
  # (with pop10e_total as its denominator). The other spellings are kept so the
  # script still works against older vintages of the same file.
  cand_pop <- intersect(c("pop10e_risco_alta_total", "pop_2010_risk_total",
                          "pop_alta_2010", "pop10_risco_alta",
                          "pop_risco_alta_2010", "pop_suscept_alta_2010",
                          "pop_2010_alta"), names(old))
  cat(sprintf("2010 risk-population column(s) found in the old file: %s\n",
              if (length(cand_pop) == 0) "NONE" else paste(cand_pop, collapse = ", ")))
  if (length(cand_pop) == 0) {
    cat("Columns present in the old file (for manual inspection):\n")
    print(names(old))
  }

  old_pop_col <- if (length(cand_pop) > 0) cand_pop[1] else NA_character_

  prov <- comp %>%
    select(cod_mun, native_2010, native_2010_A, native_2010_B, allocated_2010,
           pp_native_2010, pp_allocated_2010) %>%
    inner_join(
      old %>% select(cod_mun, any_of(c("pp_alta_2010",
                                      old_pop_col[!is.na(old_pop_col)]))) %>%
        rename_with(~paste0(., "_old"), -cod_mun),
      by = "cod_mun"
    )
  cat(sprintf("Municipalities matched between the old file and this comparison: %d\n",
              nrow(prov)))

  # --- Which series does the OLD 2010 risk population match? ----------------
  if (!is.na(old_pop_col)) {
    old_vec <- prov[[paste0(old_pop_col, "_old")]]
    cands <- list(
      "C_native (urban-filtered, any overlap)" = prov$native_2010,
      "C_allocated (stage 03 published)"       = prov$allocated_2010,
      "A native (weighted, no urban filter)"   = prov$native_2010_A,
      "B native (any overlap, no urban filter)" = prov$native_2010_B
    )
    match_tbl <- purrr::imap_dfr(cands, function(v, nm) {
      ok <- is.finite(v) & is.finite(old_vec)
      tibble::tibble(
        series          = nm,
        n               = sum(ok),
        correlation     = if (sum(ok) > 3) cor(v[ok], old_vec[ok]) else NA_real_,
        median_abs_pct  = if (sum(ok) > 0)
          median(100 * abs(v[ok] - old_vec[ok]) / pmax(old_vec[ok], 1)) else NA_real_,
        share_within_1pct = if (sum(ok) > 0)
          mean(abs(v[ok] - old_vec[ok]) <= 0.01 * pmax(old_vec[ok], 1)) else NA_real_,
        total           = sum(v[ok])
      )
    })
    cat(sprintf("\nOld column '%s' (total %s) vs. each candidate series:\n",
                old_pop_col, fmt(round(sum(old_vec, na.rm = TRUE)))))
    print(match_tbl, width = Inf)
    cat("\nRead: the matching series is the one with correlation ~1, median\n")
    cat("absolute deviation ~0 and a high share within 1%.\n")
    save_csv(match_tbl, "step2_old_population_series_match.csv")
  }

  # --- Which series does the OLD pp_alta_2010 match? ------------------------
  if ("pp_alta_2010_old" %in% names(prov)) {
    pp_cands <- list(
      "pp from C_native"    = prov$pp_native_2010,
      "pp from C_allocated" = prov$pp_allocated_2010
    )
    pp_tbl <- purrr::imap_dfr(pp_cands, function(v, nm) {
      ok <- is.finite(v) & is.finite(prov$pp_alta_2010_old)
      tibble::tibble(
        series            = nm,
        n                 = sum(ok),
        correlation       = if (sum(ok) > 3) cor(v[ok], prov$pp_alta_2010_old[ok]) else NA_real_,
        median_abs_diff_pp = if (sum(ok) > 0)
          median(abs(v[ok] - prov$pp_alta_2010_old[ok])) else NA_real_,
        share_within_0p1pp = if (sum(ok) > 0)
          mean(abs(v[ok] - prov$pp_alta_2010_old[ok]) <= 0.1) else NA_real_
      )
    })
    cat("\nOld pp_alta_2010 vs. each candidate series:\n")
    print(pp_tbl, width = Inf)
    save_csv(pp_tbl, "step2_old_pp_series_match.csv")
  }

  # --- The municipalities whose pp_alta_2010 went small-positive -> exactly 0
  # Identified here from the data rather than from a hardcoded list, so the
  # count is whatever the files actually show (an earlier write-up, kept in the
  # project's working repository, reports 12).
  if ("pp_alta_2010_old" %in% names(prov)) {
    zeroed <- prov %>%
      inner_join(ds_new %>% select(cod_mun, pp_alta_2010_new = pp_alta_2010),
                 by = "cod_mun") %>%
      filter(pp_alta_2010_old > 0, pp_alta_2010_new == 0) %>%
      add_labels()

    cat(sprintf("\nMunicipalities with pp_alta_2010 > 0 in the old file and exactly 0 now: %d\n",
                nrow(zeroed)))
    cat("(an earlier write-up reports 12 -- a different count\n")
    cat(" here is itself a finding, not an error to paper over.)\n")
    cat("\nFor each, does the NATIVE series also say zero?\n")
    print(zeroed %>%
            select(any_of(c("cod_mun", "mun_label", "uf", "pp_alta_2010_old",
                            "pp_alta_2010_new", "pp_native_2010",
                            "native_2010", "allocated_2010",
                            "native_2010_A", "native_2010_B"))) %>%
            arrange(desc(native_2010)),
          n = Inf, width = Inf)
    cat("\n  A row with native_2010 (C_native) > 0 but allocated_2010 (C_allocated)\n")
    cat("  == 0 is a municipality the native grid still places in a hazard zone in\n")
    cat("  2010 under the SAME definition, and that only the allocation empties out.\n")
    save_csv(zeroed, "step2_zeroed_pp_alta_2010.csv")
  }
}

# =============================================================================
# STEP 3 -- REFIT WITH THE 2010 SIDE FROM THE NATIVE GRID
# =============================================================================

cat("\n", strrep("=", 78), "\n")
cat("STEP 3 -- TABLE 2 REFIT, 2010 SIDE FROM THE NATIVE GRID\n")
cat(strrep("=", 78), "\n")

# --- prep()/prep_0010()/CTRL_*/fit_safe(): a COPY of 16_estimate_models.R's,
# so this diagnostic depends on no internal state of that script. The consistency manifest below prints the
# literal constants for eyeball-diffing against 16_estimate_models.R's source.

prep <- function(df) {
  df %>% mutate(
    pop_growth           = (pop_urbana_2022 - pop_urbana_2010_cg) / pop_urbana_2010_cg,
    log_pop_2010         = log(pop_urbana_2010_cg + 1),
    log_pib_pc           = log(pib_pc_2010        + 1),
    log_area_2010_km2    = log(area_urbana_2010_m2 / 1e6 + 0.001),
    log_density_2010     = log(pop_urbana_2010_cg / (area_urbana_2010_m2 / 1e6 + 0.001) + 1),
    log_pop_total_2010   = log(pop_total_2010 + 1),
    log_pop_total_2000   = log(pop_2000       + 1),
    log_area_2000_km2    = log(area_2000_m2 / 1e6 + 0.001),
    g_fora_suscept_slums = coalesce(g_slums_1022 - g_alta_slums_1022, 0),
    pct_area_periph_ext_leap = pct_area_peripheral + pct_area_extension + pct_area_leapfrog,
    regiao      = factor(regiao, levels = c("Sudeste", "Sul", "Nordeste", "Norte", "Centro-Oeste")),
    urban_class = factor(urban_class, levels = c("Urban Centers", "Metropolises",
                                                  "Metropolis Suburbs", "Regional Centers",
                                                  "Regional Centers Suburbs"))
  )
}

prep_0010 <- function(df) {
  df %>% mutate(
    pct_area_densif_infill_0010   = pct_area_densif_0010 + pct_area_infill_0010,
    log_dist_densif_0010          = log(pmax(dist_media_m_densif_0010,        1)),
    log_dist_densif_infill_0010   = log(pmax(dist_media_m_densif_infill_0010, 1)),
    pct_area_periph_ext_leap_0010 = pct_area_peripheral_0010 + pct_area_extension_0010 +
                                     pct_area_leapfrog_0010
  )
}

CTRL_ALTA <- c(
  "topo_prop_inclinado", "pp_alta_2010",
  "pct_nao_constru_fora_alta_2010_q1", "pct_nao_constru_fora_alta_2010_q4",
  "palma_rent", "palma_commute", "median_rent",
  "log_pib_pc", "log_pop_total_2000", "log_area_2000_km2", "zero_area_2000",
  "prop_favelas_2010", "regiao", "urban_class"
)
CTRL_DELTA   <- CTRL_ALTA
trat_compact <- "pct_area_densif_infill_0010"
trat_periph  <- "pct_area_periph_ext_leap_0010"

cat("\n", strrep("-", 78), "\n")
cat("CONSISTENCY MANIFEST -- diff these against 16_estimate_models.R's source\n")
cat(strrep("-", 78), "\n")
cat("MIN_POP_RISCO_2010:", MIN_POP_RISCO_2010, "\n")
cat("trat_compact       :", trat_compact, "\n")
cat("trat_periph        :", trat_periph,  "\n")
cat("CTRL_ALTA          :\n"); print(CTRL_ALTA)
cat("LIMIAR_SUSCEPT     :", LIMIAR_SUSCEPT, "\n")
cat("TIPOS              :\n"); print(TIPOS)
cat(strrep("-", 78), "\n")

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

report_specs <- function(specs, data, cluster_col = "NM_CIDADE") {
  purrr::imap_dfr(specs, function(s, nm) {
    trat_terms <- strsplit(s$trat, " \\+ ")[[1]]
    trat_terms <- trat_terms[trat_terms != "1"]
    mod <- fit_safe(make_f(s$y, s$trat, s$ctrl), data, cluster_col = cluster_col)
    if (is.null(mod)) return(tibble::tibble(spec = nm, note = "FIT FAILED"))
    coefs <- tryCatch(lmtest::coeftest(mod, vcov = vcov_clust(mod)), error = function(e) NULL)
    if (is.null(coefs)) return(tibble::tibble(spec = nm, n = attr(mod, "n"), note = "VCOV FAILED"))
    rows <- intersect(trat_terms, rownames(coefs))
    if (length(rows) == 0) rows <- setdiff(rownames(coefs), "(Intercept)")[1]
    tibble::tibble(
      spec      = nm,
      term      = rows,
      estimate  = coefs[rows, "Estimate"],
      se        = coefs[rows, "Std. Error"],
      p_value   = coefs[rows, "Pr(>|t|)"],
      n         = attr(mod, "n"),
      r_squared = summary(mod)$r.squared
    )
  }) %>% mutate(sig = case_when(p_value < 0.01 ~ "***", p_value < 0.05 ~ "**",
                                 p_value < 0.10 ~ "*", TRUE ~ ""))
}

y_high <- list(
  "(1) g_high — Compact"   = list(y = "g_alta",        trat = trat_compact,
                                   ctrl = c(CTRL_ALTA, "g_fora_alta")),
  "(2) g_high — Sprawl"    = list(y = "g_alta",        trat = trat_periph,
                                   ctrl = c(CTRL_ALTA, "g_fora_alta")),
  "(3) Dpp_high — Compact" = list(y = "delta_pp_alta", trat = trat_compact,
                                   ctrl = CTRL_DELTA),
  "(4) Dpp_high — Sprawl"  = list(y = "delta_pp_alta", trat = trat_periph,
                                   ctrl = CTRL_DELTA)
)

# --- Build the two datasets --------------------------------------------------

ds_base <- ds_new %>% prep() %>% prep_0010()

# (i) Current pipeline, exactly as 16_estimate_models.R does it.
ds_current <- ds_base %>% filter(pop_2010_risk_total > MIN_POP_RISCO_2010)

# (ii) C_NATIVE variant -- the primary native refit. The 2010 numerator and
# denominator both come from C_native (same definition as the 2022 side, which
# is already definition C and stays exactly as the current dataset has it), so
# g_alta and delta_pp_alta are built on one estimand throughout.
#
# pp_alta_2010 is ALSO a control in CTRL_ALTA. Leaving the allocated value in as
# a control while the outcome uses the native one would mix the two series
# inside a single specification, so it is overwritten with the C_native value
# (the column NAME is kept so CTRL_ALTA is unchanged; nothing is renamed in any
# data file).
c_native_series <- cmp10 %>%
  transmute(cod_mun,
            cnat_risk_2010  = risk_C_native,
            cnat_total_2010 = total_C_native)

# (iii) A-based variant, kept only as the clearly-labelled sensitivity it
# already was: 2010 from variant A (whole municipality, area-weighted) against
# an allocated definition-C 2022 side, so its g_alta mixes two estimands.
native_2010_series <- cmp10 %>%
  transmute(cod_mun,
            native_risk_2010  = risk_A_weighted_nat,
            native_total_2010 = total_all_cells_nat,
            native_risk_2010_B = risk_B_anyoverlap_nat)

ds_cnative <- ds_base %>%
  inner_join(c_native_series, by = "cod_mun") %>%
  mutate(
    pp_alta_2010_cnative = 100 * cnat_risk_2010 / pmax(cnat_total_2010, 1),
    pp_alta_2010         = pp_alta_2010_cnative,   # keep the CTRL_ALTA name
    delta_pp_alta        = pp_alta_2022 - pp_alta_2010_cnative,
    g_alta               = 100 * (pop_2022_risk_total - cnat_risk_2010) /
                             pmax(cnat_risk_2010, 1)
  ) %>%
  filter(cnat_risk_2010 > MIN_POP_RISCO_2010)

ds_native <- ds_base %>%
  inner_join(native_2010_series, by = "cod_mun") %>%
  mutate(
    pp_alta_2010_native = 100 * native_risk_2010 / pmax(native_total_2010, 1),
    pp_alta_2010        = pp_alta_2010_native,   # keep the CTRL_ALTA name
    delta_pp_alta       = pp_alta_2022 - pp_alta_2010_native,
    g_alta              = 100 * (pop_2022_risk_total - native_risk_2010) /
                            pmax(native_risk_2010, 1)
  ) %>%
  filter(native_risk_2010 > MIN_POP_RISCO_2010)

cat(sprintf("\nN after the > %d cut:\n", MIN_POP_RISCO_2010))
cat(sprintf("  current pipeline (allocated pop_2010_risk_total): %d rows (from %d)\n",
            nrow(ds_current), nrow(ds_base)))
cat(sprintf("  C_native variant (cnat_risk_2010)               : %d rows (from %d)\n",
            nrow(ds_cnative),
            nrow(ds_base %>% inner_join(c_native_series, by = "cod_mun"))))
cat(sprintf("  A-based sensitivity (native_risk_2010)          : %d rows (from %d)\n",
            nrow(ds_native),
            nrow(ds_base %>% inner_join(native_2010_series, by = "cod_mun"))))
cat(sprintf("  removed by the cut -- allocated: %d ; C_native: %d ; A-based: %d\n",
            nrow(ds_base) - nrow(ds_current),
            nrow(ds_base %>% inner_join(c_native_series, by = "cod_mun")) -
              nrow(ds_cnative),
            nrow(ds_base %>% inner_join(native_2010_series, by = "cod_mun")) -
              nrow(ds_native)))
cat("(These are rows removed by the cut; the regression N below is lower still,\n")
cat(" because fit_safe() additionally drops rows with missing controls.)\n")

# --- Do the g_alta extremes survive on the native series, with NO cut? -------

cat("\n--- g_alta extremes (|g_alta| > 500), BEFORE any population cut ---\n")
cat("  (6e CROSS-RULE WARNING: g_alta comes from the weighted pipeline; the\n")
cat("   g_alta_cnative / g_alta_native_A columns are any-overlap and variant-A\n")
cat("   reconstructions. A difference between them is NOT the grid's doing.)\n")
ds_nocut <- ds_base %>%
  inner_join(c_native_series, by = "cod_mun") %>%
  left_join(native_2010_series, by = "cod_mun") %>%
  mutate(g_alta_cnative = 100 * (pop_2022_risk_total - cnat_risk_2010) /
                            pmax(cnat_risk_2010, 1),
         g_alta_native_A = 100 * (pop_2022_risk_total - native_risk_2010) /
                            pmax(native_risk_2010, 1))
cat(sprintf("  current series      : %d municipalities with |g_alta| > 500\n",
            sum(abs(ds_base$g_alta) > 500, na.rm = TRUE)))
cat(sprintf("  C_native series     : %d municipalities with |g_alta_cnative| > 500\n",
            sum(abs(ds_nocut$g_alta_cnative) > 500, na.rm = TRUE)))
cat(sprintf("  A-based sensitivity : %d municipalities with |g_alta_native_A| > 500\n",
            sum(abs(ds_nocut$g_alta_native_A) > 500, na.rm = TRUE)))
cat(sprintf("  current series  max |g_alta|         : %.1f\n",
            max(abs(ds_base$g_alta), na.rm = TRUE)))
cat(sprintf("  C_native series max |g_alta_cnative| : %.1f\n",
            max(abs(ds_nocut$g_alta_cnative), na.rm = TRUE)))
print(ds_nocut %>%
        filter(abs(g_alta_cnative) > 500) %>%
        add_labels() %>%
        select(any_of(c("cod_mun", "mun_label", "uf", "g_alta", "g_alta_cnative",
                        "pop_2010_risk_total", "cnat_risk_2010",
                        "pop_2022_risk_total"))) %>%
        arrange(desc(abs(g_alta_cnative))),
      n = Inf, width = Inf)

# --- Refit both, plus the fully-native sensitivity ---------------------------

cat("\n--- (i) CURRENT PIPELINE (area-weighted since 6e; under the retired\n")
cat("        any-overlap rule this read 0.086 / 0.148 / 0.041** / -0.020, N = 317) ---\n")
res_current <- report_specs(y_high, ds_current)
print(res_current, n = Inf, width = Inf)

cat("\n--- (ii) C_NATIVE VARIANT -- 6e CROSS-RULE: C_native is any-overlap while\n")
cat("         the 2022 side and the live pipeline are weighted, so this column\n")
cat("         now mixes the weighting and grid changes and is no longer a clean\n")
cat("         native-vs-allocated read. Kept for continuity with the earlier run.\n")
cat("         (2010 numerator AND denominator from C_native;\n")
cat("         2022 side unchanged, already definition C) ---\n")
if (!URBAN_RULE_OK) {
  cat("*** SKIPPED: the urban-rule reconstruction did not reproduce urbano_2010,\n")
  cat("    so C_native is not trustworthy and is not refitted.\n")
  res_cnative <- tibble::tibble(spec = names(y_high), note = "C_native not reported")
} else {
  if (!TIPO_NEGLIGIBLE)
    cat(sprintf("    NOTE: C_native is urban-filtered ONLY; the growth-type filter covers\n    %.4f%% of urban-2010 population, which stays in C_native.\n",
                100 * share_pop))
  res_cnative <- report_specs(y_high, ds_cnative)
  print(res_cnative, n = Inf, width = Inf)
}

cat("\n--- (iii) A-BASED SENSITIVITY (2010 from variant A: whole municipality,\n")
cat("          area-weighted, against a definition-C 2022 side -- mixes two\n")
cat("          estimands, kept only as a labelled sensitivity) ---\n")
res_native <- report_specs(y_high, ds_native)
print(res_native, n = Inf, width = Inf)

# Sensitivity: 2022 side ALSO from the native grid, same variant-A rule, so
# g_alta compares like with like. Reported to separate a genuine native-grid
# result from the estimand-mixing the brief's variant unavoidably introduces.
native_2022_series <- nat22 %>%
  transmute(cod_mun,
            native_risk_2022  = risk_A_weighted_nat,
            native_total_2022 = total_all_cells_nat)

ds_native_both <- ds_base %>%
  inner_join(native_2010_series, by = "cod_mun") %>%
  inner_join(native_2022_series, by = "cod_mun") %>%
  mutate(
    pp_alta_2010  = 100 * native_risk_2010 / pmax(native_total_2010, 1),
    pp_alta_2022_native = 100 * native_risk_2022 / pmax(native_total_2022, 1),
    delta_pp_alta = pp_alta_2022_native - pp_alta_2010,
    g_alta        = 100 * (native_risk_2022 - native_risk_2010) /
                      pmax(native_risk_2010, 1)
  ) %>%
  filter(native_risk_2010 > MIN_POP_RISCO_2010)

cat("\n--- (iv) SENSITIVITY: BOTH years from the native grid under variant A\n")
cat("          (included only so (iii)'s mixed-estimand g_alta can be read) ---\n")
cat(sprintf("  N after the cut: %d\n", nrow(ds_native_both)))
res_native_both <- report_specs(y_high, ds_native_both)
print(res_native_both, n = Inf, width = Inf)

# --- Side-by-side table, with the published draft values --------------------

# results_used.md's Table 2 block (draft values, for reference only -- this
# script does not update any target).
published <- tibble::tibble(
  spec = names(y_high),
  published_draft = c(-0.026, 0.103, 0.040, -0.021),
  published_sig   = c("n.s.", "**", "***", "*")
)

has_cnative <- "estimate" %in% names(res_cnative)
combined <- published %>%
  left_join(res_current %>% select(spec, current_est = estimate,
                                   current_sig = sig, current_n = n), by = "spec")
if (has_cnative) {
  combined <- combined %>%
    left_join(res_cnative %>% select(spec, cnative_est = estimate,
                                     cnative_sig = sig, cnative_n = n), by = "spec")
} else {
  combined <- combined %>% mutate(cnative_est = NA_real_, cnative_sig = NA_character_,
                                  cnative_n = NA_integer_)
}
combined <- combined %>%
  left_join(res_native %>% select(spec, sensA_est = estimate,
                                  sensA_sig = sig, sensA_n = n), by = "spec") %>%
  left_join(res_native_both %>% select(spec, native_both_est = estimate,
                                       native_both_sig = sig, native_both_n = n),
            by = "spec") %>%
  select(spec,
         current_est, current_sig, current_n,
         cnative_est, cnative_sig, cnative_n,
         sensA_est, sensA_sig, sensA_n,
         published_draft, published_sig,
         native_both_est, native_both_sig, native_both_n)

cat("\n", strrep("=", 78), "\n")
cat("TABLE 2 -- FOUR COLUMNS PER COEFFICIENT\n")
cat(strrep("=", 78), "\n")
print(combined, n = Inf, width = Inf)
cat("\nColumns: current pipeline | C_native variant | A-based sensitivity |\n")
cat("published draft (results_used.md). The last pair of columns is the\n")
cat("both-years-native variant-A sensitivity. The published column is the\n")
cat("DRAFT's number, carried for reference only -- nothing in this script\n")
cat("updates any target.\n")

save_csv(res_current,     "step3_table2_current_pipeline.csv")
save_csv(res_cnative,     "step3_table2_c_native.csv")
save_csv(res_native,      "step3_table2_native_2010_variantA.csv")
save_csv(res_native_both, "step3_table2_native_both_years.csv")
save_csv(combined,        "step3_table2_comparison.csv")

cat("\n", strrep("=", 78), "\n")
cat("DONE. Outputs in:", diag_dir, "\n")
cat(strrep("=", 78), "\n")
