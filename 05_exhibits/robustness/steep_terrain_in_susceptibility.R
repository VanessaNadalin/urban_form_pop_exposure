# =============================================================================
# 12b_regressao_topo_suscept.R
# Variante de 12_regressao_preperiodo.R usando a variável de topografia
# restrita às zonas de susceptibilidade (topo_prop_inclinado_em_alta) no
# lugar de topo_prop_inclinado (círculo inteiro).
#
# Hipótese adicional: a restrição topográfica relevante é aquela que co-incide
# com as próprias zonas de risco, não o terreno acidentado em geral.
#
# Tabelas geradas:
#   Tab 2  (corpo do artigo — alternativa):
#     Municípios × Alta susceptibilidade × 4 colunas
#     (1) g_high Compact  (2) g_high Sprawl
#     (3) Dpp_high Compact (4) Dpp_high Sprawl
#
#   Tab B2 (apêndice — alternativa):
#     Arranjos × Alta susceptibilidade × 4 colunas
#
# Diferença em relação ao script 12:
#   CTRL_ALTA / CTRL_DELTA usam topo_prop_inclinado_em_alta em vez de
#   topo_prop_inclinado. N pode ser ligeiramente menor (~92,5% cobertura).
#
# SEs: municípios → clusterizados por NM_CIDADE; arranjos → HC3
#
# Inputs:
#   data/processed_data/04_regression/tables/dataset_regressao_municipio.csv  (script 15)
#   data/processed_data/04_regression/tables/dataset_regressao_arranjo.csv    (script 15)
#
# Outputs (data/processed_data/04_regression/figures/):
#   tab2_main_municipios_high_topo_suscept.html / .tex / .docx
#   tabB2_arranjos_high_topo_suscept.html       / .tex / .docx
#
# Run from the repository root (relative paths, CLAUDE.md rule 5).
# =============================================================================

source("04_regression_dataset_and_models/00_setup.R")

for (pkg in c("lmtest", "sandwich", "car", "modelsummary", "flextable")) {
  if (!requireNamespace(pkg, quietly = TRUE)) install.packages(pkg)
  library(pkg, character.only = TRUE)
}

cat("\n", strrep("=", 60), "\n")
cat("12b_REGRESSAO_TOPO_SUSCEPT.R\n")
cat(strrep("=", 60), "\n")

# =============================================================================
# 1) CARREGAR E PREPARAR DATASETS
# =============================================================================

cat("\n1) Carregando datasets...\n")

path_mun <- file.path(tables_dir, "dataset_regressao_municipio.csv")
path_arr <- file.path(tables_dir, "dataset_regressao_arranjo.csv")

if (!file.exists(path_mun)) stop("dataset_regressao_municipio.csv não encontrado — execute 11b")
if (!file.exists(path_arr)) stop("dataset_regressao_arranjo.csv não encontrado — execute 11b")

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

# Cobertura da nova variável
cat(sprintf("  topo_prop_inclinado_em_alta — municípios não-NA: %d (%.1f%%)\n",
            sum(!is.na(ds_mun$topo_prop_inclinado_em_alta)),
            100 * mean(!is.na(ds_mun$topo_prop_inclinado_em_alta))))
cat(sprintf("  topo_prop_inclinado_em_alta — arranjos   não-NA: %d (%.1f%%)\n",
            sum(!is.na(ds_arr$topo_prop_inclinado_em_alta)),
            100 * mean(!is.na(ds_arr$topo_prop_inclinado_em_alta))))

# =============================================================================
# 2) CONTROLES — USANDO topo_prop_inclinado_em_alta
# =============================================================================

CTRL_ALTA <- c(
  "topo_prop_inclinado_em_alta",          # <-- nova variável
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

vcov_clust <- function(mod) {
  cl <- attr(mod, "cluster_vec")
  if (!is.null(cl)) vcovCL(mod, cluster = cl) else vcovHC(mod, type = "HC3")
}
vcov_hc3 <- function(mod) vcovHC(mod, type = "HC3")

# =============================================================================
# 4) ESPECIFICAÇÕES
# =============================================================================

trat_compact <- "pct_area_densif_infill_0010"
trat_periph  <- "pct_area_periph_ext_leap_0010"

y_high <- list(
  "(1) g_high — Compact"    = list(y = "g_alta",        trat = trat_compact,
                                    ctrl = c(CTRL_ALTA,  "g_fora_alta")),
  "(2) g_high — Sprawl"     = list(y = "g_alta",        trat = trat_periph,
                                    ctrl = c(CTRL_ALTA,  "g_fora_alta")),
  "(3) Dpp_high — Compact"  = list(y = "delta_pp_alta", trat = trat_compact,
                                    ctrl = c(CTRL_DELTA, "g_fora_alta")),
  "(4) Dpp_high — Sprawl"   = list(y = "delta_pp_alta", trat = trat_periph,
                                    ctrl = c(CTRL_DELTA, "g_fora_alta"))
)

# =============================================================================
# 5) ESTIMAR MODELOS
# =============================================================================

cat("\n5) Estimando modelos...\n")

fit_specs2 <- function(specs, data, prefix, cluster_col = NULL) {
  mods <- lapply(names(specs), function(nm) {
    s <- specs[[nm]]
    fit_safe(make_f(s$y, s$trat, s$ctrl), data, paste(prefix, nm),
             cluster_col = cluster_col)
  })
  names(mods) <- names(specs)
  mods
}

cat("\n  Tabela 2 — municípios, alta susceptibilidade, topo restrita\n")
tab2_mun <- fit_specs2(y_high, ds_mun, "Mun-High-Topo", cluster_col = "NM_CIDADE")

cat("\n  Tabela B2 — arranjos, alta susceptibilidade, topo restrita\n")
tabB2_arr <- fit_specs2(y_high, ds_arr, "Arr-High-Topo")

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
  "topo_prop_inclinado_em_alta"         = "Steep terrain in suscept. zones",
  "pct_nao_constru_fora_alta_2010_q1"  = "Safe empty land Q1",
  "palma_commute"                       = "Palma ratio commute",
  "median_rent"                         = "Median rent",
  "prop_favelas_2010"                   = "Slum population share 2010",
  "(Intercept)"                         = "Intercept"
)

note_hidden <- paste(
  "Additional controls included but not shown:",
  "safe empty land Q4 (outside high-risk zones),",
  "Palma ratio rent, log GDP per capita 2010,",
  "no urban footprint in 2000 dummy,",
  "region and urban class dummies."
)

note_mun <- paste(
  "Standard errors clustered by functional urban area (NM_CIDADE) in parentheses.",
  note_hidden,
  "* p < 0.10, ** p < 0.05, *** p < 0.01."
)
note_arr <- paste(
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
  stars     = c("*" = .10, "**" = .05, "***" = .01),
  coef_map  = coef_map_0010,
  coef_omit = "^regiao|^urban_class",
  gof_map   = gof_0010
)

ms_opts_mun <- c(ms_base, list(vcov  = vcov_clust, notes = note_mun))
ms_opts_arr <- c(ms_base, list(vcov  = vcov_hc3,   notes = note_arr))

# =============================================================================
# 7) GERAR E SALVAR TABELAS
# =============================================================================

cat("\n7) Salvando tabelas...\n")
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

salvar_tabela(
  tab2_mun,
  paste("Table 2 — Pre-period urban form (2000–2010) and high-susceptibility",
        "population growth (2010–2022): municipalities.",
        "Terrain control: steep terrain within susceptibility zones.",
        "Cols (1)–(2): g_high; Cols (3)–(4): Dpp_high."),
  "tab2_main_municipios_high_topo_suscept",
  ms_opts_mun
)

salvar_tabela(
  tabB2_arr,
  paste("Table B2 — Pre-period urban form (2000–2010) and high-susceptibility",
        "population growth (2010–2022): functional urban areas.",
        "Terrain control: steep terrain within susceptibility zones.",
        "Cols (1)–(2): g_high; Cols (3)–(4): Dpp_high."),
  "tabB2_arranjos_high_topo_suscept",
  ms_opts_arr
)

# =============================================================================
# 8) VIF E COMPARAÇÃO COM SCRIPT 12
# =============================================================================

cat("\n8) VIF — Tab 2 col. (1) g_high, Compact, municípios:\n")
mod_vif <- tab2_mun[["(1) g_high — Compact"]]
if (!is.null(mod_vif)) {
  tryCatch(print(round(vif(mod_vif), 2)),
           error = function(e) cat("  (VIF não calculado:", e$message, ")\n"))
}

cat("\n  Comparação de N com script 12 (topo_prop_inclinado):\n")
cat("  Script 12 usa topo do círculo inteiro   → N esperado ~341\n")
cat("  Script 12b usa topo restrita à suscept. → N acima\n")

cat("\n", strrep("=", 60), "\n")
cat("CONCLUÍDO\n")
cat(strrep("=", 60), "\n")
cat("\nOutputs em: ", figures_dir, "\n")
