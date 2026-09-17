# =============================================================================
# diagnostics/grid_resolution_and_growth_composition.R
#
# READ-ONLY diagnostic. Writes only to
# data/processed_data/03_urban_footprint/diagnostics/. Touches no pipeline
# script, no column, no target, no manuscript file.
#
# Answers two questions put by the researcher on 2026-09-12:
#
# CHECK A -- grid resolution vs. the study's urban definition.
#   The IBGE statistical grid is 200 m inside IBGE's own urban classification
#   and 1 km inside its rural one. That boundary is IBGE's, not this study's:
#   the study calls a cell urban when built_pct >= 10 AND density >= 300
#   inhab/km2 (04_delimit_urban_extent.R L49/L54). The two need not agree, so
#   some cells the study calls urban are 1 km cells drawn from IBGE's rural
#   side. This quantifies how many, where, and what they carry.
#
#   Three measures degrade on a 1 km cell, each for a different reason:
#     - prop_suscept_total: one area fraction for 1 km2 instead of 25 separate
#       200 m fractions, so the weighting (MIGRATION_PLAN.md 6e) is applied at
#       1/25th the spatial detail and cannot place population within the cell.
#     - the 1000 m extension/leapfrog radius (05_classify_growth_types.R L62):
#       the cell's own width equals the whole threshold, so the distinction
#       turns on which pixels the cell rasterizes into.
#     - the 300 inhab/km2 density threshold: on a 200 m cell that is ~12
#       people, on a 1 km cell 300. A 1 km cell needs 25x the head count to
#       cross the same threshold, so sparse settlement is systematically
#       likelier to fail the urban test on the rural-side grid.
#
# CHECK B -- stock vs. flow inside the compact and sprawl aggregates.
#   Both aggregates mix cells already urban at t1 with cells that became urban
#   between t1 and t2:
#     sprawl  = peripheral (already urban, minor patch)  <- STOCK
#             + extension + leapfrog (new)                <- FLOW
#     compact = densification (already urban, major patch) <- STOCK
#             + infill (new)                              <- FLOW
#   So "new residents in sprawl areas" is not the same quantity as "residents
#   in cells that became sprawl". This decomposes both, for population and
#   area, both epochs, at municipality and arrangement level.
#
# Run from the repository root:
#   source("03_urban_footprint_and_growth_types/diagnostics/grid_resolution_and_growth_composition.R")
# =============================================================================

source("03_urban_footprint_and_growth_types/00_setup.R")

library(sfarrow)
library(readr)
library(tidyr)

out_dir <- file.path(processed_data_dir, "diagnostics")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

save_csv <- function(df, name) {
  p <- file.path(out_dir, name)
  write_csv(df, p)
  cat(sprintf("  saved: %s\n", p))
  invisible(p)
}

TIPOS   <- c("consolidated", "densification", "infill",
             "extension", "leapfrog", "peripheral")
COMPACT <- c("densification", "infill")
SPRAWL  <- c("peripheral", "extension", "leapfrog")
STOCK   <- c("consolidated", "densification", "peripheral")   # urban at t1
FLOW    <- c("infill", "extension", "leapfrog")               # became urban

cat("\n", strrep("=", 78), "\n")
cat("GRID RESOLUTION AND GROWTH-TYPE COMPOSITION\n")
cat(strrep("=", 78), "\n")

# =============================================================================
# CHECK A
# =============================================================================

cat("\n", strrep("=", 78), "\n")
cat("CHECK A -- 1 km cells inside the study's urban footprint\n")
cat(strrep("=", 78), "\n")

grade_path <- file.path(processed_data_dir, "crescimento_urbano",
                        "grade_growth_types_2010_2022.parquet")
if (!file.exists(grade_path))
  stop("grid not found: ", grade_path)

cat("\nReading the classified grid...\n")
g <- arrow::read_parquet(
  grade_path,
  col_select = dplyr::all_of(c("cod_mun", "populacao", "pop_2010_alocada",
                               "prop_suscept_total", "area_total",
                               "urbano_2010", "urbano_2020", "tipo_crescimento"))
) %>%
  mutate(
    populacao          = coalesce(as.numeric(populacao), 0),
    pop_2010_alocada   = coalesce(as.numeric(pop_2010_alocada), 0),
    prop_suscept_total = coalesce(as.numeric(prop_suscept_total), 0),
    area_total         = as.numeric(area_total),
    cod_mun            = as.character(cod_mun)
  )
cat(sprintf("  %s cells\n", fmt(nrow(g))))

# Resolution classes, read off the geometry rather than assumed. A 200 m cell
# is 40,000 m2 and a 1 km cell 1,000,000 m2; the midpoint separates them with
# room for edge cells clipped by a municipal boundary.
cat("\nDistinct cell areas actually present (top 10 by frequency):\n")
print(g %>% count(area_total, sort = TRUE) %>% head(10), n = 10)

g <- g %>% mutate(res_class = if_else(area_total >= 5e5, "1km", "200m"))

cat("\nResolution split, whole grid:\n")
print(g %>% count(res_class))

# --- A1. urban cells by resolution, each year --------------------------------
a1 <- bind_rows(
  g %>% filter(urbano_2010 == TRUE) %>%
    group_by(year = "2010", res_class) %>%
    summarise(n_cells = n(), pop = sum(pop_2010_alocada),
              area_km2 = sum(area_total) / 1e6, .groups = "drop"),
  g %>% filter(urbano_2020 == TRUE) %>%
    group_by(year = "2022", res_class) %>%
    summarise(n_cells = n(), pop = sum(populacao),
              area_km2 = sum(area_total) / 1e6, .groups = "drop")
) %>%
  group_by(year) %>%
  mutate(pct_cells = 100 * n_cells / sum(n_cells),
         pct_pop   = 100 * pop     / sum(pop),
         pct_area  = 100 * area_km2 / sum(area_km2)) %>%
  ungroup()

cat("\n--- A1. Cells the STUDY calls urban, by grid resolution ---\n")
print(a1, width = Inf)
save_csv(a1, "checkA1_urban_cells_by_resolution.csv")

# --- A2. by growth type ------------------------------------------------------
a2 <- g %>%
  filter(tipo_crescimento %in% TIPOS) %>%
  group_by(tipo_crescimento, res_class) %>%
  summarise(n_cells  = n(),
            pop_2010 = sum(pop_2010_alocada),
            pop_2022 = sum(populacao),
            area_km2 = sum(area_total) / 1e6,
            .groups = "drop") %>%
  group_by(tipo_crescimento) %>%
  mutate(pct_cells    = 100 * n_cells  / sum(n_cells),
         pct_pop_2010 = 100 * pop_2010 / sum(pop_2010),
         pct_pop_2022 = 100 * pop_2022 / sum(pop_2022),
         pct_area     = 100 * area_km2 / sum(area_km2)) %>%
  ungroup()

cat("\n--- A2. Share of each growth type carried by 1 km cells ---\n")
print(a2 %>% filter(res_class == "1km") %>%
        select(tipo_crescimento, n_cells, pct_cells, pct_pop_2010,
               pct_pop_2022, pct_area), width = Inf)
save_csv(a2, "checkA2_growth_type_by_resolution.csv")

# --- A3. susceptibility carried at 1 km --------------------------------------
a3 <- g %>%
  filter(tipo_crescimento %in% TIPOS, prop_suscept_total > 0) %>%
  group_by(res_class) %>%
  summarise(n_cells = n(),
            risk_pop_2010 = sum(pop_2010_alocada * prop_suscept_total),
            risk_pop_2022 = sum(populacao        * prop_suscept_total),
            mean_prop     = mean(prop_suscept_total),
            .groups = "drop") %>%
  mutate(pct_risk_2010 = 100 * risk_pop_2010 / sum(risk_pop_2010),
         pct_risk_2022 = 100 * risk_pop_2022 / sum(risk_pop_2022))

cat("\n--- A3. At-risk population by resolution (the 6e weighting's detail) ---\n")
print(a3, width = Inf)
save_csv(a3, "checkA3_risk_population_by_resolution.csv")

# --- A4. per-municipality distribution, against the treatment variables ------
a4 <- g %>%
  filter(urbano_2020 == TRUE) %>%
  group_by(cod_mun) %>%
  summarise(n_urban_cells = n(),
            n_1km         = sum(res_class == "1km"),
            pop_urban     = sum(populacao),
            pop_1km       = sum(populacao[res_class == "1km"]),
            .groups = "drop") %>%
  mutate(share_1km_cells = 100 * n_1km   / n_urban_cells,
         share_1km_pop   = 100 * pop_1km / pmax(pop_urban, 1))

cat("\n--- A4. Per-municipality share of urban cells that are 1 km ---\n")
cat("Quantiles of share_1km_cells (all municipalities with urban cells):\n")
print(round(quantile(a4$share_1km_cells, probs = seq(0, 1, 0.1), na.rm = TRUE), 2))

reg_path <- processed_data_path("04_regression", "tables",
                                "dataset_regressao_municipio.csv")
if (file.exists(reg_path)) {
  reg <- read_csv(reg_path, show_col_types = FALSE) %>%
    mutate(cod_mun = as.character(cod_mun)) %>%
    select(any_of(c("cod_mun", "NM_CIDADE",
                    "pct_area_densif_infill_0010",
                    "pct_area_periph_ext_leap_0010",
                    "pop_2010_risk_total", "g_alta", "delta_pp_alta")))
  a4 <- a4 %>% inner_join(reg, by = "cod_mun")

  cat(sprintf("\nJoined to the regression sample: %d municipalities\n", nrow(a4)))
  cat("\nShare-of-1km-cells deciles, with the treatment variables alongside.\n")
  cat("If the municipalities with the most 1 km urban cells are also the\n")
  cat("high-sprawl ones, the sprawl coefficient and the coarse grid are\n")
  cat("confounded. No regression is run -- read the columns together.\n\n")

  a4d <- a4 %>%
    mutate(decile = ntile(share_1km_cells, 10)) %>%
    group_by(decile) %>%
    summarise(n = n(),
              share_1km_cells_mean = mean(share_1km_cells),
              share_1km_pop_mean   = mean(share_1km_pop),
              sprawl_treat_mean    = mean(pct_area_periph_ext_leap_0010, na.rm = TRUE),
              compact_treat_mean   = mean(pct_area_densif_infill_0010,   na.rm = TRUE),
              risk_pop_2010_median = median(pop_2010_risk_total, na.rm = TRUE),
              .groups = "drop")
  print(a4d, width = Inf)

  cat("\nRank correlation, share_1km_cells vs. each treatment:\n")
  cat(sprintf("  vs sprawl  : %.4f\n",
              cor(a4$share_1km_cells, a4$pct_area_periph_ext_leap_0010,
                  method = "spearman", use = "complete.obs")))
  cat(sprintf("  vs compact : %.4f\n",
              cor(a4$share_1km_cells, a4$pct_area_densif_infill_0010,
                  method = "spearman", use = "complete.obs")))

  cat("\n20 municipalities with the highest share of 1 km urban cells:\n")
  print(a4 %>% arrange(desc(share_1km_cells)) %>% head(20) %>%
          select(any_of(c("cod_mun", "NM_CIDADE", "n_urban_cells",
                          "share_1km_cells", "share_1km_pop",
                          "pct_area_periph_ext_leap_0010",
                          "pct_area_densif_infill_0010"))), width = Inf)
  save_csv(a4d, "checkA4_resolution_deciles_vs_treatment.csv")
} else {
  cat("\n  NOTE: regression dataset not found -- the treatment comparison is skipped.\n")
}
save_csv(a4, "checkA4_municipality_resolution_shares.csv")

# =============================================================================
# CHECK B
# =============================================================================

cat("\n", strrep("=", 78), "\n")
cat("CHECK B -- stock vs. flow inside the compact and sprawl aggregates\n")
cat(strrep("=", 78), "\n")

decompose <- function(path, unit_label) {
  if (!file.exists(path)) {
    cat(sprintf("\n  %s not found -- skipped.\n", basename(path)))
    return(NULL)
  }
  m <- read_csv(path, show_col_types = FALSE)

  # Restrict to the regression sample at municipality level, so the figures
  # match Table 1's universe; arrangements are reported as produced.
  if (unit_label == "municipality" && exists("reg") && !is.null(reg)) {
    m <- m %>% mutate(cod_mun = as.character(cod_mun)) %>%
      semi_join(reg %>% select(cod_mun), by = "cod_mun")
  }

  tot <- function(pref) sapply(TIPOS, function(t) {
    col <- paste0(pref, t); if (col %in% names(m)) sum(m[[col]], na.rm = TRUE) else NA_real_
  })

  tibble::tibble(
    unit          = unit_label,
    tipo          = TIPOS,
    aggregate     = if_else(TIPOS %in% COMPACT, "compact",
                    if_else(TIPOS %in% SPRAWL, "sprawl", "consolidated")),
    branch        = if_else(TIPOS %in% STOCK, "stock (urban at t1)", "flow (became urban)"),
    pop_2010      = tot("pop_2010_"),
    pop_2022      = tot("pop_2022_"),
    risk_2010     = tot("pop_2010_risk_"),
    risk_2022     = tot("pop_2022_risk_"),
    area_m2       = tot("area_m2_"),
    n_cel         = tot("n_cel_")
  ) %>%
    mutate(delta_pop  = pop_2022  - pop_2010,
           delta_risk = risk_2022 - risk_2010,
           area_km2   = area_m2 / 1e6)
}

met_mun <- file.path(processed_data_dir, "metricas", "metricas_municipio_2010_2022.csv")
met_arr <- file.path(processed_data_dir, "metricas", "metricas_arranjo_2010_2022.csv")

b <- bind_rows(decompose(met_mun, "municipality"),
               decompose(met_arr, "arrangement"))

cat("\n--- B1. Full decomposition, per subtype ---\n")
print(b %>% select(unit, aggregate, branch, tipo, pop_2010, pop_2022, delta_pop,
                   risk_2010, risk_2022, delta_risk, area_km2, n_cel),
      n = Inf, width = Inf)
save_csv(b, "checkB1_growth_subtype_decomposition.csv")

cat("\n--- B2. Stock vs. flow within each aggregate ---\n")
b2 <- b %>%
  filter(aggregate %in% c("compact", "sprawl")) %>%
  group_by(unit, aggregate, branch) %>%
  summarise(across(c(pop_2010, pop_2022, delta_pop, risk_2010, risk_2022,
                     delta_risk, area_km2, n_cel), sum), .groups = "drop") %>%
  group_by(unit, aggregate) %>%
  mutate(pct_of_delta_pop  = 100 * delta_pop  / sum(delta_pop),
         pct_of_delta_risk = 100 * delta_risk / sum(delta_risk),
         pct_of_area       = 100 * area_km2   / sum(area_km2)) %>%
  ungroup()
print(b2, n = Inf, width = Inf)
save_csv(b2, "checkB2_stock_vs_flow.csv")

cat("\nRead B2 this way: 'new residents in sprawl areas' as Table 1 reports it\n")
cat("is the delta over ALL THREE sprawl subtypes, which includes peripheral --\n")
cat("cells already urban in 2010. The flow row is the part that is genuinely\n")
cat("new urban land; the stock row is population change inside land that was\n")
cat("already urban at t1. The same split applies to compact\n")
cat("(densification = stock, infill = flow).\n")

cat("\n", strrep("=", 78), "\n")
cat("DONE. Outputs in:", out_dir, "\n")
cat(strrep("=", 78), "\n")
