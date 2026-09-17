# =============================================================================
# 12c_regressao_preperiodo_pp80.R
# Regressões pré-período com FILTRO DUPLO:
#   1) Base mínima: pop_2010_risk_total > MIN_POP_RISCO_2010
#      (read from 04_regression_dataset_and_models/00_setup.R -- the same
#      value 16_estimate_models.R applies; 200 since 2026-09-12, was 1000
#      when decided on 2026-09-08, MIGRATION_PLAN.md 6c1 and its revision)
#   2) Share máximo: pp_alta_2010 <= 80%
#
# DIFERENÇA DO SCRIPT 12B:
#   - Adiciona filtro de pp_alta_2010 <= 80%
#   - Remove municípios onde >80% da população já está em risco em 2010
#   - Foca em municípios com espaço para crescimento fora das zonas de risco
#
# Motivação para filtro pp_alta <= 80%:
#   - Municípios quase 100% em risco não têm escolha de onde crescer
#   - Crescimento é mecanicamente "em risco" por falta de alternativa
#   - Hipótese do artigo requer que haja ESCOLHA entre áreas seguras vs risco
#
# FILTROS APLICADOS:
#   1) pop_2010_risk_total > MIN_POP_RISCO_2010  (base populacional mínima,
#      from 00_setup.R -- not hardcoded here, so this script cannot drift
#      from the main pipeline's cut the way it did between 2026-09-12 and
#      2026-09-16)
#   2) pp_alta_2010 <= 80%                        (não totalmente em risco)
#
# Hipótese: cidades que densificaram perto do centro no período 2000→2010
# têm maior crescimento de população em risco no período seguinte (2010→2022),
# porque o estoque habitacional acessível se concentrou em áreas suscetíveis.
#
# Variável de tratamento (compact growth 2000→2010):
#   pct_area_densif_infill_0010     — share densificação + infill
# Variável de comparação (sprawl growth 2000→2010):
#   pct_area_periph_ext_leap_0010   — share periférico + extension + leapfrog
#
# Tabelas geradas (modelsummary → HTML + LaTeX):
#
#   Tab 1 (corpo do artigo):
#     Municípios × Alta susceptibilidade × 4 colunas
#     (1) g_high Compact  (2) g_high Sprawl
#     (3) Dpp_high Compact (4) Dpp_high Sprawl
#
#   Tab A1 (apêndice): Arranjos × Alta susceptibilidade × mesmas 4 colunas
#
#   High susceptibility only (rule 9): Tab A2 (média) e Tab A3 (alta+média)
#   removidas 2026-09-11 -- mesma razão de minimum_population_filter.R: as
#   colunas de média suscetibilidade não são mais produzidas por nenhum
#   script desde a Task 1c (07_aggregate_municipality_metrics.R).
#
#   O filtro pp_alta_2010 <= 80% em si (a diferença deste script em relação
#   a minimum_population_filter.R) não foi adotado no pipeline principal --
#   permanece uma checagem de robustez em aberto (05_exhibits/pipeline_5.md
#   §6.8), não uma decisão tomada.
#
# SEs: municípios → clusterizados por NM_CIDADE (arranjo); arranjos → HC3
# Dummies de região e hierarquia urbana: incluídas mas não mostradas na tabela
#
# Inputs:
#   data/processed_data/04_regression/tables/dataset_regressao_municipio.csv  (script 15)
#   data/processed_data/04_regression/tables/dataset_regressao_arranjo.csv    (script 15)
#
# Outputs (data/processed_data/04_regression/figures/):
#   tab1c_main_municipios_high_pp80.html  /  .tex  /  .docx
#   tabA1c_arranjos_high_pp80.html  /  .tex  /  .docx
#
# Run from the repository root (relative paths, CLAUDE.md rule 5).
# =============================================================================

source("04_regression_dataset_and_models/00_setup.R")

for (pkg in c("lmtest", "sandwich", "car", "modelsummary", "flextable")) {
  if (!requireNamespace(pkg, quietly = TRUE)) install.packages(pkg)
  library(pkg, character.only = TRUE)
}

cat("\n", strrep("=", 60), "\n")
cat("12c_REGRESSAO_PREPERIODO - FILTRO DUPLO (BASE + PP80)\n")
cat(strrep("=", 60), "\n")

# =============================================================================
# 1) CARREGAR E PREPARAR DATASETS
# =============================================================================

cat("\n1) Carregando datasets...\n")

path_mun <- file.path(tables_dir, "dataset_regressao_municipio.csv")
path_arr <- file.path(tables_dir, "dataset_regressao_arranjo.csv")

if (!file.exists(path_mun)) stop("dataset_regressao_municipio.csv não encontrado — execute 11b")
if (!file.exists(path_arr)) stop("dataset_regressao_arranjo.csv não encontrado — execute 11b")

# Prepara variáveis derivadas comuns
prep <- function(df) {
  df %>% mutate(
    pop_growth           = (pop_urbana_2022 - pop_urbana_2010_cg) /
                             pop_urbana_2010_cg,
    log_pop_2010         = log(pop_urbana_2010_cg + 1),
    log_pib_pc           = log(pib_pc_2010        + 1),
    log_area_2010_km2    = log(area_urbana_2010_m2 / 1e6 + 0.001),
    # Denominator on the MAPPED units (6f.2): pop_urbana_2010_cg is
    # mapped-members-only at arrangement level, so its area must be too,
    # or the ratio spans the two aggregation groups. Identical to
    # area_urbana_2010_m2 at municipality level.
    log_density_2010     = log(pop_urbana_2010_cg /
                                 (area_urbana_2010_m2_mapped / 1e6 + 0.001) + 1),
    log_pop_total_2010   = log(pop_total_2010 + 1),
    log_pop_total_2000   = log(pop_2000       + 1),
    log_area_2000_km2    = log(area_2000_m2 / 1e6 + 0.001),
    g_fora_suscept_slums = coalesce(g_slums_1022 - g_alta_slums_1022, 0),
    pct_area_periph_ext_leap = pct_area_peripheral + pct_area_extension + pct_area_leapfrog,
    regiao      = factor(regiao,
                         levels = c("Sudeste", "Sul", "Nordeste",
                                    "Norte", "Centro-Oeste")),
    urban_class = factor(urban_class,
                         levels = c("Urban Centers", "Metropolises",
                                    "Metropolis Suburbs", "Regional Centers",
                                    "Regional Centers Suburbs"))
  )
}

# Prepara variáveis derivadas do crescimento 2000→2010
prep_0010 <- function(df) {
  df %>% mutate(
    pct_area_densif_infill_0010   = pct_area_densif_0010 + pct_area_infill_0010,
    log_dist_densif_0010          = log(pmax(dist_media_m_densif_0010,        1)),
    log_dist_densif_infill_0010   = log(pmax(dist_media_m_densif_infill_0010, 1)),
    pct_area_periph_ext_leap_0010 = pct_area_peripheral_0010 +
                                    pct_area_extension_0010  +
                                    pct_area_leapfrog_0010
  )
}

ds_mun <- read_csv(path_mun, show_col_types = FALSE) %>% prep() %>% prep_0010()
ds_arr <- read_csv(path_arr, show_col_types = FALSE) %>% prep() %>% prep_0010()

cat(sprintf("  Municípios: %d  |  Arranjos: %d\n", nrow(ds_mun), nrow(ds_arr)))

# =============================================================================
# 1b) APLICAR FILTRO DE BASE MÍNIMA
# =============================================================================

cat(sprintf("\n1b) Aplicando filtro de base mínima (pop_2010_risk_total > %d)...\n",
            MIN_POP_RISCO_2010))

# Verificar se variável existe
if (!"pop_2010_risk_total" %in% names(ds_mun))
  stop("pop_2010_risk_total não encontrada — execute script 11b atualizado")

# Contar antes do filtro
n_mun_antes <- nrow(ds_mun)
n_arr_antes <- nrow(ds_arr)

# Aplicar filtro. The cut is NOT declared here: it comes from
# 04_regression_dataset_and_models/00_setup.R, sourced at the top, so this
# script always applies the same baseline restriction as
# 16_estimate_models.R and only the pp_alta_2010 cut below is this script's
# own contribution. Hardcoding it is what let this script silently keep
# 1000 after the pipeline moved to 200 on 2026-09-12.
ds_mun <- ds_mun %>% filter(pop_2010_risk_total > MIN_POP_RISCO_2010)
ds_arr <- ds_arr %>% filter(pop_2010_risk_total > MIN_POP_RISCO_2010)

# Reportar remoções
n_mun_removidos <- n_mun_antes - nrow(ds_mun)
n_arr_removidos <- n_arr_antes - nrow(ds_arr)
pct_mun_removidos <- 100 * n_mun_removidos / n_mun_antes
pct_arr_removidos <- 100 * n_arr_removidos / n_arr_antes

cat(sprintf("\n  MUNICÍPIOS:\n"))
cat(sprintf("    Antes do filtro  : %d\n", n_mun_antes))
cat(sprintf("    Depois do filtro : %d\n", nrow(ds_mun)))
cat(sprintf("    Removidos        : %d (%.1f%%)\n", n_mun_removidos, pct_mun_removidos))

cat(sprintf("\n  ARRANJOS:\n"))
cat(sprintf("    Antes do filtro  : %d\n", n_arr_antes))
cat(sprintf("    Depois do filtro : %d\n", nrow(ds_arr)))
cat(sprintf("    Removidos        : %d (%.1f%%)\n", n_arr_removidos, pct_arr_removidos))

# Estatísticas da base populacional após filtro
cat(sprintf("\n  Distribuição de pop_2010_risk_total (municípios filtrados):\n"))
pop_stats <- ds_mun %>%
  summarise(
    min = min(pop_2010_risk_total, na.rm = TRUE),
    q25 = quantile(pop_2010_risk_total, 0.25, na.rm = TRUE),
    mediana = median(pop_2010_risk_total, na.rm = TRUE),
    q75 = quantile(pop_2010_risk_total, 0.75, na.rm = TRUE),
    max = max(pop_2010_risk_total, na.rm = TRUE)
  )
print(t(pop_stats), digits = 1)

# =============================================================================
# 1c) APLICAR FILTRO ADICIONAL: pp_alta_2010 <= 80%
# =============================================================================

cat("\n1c) Aplicando filtro adicional (pp_alta_2010 <= 80%)...\n")

# Verificar se variável existe
if (!"pp_alta_2010" %in% names(ds_mun))
  stop("pp_alta_2010 não encontrada — execute script 10")

# Contar antes do segundo filtro
n_mun_antes_pp <- nrow(ds_mun)
n_arr_antes_pp <- nrow(ds_arr)

# Aplicar filtro pp_alta <= 80%
MAX_PP_ALTA <- 80

ds_mun <- ds_mun %>% filter(pp_alta_2010 <= MAX_PP_ALTA)
ds_arr <- ds_arr %>% filter(pp_alta_2010 <= MAX_PP_ALTA)

# Reportar remoções do segundo filtro
n_mun_removidos_pp <- n_mun_antes_pp - nrow(ds_mun)
n_arr_removidos_pp <- n_arr_antes_pp - nrow(ds_arr)
pct_mun_removidos_pp <- 100 * n_mun_removidos_pp / n_mun_antes_pp
pct_arr_removidos_pp <- 100 * n_arr_removidos_pp / n_arr_antes_pp

cat(sprintf("\n  MUNICÍPIOS:\n"))
cat(sprintf("    Antes do filtro pp  : %d\n", n_mun_antes_pp))
cat(sprintf("    Depois do filtro pp : %d\n", nrow(ds_mun)))
cat(sprintf("    Removidos (pp>80%%) : %d (%.1f%%)\n", n_mun_removidos_pp, pct_mun_removidos_pp))
cat(sprintf("    TOTAL removido (base+pp): %d (%.1f%% da amostra original)\n",
            n_mun_antes - nrow(ds_mun),
            100 * (n_mun_antes - nrow(ds_mun)) / n_mun_antes))

cat(sprintf("\n  ARRANJOS:\n"))
cat(sprintf("    Antes do filtro pp  : %d\n", n_arr_antes_pp))
cat(sprintf("    Depois do filtro pp : %d\n", nrow(ds_arr)))
cat(sprintf("    Removidos (pp>80%%) : %d (%.1f%%)\n", n_arr_removidos_pp, pct_arr_removidos_pp))
cat(sprintf("    TOTAL removido (base+pp): %d (%.1f%% da amostra original)\n",
            n_arr_antes - nrow(ds_arr),
            100 * (n_arr_antes - nrow(ds_arr)) / n_arr_antes))

# Estatísticas de pp_alta_2010 após filtros
cat(sprintf("\n  Distribuição de pp_alta_2010 (após filtros):\n"))
pp_stats <- ds_mun %>%
  summarise(
    min = min(pp_alta_2010, na.rm = TRUE),
    q25 = quantile(pp_alta_2010, 0.25, na.rm = TRUE),
    mediana = median(pp_alta_2010, na.rm = TRUE),
    q75 = quantile(pp_alta_2010, 0.75, na.rm = TRUE),
    max = max(pp_alta_2010, na.rm = TRUE)
  )
print(t(pp_stats), digits = 1)

# Diagnóstico: NAs por variável nos arranjos
cat("\n  NAs por variável — arranjos (top 20):\n")
na_arr <- sort(colSums(is.na(ds_arr)), decreasing = TRUE)
print(head(na_arr[na_arr > 0], 20))

# Verificar presença das variáveis-chave
vars_0010 <- c("pct_area_densif_0010", "pct_area_infill_0010",
               "log_dist_densif_0010", "log_dist_densif_infill_0010")
ausentes <- setdiff(vars_0010, names(ds_mun))
if (length(ausentes) > 0)
  cat(sprintf("  AVISO: variáveis ausentes em ds_mun: %s\n",
              paste(ausentes, collapse = ", ")))

# =============================================================================
# 2) CONTROLES POR VARIÁVEL Y
# =============================================================================

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

# =============================================================================
# 3) HELPERS DE ESTIMAÇÃO
# =============================================================================

make_f <- function(y, trat, ctrl) {
  as.formula(paste(y, "~", paste(c(trat, ctrl), collapse = " + ")))
}

fit_safe <- function(f, data, label, cluster_col = NULL) {
  vars <- all.vars(f)
  dat  <- data[complete.cases(data[, intersect(vars, names(data))]), ]
  cat(sprintf("    %-40s  N = %d\n", label, nrow(dat)))
  tryCatch({
    mod <- lm(f, data = dat)
    if (!is.null(cluster_col) && cluster_col %in% names(dat))
      attr(mod, "cluster_vec") <- dat[[cluster_col]]
    mod
  }, error = function(e) {
    message("    ERRO em ", label, ": ", e$message); NULL
  })
}

# vcov por tipo de dataset:
#   municípios → clusterizados por arranjo (CD_CIDADE)
#   arranjos   → HC3 (cada linha já é um cluster único)
vcov_clust <- function(mod) {
  cl <- attr(mod, "cluster_vec")
  if (!is.null(cl)) vcovCL(mod, cluster = cl) else vcovHC(mod, type = "HC3")
}
vcov_hc3 <- function(mod) vcovHC(mod, type = "HC3")

# =============================================================================
# 4) ESPECIFICAÇÕES Y POR TABELA
# =============================================================================

trat_compact <- "pct_area_densif_infill_0010"
trat_periph  <- "pct_area_periph_ext_leap_0010"

# Tabela principal + apêndice A — susceptibilidade ALTA
y_high <- list(
  "(1) g_high — Compact"    = list(y = "g_alta",        trat = trat_compact,
                                    ctrl = c(CTRL_ALTA,  "g_fora_alta")),
  "(2) g_high — Sprawl"     = list(y = "g_alta",        trat = trat_periph,
                                    ctrl = c(CTRL_ALTA,  "g_fora_alta")),
  "(3) Dpp_high — Compact"  = list(y = "delta_pp_alta", trat = trat_compact,
                                    ctrl = CTRL_DELTA),
  "(4) Dpp_high — Sprawl"   = list(y = "delta_pp_alta", trat = trat_periph,
                                    ctrl = CTRL_DELTA)
)

# =============================================================================
# 5) ESTIMAR MODELOS
# =============================================================================

cat("\n5) Estimando modelos...\n")

# fit_specs2: trat é especificado por coluna dentro de specs
fit_specs2 <- function(specs, data, prefix, cluster_col = NULL) {
  mods <- lapply(names(specs), function(nm) {
    s <- specs[[nm]]
    fit_safe(make_f(s$y, s$trat, s$ctrl), data, paste(prefix, nm),
             cluster_col = cluster_col)
  })
  names(mods) <- names(specs)
  mods
}

cat("\n  Tabela principal + apêndice A — high susceptibility\n")
tab_main_mun <- fit_specs2(y_high, ds_mun, "Mun-High",  cluster_col = "NM_CIDADE")
tab_appA_arr <- fit_specs2(y_high, ds_arr, "Arr-High")

# =============================================================================
# 6) LABELS E OPÇÕES MODELSUMMARY
# =============================================================================

coef_map_0010 <- c(
  "pct_area_densif_infill_0010"         = "Treatment (compact or sprawl)",
  "pct_area_periph_ext_leap_0010"       = "Treatment (compact or sprawl)",
  "log_pop_total_2000"                  = "Log total population 2000",
  "log_area_2000_km2"                   = "Log urban footprint 2000",
  "g_fora_alta"                         = "Pop. growth outside risk zones",
  "pp_alta_2010"                        = "Pop. share in risk zones 2010",
  "topo_prop_inclinado"                 = "Steep terrain",
  "pct_nao_constru_fora_alta_2010_q1"  = "Safe empty land Q1",
  "palma_commute"                       = "Palma ratio commute",
  "median_rent"                         = "Median rent",
  "prop_favelas_2010"                   = "Slum population share 2010",
  "(Intercept)"                         = "Intercept"
)
# Controls included in regressions but not shown in table:
#   pct_nao_constru_fora_*_2010_q4, palma_rent, log_pib_pc,
#   log_area_2000_km2, zero_area_2000, region dummies, urban class dummies

note_hidden <- paste(
  "Additional controls included but not shown:",
  "safe empty land Q4 (outside high- and med-risk zones),",
  "Palma ratio rent, log GDP per capita 2010,",
  "no urban footprint in 2000 dummy,",
  "region and urban class dummies."
)

# Both filters are printed into the note from the constants actually applied,
# so the note cannot drift from the code the way the header comments did.
note_filters <- sprintf(
  paste("Sample restricted to pop_2010_risk_total > %d (the main pipeline's cut, from",
        "00_setup.R) AND pp_alta_2010 <= %d%%. The second cut is this script's own and is",
        "not adopted in the main pipeline."),
  MIN_POP_RISCO_2010, MAX_PP_ALTA
)

note_mun <- paste(
  note_filters,
  "Standard errors clustered by functional urban area (NM_CIDADE) in parentheses.",
  note_hidden,
  "* p < 0.10, ** p < 0.05, *** p < 0.01."
)
note_arr <- paste(
  note_filters,
  "HC3 heteroskedasticity-robust standard errors in parentheses.",
  note_hidden,
  "* p < 0.10, ** p < 0.05, *** p < 0.01."
)

gof_0010 <- tribble(
  ~raw,            ~clean,    ~fmt,
  "nobs",          "N",        0L,
  "r.squared",     "R²",       3L,
  "adj.r.squared", "R² adj.",  3L
)

ms_base <- list(
  stars    = c("*" = .10, "**" = .05, "***" = .01),
  coef_map = coef_map_0010,
  coef_omit = "^regiao|^urban_class",
  gof_map  = gof_0010
)

ms_opts_mun <- c(ms_base, list(vcov  = vcov_clust,  notes = note_mun))
ms_opts_arr <- c(ms_base, list(vcov  = vcov_hc3,    notes = note_arr))

# =============================================================================
# 7) GERAR E SALVAR TABELAS
# =============================================================================

cat("\n7) Salvando tabelas HTML e LaTeX...\n")
dir.create(figures_dir, showWarnings = FALSE, recursive = TRUE)

salvar_tabela <- function(models, titulo, base_name, opts) {
  models <- Filter(Negate(is.null), models)
  if (length(models) == 0) {
    cat(sprintf("  AVISO: nenhum modelo estimado para %s\n", base_name))
    return(invisible())
  }
  for (ext in c("html", "tex", "docx")) {
    args <- c(list(models = models, title = titulo,
                   output = file.path(figures_dir, paste0(base_name, ".", ext))), opts)
    do.call(modelsummary, args)
    cat(sprintf("  ✓ %s.%s\n", base_name, ext))
  }
}

# ── Main table (body of article) ─────────────────────────────────────────────
salvar_tabela(
  tab_main_mun,
  paste("Table 1 — Pre-period urban form (2000–2010) and high-susceptibility",
        "population growth (2010–2022): municipalities.",
        "Cols (1)–(2): growth rate g_high; Cols (3)–(4): change in pop. share Dpp_high."),
  "tab1c_main_municipios_high_pp80",
  ms_opts_mun
)

# ── Appendix A: arranjos, high susceptibility ─────────────────────────────────
salvar_tabela(
  tab_appA_arr,
  paste("Table A1 — Pre-period urban form (2000–2010) and high-susceptibility",
        "population growth (2010–2022): functional urban areas.",
        "Cols (1)–(2): g_high; Cols (3)–(4): Dpp_high."),
  "tabA1c_arranjos_high_pp80",
  ms_opts_arr
)

# =============================================================================
# 8) VIF DO MODELO PRINCIPAL
# =============================================================================

cat("\n8) VIF — Tabela principal col. (1) g_high, Compact, municípios:\n")
mod_vif <- tab_main_mun[["(1) g_high — Compact"]]
if (!is.null(mod_vif)) {
  tryCatch(print(round(vif(mod_vif), 2)),
           error = function(e) cat("  (VIF não calculado:", e$message, ")\n"))
}

cat("\n", strrep("=", 60), "\n")
cat("CONCLUÍDO\n")
cat(strrep("=", 60), "\n")
cat("\nOutputs em: ", figures_dir, "\n")
