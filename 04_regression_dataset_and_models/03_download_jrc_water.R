# =============================================================================
# 03_download_jrc_water.R
# Downloads JRC Global Surface Water ("occurrence" layer) tiles covering
# Brazil, used as a water mask in script 10_topography.R.
#
# Source: JRC GSW v1.4 (2021) -- Pekel et al. 2016
#   https://global-surface-water.appspot.com/
#
# Layer used: occurrence (0-100 %) -> fraction of time with water
#   Threshold in script 10: occurrence >= 80 % = permanent water
#
# Tiles are 10 deg x 10 deg GeoTIFFs, 30 m resolution, ~10-80 MB each.
# Fully oceanic tiles return 404 and are skipped silently.
#
# Output: data/processed_data/04_regression/jrc_gsw/  (downloaded .tif files)
# =============================================================================

source("04_regression_dataset_and_models/00_setup.R")
library(httr)
library(terra)

cat("\n", strrep("=", 60), "\n")
cat("03_DOWNLOAD_JRC_WATER.R\n")
cat(strrep("=", 60), "\n")

# --- Configuration -------------------------------------------------------------

BASE_URL  <- "https://storage.googleapis.com/global-surface-water/downloads2021/occurrence/"
JRC_DIR   <- file.path(data_dir, "jrc_gsw")
TIMEOUT_S <- 300L

dir.create(JRC_DIR, recursive = TRUE, showWarnings = FALSE)

# Tiles covering Brazil (NW corner of each 10 deg x 10 deg tile)
# Brazil: ~74W to ~34W, ~34S to ~5N
lons <- c("80W", "70W", "60W", "50W", "40W", "30W")
lats <- c("10N", "0N", "10S", "20S", "30S", "40S")

grid <- expand.grid(lon = lons, lat = lats, stringsAsFactors = FALSE)
grid$filename <- sprintf("occurrence_%s_%sv1_4_2021.tif", grid$lon, grid$lat)
grid$url      <- paste0(BASE_URL, grid$filename)
grid$dest     <- file.path(JRC_DIR, grid$filename)

cat(sprintf("\n%d candidate tiles for Brazil\n", nrow(grid)))

# --- Download function with retry and 404 detection --------------------------

# A file size check alone doesn't catch a connection dropped mid-download --
# GDAL still opens a truncated GeoTIFF's header, then fails later reading a
# tile's pixel data (as happened with occurrence_50W_30Sv1_4_2021.tif here).
# Opening it with terra::rast() and reading its dimensions forces GDAL to
# parse the file structure, catching a truncated download that a size check
# would miss.
is_valid_tif <- function(path) {
  if (!file.exists(path) || file.size(path) <= 1000L) return(FALSE)
  tryCatch({
    r <- terra::rast(path)
    terra::nrow(r) > 0 && terra::ncol(r) > 0
  }, error = function(e) FALSE)
}

download_tile <- function(url, dest, n = 4L, timeout_sec = TIMEOUT_S) {
  if (is_valid_tif(dest)) {
    cat(sprintf("  cached: %s  (%.1f MB)\n", basename(dest), file.size(dest) / 1e6))
    return("cached")
  }
  for (i in seq_len(n)) {
    sc <- tryCatch({
      r <- httr::GET(url, httr::write_disk(dest, overwrite = TRUE),
                     httr::timeout(timeout_sec), httr::progress())
      httr::status_code(r)
    }, error = function(e) { message(sprintf("    ERROR: %s", e$message)); 0L })
    if (sc == 200L) {
      if (is_valid_tif(dest)) return("ok")
      cat(sprintf("    attempt %d: downloaded file is not a valid GeoTIFF (truncated?) -- retrying ...\n", i))
      unlink(dest)
      next
    }
    if (sc == 404L) { if (file.exists(dest)) unlink(dest); return("not_found") }
    wait <- 2^i
    cat(sprintf("    attempt %d (HTTP %d) -- waiting %ds ...\n", i, sc, wait))
    Sys.sleep(wait)
    if (file.exists(dest)) unlink(dest)
  }
  "failed"
}

# --- Download ----------------------------------------------------------------

cat("\nDownloading tiles ...\n")

n_ok <- n_cached <- n_skip <- n_fail <- 0L

for (i in seq_len(nrow(grid))) {
  cat(sprintf("[%02d/%02d] %s ... ", i, nrow(grid), grid$filename[i]))
  res <- download_tile(grid$url[i], grid$dest[i])
  switch(res,
    ok        = { n_ok     <- n_ok     + 1L; cat(sprintf("OK  (%.1f MB)\n", file.size(grid$dest[i]) / 1e6)) },
    cached    = { n_cached <- n_cached + 1L },
    not_found = { n_skip   <- n_skip   + 1L; cat("does not exist (ocean/out of range)\n") },
    failed    = { n_fail   <- n_fail   + 1L; cat("FAILED\n") }
  )
}

# --- Summary ------------------------------------------------------------------

tifs_ok <- list.files(JRC_DIR, "\\.tif$", full.names = TRUE)

cat("\n", strrep("-", 40), "\n")
cat(sprintf("  Downloaded now  : %d tiles\n",   n_ok))
cat(sprintf("  Already cached  : %d tiles\n",   n_cached))
cat(sprintf("  Nonexistent     : %d tiles\n",   n_skip))
cat(sprintf("  Failed          : %d tiles\n",   n_fail))
cat(sprintf("  Total on disk   : %d tiles  (%.0f MB)\n",
            length(tifs_ok), sum(file.size(tifs_ok)) / 1e6))
cat(sprintf("  Directory       : %s\n", JRC_DIR))

if (n_fail > 0L)
  cat("\n  Warning: some tiles failed. Re-run the script to retry.\n")

cat(sprintf("\n%s\nDONE\n%s\n", strrep("=", 60), strrep("=", 60)))
cat("Next step: script 10_topography.R uses this directory automatically.\n")
