# =============================================================================
# 00_setup.R -- Regression pipeline
# Packages, paths and helper functions shared by every script in this stage.
# =============================================================================

# On Windows, libcurl's default SSL backend (Schannel) fails with
# "CRYPT_E_REVOCATION_OFFLINE" when it can't reach a certificate-revocation
# server -- common behind a corporate proxy/firewall. R packages that use
# curl/httr internally (geobr, censobr, ...) surface the resulting truncated
# download as a generic "file must have been corrupted" error, which is
# misleading (it isn't a stale-cache problem; the download itself is
# failing every time). This is the same failure already fixed for
# DUR_Municipios.xlsx's download in 01_define_sample.R via
# curl::new_handle(ssl_options = 2L) (CURLSSLOPT_NO_REVOKE -- skips only the
# revocation check, not certificate validation). Applying it globally here,
# via httr::set_config(), covers every httr-based download for the rest of
# the session (geobr, censobr, and this stage's own httr::GET() calls)
# without needing a curl SSL-backend switch, which some Windows libcurl
# builds don't support at all (curl::curl_version()$ssl_backends == NULL).
# Unlike a backend switch, this takes effect immediately -- no R restart
# needed -- since httr reads its global config at request time, not once at
# package load.
httr::set_config(httr::config(ssl_options = 2L))

library(sf)
library(dplyr)
library(tidyr)
library(readxl)
library(readr)
library(stringr)
library(arrow)
library(sfarrow)
library(here)

# --- Paths ---------------------------------------------------------------------

proj_dir <- here::here()

# Central path definitions (data/raw_data, data/processed_data, output/),
# shared across all five pipeline folders -- see R/paths.R.
source(file.path(proj_dir, "R", "paths.R"))

# Stage 03's raw/processed locations, for inputs shared across stages: the
# municipality sample, DUR/population source files, and the common-grid
# outputs (03_urban_footprint_and_growth_types/00_setup.R already writes
# here -- read directly rather than duplicating a copy under stage 04).
stage03_raw_dir  <- raw_data_path("03_urban_footprint")
stage03_data_dir <- processed_data_path("03_urban_footprint")
amostra_rds      <- file.path(stage03_data_dir, "amostra_municipios.rds")
growth_types_dir <- file.path(stage03_data_dir, "crescimento_urbano")
metricas_dir     <- file.path(stage03_data_dir, "metricas")

# Stage 02's processed location, for the susceptibility/statistical-grid
# layers several stage-04 scripts read directly (grade_*_BR.gpkg,
# grade_*_BR_com_suscept_alta_agsn.gpkg).
stage02_data_dir <- processed_data_path("02_hazard_zones")

# This stage's own raw/processed locations
raw_data_dir  <- raw_data_path("04_regression")
data_dir      <- processed_data_path("04_regression")
ghsl_susc_dir <- file.path(data_dir, "ghsl_susceptibility")
housing_dir   <- file.path(data_dir, "housing_quality")
tables_dir    <- file.path(data_dir, "tables")
figures_dir   <- file.path(data_dir, "figures")

for (d in c(data_dir, ghsl_susc_dir, housing_dir, tables_dir, figures_dir))
  dir.create(d, recursive = TRUE, showWarnings = FALSE)

# --- Analysis parameters ----------------------------------------------------------

# Minimum 2010 baseline population inside high susceptibility for a unit to
# enter the regressions. g_alta is a growth RATE whose denominator is
# pmax(pop_2010_risk_total, 1), so a near-zero baseline turns a handful of
# people into an implausible percentage that dominates the unweighted OLS fit
# of the g_alta columns. The cut removes those cases transparently.
#
# Decided 2026-09-08 at 1000 (MIGRATION_PLAN.md 6c1), against the
# any-overlap distribution of pop_2010_risk_total. REVISED 2026-09-12 to 200:
# the 6e weighting correction lowered that column substantially, so the
# unchanged nominal value had silently become a far more aggressive
# restriction than the one 6c1 decided. See 6c1's revision paragraph for the
# rescaling and for the evidence that does and does not transfer.
#
# Defined here so the robustness scripts read one value rather than each
# carrying its own copy. NOTE, as of 2026-09-16 this is not yet the single
# definition in the stage: 16_estimate_models.R:201 and
# 05_exhibits/figure2_exposure_scatter.R:32 still declare their own, at the
# same value. They agree today; if this line changes, those two must change
# with it, or be repointed here.
MIN_POP_RISCO_2010 <- 200

# --- Helper functions ------------------------------------------------------------

fmt <- function(x, ...) format(x, big.mark = ".", decimal.mark = ",", ...)

# Retries a geobr::read_*() call once after clearing geobr's local download
# cache, to recover from a corrupted/incomplete download. geobr's own error
# ("A file must have been corrupted during download. Please restart your R
# session and try again.") doesn't actually fix anything -- the corrupted
# file stays in the cache across sessions until something removes it. Used
# by 04_download_geobr_censobr.R, the only script that still calls geobr/
# censobr directly -- 07/09/10/11 just read that script's prepared .rds
# files under raw_data_dir.
#
# Two things confirmed against geobr's own source (ipeaGIT/geobr, R/utils.R)
# after this failed to trigger on a real corrupted-cache run:
#   1. That error is raised by download_metadata2() as an actual R error
#      (cli::cli_abort), not a NULL return -- a NULL-only check never sees
#      it; fn(...) throws before the `if (!is.null(result))` line is reached.
#   2. The file it corrupts lives under tempdir()'s own "geobr" subfolder
#      (fs::path_temp("geobr")/metadata_geobr_gpkg.parquet), a per-session
#      temp cache -- not tools::R_user_dir()/rappdirs::user_data_dir(), which
#      are separate, persistent cache locations geobr also uses for other
#      files. Clearing only those left the actual corrupted file in place.
geobr_retry <- function(fn, ...) {
  errored <- FALSE
  result <- tryCatch(suppressWarnings(fn(...)), error = function(e) {
    cat(sprintf("  geobr raised an error (%s) -- clearing cache and retrying...\n",
                conditionMessage(e)))
    errored <<- TRUE
    NULL
  })
  if (!is.null(result)) return(result)
  if (!errored)
    cat("  geobr returned NULL (likely a corrupted cache file) -- clearing cache and retrying...\n")

  cache_dirs <- c(
    tryCatch(fs::path_temp("geobr"),               error = function(e) NULL),
    tryCatch(file.path(tempdir(), "geobr"),        error = function(e) NULL),
    tryCatch(tools::R_user_dir("geobr", "cache"),  error = function(e) NULL),
    tryCatch(rappdirs::user_data_dir("geobr"),     error = function(e) NULL)
  )
  n_removed <- 0L
  for (cd in unique(cache_dirs[!sapply(cache_dirs, is.null)])) {
    if (!dir.exists(cd)) next
    files <- list.files(cd, full.names = TRUE, recursive = TRUE)
    if (length(files) > 0) {
      file.remove(files)
      n_removed <- n_removed + length(files)
    }
  }
  cat(sprintf("    cleared %d cached file(s)\n", n_removed))

  suppressWarnings(fn(...))
}

cat("Paths configured:\n")
cat("  stage03_raw_dir  :", stage03_raw_dir,  "\n")
cat("  stage03_data_dir :", stage03_data_dir, "\n")
cat("  amostra_rds      :", amostra_rds,      "\n")
cat("  stage02_data_dir :", stage02_data_dir, "\n")
cat("  raw_data_dir     :", raw_data_dir,     "\n")
cat("  data_dir         :", data_dir,         "\n")
cat("  ghsl_susc_dir    :", ghsl_susc_dir,    "\n")
cat("  housing_dir      :", housing_dir,      "\n")
cat("  tables_dir       :", tables_dir,       "\n")
cat("  figures_dir      :", figures_dir,      "\n")
cat("Analysis parameters:\n")
cat("  MIN_POP_RISCO_2010:", MIN_POP_RISCO_2010, "\n")
