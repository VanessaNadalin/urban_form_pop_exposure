# =============================================================================
# diagnostics/cprm_entrants_and_arrangement_denominators.R
#
# READ-ONLY. Writes only CSVs under
# data/processed_data/03_urban_footprint/diagnostics/. No pipeline script is
# sourced-for-effect, no pipeline output is overwritten, no column renamed.
# The funnel in CHECK 1 is re-derived here in a scratch object;
# 01_define_sample.R is never run and amostra_municipios.rds is never rewritten.
#
# CHECK 1 -- municipalities that enter the processing universe ONLY through the
#            CPRM risk layer, and what the sample would be without that union.
# CHECK 2 -- arrangement aggregation: which members enter which denominator, and
#            what the mapped-members-only alternative would give.
#
# Run from the repository root:
#   source("03_urban_footprint_and_growth_types/diagnostics/cprm_entrants_and_arrangement_denominators.R")
# =============================================================================

source("03_urban_footprint_and_growth_types/00_setup.R")

library(sf)
library(readr)
library(readxl)
library(tidyr)

out_dir <- file.path(processed_data_dir, "diagnostics")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
save_csv <- function(df, name) {
  p <- file.path(out_dir, name); write_csv(df, p)
  cat(sprintf("  saved: %s\n", p)); invisible(p)
}
# Direct equality test for g_alta, which the RATIO cannot express. An
# arrangement with no at-risk population in either year has g_current = 0 and
# g_mapped = 0: the two AGREE, but the ratio is 0/0 = NaN and drops out of any
# na.rm summary. Counting "ratio == 1" therefore undercounts agreement badly
# (79 of 225 on the all-354 run, with the other 146 being 0/0). Comparing the
# two values directly is the statistic that answers the question.
report_g_equality <- function(df, label) {
  eq  <- abs(df$g_current - df$g_mapped) < 1e-9
  nan <- is.nan(df$ratio_g)
  cat(sprintf("\n  %s\n", label))
  cat(sprintf("    g_current == g_mapped (direct)      : %d of %d\n",
              sum(eq, na.rm = TRUE), nrow(df)))
  cat(sprintf("    of which ratio_g is 0/0 = NaN       : %d (both g are 0 -- they agree,\n      but the ratio is undefined, so a ratio-based count misses them)\n",
              sum(nan)))
  if (any(!eq, na.rm = TRUE)) {
    cat(sprintf("    *** %d arrangement(s) where g ACTUALLY differs -- the numerator is NOT\n        untouched there. Inspect before trusting the decision's premise:\n",
                sum(!eq, na.rm = TRUE)))
    print(df[!eq, c("CD_CIDADE", "n_members", "n_unmapped",
                    "risk10_all", "risk10_mapped", "risk22_all", "risk22_mapped",
                    "g_current", "g_mapped")], n = 20, width = Inf)
  }
}

pct <- function(x) sprintf("%.2f%%", 100 * x)

# Ratio summary that survives non-finite values. An arrangement whose members
# are ALL unmapped has a mapped-only denominator of 0, so the ratios come back
# NaN (0/0) or Inf (x/0). Those poison min()/max() and are themselves a
# finding, so they are counted and excluded rather than silently propagated.
# Returns a tibble: print(tbl, width = Inf) is valid, print.data.frame is not
# (print.default coerces width to integer and Inf becomes NA -- "invalid
# printing width", which is what aborted this script's first run).
summarise_ratios <- function(df, cols) {
  dplyr::bind_rows(lapply(cols, function(cl) {
    v   <- df[[cl]]
    fin <- v[is.finite(v)]
    tibble::tibble(
      ratio       = cl,
      n_finite    = length(fin),
      n_nonfinite = sum(!is.finite(v)),
      min = if (length(fin)) min(fin)                     else NA_real_,
      p10 = if (length(fin)) unname(quantile(fin, .10))   else NA_real_,
      med = if (length(fin)) median(fin)                  else NA_real_,
      p90 = if (length(fin)) unname(quantile(fin, .90))   else NA_real_,
      max = if (length(fin)) max(fin)                     else NA_real_
    )
  }))
}

cat("\n", strrep("=", 78), "\n")
cat("CPRM ENTRANTS AND ARRANGEMENT DENOMINATORS\n")
cat(strrep("=", 78), "\n")

# =============================================================================
# CHECK 1
# =============================================================================
cat("\n", strrep("=", 78), "\n")
cat("CHECK 1 -- municipalities entering only via the CPRM risk layer\n")
cat(strrep("=", 78), "\n")

risk_proc_dir <- processed_data_path("02_hazard_zones")

# --- susceptibility set, replicating 01_define_sample.R L31-42 ---------------
sus <- st_read(file.path(risk_proc_dir, "susceptibilidade_unida.gpkg"), quiet = TRUE)
col_mun  <- intersect(c("COD_MUNICIPIO", "cd_geocmun", "cod_mun"), names(sus))[1]
cod_gpkg <- unique(as.character(sus[[col_mun]]))
cod_gpkg <- cod_gpkg[!is.na(cod_gpkg) & nchar(cod_gpkg) == 7]
cat(sprintf("\n  susceptibilidade_unida.gpkg          : %d municipalities\n", length(cod_gpkg)))

# --- transbordamento exclusion, replicating L100-104 -------------------------
transbord_csv <- file.path(risk_proc_dir, "municipios_transbordamento.csv")
cod_spillover_only <- character(0)
if (file.exists(transbord_csv)) {
  tb <- read_csv(transbord_csv, show_col_types = FALSE)
  ccol <- intersect(c("cod_mun", "COD_MUNICIPIO"), names(tb))[1]
  cod_spillover_only <- as.character(tb[[ccol]])
  cod_spillover_only <- cod_spillover_only[nchar(cod_spillover_only) == 7]
  cat(sprintf("  municipios_transbordamento.csv       : %d spillover-only\n",
              length(cod_spillover_only)))
} else {
  cat("  municipios_transbordamento.csv NOT FOUND -- no exclusion applied.\n")
}
cod_gpkg <- setdiff(cod_gpkg, cod_spillover_only)
cat(sprintf("  susceptibility after exclusion       : %d\n", length(cod_gpkg)))

# --- CPRM risk set, replicating L107-110 -------------------------------------
cod_risco <- st_read(file.path(risk_proc_dir, "risco_preparado.gpkg"), quiet = TRUE) |>
  st_drop_geometry() |> dplyr::pull(cd_geocmun) |>
  as.character() |> substr(1, 7) |> unique()
cod_risco <- cod_risco[!is.na(cod_risco) & nchar(cod_risco) == 7]
cat(sprintf("  risco_preparado.gpkg                 : %d municipalities\n", length(cod_risco)))

risk_only <- setdiff(cod_risco, cod_gpkg)
cat(sprintf("\n  >>> RISK-ONLY ENTRANTS: %d municipalities\n", length(risk_only)))

# --- labels: DUR + population ------------------------------------------------
DUR <- read_excel(file.path(raw_data_dir, "DUR_Municipios.xlsx")) |>
  mutate(cod_mun    = as.character(COD_MUNICIPIO),
         em_arranjo = NOME_MUNICIPIO != NM_CIDADE)
pop <- read_excel(file.path(raw_data_dir, "tabela4709.xlsx"), skip = 4, col_names = FALSE)
colnames(pop) <- c("cod_mun", "nome_raw", "pop_2022")
pop <- pop |> mutate(cod_mun = as.character(cod_mun), pop_2022 = as.numeric(pop_2022)) |>
  filter(nchar(cod_mun) == 7)

UF <- c("11"="RO","12"="AC","13"="AM","14"="RR","15"="PA","16"="AP","17"="TO",
        "21"="MA","22"="PI","23"="CE","24"="RN","25"="PB","26"="PE","27"="AL",
        "28"="SE","29"="BA","31"="MG","32"="ES","33"="RJ","35"="SP","41"="PR",
        "42"="SC","43"="RS","50"="MS","51"="MT","52"="GO","53"="DF")

reg_path <- processed_data_path("04_regression", "tables", "dataset_regressao_municipio.csv")
reg <- if (file.exists(reg_path))
  read_csv(reg_path, show_col_types = FALSE) |> mutate(cod_mun = as.character(cod_mun)) else NULL

tab1 <- tibble::tibble(cod_mun = risk_only) |>
  left_join(DUR |> select(cod_mun, NOME_MUNICIPIO, NM_CIDADE, CD_CIDADE, em_arranjo),
            by = "cod_mun") |>
  left_join(pop |> select(cod_mun, pop_2022), by = "cod_mun") |>
  mutate(uf = UF[substr(cod_mun, 1, 2)],
         in_regression_395 = if (!is.null(reg)) cod_mun %in% reg$cod_mun else NA) |>
  arrange(desc(pop_2022))

cat(sprintf("  of which in the 395 regression dataset: %d\n",
            sum(tab1$in_regression_395, na.rm = TRUE)))
print(tab1 |> select(cod_mun, NOME_MUNICIPIO, uf, pop_2022, em_arranjo,
                     in_regression_395), n = Inf, width = Inf)
save_csv(tab1, "check1_risk_only_entrants.csv")

# --- cross with the eight zero-exposure municipalities (6c1) -----------------
if (!is.null(reg) && all(c("pop_2010_risk_total", "pop_2022_risk_total") %in% names(reg))) {
  zeros <- reg |> filter(pop_2010_risk_total == 0, pop_2022_risk_total == 0) |> pull(cod_mun)
  cat(sprintf("\n  Municipalities with pop_2010_risk_total = pop_2022_risk_total = 0: %d\n",
              length(zeros)))
  ov <- intersect(zeros, risk_only)
  cat(sprintf("  OVERLAP with the risk-only entrants: %d\n", length(ov)))
  if (length(ov) > 0)
    print(tab1 |> filter(cod_mun %in% ov) |>
            select(cod_mun, NOME_MUNICIPIO, uf, pop_2022), n = Inf)
  save_csv(tibble::tibble(cod_mun = zeros,
                          also_risk_only = cod_mun %in% risk_only),
           "check1_zero_exposure_cross.csv")
}

# --- the funnel WITHOUT the union, recomputed --------------------------------
cat("\n--- Funnel re-run with exposed = susceptibility only (no CPRM union) ---\n")

build_sample <- function(exposed) {
  exp_arr <- DUR |> filter(em_arranjo, cod_mun %in% exposed) |> pull(CD_CIDADE) |> unique()
  s <- bind_rows(
    DUR |> filter(em_arranjo, CD_CIDADE %in% exp_arr) |>
      select(cod_mun, CD_CIDADE, NM_CIDADE, em_arranjo),
    DUR |> filter(!em_arranjo, cod_mun %in% exposed) |>
      select(cod_mun, CD_CIDADE, NM_CIDADE, em_arranjo)
  ) |> distinct(cod_mun, .keep_all = TRUE) |>
    left_join(pop |> select(cod_mun, pop_2022), by = "cod_mun")
  bind_rows(
    s |> filter(!em_arranjo, pop_2022 > 50000),
    s |> filter(em_arranjo) |> group_by(CD_CIDADE) |>
      mutate(pop_arranjo = sum(pop_2022, na.rm = TRUE)) |> ungroup() |>
      filter(pop_arranjo > 50000)
  )
}

s_current <- build_sample(union(cod_gpkg, cod_risco))
s_nounion <- build_sample(cod_gpkg)

funnel <- tibble::tibble(
  scenario           = c("current (union)", "susceptibility only"),
  universe           = c(nrow(s_current), nrow(s_nounion)),
  arrangements       = c(n_distinct(s_current$CD_CIDADE), n_distinct(s_nounion$CD_CIDADE)),
  # the regression sample is the tem_susceptibilidade subset (01_compose_sample.R:41)
  regression_sample  = c(sum(s_current$cod_mun %in% cod_gpkg),
                         sum(s_nounion$cod_mun %in% cod_gpkg))
)
print(funnel, width = Inf)
cat("\n  Note: 'regression_sample' applies 04/01_compose_sample.R:41's\n")
cat("  tem_susceptibilidade == TRUE restriction to each universe.\n")
save_csv(funnel, "check1_funnel_with_and_without_union.csv")

# =============================================================================
# CHECK 2
# =============================================================================
cat("\n", strrep("=", 78), "\n")
cat("CHECK 2 -- arrangement denominators: all members vs. mapped members only\n")
cat(strrep("=", 78), "\n")

samp <- readRDS(file.path(processed_data_dir, "amostra_municipios.rds")) |>
  mutate(cod_mun = as.character(cod_mun))
met  <- read_csv(file.path(processed_data_dir, "metricas",
                           "metricas_municipio_2010_2022.csv"),
                 show_col_types = FALSE) |>
  mutate(cod_mun = as.character(cod_mun))

# Replicate 07_aggregate_municipality_metrics.R L352-361 exactly: unmatched
# municipalities become their own singleton arrangement.
d <- met |>
  left_join(samp |> select(cod_mun, CD_CIDADE, tem_susceptibilidade) |> distinct(),
            by = "cod_mun") |>
  mutate(cod_mun_d = as.double(cod_mun),
         CD_CIDADE = if_else(is.na(CD_CIDADE), cod_mun_d, CD_CIDADE),
         mapped    = coalesce(tem_susceptibilidade, FALSE))

arr <- d |>
  group_by(CD_CIDADE) |>
  summarise(
    n_members        = n(),
    n_unmapped       = sum(!mapped),
    # (b) current denominators: ALL members
    pop10_all        = sum(pop_2010_total,      na.rm = TRUE),
    pop22_all        = sum(pop_2022_total,      na.rm = TRUE),
    # mapped-members-only denominators
    pop10_mapped     = sum(pop_2010_total[mapped],  na.rm = TRUE),
    pop22_mapped     = sum(pop_2022_total[mapped],  na.rm = TRUE),
    # (c) risk numerators, both ways
    risk10_all       = sum(pop_2010_risk_total, na.rm = TRUE),
    risk22_all       = sum(pop_2022_risk_total, na.rm = TRUE),
    risk10_mapped    = sum(pop_2010_risk_total[mapped], na.rm = TRUE),
    risk22_mapped    = sum(pop_2022_risk_total[mapped], na.rm = TRUE),
    pop_mun22_all    = sum(pop_mun_2022,        na.rm = TRUE),
    pop_mun22_unmap  = sum(pop_mun_2022[!mapped], na.rm = TRUE),
    .groups = "drop"
  ) |>
  mutate(
    share_pop_unmapped = 100 * pop_mun22_unmap / pmax(pop_mun22_all, 1),
    # exactly 13_dependent_variables.R L96-101, on each denominator
    pp10_current = 100 * risk10_all    / pop10_all,
    pp10_mapped  = 100 * risk10_mapped / pop10_mapped,
    pp22_current = 100 * risk22_all    / pop22_all,
    pp22_mapped  = 100 * risk22_mapped / pop22_mapped,
    dpp_current  = pp22_current - pp10_current,
    dpp_mapped   = pp22_mapped  - pp10_mapped,
    g_current    = 100 * (risk22_all    - risk10_all)    / pmax(risk10_all, 1),
    g_mapped     = 100 * (risk22_mapped - risk10_mapped) / pmax(risk10_mapped, 1),
    ratio_pp10   = pp10_current / pp10_mapped,
    ratio_dpp    = dpp_current  / dpp_mapped,
    ratio_g      = g_current    / g_mapped,
    risk_from_unmapped_10 = risk10_all - risk10_mapped,
    risk_from_unmapped_22 = risk22_all - risk22_mapped
  )

cat(sprintf("\n  Arrangements (as script 07 produces them): %d\n", nrow(arr)))
cat(sprintf("  With >= 1 unmapped member                : %d (%s)\n",
            sum(arr$n_unmapped > 0), pct(mean(arr$n_unmapped > 0))))
cat(sprintf("  Population in unmapped members, national : %s of %s (%s)\n",
            fmt(round(sum(arr$pop_mun22_unmap))), fmt(round(sum(arr$pop_mun22_all))),
            pct(sum(arr$pop_mun22_unmap) / sum(arr$pop_mun22_all))))

cat("\n  Does any unmapped member carry at-risk population at all?\n")
cat(sprintf("    total risk_2010 from unmapped members: %.4f\n", sum(arr$risk_from_unmapped_10)))
cat(sprintf("    total risk_2022 from unmapped members: %.4f\n", sum(arr$risk_from_unmapped_22)))
cat("    (If ~0, unmapped members inflate the DENOMINATOR only -- the numerator\n")
cat("     is untouched, so g_alta is unaffected and pp_alta is diluted.)\n")

cat("\n  Distribution of the unmapped population share, arrangements with >=1 unmapped:\n")
sub <- arr |> filter(n_unmapped > 0)
print(round(quantile(sub$share_pop_unmapped, seq(0, 1, 0.1), na.rm = TRUE), 2))

cat("\n  Top 20 arrangements by unmapped population share:\n")
print(sub |> arrange(desc(share_pop_unmapped)) |>
        select(CD_CIDADE, n_members, n_unmapped, share_pop_unmapped,
               pp10_current, pp10_mapped, ratio_pp10) |>
        head(20), n = 20, width = Inf)

cat("\n  Ratio current/mapped-only, arrangements with >=1 unmapped member:\n")
print(summarise_ratios(sub, c("ratio_pp10", "ratio_dpp", "ratio_g")), width = Inf)
cat("  n_nonfinite = arrangements whose members are ALL unmapped: the mapped-only\n")
cat("  denominator is 0, so the ratio is NaN/Inf.\n")
cat("  NOTE: since 6f.1, script 07 emits exactly the qualified 210, so this block\n")
cat("  and CHECK 2b below now cover the SAME set. They diverged only while script\n")
cat("  07 still emitted 354, when this block was diluted by 144 unqualified rows.\n")

report_g_equality(sub, sprintf(
  "g_alta under the two denominators (all %d rows script 07 emits):", nrow(arr)))

save_csv(arr, "check2_arrangement_denominators.csv")

# =============================================================================
# CHECK 2b -- the same table, restricted to the QUALIFIED arrangements
# =============================================================================
# The block above runs over every arrangement script 07 emits (354 before
# 6f.1). The number the 6f.2 decision actually needs is the same table
# restricted to the qualified arrangements -- the ones stage 04 keeps
# (210 after 6f.1) -- which is where this script's earlier run was truncated.
#
# Qualified = member of an arrangement that stage 04's 01_compose_sample.R
# retained (em_arranjo, >= 1 mapped member, pop_arranjo > 50k). Read from that
# script's own output rather than re-deriving the rule here.

cat("\n", strrep("=", 78), "\n")
cat("CHECK 2b -- restricted to the QUALIFIED arrangements\n")
cat(strrep("=", 78), "\n")

# A functional urban area is EITHER a multi-municipality arrangement OR a
# single isolated municipality -- 01_compose_sample.R L93 counts the FUA total
# as n_distinct(amostra_arr$CD_CIDADE) + nrow(mun_isol), and CHECK 1's funnel
# counts n_distinct(CD_CIDADE) over the whole sample, which is the same thing.
# Reading amostra_arr.csv ALONE gives only the multi-municipality arrangements
# (100) and silently drops the isolated FUAs, which is why the first run of
# this block reported 100 against the funnel's 210. Both files are read.
#
# Isolated FUAs are single municipalities that are in the sample only because
# they are exposed, so tem_susceptibilidade is TRUE and n_unmapped is 0 for all
# of them: they cannot be affected by the denominator change. Including them
# does not change the affected set, only the denominator of the share
# statistics below -- which is exactly why it has to be right.
arr_path  <- file.path(processed_data_path("04_regression"), "amostra_arr.csv")
isol_path <- file.path(processed_data_path("04_regression"), "mun_isol.csv")
missing_q <- c(arr_path, isol_path)[!file.exists(c(arr_path, isol_path))]
if (length(missing_q) > 0) {
  for (f in missing_q) cat(sprintf("\n  NOT FOUND: %s\n", f))
  cat("  Run 04_regression_dataset_and_models/01_compose_sample.R first.\n")
  cat("  CHECK 2b skipped -- the qualified set cannot be identified without it.\n")
} else {
  cd_arr <- read_csv(arr_path, show_col_types = FALSE) |>
    distinct(CD_CIDADE) |> pull(CD_CIDADE)
  # script 07's own fallback: an isolated municipality with no CD_CIDADE is its
  # own arrangement, keyed by cod_mun (07_aggregate_municipality_metrics.R).
  isol <- read_csv(isol_path, show_col_types = FALSE) |>
    mutate(CD_CIDADE = coalesce(as.double(CD_CIDADE), as.double(cod_mun)))
  cd_isol <- unique(isol$CD_CIDADE)

  qualified <- union(cd_arr, cd_isol)
  cat(sprintf("\n  Qualified FUAs: %d  =  %d multi-municipality arrangements + %d isolated\n",
              length(qualified), length(cd_arr), length(setdiff(cd_isol, cd_arr))))
  cat(sprintf("  (of %d rows script 07 emits)\n", nrow(arr)))
  if (length(qualified) != 210)
    cat(sprintf("  *** Expected 210 per CHECK 1's funnel, got %d -- reconcile before\n      reading anything below as the 6f.2 number.\n",
                length(qualified)))

  q <- arr |> filter(CD_CIDADE %in% qualified)
  cat(sprintf("  Matched in this table : %d\n", nrow(q)))
  if (nrow(q) < length(qualified))
    cat(sprintf("  NOT MATCHED           : %d -- a qualified arrangement with no row in\n    script 07's output is a finding, not a rounding issue.\n",
                length(qualified) - nrow(q)))

  # (a) how many have at least one unmapped member
  cat(sprintf("\n  With >= 1 unmapped member: %d (%s)\n",
              sum(q$n_unmapped > 0), pct(mean(q$n_unmapped > 0))))

  # (b) the share of arrangement population those members contribute
  cat(sprintf("  Population in unmapped members: %s of %s (%s)\n",
              fmt(round(sum(q$pop_mun22_unmap))), fmt(round(sum(q$pop_mun22_all))),
              pct(sum(q$pop_mun22_unmap) / sum(q$pop_mun22_all))))
  qs <- q |> filter(n_unmapped > 0)
  if (nrow(qs) > 0) {
    cat("\n  Distribution of the unmapped population share (arrangements with >=1):\n")
    print(round(quantile(qs$share_pop_unmapped, seq(0, 1, 0.1), na.rm = TRUE), 2))
  }

  # (c) per-arrangement pp_alta_2010 and delta_pp_alta, both denominators
  cat("\n  Ratio old/new denominator, arrangements with >= 1 unmapped member:\n")
  if (nrow(qs) > 0) {
    print(summarise_ratios(qs, c("ratio_pp10", "ratio_dpp", "ratio_g")), width = Inf)
    report_g_equality(qs, "g_alta under the two denominators (qualified arrangements):")
  }

  cat("\n  20 largest changes in pp_alta_2010 (old - new), qualified only:\n")
  print(q |> mutate(d_pp10 = pp10_current - pp10_mapped,
                    d_dpp  = dpp_current  - dpp_mapped) |>
          arrange(desc(abs(d_pp10))) |>
          select(CD_CIDADE, n_members, n_unmapped, share_pop_unmapped,
                 pp10_current, pp10_mapped, d_pp10,
                 dpp_current, dpp_mapped, d_dpp) |>
          head(20), n = 20, width = Inf)

  save_csv(q |> mutate(d_pp10 = pp10_current - pp10_mapped,
                       d_dpp  = dpp_current  - dpp_mapped),
           "check2b_qualified_arrangement_denominators.csv")
}

cat("\n", strrep("=", 78), "\n")
cat("DONE. Outputs in:", out_dir, "\n")
cat(strrep("=", 78), "\n")
