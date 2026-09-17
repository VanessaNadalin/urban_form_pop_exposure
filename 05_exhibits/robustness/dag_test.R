# =============================================================================
# 14_dag_test.R
# Testa as hipóteses do DAG causal contra os dados
#
# DAG (dagitty): urban growth form 2000–2010  →  growth pop risk 2010–2022
#
# Etapas:
#   1. Definir o DAG
#   2. Extrair conjunto de ajuste mínimo e independências condicionais
#   3. Mapear nós → variáveis observadas
#   4. Testar independências condicionais (correlações parciais)
#   5. Regressão com conjunto de ajuste canônico
#   6. Salvar figura do DAG
#   7. Triagem de variáveis externas ao DAG
#
# High susceptibility only (rule 9): the medium-susceptibility triage
# candidate (g_medio_slums_1022) was removed 2026-09-11 -- that column is
# no longer produced since 12_slum_growth.R's medium-branch retirement
# (MIGRATION_PLAN.md 6c0).
#
# Input : data/processed_data/04_regression/tables/dataset_regressao_municipio.csv  (script 15)
# Output: data/processed_data/04_regression/tables/dag_local_tests.csv
#         data/processed_data/04_regression/tables/dag_triage_external_vars.csv
#         data/processed_data/04_regression/figures/dag_causal.png
#
# Run from the repository root (relative paths, CLAUDE.md rule 5).
# =============================================================================

source("04_regression_dataset_and_models/00_setup.R")

for (pkg in c("dagitty", "ggdag", "ggplot2", "sandwich", "lmtest")) {
  if (!requireNamespace(pkg, quietly = TRUE)) install.packages(pkg)
  library(pkg, character.only = TRUE)
}

dir.create(figures_dir, recursive = TRUE, showWarnings = FALSE)

cat("\n", strrep("=", 60), "\n")
cat("14_DAG_TEST.R\n")
cat(strrep("=", 60), "\n")

# =============================================================================
# 1) Definir o DAG
# =============================================================================

cat("\n1) Definindo o DAG...\n")

dag <- dagitty('dag {
  bb="-3,-3,2,3"

  empty_spaces_scarcity [pos="-0.391,1.65"]
  gdp_pc                [pos="-2.10,1.29"]
  growth_pop_risk       [outcome,  pos="0.511,-0.400"]
  inefficiency_land     [latent,   pos="-0.140,-0.820"]
  job_accessibility     [pos="-0.255,0.313"]
  risk_distribution     [latent,   pos="-0.064,-1.84"]
  total_pop             [pos="-2.31,0.465"]
  urban_form_2000       [pos="-1.50,-1.86"]
  urban_growth_form     [exposure, pos="-1.24,-0.506"]
  urban_pop_growth      [pos="-1.63,0.047"]
  region                [pos="-1.67,1.91"]
  topography            [pos="-2.18,-1.35"]

  empty_spaces_scarcity -> growth_pop_risk
  gdp_pc                -> inefficiency_land
  gdp_pc                -> urban_pop_growth
  inefficiency_land     -> growth_pop_risk
  inefficiency_land     -> urban_form_2000
  job_accessibility     -> growth_pop_risk
  risk_distribution     -> growth_pop_risk
  total_pop             -> empty_spaces_scarcity
  total_pop             -> job_accessibility
  total_pop             -> urban_form_2000
  total_pop             -> urban_growth_form
  total_pop             -> urban_pop_growth
  urban_form_2000       -> empty_spaces_scarcity
  urban_form_2000       -> job_accessibility
  urban_form_2000       -> urban_growth_form
  urban_growth_form     -> growth_pop_risk
  urban_pop_growth      -> empty_spaces_scarcity
  urban_pop_growth      -> growth_pop_risk
  urban_pop_growth      -> urban_growth_form
  region                -> risk_distribution
  region                -> urban_pop_growth
  topography            -> risk_distribution
  topography            -> urban_form_2000
  topography            -> urban_growth_form
  region                -> gdp_pc
  region                -> job_accessibility
  topography            -> empty_spaces_scarcity
}')

cat(sprintf("  Nós: %d  |  Arestas: %d\n",
            length(names(dag)), nrow(edges(dag))))

# =============================================================================
# 2) Implicações do DAG
# =============================================================================

cat("\n2) Conjuntos de ajuste — mínimo e máximo (urban_growth_form → growth_pop_risk):\n")

adj_min <- adjustmentSets(dag, exposure = "urban_growth_form",
                          outcome = "growth_pop_risk", type = "minimal")
adj_max <- adjustmentSets(dag, exposure = "urban_growth_form",
                          outcome = "growth_pop_risk", type = "canonical")

cat("\n  Mínimo(s):\n"); print(adj_min)
cat("\n  Máximo (canônico):\n"); print(adj_max)

obs_nodes <- setdiff(names(dag),
                     c("inefficiency_land", "risk_distribution",
                       "urban_growth_form", "growth_pop_risk"))
min_vars  <- if (length(adj_min) > 0) as.character(adj_min[[1]]) else character(0)
max_vars  <- if (length(adj_max) > 0) as.character(adj_max[[1]]) else character(0)
extra     <- setdiff(max_vars, min_vars)
cat(sprintf("\n  Variáveis adicionais no máximo (vs mínimo): {%s}\n",
            if (length(extra)) paste(extra, collapse = ", ") else "nenhuma"))

cat("\n3) Independências condicionais implícitas pelo DAG:\n")
ci_list <- impliedConditionalIndependencies(dag)
print(ci_list)

# =============================================================================
# 3) Mapear nós → variáveis observadas
# =============================================================================
#
#  DAG node              Proxy no dataset                       Status
#  ───────────────────── ────────────────────────────────────── ──────────
#  growth_pop_risk       g_alta                                 observado
#  urban_growth_form     pct_area_densif_infill_0010            observado
#  urban_form_2000       log(urban_density_2000 + 1)            observado
#  urban_pop_growth      g_fora_alta                            observado (proxy)
#  total_pop             log(pop_2000 + 1)                      observado
#  gdp_pc                log_pib_pc                             observado
#  topography            topo_prop_inclinado                    observado
#  region                regiao → inteiro ordinal               observado
#  empty_spaces_scarcity pct_nao_constru_fora_alta_2010_q1      observado
#  job_accessibility     palma_commute                          observado (proxy)
#  inefficiency_land     —                                      LATENTE
#  risk_distribution     —                                      LATENTE

cat("\n4) Preparando dados para teste local...\n")

ds_raw <- read_csv(file.path(tables_dir, "dataset_regressao_municipio.csv"),
                   show_col_types = FALSE)

cat("\n  Variáveis disponíveis no dataset:\n")
grps <- list(
  "Y / risco"      = grep("^g_|^pp_|^delta_", names(ds_raw), value = TRUE),
  "Forma urbana"   = grep("pct_area|pct_urban|pct_pop_densif|area_urban", names(ds_raw), value = TRUE),
  "Terra segura"   = grep("nao_constru", names(ds_raw), value = TRUE),
  "Distância"      = grep("dist_", names(ds_raw), value = TRUE),
  "Desigualdade"   = grep("palma|rent|commute|iqr|pct_long", names(ds_raw), value = TRUE),
  "Topografia"     = grep("topo_", names(ds_raw), value = TRUE),
  "Socioeconômico" = intersect(c("pib_pc_2010","pop_total_2010","pop_urbana_2010_cg",
                                  "prop_favelas_2010"),
                               names(ds_raw)),
  "Categórico"     = intersect(c("regiao","urban_class","hierarquia_grupo"), names(ds_raw))
)
for (nm in names(grps)) {
  if (length(grps[[nm]])) cat(sprintf("  %-18s %s\n", nm, paste(grps[[nm]], collapse = ", ")))
}

dag_data <- ds_raw %>%
  mutate(
    pct_area_densif_infill_0010 = pct_area_densif_0010 + pct_area_infill_0010,
    log_pib_pc                  = log(pib_pc_2010 + 1),
    region_int = as.integer(factor(regiao,
                   levels = c("Sudeste","Sul","Nordeste","Norte","Centro-Oeste")))
  ) %>%
  transmute(
    growth_pop_risk       = g_alta,
    urban_growth_form     = pct_area_densif_infill_0010,
    urban_form_2000       = log(urban_density_2000 + 1),
    urban_pop_growth      = g_fora_alta,
    total_pop             = log(pop_2000 + 1),
    gdp_pc                = log_pib_pc,
    topography            = topo_prop_inclinado,
    region                = region_int,
    empty_spaces_scarcity = pct_nao_constru_fora_alta_2010_q1,
    job_accessibility     = palma_commute
  ) %>%
  drop_na()

cat(sprintf("\n  N com complete cases: %d  (de %d carregados)\n",
            nrow(dag_data), nrow(ds_raw)))
cat(sprintf("  Variáveis mapeadas: %s\n", paste(names(dag_data), collapse = ", ")))

# =============================================================================
# 4) Testes locais de independência condicional
# =============================================================================

cat("\n5) Testes locais de independência condicional (correlação parcial):\n")

tests <- localTests(dag, data = as.data.frame(dag_data), type = "cis")
tests <- tests[order(tests$p.value), ]

cat(sprintf("  %d independências testadas\n", nrow(tests)))
cat(sprintf("  Rejeitadas (p < 0.05): %d\n", sum(tests$p.value < 0.05, na.rm = TRUE)))
cat(sprintf("  Rejeitadas (p < 0.10): %d\n", sum(tests$p.value < 0.10, na.rm = TRUE)))
cat("\n  Top 10 violações (menor p-valor):\n")
print(round(head(tests, 10), 4))

write.csv(tests, file.path(tables_dir, "dag_local_tests.csv"))
cat(sprintf("  ✓ dag_local_tests.csv (%d testes)\n", nrow(tests)))

# =============================================================================
# 5) Regressão com conjunto de ajuste do DAG
# =============================================================================

cat("\n6) Regressão — mínimo vs máximo...\n")

run_dag_reg <- function(label, adj_vars, dag_data) {
  needed   <- c("growth_pop_risk", "urban_growth_form", adj_vars)
  needed   <- intersect(needed, names(dag_data))
  adj_vars <- intersect(adj_vars, names(dag_data))

  dat <- dag_data[complete.cases(dag_data[, needed]), ]
  rhs <- paste(c("urban_growth_form", adj_vars), collapse = " + ")
  f   <- as.formula(paste("growth_pop_risk ~", rhs))
  mod <- lm(f, data = dat)
  rob <- coeftest(mod, vcov = vcovHC(mod, type = "HC3"))

  cat(sprintf("\n  === %s  |  Ajuste: {%s}  |  N: %d ===\n",
              label, paste(adj_vars, collapse = ", "), nrow(dat)))
  print(rob)
  cat(sprintf("  R² = %.3f  |  R² adj. = %.3f\n",
              summary(mod)$r.squared, summary(mod)$adj.r.squared))

  b  <- rob["urban_growth_form", "Estimate"]
  se <- rob["urban_growth_form", "Std. Error"]
  p  <- rob["urban_growth_form", "Pr(>|t|)"]
  cat(sprintf("  β(urban_growth_form) = %.4f  SE = %.4f  p = %.4f\n", b, se, p))
  invisible(mod)
}

if (length(adj_min) > 0) {
  run_dag_reg("MÍNIMO", as.character(adj_min[[1]]), dag_data)
} else {
  cat("  AVISO: nenhum conjunto mínimo encontrado.\n")
}

if (length(adj_max) > 0) {
  run_dag_reg("MÁXIMO (canônico)", as.character(adj_max[[1]]), dag_data)
} else {
  cat("  AVISO: nenhum conjunto máximo encontrado.\n")
}

# =============================================================================
# 6) Figura do DAG
# =============================================================================

cat("\n7) Gerando figura do DAG...\n")

p_dag <- ggdag_status(dag, use_labels = "name", text = FALSE,
                      label_size = 2.8, layout = "nicely") +
  theme_dag_blank(panel.background = element_rect(fill = "white", colour = NA)) +
  scale_color_manual(values = c(exposure = "#2166ac", outcome = "#d6604d",
                                 adjusted = "#4dac26", unadjusted = "grey60"),
                     name = NULL) +
  labs(title = "Causal DAG: urban growth form 2000–2010 → risk-zone pop. growth 2010–2022",
       caption = "Blue = exposure  |  Red = outcome  |  Arrow = causal direction") +
  theme(plot.title   = element_text(size = 10, face = "bold"),
        plot.caption = element_text(size = 7),
        legend.position = "bottom")

ggsave(file.path(figures_dir, "dag_causal.png"), p_dag,
       width = 28, height = 20, units = "cm", dpi = 200)
cat("  ✓ dag_causal.png\n")

# =============================================================================
# 7) Triagem de variáveis externas ao DAG
# =============================================================================

cat("\n8) Triagem de variáveis externas ao DAG...\n")

adj_min_vars <- if (length(adj_min) > 0) as.character(adj_min[[1]]) else character(0)

candidatas <- list(
  list(var = "prop_favelas_2010",              label = "Slum share 2010",                  tempo = "pre"),
  list(var = "g_slums_1022",                   label = "Slum pop growth 2010–22 (total)",  tempo = "des"),
  list(var = "g_alta_slums_1022",              label = "Slum pop growth — alta risk",      tempo = "des"),
  list(var = "pct_area_periph_ext_leap_0010",  label = "Periph+Ext+Leap % 2000–10",        tempo = "trat"),
  list(var = "palma_rent",                     label = "Palma ratio — rent",               tempo = "pre"),
  list(var = "median_rent",                    label = "Median rent",                      tempo = "pre"),
  list(var = "topo_prop_inclinado",            label = "Steep terrain %",                  tempo = "pre"),
  list(var = "log_area_2000_km2",              label = "Log urban footprint 2000 (km²)",   tempo = "pre"),
  list(var = "log_density_2010",               label = "Log urban density 2010",           tempo = "pre")
)

dag_full <- ds_raw %>%
  mutate(
    pct_area_densif_infill_0010       = pct_area_densif_0010 + pct_area_infill_0010,
    pct_area_periph_ext_leap_0010     = pct_area_peripheral_0010 + pct_area_extension_0010 +
                                        pct_area_leapfrog_0010,
    log_pop_total_2000                = log(pop_2000 + 1),
    log_pib_pc                        = log(pib_pc_2010 + 1),
    log_area_2000_km2                 = log(area_2000_m2 / 1e6 + 0.001),
    # denominator on the mapped units (6f.2)
    log_density_2010                  = log(pop_urbana_2010_cg /
                                             (area_urbana_2010_m2_mapped / 1e6 + 0.001) + 1),
    region_int = as.integer(factor(regiao,
                   levels = c("Sudeste","Sul","Nordeste","Norte","Centro-Oeste")))
  )

triage_var <- function(cand_var, label, tempo, data, adj_vars) {
  dd <- data %>%
    mutate(
      growth_pop_risk       = g_alta,
      urban_growth_form     = pct_area_densif_infill_0010,
      urban_form_2000       = log(urban_density_2000 + 1),
      urban_pop_growth      = g_fora_alta,
      total_pop             = log_pop_total_2000,
      gdp_pc                = log_pib_pc,
      topography            = topo_prop_inclinado,
      region                = region_int,
      empty_spaces_scarcity = pct_nao_constru_fora_alta_2010_q1,
      job_accessibility     = palma_commute
    )

  p_y <- NA_real_; r_y <- NA_real_
  tryCatch({
    cols_y  <- intersect(c("growth_pop_risk", cand_var, adj_min_vars), names(dd))
    dat_y   <- dd[complete.cases(dd[, cols_y]), ]
    if (nrow(dat_y) > 20 && cand_var %in% names(dat_y)) {
      mod_y   <- lm(as.formula(paste("growth_pop_risk ~",
                                     paste(c(cand_var, adj_min_vars), collapse = " + "))),
                    data = dat_y)
      coefs_y <- coef(summary(mod_y))
      if (cand_var %in% rownames(coefs_y)) {
        r_y <- coefs_y[cand_var, "Estimate"]
        p_y <- coefs_y[cand_var, "Pr(>|t|)"]
      }
    }
  }, error = function(e) NULL)

  p_x <- NA_real_; r_x <- NA_real_
  tryCatch({
    cols_x  <- intersect(c("urban_growth_form", cand_var, adj_min_vars), names(dd))
    dat_x   <- dd[complete.cases(dd[, cols_x]), ]
    if (nrow(dat_x) > 20 && cand_var %in% names(dat_x)) {
      mod_x   <- lm(as.formula(paste("urban_growth_form ~",
                                     paste(c(cand_var, adj_min_vars), collapse = " + "))),
                    data = dat_x)
      coefs_x <- coef(summary(mod_x))
      if (cand_var %in% rownames(coefs_x)) {
        r_x <- coefs_x[cand_var, "Estimate"]
        p_x <- coefs_x[cand_var, "Pr(>|t|)"]
      }
    }
  }, error = function(e) NULL)

  sig_y <- !is.na(p_y) && p_y < 0.05
  sig_x <- !is.na(p_x) && p_x < 0.05
  papel <- dplyr::case_when(
    tempo == "des"  & sig_y              ~ "mediador/paralelo — NÃO adicionar ao DAG",
    tempo == "pre"  & sig_y & sig_x      ~ "** CONFUNDIDOR — candidato a entrar no DAG",
    tempo == "trat" & sig_y & sig_x      ~ "* confundidor/mediador — avaliar inclusão",
    tempo == "pre"  & sig_y & !sig_x     ~ "causa direta do Y — possível nó adicional",
    tempo == "pre"  & !sig_y             ~ "irrelevante (não associado a Y | ajuste)",
    tempo == "trat" & !sig_y             ~ "irrelevante (não associado a Y | ajuste)",
    TRUE                                 ~ "inconclusivo"
  )

  list(var = cand_var, label = label, tempo = tempo,
       beta_y = r_y, p_y = p_y, beta_x = r_x, p_x = p_x, papel = papel)
}

results_triage <- lapply(candidatas, function(c)
  triage_var(c$var, c$label, c$tempo, dag_full, adj_min_vars))

cat(sprintf("\n  %-42s %-6s  %7s %6s  %7s %6s  %s\n",
            "Variável", "Tempo", "β→Y", "p→Y", "β→X", "p→X", "Papel"))
cat(strrep("-", 115), "\n")
for (r in results_triage) {
  cat(sprintf("  %-42s %-6s  %7.3f %6.3f  %7.3f %6.3f  %s\n",
              r$label, r$tempo,
              ifelse(is.na(r$beta_y), 0, r$beta_y), ifelse(is.na(r$p_y), 1, r$p_y),
              ifelse(is.na(r$beta_x), 0, r$beta_x), ifelse(is.na(r$p_x), 1, r$p_x),
              r$papel))
}

triage_df <- do.call(rbind, lapply(results_triage, as.data.frame))
write.csv(triage_df, file.path(tables_dir, "dag_triage_external_vars.csv"),
          row.names = FALSE)
cat(sprintf("\n  ✓ dag_triage_external_vars.csv\n"))

cat("\n", strrep("=", 60), "\n")
cat("CONCLUÍDO\n")
cat(strrep("=", 60), "\n")
