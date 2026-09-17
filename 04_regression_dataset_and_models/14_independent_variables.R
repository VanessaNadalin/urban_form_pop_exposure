# =============================================================================
# 14_independent_variables.R
# Assembles the independent variables (X) for the two regression datasets
# (municipalities and arrangements), joining the outputs of every prior
# script.
#
# Inputs (all already computed by prior scripts):
#   data/processed_data/04_regression/tables/met_municipio_com_y_BR.csv   (script 13)
#   data/processed_data/04_regression/tables/met_arranjo_com_y_BR.csv     (script 13)
#   data/processed_data/04_regression/tables/pct_nao_constru_municipio_BR.csv (script 08)
#   data/processed_data/04_regression/tables/pct_nao_constru_arranjo_BR.csv   (script 08)
#   data/processed_data/04_regression/tables/topografia_municipio_BR.csv      (script 10)
#   data/processed_data/04_regression/tables/topografia_arranjo_BR.csv        (script 10)
#   data/processed_data/04_regression/tables/dist_sede_municipio_BR.csv       (script 09)
#   data/processed_data/04_regression/tables/dist_sede_arranjo_BR.csv         (script 09)
#   data/processed_data/04_regression/tables/slums_municipio_BR.csv           (script 12)
#   data/processed_data/04_regression/tables/slums_arranjo_BR.csv             (script 12)
#   data/processed_data/04_regression/tables/housing_mobility_inequality_municipio.csv (script 11)
#   data/processed_data/04_regression/tables/housing_mobility_inequality_arranjo.csv   (script 11)
#   data/processed_data/04_regression/pib_municipios_2010.csv               (script 05)
#   data/processed_data/04_regression/pop_total_2000.csv                    (script 05)
#   data/processed_data/03_urban_footprint/metricas/metricas_crescimento_2000_2010.csv
#   data/processed_data/03_urban_footprint/metricas/metricas_crescimento_2000_2010_arranjo.csv
#   data/raw_data/04_regression/tabela3381.xlsx     (IBGE 2010 Census -- slums, AGSN)
#   data/raw_data/04_regression/regic_2018_hierarquia.csv               (REGIC 2018, auto-download)
#   data/processed_data/04_regression/amostra_universo.csv  (script 01)
#
# Outputs (data/processed_data/04_regression/tables/):
#   dataset_completo_municipio.csv
#   dataset_completo_arranjo.csv
# =============================================================================

source("04_regression_dataset_and_models/00_setup.R")
library(httr)

cat("\n", strrep("=", 60), "\n")
cat("14_INDEPENDENT_VARIABLES.R\n")
cat(strrep("=", 60), "\n")

# =============================================================================
# 0) SAMPLE
# =============================================================================

cat("\n0) Loading sample...\n")

amostra <- read_csv(file.path(data_dir, "amostra_universo.csv"),
                    show_col_types = FALSE) %>%
  mutate(cod_mun   = as.double(cod_mun),
         CD_CIDADE = as.double(CD_CIDADE))

pop_col_candidates <- c("pop_2022", "pop_22", "pop_filtro", "pop_total", "pop", "populacao")
col_pop_arr <- intersect(pop_col_candidates, names(amostra))[1]
if (is.na(col_pop_arr))
  stop("Population column not found in amostra.")

for (f in c("amostra_mun.csv", "amostra_arr.csv", "mun_isol.csv")) {
  if (!file.exists(file.path(data_dir, f)))
    stop("Run 01_compose_sample.R first to generate: ", f)
}
cod_mun_mun   <- as.double(read_csv(file.path(data_dir, "amostra_mun.csv"),
                                    show_col_types = FALSE)$cod_mun)
cd_cidade_arr <- read_csv(file.path(data_dir, "amostra_arr.csv"),
                          show_col_types = FALSE) %>%
  pull(CD_CIDADE) %>% as.double() %>% unique()
mun_isol_df   <- read_csv(file.path(data_dir, "mun_isol.csv"),
                          show_col_types = FALSE) %>%
  mutate(cod_mun = as.double(cod_mun))

cat(sprintf("  Municipal sample      : %d municipalities\n", length(cod_mun_mun)))
cat(sprintf("  Qualified arrangements: %d CD_CIDADEs\n", length(cd_cidade_arr)))
cat(sprintf("  Isolated municipalities: %d\n", nrow(mun_isol_df)))

# =============================================================================
# 1) LOAD Y AND URBAN FORM (script 13)
# =============================================================================

cat("\n1) Loading Y and urban form (script 13)...\n")

met_mun_path <- file.path(tables_dir, "met_municipio_com_y_BR.csv")
met_arr_path <- file.path(tables_dir, "met_arranjo_com_y_BR.csv")

if (!file.exists(met_mun_path) || !file.exists(met_arr_path))
  stop("Run 13_dependent_variables.R first.")

met_mun <- read_csv(met_mun_path, show_col_types = FALSE) %>%
  mutate(cod_mun = as.double(cod_mun))
met_arr <- read_csv(met_arr_path, show_col_types = FALSE) %>%
  mutate(CD_CIDADE = as.double(CD_CIDADE))

cat(sprintf("  Municipalities: %d  |  Arrangements: %d\n", nrow(met_mun), nrow(met_arr)))

# =============================================================================
# 2) SAFE AVAILABLE LAND (script 08)
# =============================================================================

cat("\n2) Loading safe available land (script 08)...\n")

terra_mun_path <- file.path(tables_dir, "pct_nao_constru_municipio_BR.csv")
terra_arr_path <- file.path(tables_dir, "pct_nao_constru_arranjo_BR.csv")

if (file.exists(terra_mun_path)) {
  terra_mun <- read_csv(terra_mun_path, show_col_types = FALSE)
  met_mun   <- left_join(met_mun, terra_mun, by = "cod_mun")
  cat(sprintf("  Municipalities with available land: %d\n",
              sum(!is.na(met_mun$pct_nao_constru_fora_alta_2010))))
} else {
  cat("  Warning: pct_nao_constru_municipio_BR.csv not found -- run script 08\n")
}

if (file.exists(terra_arr_path)) {
  terra_arr <- read_csv(terra_arr_path, show_col_types = FALSE)
  met_arr   <- left_join(met_arr, terra_arr, by = "CD_CIDADE")
  cat(sprintf("  Arrangements with available land: %d\n",
              sum(!is.na(met_arr$pct_nao_constru_fora_alta_2010))))
} else {
  cat("  Warning: pct_nao_constru_arranjo_BR.csv not found -- run script 08\n")
}

# =============================================================================
# 3) TOPOGRAPHY (script 10)
# =============================================================================

cat("\n3) Loading topography (script 10)...\n")

topo_mun_path <- file.path(tables_dir, "topografia_municipio_BR.csv")
topo_arr_path <- file.path(tables_dir, "topografia_arranjo_BR.csv")

# High susceptibility only (rule 9): script 10 no longer computes a medium
# branch, so topo_prop_inclinado_em_alta_medio is not read here.
if (file.exists(topo_mun_path)) {
  topo_mun <- read_csv(topo_mun_path, show_col_types = FALSE) %>%
    select(cod_mun,
           topo_prop_inclinado         = prop_inclinado,
           topo_prop_agua              = prop_agua,
           topo_prop_sem_dado          = prop_sem_dado,
           topo_prop_restrita          = prop_restrita,
           topo_prop_inclinado_em_alta = prop_inclinado_em_alta)
  met_mun <- left_join(met_mun, topo_mun, by = "cod_mun")
  cat(sprintf("  Municipalities with topography: %d\n", sum(!is.na(met_mun$topo_prop_restrita))))
} else {
  cat("  Warning: topografia_municipio_BR.csv not found -- run script 10\n")
}

if (file.exists(topo_arr_path)) {
  topo_arr <- read_csv(topo_arr_path, show_col_types = FALSE) %>%
    select(CD_CIDADE,
           topo_prop_inclinado         = prop_inclinado,
           topo_prop_agua              = prop_agua,
           topo_prop_sem_dado          = prop_sem_dado,
           topo_prop_restrita          = prop_restrita,
           topo_prop_inclinado_em_alta = prop_inclinado_em_alta)
  met_arr <- left_join(met_arr, topo_arr, by = "CD_CIDADE")
  cat(sprintf("  Arrangements with topography: %d\n", sum(!is.na(met_arr$topo_prop_restrita))))
} else {
  cat("  Warning: topografia_arranjo_BR.csv not found -- run script 10\n")
}

# =============================================================================
# 4) DISTANCE TO MUNICIPAL SEAT (script 09)
# =============================================================================

cat("\n4) Loading distances (script 09)...\n")

dist_mun_path <- file.path(tables_dir, "dist_sede_municipio_BR.csv")
dist_arr_path <- file.path(tables_dir, "dist_sede_arranjo_BR.csv")

if (file.exists(dist_mun_path)) {
  dist_mun <- read_csv(dist_mun_path, show_col_types = FALSE) %>%
    select(cod_mun,
           dist_sede_m       = dist_media_m,
           dist_sede_q1_m    = dist_media_m_q1,
           dif_dist_q1_total,
           any_of(c(dist_densif_m                  = "dist_media_m_densification",
                    dist_media_m_densif_0010        = "dist_media_m_densif_0010",
                    dist_media_m_densif_infill_0010 = "dist_media_m_densif_infill_0010")))
  met_mun <- left_join(met_mun, dist_mun, by = "cod_mun")
  cat(sprintf("  Municipalities with distance: %d\n", sum(!is.na(met_mun$dist_sede_m))))
  cat(sprintf("  Municipalities with dist_densif_m: %d\n", sum(!is.na(met_mun$dist_densif_m))))
} else {
  cat("  Warning: dist_sede_municipio_BR.csv not found -- run script 09\n")
}

if (file.exists(dist_arr_path)) {
  dist_arr <- read_csv(dist_arr_path, show_col_types = FALSE) %>%
    select(CD_CIDADE,
           dist_sede_m       = dist_media_m,
           dist_sede_q1_m    = dist_media_m_q1,
           dif_dist_q1_total,
           any_of(c(dist_densif_m                  = "dist_media_m_densification",
                    dist_media_m_densif_0010        = "dist_media_m_densif_0010",
                    dist_media_m_densif_infill_0010 = "dist_media_m_densif_infill_0010")))
  met_arr <- left_join(met_arr, dist_arr, by = "CD_CIDADE")
  cat(sprintf("  Arrangements with distance: %d\n", sum(!is.na(met_arr$dist_sede_m))))
  cat(sprintf("  Arrangements with dist_densif_m: %d\n", sum(!is.na(met_arr$dist_densif_m))))
} else {
  cat("  Warning: dist_sede_arranjo_BR.csv not found -- run script 09\n")
}

# =============================================================================
# 5) REGION
# =============================================================================

cat("\n5) Computing region...\n")

uf_regiao <- tibble(
  uf_cod = c("11","12","13","14","15","16","17",
             "21","22","23","24","25","26","27","28","29",
             "31","32","33","35",
             "41","42","43",
             "50","51","52","53"),
  regiao = c(rep("Norte", 7), rep("Nordeste", 9),
             rep("Sudeste", 4), rep("Sul", 3), rep("Centro-Oeste", 4))
)

met_mun <- met_mun %>%
  mutate(uf_cod = substr(as.character(cod_mun), 1, 2)) %>%
  left_join(uf_regiao, by = "uf_cod") %>%
  select(-uf_cod)

if ("cod_mun" %in% names(met_arr)) {
  met_arr <- met_arr %>%
    mutate(uf_cod = substr(as.character(cod_mun), 1, 2)) %>%
    left_join(uf_regiao, by = "uf_cod") %>%
    select(-uf_cod)
} else {
  met_arr <- met_arr %>%
    mutate(uf_cod = substr(as.character(CD_CIDADE), 1, 2)) %>%
    left_join(uf_regiao, by = "uf_cod") %>%
    select(-uf_cod)
}

cat(sprintf("  Distribution by region (municipalities):\n"))
print(table(met_mun$regiao, useNA = "ifany"))

# =============================================================================
# 6) GDP PER CAPITA 2010 (script 05)
# =============================================================================

cat("\n6) GDP per capita 2010 (script 05)...\n")

pib_path <- file.path(data_dir, "pib_municipios_2010.csv")

if (!file.exists(pib_path))
  stop("pib_municipios_2010.csv not found -- run 05_prepare_gdp.R first.")

pib <- read_csv(pib_path, show_col_types = FALSE)

met_mun <- met_mun %>%
  left_join(pib %>% select(cod_mun, pop_total_2010, pib_total_2010, pib_pc_2010),
            by = "cod_mun")

# Arrangement: sum GDP and pop across member municipalities, recompute per capita
if (all(c("cod_mun", "CD_CIDADE") %in% names(met_mun))) {
  pib_arr <- met_mun %>%
    select(cod_mun, CD_CIDADE) %>%
    distinct() %>%
    left_join(pib %>% select(cod_mun, pib_total_2010, pop_total_2010), by = "cod_mun") %>%
    group_by(CD_CIDADE) %>%
    summarise(pib_total_2010 = sum(pib_total_2010, na.rm = TRUE),
              pop_total_2010 = sum(pop_total_2010, na.rm = TRUE),
              .groups = "drop") %>%
    mutate(pib_pc_2010 = ifelse(pop_total_2010 > 0,
                                pib_total_2010 / pop_total_2010, NA_real_))
  met_arr <- left_join(met_arr, pib_arr, by = "CD_CIDADE")
}

cat(sprintf("  Municipalities with GDP per capita: %d\n", sum(!is.na(met_mun$pib_pc_2010))))
cat(sprintf("  Arrangements with GDP per capita: %d\n", sum(!is.na(met_arr$pib_pc_2010))))

# Health facilities (2015 disaster-exposure table) were dropped from this
# script: n_estab_saude was never read by 16_estimate_models.R or any
# 05_exhibits/robustness/*.R script -- confirmed dead (MIGRATION_PLAN.md
# 6c0). The raw CSV no longer needs to be placed under
# data/raw_data/04_regression/.

# =============================================================================
# 7) URBAN HIERARCHY -- REGIC 2018 (IBGE)
# =============================================================================

cat("\n7) Loading REGIC 2018 urban hierarchy...\n")

REGIC_URL  <- paste0(
  "https://geoftp.ibge.gov.br/organizacao_do_territorio/divisao_regional/",
  "regioes_de_influencia_das_cidades/",
  "Regioes_de_influencia_das_cidades_2018_Resultados_definitivos/",
  "base_tabular/REGIC2018_Municipios_Hierarquia_e_regiao.xlsx"
)
regic_xl_path  <- file.path(raw_data_dir, "REGIC2018_Municipios_Hierarquia_e_regiao.xlsx")
regic_csv_path <- file.path(data_dir, "regic_2018_hierarquia.csv")

if (!file.exists(regic_xl_path)) {
  cat("  Downloading REGIC 2018 from the IBGE FTP...\n")
  tryCatch(
    download.file(REGIC_URL, regic_xl_path, mode = "wb", quiet = FALSE),
    error = function(e) {
      message("  Warning: download failed -- ", e$message)
      message("  -> Download manually: ", REGIC_URL)
      message("  -> Save to: ", regic_xl_path)
    }
  )
}

if (file.exists(regic_xl_path) && !file.exists(regic_csv_path)) {
  regic_raw  <- readxl::read_excel(regic_xl_path)
  cat(sprintf("  Columns: %s\n", paste(names(regic_raw), collapse = " | ")))

  regic_raw2 <- regic_raw
  names(regic_raw2)[names(regic_raw2) == "Hierarquia - grupo"] <- "hierarquia_grupo"

  regic_csv <- regic_raw2 %>%
    transmute(
      cod_mun          = as.double(codmun),
      hierarquia_grupo = trimws(as.character(hierarquia_grupo)),
      urban_class      = dplyr::case_when(
        stringr::str_detect(hierarquia_grupo, "^[12] -") &
          !stringr::str_detect(hierarquia_grupo, "Integrante") ~ "Metropolises",
        stringr::str_detect(hierarquia_grupo, "^[12] -") &
          stringr::str_detect(hierarquia_grupo, "Integrante")  ~ "Metropolis Suburbs",
        stringr::str_detect(hierarquia_grupo, "^3 -") &
          !stringr::str_detect(hierarquia_grupo, "Integrante") ~ "Regional Centers",
        stringr::str_detect(hierarquia_grupo, "^3 -") &
          stringr::str_detect(hierarquia_grupo, "Integrante")  ~ "Regional Centers Suburbs",
        stringr::str_detect(hierarquia_grupo, "^[45] -")       ~ "Urban Centers",
        TRUE ~ NA_character_
      )
    ) %>%
    filter(!is.na(cod_mun), cod_mun >= 1000000, !is.na(hierarquia_grupo))

  write_csv(regic_csv, regic_csv_path)
  cat(sprintf("  %d REGIC municipalities saved to %s\n",
              nrow(regic_csv), basename(regic_csv_path)))
}

if (file.exists(regic_csv_path)) {
  regic <- read_csv(regic_csv_path, show_col_types = FALSE) %>%
    mutate(cod_mun = as.double(cod_mun)) %>%
    filter(!is.na(cod_mun), cod_mun >= 1000000)

  cat(sprintf("  %d municipalities with REGIC\n", nrow(regic)))
  cat("  Distribution (urban_class):\n")
  print(sort(table(regic$urban_class), decreasing = TRUE))

  met_mun <- left_join(met_mun,
                       regic %>% select(cod_mun, hierarquia_grupo, urban_class),
                       by = "cod_mun")

  if (all(c("cod_mun", "CD_CIDADE") %in% names(met_mun))) {
    sede_regic <- amostra %>%
      filter(!is.na(CD_CIDADE)) %>%
      group_by(CD_CIDADE) %>%
      slice_max(order_by = .data[[col_pop_arr]], n = 1, with_ties = FALSE) %>%
      ungroup() %>%
      select(CD_CIDADE, cod_mun_sede = cod_mun) %>%
      mutate(cod_mun_sede = as.double(cod_mun_sede)) %>%
      left_join(regic %>% select(cod_mun, hierarquia_grupo, urban_class) %>%
                  rename(cod_mun_sede = cod_mun),
                by = "cod_mun_sede") %>%
      select(CD_CIDADE, hierarquia_grupo, urban_class)
    met_arr <- left_join(met_arr, sede_regic, by = "CD_CIDADE")
  }

  cat(sprintf("  Municipalities with urban_class: %d\n", sum(!is.na(met_mun$urban_class))))
  cat(sprintf("  Arrangements with urban_class: %d\n",  sum(!is.na(met_arr$urban_class))))
} else {
  cat("  Warning: REGIC not available\n")
}

# =============================================================================
# 8) POPULATION IN SLUMS 2010 -- IBGE 2010 Census, table 3381
# =============================================================================

cat("\n8) Loading 2010 population in slums (table 3381)...\n")

fav_path <- file.path(raw_data_dir, "tabela3381.xlsx")

# Ensure pop_total_2010 exists in met_mun (may not have been joined if GDP was missing)
if (!"pop_total_2010" %in% names(met_mun) && exists("pib")) {
  pop2010_fill <- pib %>% select(cod_mun, pop_total_2010)
  met_mun <- left_join(met_mun, pop2010_fill, by = "cod_mun")
}

if (file.exists(fav_path)) {
  favelas <- readxl::read_excel(fav_path, skip = 5, col_names = FALSE) %>%
    transmute(
      cod_mun          = as.double(trimws(as.character(...1))),
      pop_favelas_2010 = as.numeric(trimws(as.character(...3)))
    ) %>%
    filter(!is.na(cod_mun), cod_mun >= 1000000, !is.na(pop_favelas_2010))

  cat(sprintf("  %d municipalities with slum data\n", nrow(favelas)))

  met_mun <- left_join(met_mun, favelas, by = "cod_mun") %>%
    mutate(
      pop_favelas_2010  = coalesce(pop_favelas_2010, 0),
      prop_favelas_2010 = ifelse(
        !is.na(pop_total_2010) & pop_total_2010 > 0,
        pop_favelas_2010 / pop_total_2010,
        NA_real_
      )
    )

  if (all(c("cod_mun", "CD_CIDADE") %in% names(met_mun))) {
    fav_arr <- met_mun %>%
      select(cod_mun, CD_CIDADE, pop_favelas_2010, pop_total_2010) %>%
      distinct() %>%
      group_by(CD_CIDADE) %>%
      summarise(
        pop_favelas_2010 = sum(pop_favelas_2010, na.rm = TRUE),
        pop_total_arr    = sum(pop_total_2010,   na.rm = TRUE),
        .groups = "drop"
      ) %>%
      mutate(prop_favelas_2010 = ifelse(
        pop_total_arr > 0, pop_favelas_2010 / pop_total_arr, NA_real_
      )) %>%
      rename(pop_total_2010 = pop_total_arr) %>%
      select(CD_CIDADE, pop_favelas_2010, prop_favelas_2010, pop_total_2010)
    met_arr <- left_join(met_arr, fav_arr, by = "CD_CIDADE")
  }

  # Fill pop_total_2010 for arrangements not covered by the slum data block
  if (exists("pib") && "CD_CIDADE" %in% names(amostra)) {
    pop_arr_fill <- amostra %>%
      select(cod_mun, CD_CIDADE) %>%
      left_join(pib %>% select(cod_mun, pop_total_2010), by = "cod_mun") %>%
      group_by(CD_CIDADE) %>%
      summarise(pop_total_2010_fill = sum(pop_total_2010, na.rm = TRUE), .groups = "drop") %>%
      mutate(pop_total_2010_fill = na_if(pop_total_2010_fill, 0))

    if (!"pop_total_2010" %in% names(met_arr)) {
      met_arr <- left_join(met_arr,
                           pop_arr_fill %>% rename(pop_total_2010 = pop_total_2010_fill),
                           by = "CD_CIDADE")
    } else {
      met_arr <- met_arr %>%
        left_join(pop_arr_fill, by = "CD_CIDADE") %>%
        mutate(pop_total_2010 = coalesce(pop_total_2010, pop_total_2010_fill)) %>%
        select(-pop_total_2010_fill)
    }
  }

  cat(sprintf("  Municipalities with prop_favelas_2010: %d\n",
              sum(!is.na(met_mun$prop_favelas_2010))))
  cat(sprintf("  Arrangements with prop_favelas_2010: %d\n",
              sum(!is.na(met_arr$prop_favelas_2010))))
} else {
  cat("  Warning: tabela3381.xlsx not found at: ", fav_path, "\n")
}

# =============================================================================
# 9) SLUM GROWTH 2010-2022 (script 12)
# =============================================================================

cat("\n9) Loading slum growth (script 12)...\n")

slums_mun_path <- file.path(tables_dir, "slums_municipio_BR.csv")
slums_arr_path <- file.path(tables_dir, "slums_arranjo_BR.csv")

# High susceptibility only (rule 9): script 12 no longer computes a medium
# branch or the unused g_fora_alta_slums_1022/pop_fora_alta_slums_* columns
# (16_estimate_models.R derives the equivalent g_fora_suscept_slums itself),
# so only the pop_alta_slums_*/pop_total_slums_* level columns are coalesced
# here.
if (file.exists(slums_mun_path)) {
  slums_mun <- read_csv(slums_mun_path, show_col_types = FALSE)
  met_mun   <- left_join(met_mun, slums_mun, by = "cod_mun") %>%
    mutate(
      pop_alta_slums_2010      = coalesce(pop_alta_slums_2010,      0),
      pop_total_slums_2010     = coalesce(pop_total_slums_2010,     0),
      pop_alta_slums_2022      = coalesce(pop_alta_slums_2022,      0),
      pop_total_slums_2022     = coalesce(pop_total_slums_2022,     0)
    )
  cat(sprintf("  Municipalities with g_slums_1022: %d\n", sum(!is.na(met_mun$g_slums_1022))))
} else {
  cat("  Warning: slums_municipio_BR.csv not found -- run script 12\n")
}

if (file.exists(slums_arr_path)) {
  slums_arr <- read_csv(slums_arr_path, show_col_types = FALSE)
  met_arr   <- left_join(met_arr, slums_arr, by = "CD_CIDADE") %>%
    mutate(
      pop_alta_slums_2010      = coalesce(pop_alta_slums_2010,      0),
      pop_total_slums_2010     = coalesce(pop_total_slums_2010,     0),
      pop_alta_slums_2022      = coalesce(pop_alta_slums_2022,      0),
      pop_total_slums_2022     = coalesce(pop_total_slums_2022,     0)
    )
  cat(sprintf("  Arrangements with g_slums_1022: %d\n", sum(!is.na(met_arr$g_slums_1022))))
} else {
  cat("  Warning: slums_arranjo_BR.csv not found -- run script 12\n")
}

# =============================================================================
# 10) URBAN GROWTH 2000-2010 (stage 03 script 06)
# =============================================================================

cat("\n10) Loading urban growth 2000-2010...\n")

cresc_mun_path <- file.path(metricas_dir, "metricas_crescimento_2000_2010.csv")
cresc_arr_path <- file.path(metricas_dir, "metricas_crescimento_2000_2010_arranjo.csv")

cresc_cols_mun <- c("pct_urban_growth_0010",
                    "pct_area_densif_0010", "pct_area_consolidated_0010",
                    "pct_area_peripheral_0010", "pct_area_infill_0010",
                    "pct_area_extension_0010", "pct_area_leapfrog_0010",
                    "pct_area_densif_infill_0010", "pct_area_periph_ext_leap_0010")

if (file.exists(cresc_mun_path)) {
  cresc_mun <- read_csv(cresc_mun_path, show_col_types = FALSE) %>%
    mutate(cod_mun = as.double(cod_mun)) %>%
    select(cod_mun,
           any_of(cresc_cols_mun),
           area_m2_consolidated_0010 = any_of("area_m2_consolidated"),
           area_m2_densification_0010 = any_of("area_m2_densification"))
  met_mun <- left_join(met_mun, cresc_mun, by = "cod_mun")
  cat(sprintf("  Municipalities with growth 2000-2010: %d\n",
              sum(!is.na(met_mun$pct_urban_growth_0010))))
} else {
  cat("  Warning: metricas_crescimento_2000_2010.csv not found -- run stage 03 script 06\n")
}

if (file.exists(cresc_arr_path)) {
  cresc_arr <- read_csv(cresc_arr_path, show_col_types = FALSE) %>%
    mutate(CD_CIDADE = as.double(CD_CIDADE)) %>%
    select(CD_CIDADE,
           any_of(cresc_cols_mun),
           area_m2_consolidated_0010 = any_of("area_m2_consolidated"),
           area_m2_densification_0010 = any_of("area_m2_densification"))
  met_arr <- left_join(met_arr, cresc_arr, by = "CD_CIDADE")
  cat(sprintf("  Arrangements with growth 2000-2010: %d\n",
              sum(!is.na(met_arr$pct_urban_growth_0010))))
} else {
  cat("  Warning: metricas_crescimento_2000_2010_arranjo.csv not found -- run stage 03 script 06\n")
}

# =============================================================================
# 11) URBAN DENSITY 2000
#
# area_2000_m2       = area_m2_consolidated_0010 + area_m2_densification_0010
# urban_density_2000 = pop_2000 / (area_2000_m2 / 1e6)  [inhab/km2]
# =============================================================================

cat("\n11) Computing urban_density_2000...\n")

pop2000_path <- file.path(data_dir, "pop_total_2000.csv")
if (!file.exists(pop2000_path))
  stop("pop_total_2000.csv not found -- run 05_prepare_gdp.R first.")

pop2000 <- read_csv(pop2000_path, show_col_types = FALSE)
cat(sprintf("  pop2000: %d municipalities loaded\n", nrow(pop2000)))

met_mun <- met_mun %>%
  left_join(pop2000, by = "cod_mun") %>%
  mutate(
    area_2000_m2       = area_m2_consolidated_0010 + area_m2_densification_0010,
    zero_area_2000     = as.integer(area_2000_m2 == 0 | is.na(area_2000_m2)),
    urban_density_2000 = ifelse(
      !is.na(area_2000_m2) & area_2000_m2 > 0,
      pop_2000 / (area_2000_m2 / 1e6),
      NA_real_)
  )
cat(sprintf("  Municipalities with urban_density_2000: %d\n",
            sum(!is.na(met_mun$urban_density_2000))))

if ("CD_CIDADE" %in% names(amostra)) {
  pop2000_arr <- amostra %>%
    select(cod_mun, CD_CIDADE) %>%
    left_join(pop2000, by = "cod_mun") %>%
    group_by(CD_CIDADE) %>%
    summarise(pop_2000 = sum(pop_2000, na.rm = TRUE), .groups = "drop") %>%
    mutate(pop_2000 = na_if(pop_2000, 0))
  met_arr <- met_arr %>%
    left_join(pop2000_arr, by = "CD_CIDADE") %>%
    mutate(
      area_2000_m2       = area_m2_consolidated_0010 + area_m2_densification_0010,
      zero_area_2000     = as.integer(area_2000_m2 == 0 | is.na(area_2000_m2)),
      urban_density_2000 = ifelse(
        !is.na(area_2000_m2) & area_2000_m2 > 0,
        pop_2000 / (area_2000_m2 / 1e6),
        NA_real_)
    )
  cat(sprintf("  Arrangements with urban_density_2000: %d\n",
              sum(!is.na(met_arr$urban_density_2000))))
}

# =============================================================================
# 12) HOUSING AND MOBILITY INEQUALITY (script 11)
# =============================================================================

cat("\n12) Loading housing and mobility inequality (script 11)...\n")

hm_mun_path <- file.path(tables_dir, "housing_mobility_inequality_municipio.csv")
hm_arr_path <- file.path(tables_dir, "housing_mobility_inequality_arranjo.csv")

vars_hm <- c("median_rent", "iqr_rent", "palma_rent",
             "mean_commute_min", "iqr_commute_min",
             "pct_long_commute", "pct_long_commute_low_inc", "palma_commute")

if (file.exists(hm_mun_path)) {
  hm_mun  <- read_csv(hm_mun_path, show_col_types = FALSE) %>%
    mutate(cod_mun = as.double(cod_mun))
  met_mun <- left_join(met_mun, hm_mun, by = "cod_mun")
  for (v in vars_hm)
    cat(sprintf("  Municipalities %-30s: %d\n", v, sum(!is.na(met_mun[[v]]))))
} else {
  cat("  Warning: housing_mobility_inequality_municipio.csv not found -- run script 11\n")
}

if (file.exists(hm_arr_path)) {
  hm_arr  <- read_csv(hm_arr_path, show_col_types = FALSE) %>%
    mutate(CD_CIDADE = as.double(CD_CIDADE))
  met_arr <- left_join(met_arr, hm_arr, by = "CD_CIDADE")
  for (v in vars_hm)
    cat(sprintf("  Arrangements %-30s: %d\n", v, sum(!is.na(met_arr[[v]]))))
} else {
  cat("  Warning: housing_mobility_inequality_arranjo.csv not found -- run script 11\n")
}

# =============================================================================
# 13) SAVE FULL DATASET
# =============================================================================

cat("\n13) Saving...\n")

path_mun <- file.path(tables_dir, "dataset_completo_municipio.csv")
path_arr <- file.path(tables_dir, "dataset_completo_arranjo.csv")

write_csv(met_mun, path_mun)
cat(sprintf("  OK %s  (%d rows x %d columns)\n", basename(path_mun), nrow(met_mun), ncol(met_mun)))

write_csv(met_arr, path_arr)
cat(sprintf("  OK %s  (%d rows x %d columns)\n", basename(path_arr), nrow(met_arr), ncol(met_arr)))

# Diagnostics: variables with incomplete coverage
cat("\n  Coverage of key variables (% non-NA) -- municipalities:\n")
vars_diagnostico <- c("g_alta", "delta_pp_alta",
                      "pct_area_densif_0010", "pct_area_periph_ext_leap_0010",
                      "pct_nao_constru_fora_alta_2010", "topo_prop_restrita",
                      "dist_sede_m", "pib_pc_2010", "urban_density_2000",
                      "prop_favelas_2010", "g_slums_1022", "median_rent", "palma_commute")
for (v in intersect(vars_diagnostico, names(met_mun)))
  cat(sprintf("    %-45s: %.1f%%\n", v, 100 * mean(!is.na(met_mun[[v]]))))

cat("\n  Next step: run 15_final_dataset.R to select columns and filter.\n")

cat("\n", strrep("=", 60), "\n")
cat("DONE\n")
cat(strrep("=", 60), "\n")
