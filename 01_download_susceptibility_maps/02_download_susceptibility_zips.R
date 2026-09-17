# ======================================================================
# 0) PACOTES
# ======================================================================
library(rvest)
library(httr)
library(dplyr)
library(stringr)
library(readr)
library(fs)
library(future.apply)
library(progress)
library(sf)

# ======================================================================
# 1) CONFIGURAÇÕES GERAIS
# ======================================================================
plan(multisession, workers = 2)

CSV_INPUT <- "municipios_suscetibilidade_SGB.csv"
DIR_RAW   <- "suscet_sig_processado"
DIR_GPKG  <- "GPKG"
LOG_FILE  <- "pipeline_log.txt"

dir_create(DIR_RAW)
dir_create(DIR_GPKG)
if (!file_exists(LOG_FILE)) file_create(LOG_FILE)

log_msg <- function(...) {
  linha <- paste(Sys.time(), "-", ..., collapse = " ")
  write_lines(linha, LOG_FILE, append = TRUE)
}

# função segura para deletar arquivos sem derrubar o script em caso de EBUSY
safe_delete <- function(path) {
  if (!file_exists(path)) return(TRUE)
  
  for (tent in 1:5) {
    ok <- try(fs::file_delete(path), silent = TRUE)
    if (!inherits(ok, "try-error")) {
      log_msg("ARQUIVO_DELETADO:", path)
      return(TRUE)
    }
    Sys.sleep(1)
  }
  
  log_msg("NAO_CONSEGUI_DELETAR (EBUSY?):", path)
  return(FALSE)
}

# função para higienizar nomes de diretórios/arquivos (Windows-friendly)
sanitize_name <- function(x) {
  x |>
    # remove caracteres proibidos em nomes de pastas/arquivos no Windows
    str_replace_all('[\\\\/:*?"<>|]', '') |>
    str_squish() |>
    str_replace_all('\\s+', ' ')
}

# ======================================================================
# 2) CARREGAR MUNICIPIOS
# ======================================================================
dados <- read_csv(CSV_INPUT, show_col_types = FALSE) |>
  filter(!is.na(Link), Link != "")

message("Total de municípios detectados: ", nrow(dados))

### PARA TESTAR SOMENTE ALGUNS MUNICÍPIOS:
# dados <- dados |> filter(UF == "SP", str_detect(Municipio, "Alambari"))

# ======================================================================
# 3) IDENTIFICAR ZIP SIG (todos os padrões reais)
# ======================================================================
extrair_zip_sig <- function(url_pagina) {
  
  html <- try(read_html(url_pagina), silent = TRUE)
  if (inherits(html, "try-error")) return(character(0))
  
  hrefs <- html |>
    html_elements("a") |>
    html_attr("href") |>
    na.omit()
  
  sel <- hrefs[
    str_detect(hrefs, "\\.zip$") &
      str_detect(hrefs, regex("sig", ignore_case = TRUE)) &
      !str_detect(hrefs, regex("mde|curva|base|imagem|img", ignore_case = TRUE))
  ]
  
  if (length(sel) == 0) return(character(0))
  
  ifelse(str_starts(sel, "http"), sel, paste0("https://rigeo.sgb.gov.br", sel))
}

# ======================================================================
# 4) DOWNLOAD VIA CURL + VERIFICAÇÃO DE ZIP
# ======================================================================
baixar_zip <- function(url, destino) {
  
  # Se já existe, testar se o ZIP é válido
  if (file_exists(destino)) {
    teste <- try(unzip(destino, list = TRUE), silent = TRUE)
    if (!inherits(teste, "try-error") && nrow(teste) > 0) {
      log_msg("ZIP_OK (pular download):", destino)
      return(TRUE)
    }
    log_msg("ZIP_INVALIDO (apagando):", destino)
    safe_delete(destino)
  }
  
  user_agent <- "Mozilla/5.0 (Macintosh; Intel Mac OS X) Chrome/119 Safari/537.36"
  
  cmd <- sprintf(
    'curl -L --fail --retry 5 --retry-delay 5 -A "%s" "%s" -o "%s"',
    user_agent, url, destino
  )
  
  status <- system(cmd, ignore.stdout = TRUE, ignore.stderr = TRUE)
  
  if (status != 0) {
    log_msg("ERRO_DOWNLOAD:", url)
    return(FALSE)
  }
  
  # validar ZIP baixado
  teste2 <- try(unzip(destino, list = TRUE), silent = TRUE)
  
  if (inherits(teste2, "try-error") || nrow(teste2) == 0) {
    log_msg("ZIP_CORROMPIDO (apagando):", destino)
    safe_delete(destino)
    return(FALSE)
  }
  
  log_msg("OK_DOWNLOAD:", url)
  return(TRUE)
}

# ======================================================================
# 5) EXTRAIR APENAS ARQUIVOS RELEVANTES
# ======================================================================
extrair_relevantes <- function(zipfile, destino) {
  
  lista <- try(unzip(zipfile, list = TRUE), silent = TRUE)
  
  if (inherits(lista, "try-error")) {
    log_msg("ZIP_INVALIDO_NO_UNZIP:", zipfile)
    safe_delete(zipfile)
    return(FALSE)
  }
  
  alvos <- lista$Name[
    str_detect(lista$Name, regex("inund|massa|mov|susc", ignore_case = TRUE))
  ]
  
  if (length(alvos) == 0) {
    log_msg("SEM_ARQUIVOS_RELEVANTES:", zipfile)
    safe_delete(zipfile)
    return(FALSE)
  }
  
  extr <- try(unzip(zipfile, files = alvos, exdir = destino), silent = TRUE)
  
  if (inherits(extr, "try-error")) {
    log_msg("FALHA_UNZIP:", zipfile)
    safe_delete(zipfile)
    return(FALSE)
  }
  
  safe_delete(zipfile)
  log_msg("OK_EXTRACAO:", basename(zipfile))
  TRUE
}

# ======================================================================
# 6) PROCESSAR MUNICÍPIO COMPLETO
# ======================================================================
processar_municipio <- function(i) {
  
  uf        <- dados$UF[i]
  muni_raw  <- dados$Municipio[i]         # nome original (pode ter *)
  muni_dir  <- sanitize_name(muni_raw)    # nome para pasta
  url       <- dados$Link[i]
  
  dir_uf   <- path(DIR_RAW, uf)
  dir_muni <- path(dir_uf, muni_dir)
  dir_create(dir_uf); dir_create(dir_muni)
  
  zip_url <- extrair_zip_sig(url)
  
  if (length(zip_url) == 0) {
    log_msg("SEM_SIG:", muni_raw, uf)
    return(FALSE)
  }
  
  zipfile <- path(dir_muni, basename(zip_url[1]))
  
  ok <- baixar_zip(zip_url[1], zipfile)
  if (!ok) return(FALSE)
  
  ok2 <- extrair_relevantes(zipfile, dir_muni)
  if (!ok2) return(FALSE)
  
  return(TRUE)
}

# ======================================================================
# 7) LOOP PARALELO (NÃO PARA EM ERRO)
# ======================================================================
pb <- progress_bar$new(
  format = "⏬ Processando [:bar] :current/:total (:percent) eta::eta",
  total = nrow(dados)
)

resultados <- future_lapply(seq_len(nrow(dados)), function(i) {
  r <- processar_municipio(i)
  pb$tick()
  r
})

message("✔️ DOWNLOAD + EXTRAÇÃO concluídos.")
# demorou 8 horas falhou apenas em
# ❌ 1) SEM_SIG (não existe no SGB)
# 
# Correia Pinto (SC)
# 
# Coronel Fabriciano (MG)
# 
# Curral de Dentro (MG)
# 
# Extrema (MG)
# 
# Poços de Caldas (MG)
# 
# ❌ 2) ZIP_CORROMPIDO
# 
# Corupá (SC)
# 
# Registro (SP)
# 
# ❌ 3) FALHA_UNZIP
# 
# Resende (RJ)
## pos processamento nao funcionou. outro script
# ======================================================================
# 8) PÓS-PROCESSAMENTO → GPKG (MUNICIPAL, ESTADUAL, BRASIL)
# ======================================================================
message("🔄 Convertendo para GPKG...")

# 8.1 MUNICIPAL
for (uf in unique(dados$UF)) {
  
  munis <- unique(dados$Municipio[dados$UF == uf])
  
  for (muni_raw in munis) {
    
    muni_dir <- sanitize_name(muni_raw)
    pasta    <- path(DIR_RAW, uf, muni_dir)
    if (!dir_exists(pasta)) next
    
    arquivos <- dir_ls(pasta, regexp = "\\.(shp|tif|gpkg)$")
    if (length(arquivos) == 0) next
    
    nome_muni <- str_replace_all(muni_dir, " ", "_")
    out_file  <- path(DIR_GPKG, paste0(uf, "_", nome_muni, "_suscet.gpkg"))
    
    for (a in arquivos) {
      camada <- tools::file_path_sans_ext(basename(a))
      sfobj  <- st_read(a, quiet = TRUE)
      sfobj$UF        <- uf
      sfobj$Municipio <- muni_raw      # aqui fica o nome original
      st_write(sfobj, out_file, layer = camada, delete_layer = TRUE, quiet = TRUE)
    }
  }
}

# 8.2 ESTADUAL
for (uf in unique(dados$UF)) {
  
  muni_files <- dir_ls(DIR_GPKG, regexp = paste0("^", uf, "_.*_suscet\\.gpkg$"))
  if (length(muni_files) == 0) next
  
  uf_out <- path(DIR_GPKG, paste0(uf, "_suscet.gpkg"))
  
  for (f in muni_files) {
    layers <- st_layers(f)$name
    for (l in layers) {
      obj <- st_read(f, layer = l, quiet = TRUE)
      st_write(obj, uf_out, layer = l, append = TRUE, quiet = TRUE)
    }
  }
}

# 8.3 BRASIL
brasil_out <- path(DIR_GPKG, "Brasil_Suscetibilidade.gpkg")

for (uf in unique(dados$UF)) {
  
  uf_file <- path(DIR_GPKG, paste0(uf, "_suscet.gpkg"))
  if (!file_exists(uf_file)) next
  
  layers <- st_layers(uf_file)$name
  for (l in layers) {
    obj <- st_read(uf_file, layer = l, quiet = TRUE)
    st_write(obj, brasil_out, layer = l, append = TRUE, quiet = TRUE)
  }
}

message("🎉 Conversão final concluída!")

# ======================================================================
# 9) RELATÓRIO FINAL
# ======================================================================
sucesso <- sum(unlist(resultados))
falha   <- length(resultados) - sucesso

message("=========================================")
message("RELATÓRIO FINAL")
message("Total de municípios: ", length(resultados))
message("Sucessos: ", sucesso)
message("Falhas: ", falha)
message("Falha (%) : ", round(100 * falha / length(resultados), 2), "%")
message("=========================================")

log_msg("FINAL:", sucesso, "sucesso,", falha, "falha")
