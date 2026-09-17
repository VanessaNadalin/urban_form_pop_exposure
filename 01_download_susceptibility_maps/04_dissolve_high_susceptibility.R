# Run this script with the working directory set to the stage-01 raw-data folder (see making_suscep_national.md, "Working directory"). A machine-specific setwd() was removed here for publication.

# ============================================================
# POS-PROCESSAMENTO FINAL — versão 11
# ============================================================

library(sf)
library(dplyr)
library(stringr)
library(readxl)
library(data.table)
library(lwgeom)

sf_use_s2(FALSE)

cat("\nIniciando pós-processamento v11...\n")

# ------------------------------------------------------------
# 1) Carregar objetos do Script 1 (INUND + MASSA)
# ------------------------------------------------------------

load("saida/script1_objetos_sf.RData")

# Correto: manter listas corretas
lista_inund <- lista_inundacao
lista_massa <- lista_massa

# Remover apenas a original, sem apagar cópias
rm(lista_inundacao)
gc()

# ------------------------------------------------------------
# 2) Função normalizadora de textos
# ------------------------------------------------------------

normalizar_nome <- function(x){
  x |>
    tolower() |>
    stringi::stri_trans_general("Latin-ASCII") |>
    str_replace_all("[^a-z0-9 ]", "") |>
    str_squish()
}

# ------------------------------------------------------------
# 3) Tabela de códigos IBGE
# ------------------------------------------------------------

tab <- as.data.table(read_excel("suc_codemun.xlsx"))
tab[, Municipio_norm := normalizar_nome(Municipio)]

codigo_por_nome <- tab$COD_MUNICIPIO
names(codigo_por_nome) <- tab$Municipio_norm

# ------------------------------------------------------------
# 4) LOG de falhas
# ------------------------------------------------------------

log_falhas <- data.table(
  tipo    = character(),
  chave   = character(),
  motivo  = character(),
  detalhe = character()
)

adicionar_log <- function(tipo, chave, motivo, detalhe = ""){
  log_falhas <<- rbind(
    log_falhas,
    data.table(tipo = tipo, chave = chave,
               motivo = motivo, detalhe = detalhe),
    use.names = TRUE
  )
}

# ------------------------------------------------------------
# 5) Função de processamento municipal
# ------------------------------------------------------------

processar_um_municipio <- function(nome_chave, sfobj, tipo){
  
  # 1 — pular NULL
  if (is.null(sfobj)) {
    adicionar_log(tipo, nome_chave, "objeto_null")
    return(NULL)
  }
  
  # 2 — garantir sf
  if (!inherits(sfobj, "sf")) {
    adicionar_log(tipo, nome_chave, "nao_e_sf")
    return(NULL)
  }
  
  # 3 — padronizar geom → geometry
  geom_col <- attr(sfobj, "sf_column")
  
  if (geom_col == "geom") {
    names(sfobj)[names(sfobj) == "geom"] <- "geometry"
    attr(sfobj, "sf_column") <- "geometry"
  }
  
  if (!"geometry" %in% names(sfobj)) {
    adicionar_log(tipo, nome_chave, "sem_geometry")
    return(NULL)
  }
  
  if (nrow(sfobj) == 0) {
    adicionar_log(tipo, nome_chave, "sem_linhas")
    return(NULL)
  }
  
  # 4 — validar geometria ANTES de qualquer outra operação
  teste_valid <- try(st_is_valid(sfobj), silent = TRUE)
  
  if (inherits(teste_valid, "try-error")) {
    adicionar_log(tipo, nome_chave, "geometria_irrecuperavel")
    return(NULL)
  }
  
  if (any(!teste_valid)) {
    sfobj <- suppressWarnings(st_make_valid(sfobj))
    teste2 <- try(st_is_valid(sfobj), silent = TRUE)
    
    if (inherits(teste2, "try-error") || any(!teste2)) {
      adicionar_log(tipo, nome_chave, "geometria_invalida_pos_makevalid")
      return(NULL)
    }
  }
  
  # 5 — obter COD IBGE
  partes <- str_split(nome_chave, "_", n = 2, simplify = TRUE)
  muni_norm <- normalizar_nome(partes[,2])
  
  cod <- codigo_por_nome[[muni_norm]]
  
  if (is.na(cod)) {
    adicionar_log(tipo, nome_chave, "sem_codigo_ibge", muni_norm)
    return(NULL)
  }
  
  # 6 — transformar CRS
  if (is.na(st_crs(sfobj))) {
    adicionar_log(tipo, nome_chave, "sem_CRS")
    return(NULL)
  }
  
  sfobj <- try(suppressWarnings(st_transform(sfobj, 4674)), silent = TRUE)
  
  if (inherits(sfobj, "try-error")) {
    adicionar_log(tipo, nome_chave, "erro_transformacao_crs")
    return(NULL)
  }
  
  # 7 — filtrar CLASSE alta
  col_classe <- names(sfobj)[grepl("classe|nivel|grau|risco", names(sfobj), ignore.case = TRUE)][1]
  
  if (!is.na(col_classe)) {
    valores <- tolower(stringi::stri_trans_general(sfobj[[col_classe]], "Latin-ASCII"))
    
    # padronizar expressões
    valores <- str_replace_all(valores, "[^a-z ]", " ")
    valores <- str_squish(valores)
    
    # Filtragem de ALTA
    idx_alta <-
      valores %in% c("alta", "alto", "risco alto") |
      grepl("\\balta\\b", valores) |
      grepl("\\balto\\b", valores) |
      grepl("nivel 3|grau 3|high|3$", valores)
    
    # Filtrando apenas os dados "alta"
    sfobj <- sfobj[idx_alta, ]
    
    if (nrow(sfobj) == 0) {
      adicionar_log(tipo, nome_chave, "sem_classe_alta")
      return(NULL)
    }
  }
  
  # 8 — selecionar colunas
  sfobj$COD_MUNICIPIO <- cod
  sfobj <- sfobj[, c("COD_MUNICIPIO", "geometry")]
  
  return(sfobj)
}

# ------------------------------------------------------------
# 6) Processar listas com captura de erros graves
# ------------------------------------------------------------

processar_lista <- function(lista_sf, tipo){
  
  resultados <- list()
  
  for (nm in names(lista_sf)) {
    cat("\n[", tipo, "] Processando:", nm)
    
    x <- tryCatch(
      processar_um_municipio(nm, lista_sf[[nm]], tipo),
      error = function(e){
        adicionar_log(tipo, nm, "erro_grave_processamento", as.character(e))
        return(NULL)
      }
    )
    
    if (!is.null(x)) {
      resultados[[nm]] <- x  # ← Nomes únicos, sem sobrescrita
    }
  }
  
  if (length(resultados) == 0) return(NULL)
  do.call(rbind, resultados)
}

cat("\n🔧 Processando INUNDAÇÃO...\n")
inundacao_sf <- processar_lista(lista_inund, "inundacao")

cat("\n🔧 Processando MASSA...\n")
massa_sf <- processar_lista(lista_massa, "massa")

# ------------------------------------------------------------
# 7) Dissolver por município
# ------------------------------------------------------------

unir_por_municipio <- function(sfobj, tipo) {
  
  if (is.null(sfobj) || nrow(sfobj) == 0) {
    adicionar_log(tipo, "UNIAO", "sem_dados_para_unir")
    return(NULL)
  }
  
  sfobj <- suppressWarnings(st_make_valid(sfobj))
  
  cat("\n[", tipo, "] Dissolvendo...\n")
  
  unido <- try(
    sfobj |>
      group_by(COD_MUNICIPIO) |>
      summarise(
        geometry = suppressWarnings(
          st_make_valid(st_union(geometry))
        ),
        .groups = "drop"
      ),
    silent = TRUE
  )
  
  if (inherits(unido, "try-error")) {
    adicionar_log(tipo, "UNIAO", "erro_dissolve")
    return(NULL)
  }
  
  unido <- suppressWarnings(st_make_valid(unido))
  unido
}

inundacao_final <- unir_por_municipio(inundacao_sf, "inundacao")
massa_final     <- unir_por_municipio(massa_sf, "massa")

# ------------------------------------------------------------
# 8) Salvar arquivos finais
# ------------------------------------------------------------

dir.create("saida", showWarnings = FALSE)

if (!is.null(inundacao_final))
  st_write(inundacao_final, "saida/suscet_inundacao_br.gpkg", delete_dsn = TRUE)

if (!is.null(massa_final))
  st_write(massa_final, "saida/suscet_massa_br.gpkg", delete_dsn = TRUE)

fwrite(log_falhas, "saida/log_falhas_municipios.csv")

cat("\n🎉 PROCESSAMENTO FINALIZADO v11!\n")
cat("Gerados:\n")
cat(" • saida/suscet_inundacao_br.gpkg\n")
cat(" • saida/suscet_massa_br.gpkg\n")
cat(" • saida/log_falhas_municipios.csv\n")
