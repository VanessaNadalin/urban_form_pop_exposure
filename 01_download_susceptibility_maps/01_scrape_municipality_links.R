
# Run this script with the working directory set to the stage-01 raw-data folder (see making_suscep_national.md, "Working directory"). A machine-specific setwd() was removed here for publication.
# -------------------------------------------------------
# EXTRATOR NACIONAL DE MUNICÍPIOS DE SUSCETIBILIDADE – SGB
# -------------------------------------------------------

library(rvest)
library(stringr)
library(dplyr)
library(purrr)
library(readr)
library(tidyr)

# -------------------------------------------------------
# 1) Ler todos os arquivos .html de estados
# -------------------------------------------------------

arquivos <- list.files(pattern = "\\.html$", full.names = TRUE)

message("Encontrados ", length(arquivos), " arquivos HTML de estados.")

# Função: extrair UF a partir do nome do arquivo
extrair_uf <- function(filename) {
  nome <- tolower(basename(filename))
  nome <- str_replace(nome, "\\.html$", "")
  
  # mapa nome → UF
  mapa <- c(
    "acre"="AC", "alagoas"="AL", "amapa"="AP", "amazonas"="AM",
    "bahia"="BA", "ceara"="CE", "distrito-federal"="DF",
    "espirito-santo"="ES", "goias"="GO", "maranhao"="MA",
    "mato-grosso"="MT", "mato-grosso-do-sul"="MS",
    "minas-gerais"="MG", "para"="PA", "paraiba"="PB",
    "parana"="PR", "pernambuco"="PE", "piaui"="PI",
    "rio-de-janeiro"="RJ", "rio-grande-do-norte"="RN",
    "rio-grande-do-sul"="RS", "rondonia"="RO", "roraima"="RR",
    "santa-catarina"="SC", "sao-paulo"="SP", "sergipe"="SE",
    "tocantins"="TO"
  )
  mapa[nome]
}

# -------------------------------------------------------
# 2) Função que extrai MUNICÍPIO + LINK de cada HTML
# -------------------------------------------------------

extrair_tabela <- function(arquivo) {
  
  uf <- extrair_uf(arquivo)
  html <- read_html(arquivo, encoding = "UTF-8")
  # todas as linhas <tr> depois do cabeçalho
  linhas <- html |>
    html_elements("table tbody tr")
  
  # cada linha tem <td> com "Município" e <a href="...">
  map_dfr(linhas[-1], function(linha) {
    cols <- linha |> html_elements("td")
    
    if (length(cols) < 2) return(NULL)
    
    municipio <- cols[1] |> html_text2()
    
    link <- cols[2] |>
      html_element("a") |>
      html_attr("href")
    
    tibble(
      UF = uf,
      Municipio = municipio,
      Link = link
    )
  })
}

# -------------------------------------------------------
# 3) Extrair dados de todos os estados
# -------------------------------------------------------

dados <- map_dfr(arquivos, extrair_tabela)

message("Total de linhas extraídas: ", nrow(dados))

# -------------------------------------------------------
# 4) Ajustes finais
# -------------------------------------------------------

dados <- dados |>
  mutate(Link = if_else(
    !str_detect(Link, "^http"),
    paste0("https://rigeo.sgb.gov.br", Link),
    Link
  )) |>
  distinct() |>
  arrange(UF, Municipio)
dados_filtrados <- dados |> filter(!is.na(Link), Link != "")
# -------------------------------------------------------
# 5) Exportar CSV final
# -------------------------------------------------------

write_csv(dados_filtrados, "municipios_suscetibilidade_SGB.csv")

message("CSV salvo como municipios_suscetibilidade_SGB.csv")
