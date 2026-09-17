# =============================================================================
# 15_estudo_de_caso.R
# Tabela de comparação para municípios selecionados para análise de mapas
#
# Linhas : municípios selecionados (cod_mun verificados no IBGE)
# Colunas:
#   1. % terrain inclinado (topo_prop_inclinado)
#   2. Crescimento pop fora da suscept. alta 2010→2022, % (g_fora_alta)
#   3. % área periférica+extensão+leapfrog 2000→2010
#   4. % pop em suscept. alta 2010 (pp_alta_2010)
#   5. Pop total 2010 (pop_total_2010)
#   6. PIB per capita 2010 (pib_pc_2010)
#   7. Dens. urbana 2010, hab/km² (pop_urbana_2010_cg / area_urbana_2010_m2)
#   8. Urban footprint 2000, km² (area_2000_m2)
#   9. Slum share 2010 — % pop em AGSN (prop_favelas_2010)
#  10. Palma ratio — rent (palma_rent)
#  11. Palma ratio — commute (palma_commute)
#  12. Median rent 2010 — R$ (median_rent)
#  13. Safe empty land Q1 — % urban footprint fora alta suscept., Q1 renda
#  14. Rank g_alta na amostra completa (rank_g_alta)
#  15. Rank pp_alta_2010 na amostra completa (rank_pp_alta)
#  16. Rank delta_pp_alta na amostra completa (rank_delta_pp_alta)
#
# Input : data/processed_data/04_regression/tables/dataset_regressao_municipio.csv  (script 15)
# Output: data/processed_data/04_regression/tables/case_study_municipios.csv  (write.csv2)
#
# Run from the repository root (relative paths, CLAUDE.md rule 5).
# =============================================================================

source("04_regression_dataset_and_models/00_setup.R")

cat("\n", strrep("=", 60), "\n")
cat("15_ESTUDO_DE_CASO.R\n")
cat(strrep("=", 60), "\n")

# =============================================================================
# 1) Municípios alvo (cod_mun verificados no IBGE)
# =============================================================================

alvo <- tibble::tibble(
  label   = c("Florianópolis-SC", "Salvador-BA", "Pedreiras-MA",
              "Extrema-MG", "Jaraguá do Sul-SC", "União dos Palmares-AL",
              "Sinop-MT", "Belém-PA", "Curitiba-PR", "Paranaguá-PR"),
  cod_mun = c(4205407, 2927408, 2108207,
              3125101, 4208906, 2709301,
              5107909, 1501402, 4106902, 4118204)
)

# =============================================================================
# 2) Verificar presença na amostra
# =============================================================================

amostra <- readRDS(amostra_rds) |>
  mutate(cod_mun = as.double(cod_mun))
cat(sprintf("amostra_municipios.rds: %d municípios\n", nrow(amostra)))

alvo <- alvo |>
  mutate(na_amostra = cod_mun %in% amostra$cod_mun)

fora <- alvo |> filter(!na_amostra)
if (nrow(fora) > 0) {
  cat("\nATENÇÃO: municípios ausentes da amostra:\n")
  print(fora |> select(label, cod_mun))
} else {
  cat(sprintf("\nTodos os %d municípios presentes na amostra.\n", nrow(alvo)))
}

# =============================================================================
# 3) Carregar dataset de regressão
# =============================================================================

ds_path <- file.path(tables_dir, "dataset_regressao_municipio.csv")
if (!file.exists(ds_path))
  stop("dataset_regressao_municipio.csv não encontrado — execute 11b primeiro.\n",
       "Esperado em: ", ds_path)

ds <- readr::read_csv(ds_path, show_col_types = FALSE) |>
  mutate(cod_mun = as.double(cod_mun))

cat(sprintf("dataset_regressao_municipio.csv: %d municípios × %d variáveis\n",
            nrow(ds), ncol(ds)))

# =============================================================================
# 4) Extrair variáveis e calcular derivadas
# =============================================================================

# Ranks calculados na amostra completa (maior valor = rank 1)
n_total <- nrow(ds)
ranks_ds <- ds |>
  mutate(
    rank_g_alta       = rank(-g_alta,        ties.method = "min", na.last = "keep"),
    rank_pp_alta      = rank(-pp_alta_2010,  ties.method = "min", na.last = "keep"),
    rank_delta_pp_alta = rank(-delta_pp_alta, ties.method = "min", na.last = "keep")
  ) |>
  select(cod_mun, rank_g_alta, rank_pp_alta, rank_delta_pp_alta)

tabela_raw <- ds |>
  filter(cod_mun %in% alvo$cod_mun) |>
  mutate(
    pct_periph_ext_leap_0010 = pct_area_peripheral_0010 +
                                pct_area_extension_0010  +
                                pct_area_leapfrog_0010,
    # denominator on the mapped units (6f.2)
    dens_urbana_2010 = ifelse(
      !is.na(area_urbana_2010_m2_mapped) & area_urbana_2010_m2_mapped > 0,
      pop_urbana_2010_cg / (area_urbana_2010_m2_mapped / 1e6),
      NA_real_
    ),
    urban_footprint_2000_km2 = area_2000_m2 / 1e6
  ) |>
  select(
    cod_mun,
    topo_prop_inclinado,
    g_fora_alta,
    pct_periph_ext_leap_0010,
    pp_alta_2010,
    pop_total_2010,
    pib_pc_2010,
    dens_urbana_2010,
    urban_footprint_2000_km2,
    prop_favelas_2010,
    palma_rent,
    palma_commute,
    median_rent,
    pct_nao_constru_fora_alta_2010_q1
  ) |>
  left_join(ranks_ds, by = "cod_mun")

# =============================================================================
# 5) Montar tabela final com rótulos
# =============================================================================

tabela <- alvo |>
  select(label, cod_mun) |>
  left_join(tabela_raw, by = "cod_mun") |>
  select(-cod_mun)

names(tabela) <- c(
  "Municipality",
  "Steep terrain (%)",
  "Pop growth outside high suscept. 2010-22 (%)",
  "Periph+ext+leapfrog area share 2000-10 (%)",
  "Pop in high suscept. 2010 (%)",
  "Total pop 2010",
  "GDP per capita 2010 (R$)",
  "Urban density 2010 (hab/km2)",
  "Urban footprint 2000 (km2)",
  "Slum pop share 2010 (%)",
  "Palma ratio - rent",
  "Palma ratio - commute",
  "Median rent 2010 (R$)",
  "Safe empty land Q1 - outside high suscept. (%)",
  sprintf("Rank g_high (of %d)", n_total),
  sprintf("Rank pp_high 2010 (of %d)", n_total),
  sprintf("Rank delta_pp_high (of %d)", n_total)
)

# =============================================================================
# 6) Imprimir tabela
# =============================================================================

cat("\n", strrep("=", 70), "\n")
cat("TABELA: Municípios selecionados — variáveis estruturais\n")
cat(strrep("=", 70), "\n\n")

print(
  tabela |>
    mutate(across(where(is.numeric), \(x) round(x, 1))),
  n = nrow(tabela)
)

# =============================================================================
# 7) Salvar CSV
# =============================================================================

out_path <- file.path(tables_dir, "case_study_municipios.csv")
write.csv2(tabela, out_path, row.names = FALSE)
cat(sprintf("\n✓ Tabela salva em: %s\n", basename(out_path)))

cat("\n", strrep("=", 60), "\n")
cat("CONCLUÍDO\n")
cat(strrep("=", 60), "\n")
