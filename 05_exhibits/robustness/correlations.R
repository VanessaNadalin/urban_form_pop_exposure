# =============================================================================
# 13_correlacoes.R
# Matriz de correlação de Pearson para todas as variáveis das regressões
#
# Paleta color-blind safe: azul–branco–laranja (ColorBrewer PuOr)
# Células não significativas (p > 0.05) deixadas em branco.
#
# High susceptibility only (rule 9): the medium-susceptibility label entries
# (g_medio, g_alta_medio, g_fora_medio, safe-land medium columns) were
# removed 2026-09-11 -- those columns are no longer produced by any script
# since the Task 1c retirement (07_aggregate_municipality_metrics.R).
#
# Inputs:
#   data/processed_data/04_regression/tables/dataset_regressao_municipio.csv  (script 15)
#   data/processed_data/04_regression/tables/dataset_regressao_arranjo.csv    (script 15)
#
# Outputs (data/processed_data/04_regression/figures/):
#   correlacao_municipios.png
#   correlacao_arranjos.png
#
# Run from the repository root (relative paths, CLAUDE.md rule 5).
# =============================================================================

source("04_regression_dataset_and_models/00_setup.R")

for (pkg in c("ggcorrplot", "ggplot2")) {
  if (!requireNamespace(pkg, quietly = TRUE)) install.packages(pkg)
  library(pkg, character.only = TRUE)
}

dir.create(figures_dir, recursive = TRUE, showWarnings = FALSE)

cat("\n", strrep("=", 60), "\n")
cat("13_CORRELACOES.R\n")
cat(strrep("=", 60), "\n")

# =============================================================================
# prep — variáveis derivadas idênticas ao script 12
# =============================================================================

prep <- function(df) {
  df %>% mutate(
    # denominator on the mapped units (6f.2)
    log_density_2010             = log(pop_urbana_2010_cg /
                                         (area_urbana_2010_m2_mapped / 1e6 + 0.001) + 1),
    log_pop_total_2010           = log(pop_total_2010 + 1),
    log_pib_pc                   = log(pib_pc_2010 + 1),
    topo_restrita                = topo_prop_restrita,
    pct_area_periph_ext_leap     = pct_area_peripheral + pct_area_extension + pct_area_leapfrog,
    pct_area_densif_infill_0010  = pct_area_densif_0010 + pct_area_infill_0010,
    pct_area_periph_ext_leap_0010 = pct_area_peripheral_0010 +
                                    pct_area_extension_0010  +
                                    pct_area_leapfrog_0010,
    log_dist_densif_0010         = log(pmax(dist_media_m_densif_0010,        1)),
    log_dist_densif_infill_0010  = log(pmax(dist_media_m_densif_infill_0010, 1))
  )
}

# =============================================================================
# Variáveis e labels — ordem por grupo conceptual
# =============================================================================

labels_en <- c(
  # ── Y (variáveis dependentes) ────────────────────────────────────────────
  g_alta                               = "g_alta (high-risk pop. growth)",
  delta_pp_alta                        = "Δpp_alta (pp change, mov. denom.)",

  # ── Urban form 2000→2010 (pré-período) ──────────────────────────────────
  pct_area_densif_0010                 = "Densif. area % 2000–2010",
  pct_area_infill_0010                 = "Infill area % 2000–2010",
  pct_area_densif_infill_0010          = "Densif.+Infill % 2000–2010",
  pct_area_periph_ext_leap_0010        = "Periph.+Ext.+Leapfrog % 2000–2010",
  pct_area_peripheral_0010             = "Peripheral area % 2000–2010",
  pct_area_extension_0010              = "Extension area % 2000–2010",
  pct_area_leapfrog_0010               = "Leapfrog area % 2000–2010",
  log_dist_densif_0010                 = "Log dist. densif. 2000–2010",
  log_dist_densif_infill_0010          = "Log dist. densif.+infill 2000–2010",

  # ── Urban form 2010→2022 (período corrente) ──────────────────────────────
  pct_area_densif                      = "Densif. area % 2010–2022",
  pct_area_periph_ext_leap             = "Periph.+Ext.+Leapfrog area % 2010–2022",
  pct_area_peripheral                  = "Peripheral area % 2010–2022",
  pct_area_extension                   = "Extension area % 2010–2022",
  pct_area_leapfrog                    = "Leapfrog area % 2010–2022",

  # ── Crescimento fora das zonas de risco ──────────────────────────────────
  g_fora_alta                          = "Pop. growth outside high-risk (%)",

  # ── Terra segura disponível ──────────────────────────────────────────────
  pct_nao_constru_fora_alta_2010_q1    = "Safe land Q1 high-risk excl. (%)",
  pct_nao_constru_fora_alta_2010_q4    = "Safe land Q4 high-risk excl. (%)",

  # ── Distância ────────────────────────────────────────────────────────────
  dist_densif_m                        = "Dist. to densif. zone 2010 (m)",
  dist_sede_q1_m                       = "Dist. city centre Q1 (m)",

  # ── Desigualdade / mobilidade ────────────────────────────────────────────
  palma_rent                           = "Palma ratio — rent",
  palma_commute                        = "Palma ratio — commute",

  # ── Topografia ───────────────────────────────────────────────────────────
  topo_restrita                        = "Restricted terrain (%)",

  # ── Controles socioeconômicos ─────────────────────────────────────────────
  log_density_2010                     = "Log urban density 2010",
  log_pop_total_2010                   = "Log total population 2010",
  log_pib_pc                           = "Log GDP per capita 2010",
  prop_favelas_2010                    = "Slum share 2010"
)

vars_corr <- names(labels_en)

# =============================================================================
# Helper: construir e salvar figura
# =============================================================================

plot_corr <- function(ds, title, path) {
  df <- ds %>%
    select(all_of(intersect(vars_corr, names(ds)))) %>%
    drop_na()

  n_vars <- ncol(df)
  cat(sprintf("  Variáveis presentes: %d de %d  |  N (complete cases): %d\n",
              n_vars, length(vars_corr), nrow(df)))

  if (nrow(df) < 5 || n_vars < 2) {
    cat("  AVISO: amostra insuficiente\n"); return(invisible(NULL))
  }

  present <- intersect(vars_corr, names(df))
  names(df)[match(present, names(df))] <- labels_en[present]

  cor_mat <- cor(df, use = "pairwise.complete.obs")
  p_mat   <- ggcorrplot::cor_pmat(df, use = "pairwise.complete.obs")

  lab_size <- if (n_vars <= 16) 2.6 else 1.8

  p <- ggcorrplot(
    cor_mat,
    p.mat        = p_mat,
    hc.order     = FALSE,
    type         = "lower",
    insig        = "blank",
    lab          = TRUE,
    lab_size     = lab_size,
    digits       = 2,
    outline.col  = "white",
    colors       = c("#4393c3", "white", "#e08214"),
    title        = title,
    legend.title = "r"
  ) +
    theme(
      plot.title   = element_text(size = 11, face = "bold"),
      axis.text.x  = element_text(size = 7,  angle = 45, hjust = 1),
      axis.text.y  = element_text(size = 7),
      legend.text  = element_text(size = 8),
      legend.title = element_text(size = 8),
      plot.margin  = margin(5, 5, 10, 5, "mm")
    )

  dim_cm <- max(26, n_vars * 1.35)
  ggsave(path, plot = p,
         width  = dim_cm,
         height = dim_cm * 0.93,
         units  = "cm", dpi = 200)
  cat(sprintf("  ✓ %s  (%.0f × %.0f cm)\n", basename(path), dim_cm, dim_cm * 0.93))
  invisible(p)
}

# =============================================================================
# Municipal dataset
# =============================================================================

cat("\n1) Dataset municipal\n")
path_mun <- file.path(tables_dir, "dataset_regressao_municipio.csv")
if (!file.exists(path_mun))
  stop("dataset_regressao_municipio.csv não encontrado — execute 11b")

ds_mun <- read_csv(path_mun, show_col_types = FALSE) %>% prep()
cat(sprintf("  Linhas carregadas: %d\n", nrow(ds_mun)))

plot_corr(ds_mun,
          "Correlation matrix — Municipalities (Pearson, p > 0.05 blank)",
          file.path(figures_dir, "correlacao_municipios.png"))

# =============================================================================
# Arranjo dataset
# =============================================================================

cat("\n2) Dataset arranjos populacionais\n")
path_arr <- file.path(tables_dir, "dataset_regressao_arranjo.csv")
if (!file.exists(path_arr))
  stop("dataset_regressao_arranjo.csv não encontrado — execute 11b")

ds_arr <- read_csv(path_arr, show_col_types = FALSE) %>% prep()
cat(sprintf("  Linhas carregadas: %d\n", nrow(ds_arr)))

plot_corr(ds_arr,
          "Correlation matrix — Functional urban areas (Pearson, p > 0.05 blank)",
          file.path(figures_dir, "correlacao_arranjos.png"))

cat("\n", strrep("=", 60), "\n")
cat("CONCLUÍDO\n")
cat(strrep("=", 60), "\n")
