
# Run this script with the working directory set to the stage-01 raw-data folder (see making_suscep_national.md, "Working directory"). A machine-specific setwd() was removed here for publication.
# ============================================================
# SCRIPT 1 — VERSÃO FINAL DEFINITIVA (2025)
# ============================================================

library(sf)
library(fs)
library(stringr)
library(lwgeom)

sf_use_s2(FALSE)

# ------------------------------------------------------------
# Função auxiliar para padronizar geometrias
# ------------------------------------------------------------
padronizar_geometria <- function(sfobj) {
  if (is.null(sfobj) || nrow(sfobj) == 0) return(NULL)
  
  geom_class <- unique(sf::st_geometry_type(sfobj))
  
  if (all(geom_class %in% c("POLYGON", "MULTIPOLYGON"))) {
    sfobj <- try(suppressWarnings(st_cast(sfobj, "MULTIPOLYGON")), silent=TRUE)
    if (inherits(sfobj, "try-error")) return(sfobj)
  }
  
  sfobj
}

# ============================================================
# Função principal: ler camadas de suscetibilidade do município
# ============================================================

ler_camadas_municipio <- function(pasta) {
  
  out <- list(inund=NULL, massa=NULL)
  
  # IMPORTANTE:
  # NÃO usar path_abs(), NÃO usar enc2utf8()
  # → o script original funciona perfeitamente com acentos assim.
  arquivos <- try(dir_ls(pasta, recurse=TRUE, type="file"), silent=TRUE)
  if (inherits(arquivos, "try-error")) return(out)
  
  arquivos_shp  <- arquivos[grepl("\\.shp$",  arquivos, ignore.case=TRUE)]
  arquivos_gpkg <- arquivos[grepl("\\.gpkg$", arquivos, ignore.case=TRUE)]
  
  # ============================================================
  # 1) GPKG — somente as layers padronizadas do SGB
  # ============================================================
  for (g in arquivos_gpkg) {
    lays <- try(st_layers(g)$name, silent=TRUE)
    if (inherits(lays, "try-error")) next
    
    for (lay in lays) {
      lay_low <- tolower(lay)
      
      if (lay_low == "inundacao_a") {
        sfobj <- try(suppressWarnings(st_read(g, layer=lay, quiet=TRUE)), silent=TRUE)
        if (inherits(sfobj, "sf"))
          out$inund <- padronizar_geometria(sfobj)
      }
      
      if (lay_low == "movimento_de_massa_a") {
        sfobj <- try(suppressWarnings(st_read(g, layer=lay, quiet=TRUE)), silent=TRUE)
        if (inherits(sfobj, "sf"))
          out$massa <- padronizar_geometria(sfobj)
      }
    }
  }
  
  # ============================================================
  # 2) SHP — nome primeiro, fallback por CLASSE depois
  # ============================================================
  
  for (f in arquivos_shp) {
    
    nm <- tolower(basename(f))
    
    # ignorar perigos não desejados
    if (grepl("enxurr|corrida|relevo|eros", nm)) next
    
    tipo <- NULL
    
    # Classificação pelo nome
    if (grepl("inund", nm)) tipo <- "inund"
    if (grepl("mov", nm) & grepl("massa", nm)) tipo <- "massa"
    
    sfobj <- try(suppressWarnings(st_read(f, quiet=TRUE)), silent=TRUE)
    if (!inherits(sfobj, "sf")) next
    sfobj <- padronizar_geometria(sfobj)
    
    # Fallback via CLASSE caso nome não resolva
    if (is.null(tipo)) {
      
      cols <- names(sfobj)
      campo <- cols[grepl("classe|tipo|process", cols, ignore.case=TRUE)][1]
      
      if (!is.na(campo)) {
        valores <- sfobj[[campo]]
        
        if (any(grepl("inund", valores, ignore.case=TRUE)))
          tipo <- "inund"
        
        # AQUI aplicamos sua regra FINAL:
        # MASSA somente se "mov" + "massa"
        if (any(grepl("mov", valores, ignore.case=TRUE) &
                grepl("massa", valores, ignore.case=TRUE)))
          tipo <- "massa"
      }
    }
    
    if (!is.null(tipo))
      out[[tipo]] <- sfobj
  }
  
  return(out)
}

# ============================================================
# LOOP PRINCIPAL — igual ao script original
# ============================================================

base_dir <- "suscet_sig_processado"

cat("\nINICIANDO SCRIPT 1 - LEITURA COMPLETA\n\n")

ufs <- dir_ls(base_dir, type="directory", recurse=FALSE)

lista_inundacao <- list()
lista_massa <- list()
municipios_pulados <- c()

for (uf in ufs) {
  
  municipios <- dir_ls(uf, type="directory", recurse=FALSE)
  
  for (mp in municipios) {
    
    uf_nome <- basename(uf)
    muni_nome <- basename(mp)
    
    cat("\n--- UF:", uf_nome, "| Municipio:", muni_nome, "\n")
    
    cam <- try(ler_camadas_municipio(mp), silent=TRUE)
    
    if (inherits(cam, "try-error")) {
      municipios_pulados <- c(municipios_pulados, paste(uf_nome, muni_nome))
      next
    }
    
    chave <- paste0(uf_nome, "_", muni_nome)
    
    lista_inundacao[[chave]] <- cam$inund
    lista_massa[[chave]]     <- cam$massa
  }
}

# ============================================================
# SALVAR RESULTADOS
# ============================================================

if (!dir_exists("saida")) dir_create("saida")

save(lista_inundacao, lista_massa, municipios_pulados,
     file="saida/script1_objetos_sf.RData")

cat("\nSCRIPT 1 FINALIZADO!\n")
cat("Objetos salvos em: saida/script1_objetos_sf.RData\n")
cat("Municipios ignorados:", length(municipios_pulados), "\n\n")
write.csv(municipios_pulados,"pulados3.csv")
