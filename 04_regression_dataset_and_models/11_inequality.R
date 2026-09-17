# =============================================================================
# 11_inequality.R
#
# Housing and urban-mobility inequality variables (2010 Census):
#
#   HOUSING (rented dwellings):
#     median_rent      : weighted median monthly rent (R$)
#     iqr_rent         : weighted IQR of rent (P75 - P25, R$)
#     palma_rent       : mean rent top 10% / mean rent bottom 40%
#                        (groups defined by household income)
#
#   MOBILITY (workers who commute):
#     pct_long_commute_low_inc : % workers with per-capita household income < 0.5 MW
#                                commuting > 1 hour to work
#     mean_commute_min         : weighted mean commute time (minutes, midpoints)
#     iqr_commute_min          : weighted IQR commute time (P75-P25, minutes)
#     pct_long_commute         : % workers with commute > 1h (V0662 >= 4)
#     palma_commute            : mean commute top 10% / mean commute bottom 40%
#                                (ordered by work income; >1 = richer commute longer)
#
# 2010 minimum wage: R$ 510/month -> poverty line = 0.5 MW per capita = R$ 255/month
#
# Source: IBGE 2010 Demographic Census, sample microdata via the censobr package
#   households : V0201 (occupancy status), V2011 (rent),
#                V6531 (household income per capita), V0010 (weight)
#   persons    : V6531 (household income per capita) -> commute poverty threshold
#                V6527 (main job income) -> palma_commute
#                V0662 (home-to-work commute time, categories 1-5)
#                V0010 (weight)
#
# Inputs:
#   data/processed_data/04_regression/amostra_universo.csv  (from 01_compose_sample.R)
#   data/raw_data/04_regression/censo_domicilios_2010.rds            (script 04)
#   data/raw_data/04_regression/censo_populacao_colnames_2010.rds    (script 04)
#   data/raw_data/04_regression/censo_populacao_mobilidade_2010.rds  (script 04)
#
# Outputs (data/processed_data/04_regression/tables/):
#   housing_mobility_inequality_municipio.csv
#   housing_mobility_inequality_arranjo.csv
# =============================================================================

source("04_regression_dataset_and_models/00_setup.R")

MW_2010      <- 510              # 2010 minimum wage (R$/month)
POVERTY_PC   <- 0.5 * MW_2010    # R$ 255 -- half minimum wage per capita (CadUnico poverty line)

cat("\n", strrep("=", 60), "\n")
cat("11_INEQUALITY.R\n")
cat(strrep("=", 60), "\n")

# =============================================================================
# 1) SAMPLE
# =============================================================================

cat("\n1) Loading sample...\n")

amostra <- read_csv(file.path(data_dir, "amostra_universo.csv"),
                    show_col_types = FALSE) %>%
  mutate(
    cod_mun   = formatC(as.integer(as.double(cod_mun)), width = 7, flag = "0"),
    CD_CIDADE = as.double(CD_CIDADE)
  )

cod_mun_vec <- unique(amostra$cod_mun)
cod_mun_int <- as.integer(cod_mun_vec)   # Arrow stores it as integer
cat(sprintf("  %d municipalities in sample\n", length(cod_mun_vec)))

# map cod_mun -> CD_CIDADE
mun_to_arr <- amostra %>%
  select(cod_mun, CD_CIDADE) %>%
  distinct()

# =============================================================================
# 2) HELPER FUNCTIONS
# =============================================================================

# Weighted quantile via cumulative weight (no interpolation)
wtd_quantile <- function(x, w, p) {
  ok  <- is.finite(x) & is.finite(w) & w > 0
  x   <- x[ok]; w <- w[ok]
  if (length(x) == 0) return(NA_real_)
  ord <- order(x)
  x   <- x[ord]; w <- w[ord]
  cw  <- cumsum(w) / sum(w)
  x[which(cw >= p)[1]]
}

# Weighted IQR (P75 - P25)
wtd_iqr <- function(x, w) {
  q75 <- wtd_quantile(x, w, 0.75)
  q25 <- wtd_quantile(x, w, 0.25)
  if (is.na(q75) || is.na(q25)) NA_real_ else q75 - q25
}

# Palma ratio of mean values:
#   weighted mean of x_val in the top `top_pct` by x_income /
#   weighted mean of x_val in the bottom `bot_pct` by x_income
palma_mean <- function(x_val, x_income, w, top_pct = 0.10, bot_pct = 0.40) {
  ok       <- is.finite(x_val) & is.finite(x_income) & is.finite(w) & w > 0
  x_val    <- x_val[ok]; x_income <- x_income[ok]; w <- w[ok]
  if (length(x_val) < 10) return(NA_real_)
  ord      <- order(x_income)
  x_val    <- x_val[ord]; w <- w[ord]
  cw       <- cumsum(w) / sum(w)
  bot      <- cw <= bot_pct
  top      <- cw >  (1 - top_pct)
  if (sum(bot) == 0 || sum(top) == 0) return(NA_real_)
  mb <- weighted.mean(x_val[bot], w[bot])
  mt <- weighted.mean(x_val[top], w[top])
  if (!is.finite(mb) || mb == 0) return(NA_real_)
  mt / mb
}

# Housing statistics for one group of rows
# df must have: V2011 (rent), hh_income_pc, V0010 (weight)
calc_housing <- function(df) {
  tibble(
    n_renters_w = sum(df$V0010, na.rm = TRUE),
    median_rent = wtd_quantile(df$V2011, df$V0010, 0.50),
    iqr_rent    = wtd_iqr(df$V2011, df$V0010),
    palma_rent  = palma_mean(df$V2011, df$hh_income_pc, df$V0010)
  )
}

# Mobility statistics for one group of rows
# df must have: commute_min, long_commute, hh_income, ind_income, V0010
calc_mobility <- function(df) {
  low_inc <- df[is.finite(df$hh_income) & df$hh_income < POVERTY_PC, ]
  pct_long_commute_low_inc <- if (nrow(low_inc) == 0 ||
                       sum(low_inc$V0010, na.rm = TRUE) == 0) {
    NA_real_
  } else {
    100 * sum(low_inc$V0010[low_inc$long_commute], na.rm = TRUE) /
          sum(low_inc$V0010, na.rm = TRUE)
  }
  tibble(
    n_workers_w              = sum(df$V0010, na.rm = TRUE),
    mean_commute_min         = weighted.mean(df$commute_min, df$V0010, na.rm = TRUE),
    iqr_commute_min          = wtd_iqr(df$commute_min, df$V0010),
    pct_long_commute         = 100 * weighted.mean(df$long_commute, df$V0010, na.rm = TRUE),
    pct_long_commute_low_inc = pct_long_commute_low_inc,
    # palma_commute: mean commute time of top 10% / bottom 40% (ordered by indiv. income)
    palma_commute            = palma_mean(df$commute_min, df$ind_income, df$V0010)
  )
}

# =============================================================================
# 3) HOUSING DATA -- rented dwellings
#
# V6531 (household income per capita) exists directly in the households
# file, so no join with the persons file is needed.
# =============================================================================

cat("\n3) Loading household microdata...\n")

dom_cache_path <- file.path(raw_data_dir, "censo_domicilios_2010.rds")
if (!file.exists(dom_cache_path))
  stop("Run 04_download_geobr_censobr.R first: ", dom_cache_path, " not found")
dom_arrow <- readRDS(dom_cache_path)

dom <- dom_arrow |>
  filter(code_muni %in% cod_mun_int) |>
  mutate(
    code_muni    = formatC(as.integer(code_muni), width = 7, flag = "0"),
    V0201        = as.integer(V0201),
    V2011        = as.numeric(V2011),
    hh_income_pc = as.numeric(V6531),
    V0010        = as.numeric(V0010)
  ) |>
  filter(V0201 == 3L, is.finite(V2011), V2011 > 0)

cat(sprintf("  %s rented dwellings with rent > 0\n", fmt(nrow(dom))))
cat(sprintf("  Missing hh_income_pc: %s (%.1f%%)\n",
            fmt(sum(is.na(dom$hh_income_pc))),
            100 * mean(is.na(dom$hh_income_pc))))
cat(sprintf("  Municipalities covered: %d\n", n_distinct(dom$code_muni)))

# -- 3a) By municipality -----------------------------------------------------
cat("  Computing statistics by municipality...\n")

housing_mun <- dom %>%
  group_by(cod_mun = code_muni) %>%
  group_modify(~ calc_housing(.x)) %>%
  ungroup()

cat(sprintf("  %d municipalities with housing data\n", nrow(housing_mun)))

# -- 3b) By arrangement (groups member municipalities) -----------------------
cat("  Computing statistics by arrangement...\n")

housing_arr <- dom %>%
  left_join(mun_to_arr, by = c("code_muni" = "cod_mun")) %>%
  filter(!is.na(CD_CIDADE)) %>%
  group_by(CD_CIDADE) %>%
  group_modify(~ calc_housing(.x)) %>%
  ungroup()

cat(sprintf("  %d arrangements with housing data\n", nrow(housing_arr)))

# =============================================================================
# 4) MOBILITY DATA -- commuting workers
# =============================================================================

cat("\n4) Loading person microdata...\n")

# col_ind_income: individual income to sort by for the commute Palma ratio
# V4718 (total monthly income) -> V6527 (main job)
pes_colnames_cache_path <- file.path(raw_data_dir, "censo_populacao_colnames_2010.rds")
if (!file.exists(pes_colnames_cache_path))
  stop("Run 04_download_geobr_censobr.R first: ", pes_colnames_cache_path, " not found")
pes_colnames <- readRDS(pes_colnames_cache_path)

col_ind_income <- intersect(c("V4718", "V6527"), pes_colnames)[1]
if (is.na(col_ind_income))
  stop("No individual income column found. Columns: ",
       paste(pes_colnames, collapse = ", "))

cat(sprintf("  Household income per capita (poverty threshold): V6531\n"))
cat(sprintf("  Individual income (commute Palma ratio): %s\n", col_ind_income))

cols_mob <- unique(c("code_muni", "V0662", "V6531", "V0010", col_ind_income))

pes_cache_path <- file.path(raw_data_dir, "censo_populacao_mobilidade_2010.rds")
if (!file.exists(pes_cache_path))
  stop("Run 04_download_geobr_censobr.R first: ", pes_cache_path, " not found")
pes_arrow <- readRDS(pes_cache_path)
if (!all(cols_mob %in% names(pes_arrow)))
  stop(pes_cache_path, " is missing required columns (", paste(setdiff(cols_mob, names(pes_arrow)), collapse = ", "),
       ") -- regenerate it with 04_download_geobr_censobr.R's exact read_population(columns = cols_mob) call.")

# Midpoints of the V0662 categories (2010 Census -- commute time):
#   1 = up to 5 min    -> 2.5 min
#   2 = 6-30 min       -> 18 min
#   3 = 31-60 min      -> 45 min
#   4 = 1h-2h          -> 90 min
#   5 = more than 2h   -> 150 min
COMMUTE_MID <- c("1" = 2.5, "2" = 18, "3" = 45, "4" = 90, "5" = 150)

pes <- pes_arrow |>
  filter(code_muni %in% cod_mun_int, !is.na(V0662)) |>
  mutate(
    code_muni  = formatC(as.integer(code_muni), width = 7, flag = "0"),
    V0662      = as.integer(as.character(V0662)),
    hh_income  = as.numeric(V6531),
    ind_income = as.numeric(.data[[col_ind_income]]),
    V0010      = as.numeric(V0010)
  ) |>
  filter(V0662 %in% 1:5) |>
  mutate(
    commute_min  = COMMUTE_MID[as.character(V0662)],
    long_commute = V0662 >= 4L
  )

cat(sprintf("  %s commuting workers\n", fmt(nrow(pes))))
cat(sprintf("  Commute > 1h (V0662 >= 4): %.1f%%\n",
            100 * weighted.mean(pes$long_commute, pes$V0010, na.rm = TRUE)))

# -- 4a) By municipality ------------------------------------------------------
cat("  Computing statistics by municipality...\n")

mobility_mun <- pes %>%
  group_by(cod_mun = code_muni) %>%
  group_modify(~ calc_mobility(.x)) %>%
  ungroup()

cat(sprintf("  %d municipalities with mobility data\n", nrow(mobility_mun)))

# -- 4b) By arrangement -------------------------------------------------------
cat("  Computing statistics by arrangement...\n")

mobility_arr <- pes %>%
  left_join(mun_to_arr, by = c("code_muni" = "cod_mun")) %>%
  filter(!is.na(CD_CIDADE)) %>%
  group_by(CD_CIDADE) %>%
  group_modify(~ calc_mobility(.x)) %>%
  ungroup()

cat(sprintf("  %d arrangements with mobility data\n", nrow(mobility_arr)))

# =============================================================================
# 5) MERGE, DIAGNOSE, AND SAVE
# =============================================================================

cat("\n5) Merging and saving...\n")

result_mun <- housing_mun %>%
  full_join(mobility_mun, by = "cod_mun") %>%
  arrange(cod_mun)

result_arr <- housing_arr %>%
  full_join(mobility_arr, by = "CD_CIDADE") %>%
  arrange(CD_CIDADE)

cat("\n  Preview -- municipalities (complete rows):\n")
result_mun %>%
  select(cod_mun, median_rent, iqr_rent, palma_rent,
         mean_commute_min, palma_commute, pct_long_commute_low_inc) %>%
  filter(complete.cases(.)) %>%
  print(n = 10)

cat("\n  Coverage (% non-NA) -- municipalities:\n")
result_mun %>%
  summarise(across(-cod_mun,
                   ~ sprintf("%.1f%%", 100 * mean(!is.na(.))))) %>%
  pivot_longer(everything()) %>%
  { for (i in seq_len(nrow(.)))
      cat(sprintf("    %-25s: %s\n", .$name[i], .$value[i])) }

path_mun <- file.path(tables_dir, "housing_mobility_inequality_municipio.csv")
path_arr <- file.path(tables_dir, "housing_mobility_inequality_arranjo.csv")

write_csv(result_mun, path_mun)
cat(sprintf("\n  OK %s  (%d rows)\n", basename(path_mun), nrow(result_mun)))

write_csv(result_arr, path_arr)
cat(sprintf("  OK %s  (%d rows)\n", basename(path_arr), nrow(result_arr)))

cat("\nVariables generated:\n")
cat("  HOUSING (rented dwellings):\n")
cat("    n_renters_w              : weighted count of renters\n")
cat("    median_rent              : weighted median monthly rent (R$)\n")
cat("    iqr_rent                 : weighted IQR P75-P25 (R$)\n")
cat("    palma_rent               : mean rent top 10% / bottom 40% (by household income)\n")
cat("  MOBILITY (commuting workers; midpoints: 1->2.5, 2->18, 3->45, 4->90, 5->150 min):\n")
cat("    n_workers_w              : weighted count of workers\n")
cat("    mean_commute_min         : weighted mean commute time (min)\n")
cat("    iqr_commute_min          : weighted IQR of commute time (min)\n")
cat("    pct_long_commute         : % workers with commute > 1h\n")
cat("    pct_long_commute_low_inc : % workers with per-capita income < 0.5 MW AND commute > 1h\n")
cat("    palma_commute            : mean commute top 10% / bottom 40% (by individual income)\n")

cat("\n", strrep("=", 60), "\n")
cat("DONE\n")
cat(strrep("=", 60), "\n")
