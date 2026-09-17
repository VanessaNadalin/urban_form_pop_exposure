# =============================================================================
# 12a_diagnostico_outliers.R
# Diagnóstico de outliers e observações influentes para g_alta
#
# MOTIVAÇÃO:
#   Com a nova fórmula g_alta = 100 * (pop22 - pop10) / pop_2010_risk_total,
#   municípios com base populacional pequena em áreas de risco geram valores
#   extremos que podem dominar a regressão (alta alavancagem/Cook's distance).
#
# ANÁLISES:
#   1) Distribuição de g_alta: histogramas, quantis, assimetria
#   2) Base populacional mínima: identificar municípios com pop_risco_2010 pequena
#   3) Observações influentes: Cook's D, leverage, DFBETAs
#   4) Transformações:
#      - log(1 + g_alta) para valores positivos
#      - Winsorização (95%, 99%)
#      - Filtro de base mínima (pop_risco_2010 > threshold)
#   5) Comparação de coeficientes: original vs transformadas
#
# Inputs:
#   data/processed_data/04_regression/tables/dataset_regressao_municipio.csv  (script 15)
#
# Outputs (data/processed_data/04_regression/diagnosticos/):
#   outliers_g_alta.pdf          : gráficos de diagnóstico
#   influential_obs.csv          : observações influentes identificadas
#   comparacao_especificacoes.csv : coeficientes lado a lado
#   dataset_regressao_municipio_winsorizado.csv : dados com winsorização
#
# Run from the repository root (relative paths, CLAUDE.md rule 5).
# =============================================================================

source("04_regression_dataset_and_models/00_setup.R")

library(car)        # Para vif, influencePlot
library(DescTools)  # Para Winsorize

cat("\n", strrep("=", 60), "\n")
cat("12a_DIAGNOSTICO_OUTLIERS.R\n")
cat(strrep("=", 60), "\n")

# =============================================================================
# 0) CRIAR DIRETÓRIO DE DIAGNÓSTICOS
# =============================================================================

diag_dir <- file.path(data_dir, "diagnosticos")
dir.create(diag_dir, showWarnings = FALSE, recursive = TRUE)

# =============================================================================
# 1) CARREGAR DADOS
# =============================================================================

cat("\n1) Carregando dataset de regressão...\n")

path_mun <- file.path(tables_dir, "dataset_regressao_municipio.csv")
if (!file.exists(path_mun))
  stop("Execute 11b_dataset_final.R primeiro.")

df <- read_csv(path_mun, show_col_types = FALSE)

cat(sprintf("  Dataset: %d municípios × %d colunas\n", nrow(df), ncol(df)))

# =============================================================================
# 2) DISTRIBUIÇÃO DE g_alta
# =============================================================================

cat("\n2) Analisando distribuição de g_alta...\n")

# Verificar se g_alta existe
if (!"g_alta" %in% names(df)) {
  stop("Variável g_alta não encontrada. Execute script 10 com nova fórmula primeiro.")
}

# Remover NAs para análise
df_valido <- df %>% filter(!is.na(g_alta))
cat(sprintf("  Observações válidas: %d\n", nrow(df_valido)))

# Estatísticas descritivas
cat("\n  Estatísticas descritivas de g_alta:\n")
stats <- df_valido %>%
  summarise(
    n = n(),
    media = mean(g_alta),
    mediana = median(g_alta),
    dp = sd(g_alta),
    min = min(g_alta),
    p5 = quantile(g_alta, 0.05),
    p25 = quantile(g_alta, 0.25),
    p75 = quantile(g_alta, 0.75),
    p95 = quantile(g_alta, 0.95),
    p99 = quantile(g_alta, 0.99),
    max = max(g_alta),
    assimetria = moments::skewness(g_alta),
    curtose = moments::kurtosis(g_alta)
  )

print(t(stats), digits = 2)

# Identificar extremos
cat("\n  Municípios com g_alta nos extremos:\n")
cat("\n  TOP 10 maiores g_alta:\n")

# Selecionar apenas colunas que existem
cols_base <- c("cod_mun", "NM_CIDADE", "g_alta", "pop_urbana_2010_cg")
cols_extras <- c("pp_alta_2010", "pp_alta_2022", "delta_pp_alta",
                 "pop_2010_risk_total", "pop_2022_risk_total")
cols_disponivel <- c(cols_base, intersect(cols_extras, names(df_valido)))

df_valido %>%
  select(all_of(cols_disponivel)) %>%
  arrange(desc(g_alta)) %>%
  head(10) %>%
  print()

cat("\n  TOP 10 menores g_alta (decrescimento):\n")
df_valido %>%
  select(all_of(cols_disponivel)) %>%
  arrange(g_alta) %>%
  head(10) %>%
  print()

# =============================================================================
# 3) BASE POPULACIONAL MÍNIMA
# =============================================================================

cat("\n3) Analisando base populacional em áreas de risco...\n")

# Verificar se pop_2010_risk_total existe
if ("pop_2010_risk_total" %in% names(df_valido)) {
  cat("\n  Distribuição de pop_2010_risk_total (base 2010):\n")

  base_stats <- df_valido %>%
    summarise(
      n = n(),
      media = mean(pop_2010_risk_total, na.rm = TRUE),
      mediana = median(pop_2010_risk_total, na.rm = TRUE),
      min = min(pop_2010_risk_total, na.rm = TRUE),
      p10 = quantile(pop_2010_risk_total, 0.10, na.rm = TRUE),
      p25 = quantile(pop_2010_risk_total, 0.25, na.rm = TRUE),
      p50 = quantile(pop_2010_risk_total, 0.50, na.rm = TRUE),
      p75 = quantile(pop_2010_risk_total, 0.75, na.rm = TRUE),
      p90 = quantile(pop_2010_risk_total, 0.90, na.rm = TRUE),
      max = max(pop_2010_risk_total, na.rm = TRUE)
    )
  print(t(base_stats), digits = 1)

  # Contagem por faixas
  cat("\n  Municípios por faixa de população em risco (2010):\n")
  df_valido %>%
    mutate(
      faixa = cut(pop_2010_risk_total,
                  breaks = c(0, 100, 500, 1000, 5000, 10000, Inf),
                  labels = c("<100", "100-500", "500-1k", "1k-5k", "5k-10k", ">10k"),
                  include.lowest = TRUE)
    ) %>%
    count(faixa) %>%
    print()

  # Correlação entre base populacional e g_alta
  cat("\n  Correlação entre pop_2010_risk_total e g_alta:\n")
  cor_base_g <- cor(df_valido$pop_2010_risk_total, df_valido$g_alta,
                     use = "complete.obs", method = "spearman")
  cat(sprintf("    Spearman rho = %.3f\n", cor_base_g))

} else {
  cat("  ⚠ pop_2010_risk_total não disponível no dataset.\n")
  cat("    Execute script 11b atualizado para incluir esta variável.\n")
}

# =============================================================================
# 4) GRÁFICOS DE DISTRIBUIÇÃO
# =============================================================================

cat("\n4) Gerando gráficos de distribuição...\n")

pdf(file.path(diag_dir, "outliers_g_alta.pdf"), width = 12, height = 8)

# Painel 1: Histograma + densidade
par(mfrow = c(2, 3))

hist(df_valido$g_alta, breaks = 50, col = "lightblue", border = "white",
     main = "Distribuição de g_alta",
     xlab = "g_alta (%)", ylab = "Frequência")
abline(v = median(df_valido$g_alta), col = "red", lwd = 2, lty = 2)

# Histograma em escala log (valores positivos)
df_pos <- df_valido %>% filter(g_alta > 0)
if (nrow(df_pos) > 0) {
  hist(log10(df_pos$g_alta + 1), breaks = 50, col = "lightgreen", border = "white",
       main = "Distribuição de log10(1 + g_alta)\n(apenas valores positivos)",
       xlab = "log10(1 + g_alta)", ylab = "Frequência")
}

# Boxplot
boxplot(df_valido$g_alta, col = "lightcoral",
        main = "Boxplot de g_alta",
        ylab = "g_alta (%)")

# Q-Q plot
qqnorm(df_valido$g_alta, main = "Q-Q Plot: g_alta vs Normal")
qqline(df_valido$g_alta, col = "red", lwd = 2)

# Se temos pop_risco base, fazer scatterplot
if ("pop_2010_risk_total" %in% names(df_valido)) {
  plot(df_valido$pop_2010_risk_total, df_valido$g_alta,
       pch = 16, col = rgb(0, 0, 0, 0.3),
       xlab = "Pop em risco 2010 (base)", ylab = "g_alta (%)",
       main = "g_alta vs Base populacional")
  abline(h = 0, col = "red", lty = 2)

  # Versão em escala log-log
  plot(log10(df_valido$pop_2010_risk_total + 1), df_valido$g_alta,
       pch = 16, col = rgb(0, 0, 0, 0.3),
       xlab = "log10(Pop em risco 2010 + 1)", ylab = "g_alta (%)",
       main = "g_alta vs log(Base populacional)")
  abline(h = 0, col = "red", lty = 2)
}

dev.off()
cat(sprintf("  ✓ Gráficos salvos em: %s\n", basename(file.path(diag_dir, "outliers_g_alta.pdf"))))

# =============================================================================
# 5) REGRESSÃO DE REFERÊNCIA E DIAGNÓSTICO DE INFLUÊNCIA
# =============================================================================

cat("\n5) Estimando regressão de referência para diagnóstico...\n")

# Modelo simples para diagnóstico (usar especificação do script 12)
# Vou usar uma especificação compacta como exemplo

# Verificar disponibilidade de variáveis-chave
vars_trat <- c("pct_urban_growth_0010", "pct_area_densif_0010",
               "pct_area_periph_ext_leap_0010")
vars_ctrl <- c("regiao", "log(pib_pc_2010)", "log(pop_total_2010)")

# Preparar dados
df_reg <- df_valido %>%
  filter(!is.na(g_alta),
         !is.na(pct_urban_growth_0010))

# Adicionar variáveis auxiliares se necessário
if (!"pct_area_periph_ext_leap_0010" %in% names(df_reg)) {
  if (all(c("pct_area_peripheral_0010", "pct_area_extension_0010", "pct_area_leapfrog_0010") %in% names(df_reg))) {
    df_reg <- df_reg %>%
      mutate(pct_area_periph_ext_leap_0010 = pct_area_peripheral_0010 +
                                              pct_area_extension_0010 +
                                              pct_area_leapfrog_0010)
  }
}

cat(sprintf("  Observações para regressão: %d\n", nrow(df_reg)))

# Modelo de referência
if (nrow(df_reg) > 50) {
  formula_ref <- as.formula(paste("g_alta ~", paste(vars_trat, collapse = " + "),
                                  "+ regiao + log(pib_pc_2010) + log(pop_total_2010)"))

  modelo_ref <- lm(formula_ref, data = df_reg)

  cat("\n  Resumo do modelo de referência:\n")
  print(summary(modelo_ref))

  # Diagnóstico de influência
  cat("\n6) Calculando medidas de influência...\n")

  # Cook's distance
  cooksd <- cooks.distance(modelo_ref)
  n <- nrow(df_reg)
  threshold_cook <- 4 / n

  cat(sprintf("\n  Threshold Cook's D (4/n): %.4f\n", threshold_cook))
  cat(sprintf("  Observações acima do threshold: %d\n", sum(cooksd > threshold_cook)))

  # Leverage (hat values)
  leverage <- hatvalues(modelo_ref)
  k <- length(coef(modelo_ref))
  threshold_lev <- 2 * k / n

  cat(sprintf("  Threshold leverage (2k/n): %.4f\n", threshold_lev))
  cat(sprintf("  Observações com alta alavancagem: %d\n", sum(leverage > threshold_lev)))

  # Identificar observações influentes
  df_reg <- df_reg %>%
    mutate(
      cooksd = cooksd,
      leverage = leverage,
      influente_cook = cooksd > threshold_cook,
      influente_lev = leverage > threshold_lev,
      influente = influente_cook | influente_lev
    )

  cat("\n  TOP 20 observações mais influentes (Cook's D):\n")
  df_influentes <- df_reg %>%
    arrange(desc(cooksd)) %>%
    select(cod_mun, NM_CIDADE, g_alta, cooksd, leverage,
           pop_total_2010, pct_urban_growth_0010) %>%
    head(20)
  print(df_influentes)

  # Salvar observações influentes
  path_infl <- file.path(diag_dir, "influential_obs.csv")
  write_csv(df_influentes, path_infl)
  cat(sprintf("\n  ✓ Observações influentes salvas: %s\n", basename(path_infl)))

  # Gráfico de influência
  pdf(file.path(diag_dir, "influence_plots.pdf"), width = 12, height = 8)
  par(mfrow = c(2, 2))

  plot(cooksd, pch = 16, col = ifelse(cooksd > threshold_cook, "red", "gray"),
       main = "Cook's Distance", ylab = "Cook's D", xlab = "Observação")
  abline(h = threshold_cook, col = "red", lty = 2)

  plot(leverage, pch = 16, col = ifelse(leverage > threshold_lev, "red", "gray"),
       main = "Leverage (Hat Values)", ylab = "Leverage", xlab = "Observação")
  abline(h = threshold_lev, col = "red", lty = 2)

  plot(leverage, cooksd, pch = 16,
       col = ifelse(cooksd > threshold_cook | leverage > threshold_lev, "red", "gray"),
       main = "Cook's D vs Leverage", xlab = "Leverage", ylab = "Cook's D")
  abline(h = threshold_cook, v = threshold_lev, col = "red", lty = 2)

  # Residuals vs Fitted
  plot(modelo_ref, which = 1)

  dev.off()
  cat(sprintf("  ✓ Gráficos de influência salvos: influence_plots.pdf\n"))

} else {
  cat("  ⚠ Dados insuficientes para regressão de referência.\n")
}

# =============================================================================
# 7) TRANSFORMAÇÕES E ALTERNATIVAS
# =============================================================================

cat("\n7) Criando versões transformadas de g_alta...\n")

# Calcular limites para winsorização
q_95_lower <- quantile(df_valido$g_alta, 0.025, na.rm = TRUE)
q_95_upper <- quantile(df_valido$g_alta, 0.975, na.rm = TRUE)
q_99_lower <- quantile(df_valido$g_alta, 0.005, na.rm = TRUE)
q_99_upper <- quantile(df_valido$g_alta, 0.995, na.rm = TRUE)

cat(sprintf("  Limites winsorização 95%%: [%.2f, %.2f]\n", q_95_lower, q_95_upper))
cat(sprintf("  Limites winsorização 99%%: [%.2f, %.2f]\n", q_99_lower, q_99_upper))

df_transform <- df_valido %>%
  mutate(
    # Log(1 + g) — funciona para positivos
    g_alta_log1p = ifelse(g_alta > -100, log(1 + g_alta/100) * 100, NA),

    # Winsorização em diferentes níveis (manual)
    g_alta_wins95 = pmin(pmax(g_alta, q_95_lower), q_95_upper),
    g_alta_wins99 = pmin(pmax(g_alta, q_99_lower), q_99_upper),

    # Indicadora de base pequena (se disponível)
    base_pequena = if("pop_2010_risk_total" %in% names(.))
                     pop_2010_risk_total < 500 else NA
  )

# Estatísticas comparativas
cat("\n  Comparação das distribuições:\n\n")
comp_stats <- df_transform %>%
  summarise(
    across(
      c(g_alta, g_alta_log1p, g_alta_wins95, g_alta_wins99),
      list(
        media = ~mean(., na.rm = TRUE),
        mediana = ~median(., na.rm = TRUE),
        dp = ~sd(., na.rm = TRUE),
        min = ~min(., na.rm = TRUE),
        max = ~max(., na.rm = TRUE),
        p95 = ~quantile(., 0.95, na.rm = TRUE)
      ),
      .names = "{.col}_{.fn}"
    )
  )

print(t(comp_stats), digits = 2)

# Salvar dataset com transformações
path_wins <- file.path(tables_dir, "dataset_regressao_municipio_winsorizado.csv")

df_final <- df %>%
  left_join(
    df_transform %>% select(cod_mun, g_alta_log1p, g_alta_wins95, g_alta_wins99),
    by = "cod_mun"
  )

write_csv(df_final, path_wins)
cat(sprintf("\n  ✓ Dataset com transformações salvo: %s\n", basename(path_wins)))

# =============================================================================
# 8) COMPARAÇÃO DE ESPECIFICAÇÕES (se modelo foi estimado)
# =============================================================================

if (exists("modelo_ref")) {
  cat("\n8) Comparando especificações alternativas...\n")

  # Re-estimar com versões transformadas
  df_reg_trans <- df_final %>%
    filter(!is.na(g_alta), !is.na(pct_urban_growth_0010))

  if (nrow(df_reg_trans) > 50) {

    # Modelo com winsorização 95%
    modelo_wins95 <- lm(
      update(formula_ref, g_alta_wins95 ~ .),
      data = df_reg_trans
    )

    # Modelo com winsorização 99%
    modelo_wins99 <- lm(
      update(formula_ref, g_alta_wins99 ~ .),
      data = df_reg_trans
    )

    # Modelo com log(1+g) (apenas valores positivos)
    df_reg_log <- df_reg_trans %>% filter(!is.na(g_alta_log1p))
    modelo_log <- lm(
      update(formula_ref, g_alta_log1p ~ .),
      data = df_reg_log
    )

    # Comparar coeficientes
    cat("\n  Comparação de coeficientes (variável de tratamento principal):\n")

    coef_comp <- data.frame(
      variavel = names(coef(modelo_ref)),
      original = coef(modelo_ref),
      se_original = sqrt(diag(vcov(modelo_ref))),
      wins95 = coef(modelo_wins95),
      se_wins95 = sqrt(diag(vcov(modelo_wins95))),
      wins99 = coef(modelo_wins99),
      se_wins99 = sqrt(diag(vcov(modelo_wins99))),
      log1p = c(coef(modelo_log), rep(NA, length(coef(modelo_ref)) - length(coef(modelo_log)))),
      se_log1p = c(sqrt(diag(vcov(modelo_log))), rep(NA, length(coef(modelo_ref)) - length(coef(modelo_log))))
    )

    # Filtrar apenas variáveis de tratamento
    coef_comp_trat <- coef_comp %>%
      filter(variavel %in% vars_trat)

    print(coef_comp_trat, digits = 3)

    # Salvar comparação completa
    path_comp <- file.path(diag_dir, "comparacao_especificacoes.csv")
    write_csv(coef_comp, path_comp)
    cat(sprintf("\n  ✓ Comparação de coeficientes salva: %s\n", basename(path_comp)))

    # R² comparado
    cat("\n  Comparação de R²:\n")
    r2_comp <- data.frame(
      modelo = c("Original", "Winsorizado 95%", "Winsorizado 99%", "Log(1+g)"),
      R2 = c(summary(modelo_ref)$r.squared,
             summary(modelo_wins95)$r.squared,
             summary(modelo_wins99)$r.squared,
             summary(modelo_log)$r.squared),
      R2_adj = c(summary(modelo_ref)$adj.r.squared,
                 summary(modelo_wins95)$adj.r.squared,
                 summary(modelo_wins99)$adj.r.squared,
                 summary(modelo_log)$adj.r.squared),
      n_obs = c(nobs(modelo_ref), nobs(modelo_wins95),
                nobs(modelo_wins99), nobs(modelo_log))
    )
    print(r2_comp, digits = 4)
  }
}

# =============================================================================
# 9) RECOMENDAÇÕES
# =============================================================================

cat("\n", strrep("=", 60), "\n")
cat("CONCLUÍDO - DIAGNÓSTICO DE OUTLIERS\n")
cat(strrep("=", 60), "\n")

cat("\nARQUIVOS GERADOS:\n")
cat(sprintf("  1) %s/outliers_g_alta.pdf\n", basename(diag_dir)))
cat(sprintf("  2) %s/influence_plots.pdf\n", basename(diag_dir)))
cat(sprintf("  3) %s/influential_obs.csv\n", basename(diag_dir)))
cat(sprintf("  4) %s/comparacao_especificacoes.csv\n", basename(diag_dir)))
cat(sprintf("  5) %s (dataset com transformações)\n", basename(path_wins)))

cat("\nRECOMENDAÇÕES:\n")
cat("  1) Examine os gráficos em outliers_g_alfa.pdf\n")
cat("  2) Identifique municípios influentes em influential_obs.csv\n")
cat("  3) Compare coeficientes em comparacao_especificacoes.csv\n")
cat("  4) CONSIDERE:\n")
cat("     - Usar winsorização (95% ou 99%) se outliers dominam\n")
cat("     - Usar log(1+g) se a relação é multiplicativa\n")
cat("     - Adicionar filtro de base mínima (pop_risco_2010 > 500 ou 1000)\n")
cat("     - Excluir observações com Cook's D muito alto (> 4/n)\n")
cat("  5) Re-estime script 12 com a especificação escolhida\n")

cat("\nPróximo passo: Revisar diagnósticos e decidir especificação final.\n")
