# =============================================================================
# 02_download_census_basic.R
# Downloads Basico_{UF}.csv directly from the IBGE FTP (2010 Census --
# Universe) for all 27 states and extracts Cod_setor + V002 + V009.
#
# Source:
#   https://ftp.ibge.gov.br/Censos/Censo_Demografico_2010/
#   Resultados_do_Universo/Agregados_por_Setores_Censitarios/{UF}_{date}.zip
#
# Output: data/processed_data/04_regression/basico_ibge_2010.parquet
#   code_tract      : character(15) -- census tract code
#   V002            : residents in permanent private households
#   V009            : average nominal monthly income of householders (R$)
#   renda_percapita : V009 / V002
#
# Cache: data/raw_data/04_regression/cache_basico_zips/ (delete to force re-download)
#
# After running this script, script 07 (housing quality) uses this parquet
# instead of censobr's "Basico" dataset, which has V009=NA for most states.
# =============================================================================

source("04_regression_dataset_and_models/00_setup.R")
library(httr)
library(rvest)
library(stringr)

cat("\n", strrep("=", 60), "\n")
cat("02_DOWNLOAD_CENSUS_BASIC.R\n")
cat(strrep("=", 60), "\n")

# --- Configuration --------------------------------------------------------------

BASE_URL  <- paste0(
  "https://ftp.ibge.gov.br/Censos/Censo_Demografico_2010/",
  "Resultados_do_Universo/Agregados_por_Setores_Censitarios/"
)
TIMEOUT_S <- 600L

cache_dir  <- file.path(raw_data_dir, "cache_basico_zips")
output_par <- file.path(data_dir, "basico_ibge_2010.parquet")

dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)

UF_SIGLAS <- c("RO","AC","AM","RR","PA","AP","TO",
               "MA","PI","CE","RN","PB","PE","AL","SE","BA",
               "MG","ES","RJ","SP","PR","SC","RS",
               "MS","MT","GO","DF")

# --- Helper functions -------------------------------------------------------------

get_retry <- function(url, n = 4L, timeout_sec = 30L) {
  for (i in seq_len(n)) {
    resp <- tryCatch(httr::GET(url, httr::timeout(timeout_sec)), error = function(e) NULL)
    if (!is.null(resp) && httr::status_code(resp) == 200L) return(resp)
    wait <- 2^i
    cat(sprintf("    attempt %d failed -- waiting %ds ...\n", i, wait))
    Sys.sleep(wait)
  }
  NULL
}

download_retry <- function(url, dest, n = 4L, timeout_sec = TIMEOUT_S) {
  if (file.exists(dest) && file.size(dest) > 1000L) {
    cat(sprintf("    cached: %s (%.1f MB)\n", basename(dest), file.size(dest) / 1e6))
    return(TRUE)
  }
  for (i in seq_len(n)) {
    ok <- tryCatch({
      r <- httr::GET(url, httr::write_disk(dest, overwrite = TRUE),
                     httr::timeout(timeout_sec), httr::progress())
      httr::status_code(r) == 200L
    }, error = function(e) { message(sprintf("    ERROR: %s", e$message)); FALSE })
    if (ok) return(TRUE)
    wait <- 2^i
    cat(sprintf("    attempt %d failed -- waiting %ds ...\n", i, wait))
    Sys.sleep(wait)
    if (file.exists(dest)) unlink(dest)
  }
  FALSE
}

# =============================================================================
# 1) LIST ZIPS ON THE IBGE FTP
# =============================================================================
cat("\n1) Listing zips on the IBGE FTP ...\n")

DATAS_FALLBACK <- c("20231030", "20231012", "20231017", "20231031",
                     "20171016", "20160621", "20161128", "20120625")

mk_url <- function(href) {
  if (grepl("^https?://", href)) href else paste0(BASE_URL, basename(href))
}

list_zips_html <- function() {
  resp <- get_retry(BASE_URL, timeout_sec = 30L)
  if (is.null(resp)) return(NULL)
  hrefs <- tryCatch(
    xml2::read_html(httr::content(resp, as = "raw"), encoding = "latin1") |>
      rvest::html_nodes("a") |>
      rvest::html_attr("href") |>
      grep("\\.zip$", x = _, value = TRUE, ignore.case = TRUE),
    error = function(e) NULL
  )
  if (is.null(hrefs) || length(hrefs) == 0L) return(NULL)
  data.frame(
    filename = basename(hrefs),
    url      = sapply(hrefs, mk_url),
    uf       = sub("^([A-Z]{2})_.*\\.zip$", "\\1", basename(hrefs), ignore.case = TRUE),
    stringsAsFactors = FALSE
  )
}

probe_zips <- function(ufs) {
  cat("  HTML listing failed -- probing via HEAD requests ...\n")
  rows <- lapply(ufs, function(uf) {
    for (data in DATAS_FALLBACK) {
      url  <- paste0(BASE_URL, uf, "_", data, ".zip")
      resp <- tryCatch(httr::HEAD(url, httr::timeout(15L)), error = function(e) NULL)
      if (!is.null(resp) && httr::status_code(resp) == 200L) {
        cat(sprintf("    found %s -> %s_%s.zip\n", uf, uf, data))
        return(data.frame(filename = basename(url), url = url,
                          uf = uf, stringsAsFactors = FALSE))
      }
    }
    cat(sprintf("    %s -- no date found\n", uf)); NULL
  })
  do.call(rbind, Filter(Negate(is.null), rows))
}

zip_index <- list_zips_html()
if (is.null(zip_index) || nrow(zip_index) == 0L) {
  zip_index <- probe_zips(UF_SIGLAS)
} else {
  zip_index <- zip_index[zip_index$uf %in% UF_SIGLAS, ]
}
if (is.null(zip_index) || nrow(zip_index) == 0L)
  stop("Could not locate the zips on the FTP. Check the connection.")

# Keep only the most recent zip per state ({UF}_{date}.zip)
simple_mask <- grepl("^[A-Z]{2}_[0-9]{8}\\.zip$", zip_index$filename, ignore.case = TRUE)
zip_simples <- zip_index[ simple_mask, ]
zip_split   <- zip_index[!simple_mask, ]
if (anyDuplicated(zip_simples$uf)) {
  zip_simples <- zip_simples[order(zip_simples$uf, -xtfrm(zip_simples$filename)), ]
  zip_simples <- zip_simples[!duplicated(zip_simples$uf), ]
}
zip_index <- rbind(zip_simples, zip_split)

missing <- setdiff(UF_SIGLAS, zip_index$uf)
if (length(missing) > 0L)
  cat(sprintf("  WARNING: states not found: %s\n", paste(missing, collapse = ", ")))
cat(sprintf("  %d zips found: %s\n",
            nrow(zip_index), paste(sort(zip_index$uf), collapse = " ")))

# =============================================================================
# 2) DOWNLOAD ZIPS (PERSISTENT CACHE)
# =============================================================================
cat("\n2) Downloading zips to cache ...\n")

for (i in seq_len(nrow(zip_index))) {
  cat(sprintf("  [%s] %s ...\n", zip_index$uf[i], basename(zip_index$url[i])))
  ok <- download_retry(zip_index$url[i],
                       file.path(cache_dir, zip_index$filename[i]))
  if (!ok) warning(sprintf("[%s] Download failed -- state will be skipped", zip_index$uf[i]))
}

# =============================================================================
# 3) READ Basico_{UF}.csv FROM THE ZIP
# =============================================================================

read_basico_uf <- function(uf, filename) {
  zip_path <- file.path(cache_dir, filename)
  if (!file.exists(zip_path) || file.size(zip_path) < 1000L) {
    cat(sprintf("  [%s] missing or invalid zip -- skipping\n", uf)); return(NULL)
  }
  contents <- tryCatch(utils::unzip(zip_path, list = TRUE),
                       error = function(e) { message(sprintf("  [%s] ERROR: %s", uf, e$message)); NULL })
  if (is.null(contents)) return(NULL)

  # Internal paths are CP-850: convert to UTF-8 before searching
  utf8_names <- suppressWarnings(iconv(contents$Name, from = "CP850", to = "UTF-8"))
  utf8_names[is.na(utf8_names)] <- contents$Name[is.na(utf8_names)]
  idx <- grep(paste0("Basico_", uf, "[^/]*\\.csv$"), utf8_names, ignore.case = TRUE)

  if (length(idx) == 0L) {
    cat(sprintf("  [%s] Basico_%s*.csv not found in the zip.\n", uf, uf))
    cat(sprintf("       Files: %s\n", paste(head(utf8_names, 8L), collapse = " | ")))
    return(NULL)
  }
  internal_csvs <- contents$Name[idx]

  tmp_dir <- tempfile()
  dir.create(tmp_dir, recursive = TRUE)
  on.exit(unlink(tmp_dir, recursive = TRUE), add = TRUE)

  csv_paths <- character(0L)

  # Method 1: utils::unzip with LC_CTYPE="C"
  old_lc <- Sys.getlocale("LC_CTYPE")
  Sys.setlocale("LC_CTYPE", "C")
  tryCatch({
    utils::unzip(zip_path, files = internal_csvs, exdir = tmp_dir, junkpaths = TRUE)
    csv_paths <- list.files(tmp_dir, "^Basico_.*\\.csv$", full.names = TRUE, ignore.case = TRUE)
  }, error = function(e) NULL)
  if (length(csv_paths) == 0L) {
    tryCatch({
      utils::unzip(zip_path, exdir = tmp_dir, junkpaths = TRUE)
      csv_paths <- list.files(tmp_dir, "^Basico_.*\\.csv$", full.names = TRUE, ignore.case = TRUE)
    }, error = function(e) NULL)
  }
  Sys.setlocale("LC_CTYPE", old_lc)

  # Method 2: PowerShell (Windows)
  if (length(csv_paths) == 0L && .Platform$OS.type == "windows") {
    cat(sprintf("  [%s] using PowerShell for extraction ...\n", uf))
    ps_out <- file.path(tmp_dir, "ps_out")
    dir.create(ps_out, recursive = TRUE)
    ps1 <- file.path(tmp_dir, "extract.ps1")
    writeLines(sprintf('Expand-Archive -LiteralPath "%s" -DestinationPath "%s" -Force',
                       normalizePath(zip_path, winslash = "/"),
                       normalizePath(ps_out,   winslash = "/")), ps1)
    system2("powershell",
            c("-NoProfile", "-ExecutionPolicy", "Bypass", "-File",
              normalizePath(ps1, winslash = "/")),
            stdout = FALSE, stderr = FALSE)
    csv_paths <- list.files(ps_out, "^Basico_.*\\.csv$",
                             full.names = TRUE, recursive = TRUE, ignore.case = TRUE)
  }

  if (length(csv_paths) == 0L) {
    cat(sprintf("  [%s] CSV not extracted (all methods failed).\n", uf))
    return(NULL)
  }

  dfs <- lapply(csv_paths, function(p) {
    tryCatch(read.csv2(p, fileEncoding = "Latin1",
                       stringsAsFactors = FALSE, colClasses = "character"),
             error = function(e) { message(sprintf("  [%s] ERROR reading: %s", uf, e$message)); NULL })
  })
  dfs <- Filter(Negate(is.null), dfs)
  if (length(dfs) == 0L) return(NULL)

  df        <- do.call(rbind, dfs)
  names(df) <- trimws(names(df))

  cod_col <- grep("^[Cc]od[._]?[Ss]etor$|^code_tract$", names(df), value = TRUE)
  if (length(cod_col) == 0L) {
    cat(sprintf("  [%s] census tract code column not found.\n", uf))
    return(NULL)
  }
  cod_col <- cod_col[[1L]]

  for (v in c("V002", "V009")) {
    if (!v %in% names(df)) {
      cat(sprintf("  [%s] column %s missing.\n", uf, v)); return(NULL)
    }
  }

  code_tract <- stringr::str_pad(trimws(df[[cod_col]]), width = 15L, side = "left", pad = "0")
  v002 <- suppressWarnings(as.numeric(gsub(",", ".", df$V002)))
  v009 <- suppressWarnings(as.numeric(gsub(",", ".", df$V009)))

  out <- data.frame(code_tract = code_tract, V002 = v002, V009 = v009,
                    stringsAsFactors = FALSE)
  cat(sprintf("  [%s] %s tracts | V009 valid: %s (%.1f%%)\n",
              uf, fmt(nrow(out)), fmt(sum(!is.na(out$V009))),
              100 * mean(!is.na(out$V009))))
  out
}

# =============================================================================
# 4) PROCESS AND SAVE
# =============================================================================
cat("\n3) Reading CSVs from the zips ...\n")

results <- Filter(Negate(is.null),
                  lapply(seq_len(nrow(zip_index)),
                         function(i) read_basico_uf(zip_index$uf[i], zip_index$filename[i])))

if (length(results) == 0L)
  stop("No data processed. Check the connection and the errors above.")
cat(sprintf("\n  %d/%d states loaded\n", length(results), length(UF_SIGLAS)))

cat("\n4) Combining and saving ...\n")

basico_br <- dplyr::bind_rows(results) |>
  dplyr::distinct(code_tract, .keep_all = TRUE) |>
  dplyr::mutate(renda_percapita = ifelse(!is.na(V002) & V002 > 0, V009 / V002, NA_real_))

cat(sprintf("  Total tracts    : %s\n",    fmt(nrow(basico_br))))
cat(sprintf("  V009 valid      : %s (%.1f%%)\n",
            fmt(sum(!is.na(basico_br$V009))), 100 * mean(!is.na(basico_br$V009))))

arrow::write_parquet(basico_br, output_par)
cat(sprintf("  - %s (%.1f MB)\n", output_par, file.size(output_par) / 1e6))

cat(sprintf("\n%s\nDONE\n%s\n", strrep("=", 60), strrep("=", 60)))
cat(sprintf("Output: %s\n", output_par))
cat(sprintf("Cache : %s\n", cache_dir))
cat("Columns: code_tract | V002 | V009 | renda_percapita\n")
cat("Next step: script 07 (housing quality) uses this parquet automatically.\n")
