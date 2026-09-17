# =============================================================================
# 02_download_ghsl_data.R
# Download GHSL R2023A (100m, Mollweide) -- global files per product and epoch
#
# Products downloaded:
#
#   GHS-BUILT-S R2023A  --  built-up surface (m^2/100m cell)
#     Epochs: E2000, E2010, E2020
#     Derived from Sentinel-2 and Landsat; values 0-10000
#
#   GHS-POP R2023A  --  population count per 100m cell
#     Epochs: E2000, E2010
#     Derived from national census data anchored to BUILT-S
#     Values: inhabitants (floating point)
#
# Used downstream by:
#   BUILT-S E2010, E2020  ->  03_integrate_grid_with_ghsl.R (join onto the 2010/2022 IBGE grid)
#   BUILT-S E2000         ->  06_classify_growth_types_2000_2010.R (2000->2010 growth, t1 urban criterion)
#   POP    E2000          ->  06_classify_growth_types_2000_2010.R (2000 density, t1 major/minor patches)
#   POP    E2010          ->  06_classify_growth_types_2000_2010.R (2010 density, consistent t2 urban criterion)
#
# Source: European Commission, Joint Research Centre (JRC)
#   Pesaresi, M.; Politis, P. (2023): GHS-BUILT-S R2023A / GHS-POP R2023A
#   https://human-settlement.emergency.copernicus.eu/
#
# NOTE: Large downloads (~1.5-2 GB each, ~8-10 GB total).
#       Files already downloaded (TIF present) are skipped automatically.
#
# Output: data/raw_data/03_urban_footprint/ghsl_raw/*.tif
# =============================================================================

source("03_urban_footprint_and_growth_types/00_setup.R")

# =============================================================================
# 1. Configuration -- list of files to download
# =============================================================================

# Each entry: readable name -> global ZIP URL
ghsl_downloads <- list(

  # -- GHS-BUILT-S (built-up surface) ------------------------------------------
  "BUILT-S E2000" = "https://jeodpp.jrc.ec.europa.eu/ftp/jrc-opendata/GHSL/GHS_BUILT_S_GLOBE_R2023A/GHS_BUILT_S_E2000_GLOBE_R2023A_54009_100/V1-0/GHS_BUILT_S_E2000_GLOBE_R2023A_54009_100_V1_0.zip",
  "BUILT-S E2010" = "https://jeodpp.jrc.ec.europa.eu/ftp/jrc-opendata/GHSL/GHS_BUILT_S_GLOBE_R2023A/GHS_BUILT_S_E2010_GLOBE_R2023A_54009_100/V1-0/GHS_BUILT_S_E2010_GLOBE_R2023A_54009_100_V1_0.zip",
  "BUILT-S E2020" = "https://jeodpp.jrc.ec.europa.eu/ftp/jrc-opendata/GHSL/GHS_BUILT_S_GLOBE_R2023A/GHS_BUILT_S_E2020_GLOBE_R2023A_54009_100/V1-0/GHS_BUILT_S_E2020_GLOBE_R2023A_54009_100_V1_0.zip",

  # -- GHS-POP (population count) -----------------------------------------------
  "POP E2000"     = "https://jeodpp.jrc.ec.europa.eu/ftp/jrc-opendata/GHSL/GHS_POP_GLOBE_R2023A/GHS_POP_E2000_GLOBE_R2023A_54009_100/V1-0/GHS_POP_E2000_GLOBE_R2023A_54009_100_V1_0.zip",
  "POP E2010"     = "https://jeodpp.jrc.ec.europa.eu/ftp/jrc-opendata/GHSL/GHS_POP_GLOBE_R2023A/GHS_POP_E2010_GLOBE_R2023A_54009_100/V1-0/GHS_POP_E2010_GLOBE_R2023A_54009_100_V1_0.zip"
)

# Output directory
ghsl_dir <- file.path(raw_data_dir, "ghsl_raw")
dir.create(ghsl_dir, recursive = TRUE, showWarnings = FALSE)

cat("=== GHSL R2023A Download ===\n")
cat(sprintf("Files to download: %d\n", length(ghsl_downloads)))
cat(sprintf("Destination: %s\n\n", ghsl_dir))
cat("Resolution: 100m | CRS: Mollweide (ESRI:54009)\n")
cat("Type: global file (one per epoch)\n")
cat("Destination:", ghsl_dir, "\n\n")

# =============================================================================
# 2. Download function with retries
# =============================================================================

download_ghsl <- function(url, dest_dir, max_retries = 4) {
  fname <- basename(url)
  dest  <- file.path(dest_dir, fname)

  # Expected TIF name after unzipping
  tif_name <- sub("\\.zip$", ".tif", fname)
  tif_path <- file.path(dest_dir, tif_name)

  # If the TIF already exists, skip entirely
  if (file.exists(tif_path)) {
    size_gb <- file.size(tif_path) / 1024^3
    cat(sprintf("  TIF already exists: %s (%.2f GB) -- skipping\n", tif_name, size_gb))
    return("already exists")
  }

  # If the ZIP already exists and has a reasonable size (> 100 MB), go straight to unzip
  if (file.exists(dest) && file.size(dest) > 100 * 1024^2) {
    size_gb <- file.size(dest) / 1024^3
    cat(sprintf("  ZIP already exists: %s (%.2f GB) -- unzipping...\n", fname, size_gb))
  } else {
    # Download the file
    cat(sprintf("  Downloading: %s\n", fname))
    cat("  (this can take 15-30 minutes per file)\n")

    for (attempt in seq_len(max_retries)) {
      t0 <- Sys.time()

      ok <- tryCatch({
        # long timeout for large files (2 hours)
        options(timeout = 7200)
        download.file(url, dest, mode = "wb", quiet = FALSE)
        file.exists(dest) && file.size(dest) > 100 * 1024^2
      }, error = function(e) {
        cat(sprintf("    ERROR: %s\n", conditionMessage(e)))
        FALSE
      })

      elapsed <- round(as.numeric(difftime(Sys.time(), t0, units = "mins")), 1)

      if (ok) {
        size_gb <- file.size(dest) / 1024^3
        cat(sprintf("  Download complete: %.2f GB in %.1f min\n", size_gb, elapsed))
        break
      }

      # Clean up incomplete file
      if (file.exists(dest)) file.remove(dest)

      if (attempt < max_retries) {
        wait <- 2^attempt
        cat(sprintf("    Attempt %d/%d failed (%.1f min), waiting %ds...\n",
                    attempt, max_retries, elapsed, wait))
        Sys.sleep(wait)
      } else {
        cat(sprintf("    All %d attempts failed.\n", max_retries))
        return("failed")
      }
    }
  }

  # Unzip
  cat(sprintf("  Unzipping %s...\n", fname))
  tryCatch({
    unzip(dest, exdir = dest_dir, overwrite = FALSE)
    cat("  Unzipped successfully.\n")
  }, error = function(e) {
    cat(sprintf("  ERROR while unzipping: %s\n", conditionMessage(e)))
    return("unzip_error")
  })

  # Check whether the TIF was created
  if (file.exists(tif_path)) {
    size_gb <- file.size(tif_path) / 1024^3
    cat(sprintf("  TIF created: %s (%.2f GB)\n", tif_name, size_gb))
    return("downloaded")
  } else {
    cat("  WARNING: TIF not found after unzipping.\n")
    # List what was extracted
    extracted <- list.files(dest_dir, pattern = sub("V1_0\\.zip$", "V1_0", fname))
    if (length(extracted) > 0) {
      cat("  Extracted files:\n")
      for (f in extracted) cat(sprintf("    %s\n", f))
    }
    return("downloaded")
  }
}

# =============================================================================
# 3. Download each file
# =============================================================================

cat("--- Starting downloads ---\n")
cat("(files with a TIF already present are skipped)\n\n")

names_vec <- names(ghsl_downloads)
results   <- setNames(character(length(ghsl_downloads)), names_vec)

for (i in seq_along(ghsl_downloads)) {
  nm  <- names_vec[i]
  url <- ghsl_downloads[[i]]
  cat(sprintf("=== %s [%d/%d] ===\n", nm, i, length(ghsl_downloads)))

  results[nm] <- download_ghsl(url = url, dest_dir = ghsl_dir)
  cat("\n")
}

# =============================================================================
# 4. Verification and summary
# =============================================================================

tifs <- list.files(ghsl_dir, pattern = "\\.tif$", full.names = TRUE)
zips <- list.files(ghsl_dir, pattern = "\\.zip$", full.names = TRUE)

cat("=== DOWNLOAD SUMMARY ===\n")
cat(sprintf("TIF files available: %d of %d expected\n",
            length(tifs), length(ghsl_downloads)))

for (nm in names_vec) {
  url     <- ghsl_downloads[[nm]]
  tif_nm  <- sub("\\.zip$", ".tif", basename(url))
  tif_pth <- file.path(ghsl_dir, tif_nm)
  status  <- if (file.exists(tif_pth))
    sprintf("OK  (%.2f GB)", file.size(tif_pth) / 1024^3)
  else
    "MISSING"
  cat(sprintf("  %-15s : %s\n", nm, status))
}

n_ok <- sum(results %in% c("downloaded", "already exists"))
cat(sprintf("\nStatus: %d/%d files OK\n", n_ok, length(ghsl_downloads)))
if (n_ok < length(ghsl_downloads)) {
  cat("WARNING: missing files. Re-run this script.\n")
}

total_zip_gb <- if (length(zips) > 0) sum(file.size(zips)) / 1024^3 else 0
total_tif_gb <- if (length(tifs) > 0) sum(file.size(tifs)) / 1024^3 else 0
cat(sprintf("\nDisk space:\n"))
cat(sprintf("  TIFs : %.2f GB\n", total_tif_gb))
cat(sprintf("  ZIPs : %.2f GB\n", total_zip_gb))
cat(sprintf("  Total: %.2f GB\n", total_tif_gb + total_zip_gb))
cat("Tip: once the TIFs are verified, the ZIPs can be deleted.\n")

cat("\n=== Script 02 complete ===\n")
cat("Next steps:\n")
cat("  03_integrate_grid_with_ghsl.R      -- join BUILT-S E2010/E2020 onto the IBGE grid\n")
cat("  06_classify_growth_types_2000_2010.R -- use BUILT-S E2000 + POP E2000/E2010\n")
