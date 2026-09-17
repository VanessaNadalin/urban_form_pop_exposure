# =============================================================================
# 04_download_geobr_censobr.R
# Downloads and caches every geobr/censobr dataset used later in this stage,
# as plain .rds files under data/raw_data/04_regression/. Consumer scripts
# (07, 09, 10, 11) just read these files directly -- no geobr:: or censobr::
# calls, and no live-download fallback logic, in the analysis scripts
# themselves.
#
# Why this script exists: geobr's and censobr's own data servers were
# confirmed unreachable independent of network/proxy configuration (fails
# the same way from an unrelated machine and network -- not fixable from
# the client side). When that happens, generate the same file on a machine
# where it works (identical calls below) and place it directly in
# data/raw_data/04_regression/ before running this script -- it is used
# as-is and the live download is skipped for that file.
#
# Outputs (data/raw_data/04_regression/), each consumed by the script noted:
#   setores_censitarios_2010_brasil.rds      (script 07)
#   censo_domicilio_setores_2010.rds         (script 07)
#   censo_domicilios_2010.rds                (script 11)
#   censo_populacao_colnames_2010.rds        (script 11)
#   censo_populacao_mobilidade_2010.rds      (script 11)
#   sedes_municipais_geobr_1950_2010.rds     (script 09)
#   brasil_pais_2020.rds                     (script 10)
#   malha_municipal_2022.rds                 (script 10)
# =============================================================================

source("04_regression_dataset_and_models/00_setup.R")
library(geobr)
library(censobr)

cat("\n", strrep("=", 60), "\n")
cat("04_DOWNLOAD_GEOBR_CENSOBR.R\n")
cat(strrep("=", 60), "\n")

# Runs `produce()` and saves its result to `path` only if `path` doesn't
# already exist (whether from an earlier run of this script, or manually
# placed per this script's header). Catches and reports a download failure
# without stopping the other datasets in this script from being attempted.
#
# A file that exists but fails to load (partial write from an interrupted
# run, disk full, a killed process) used to be treated as "already present"
# forever, since only file.exists() was checked -- readRDS() would then fail
# downstream, in whichever consumer script (07, 09, 10, 11) happened to read
# it next, with a generic "erro ao ler a partir de conexão" that gave no hint
# the actual problem was here. Now validates the existing file with readRDS()
# before accepting it; a file that fails to load is deleted and re-downloaded.
prepare <- function(path, label, produce) {
  if (file.exists(path)) {
    valid <- tryCatch({ readRDS(path); TRUE }, error = function(e) FALSE)
    if (valid) {
      cat(sprintf("  OK (already present) %s\n", basename(path)))
      return(invisible(TRUE))
    }
    cat(sprintf("  CORRUPTED (fails to load) %s -- deleting and re-downloading\n", basename(path)))
    file.remove(path)
  }
  cat(sprintf("  Downloading %s ...\n", label))
  result <- tryCatch(produce(), error = function(e) {
    cat(sprintf("  FAILED %s: %s\n", label, conditionMessage(e)))
    NULL
  })
  if (is.null(result)) {
    cat(sprintf("  -> place a local copy at %s manually (see this script's header)\n", path))
    return(invisible(FALSE))
  }
  saveRDS(result, path)
  cat(sprintf("  OK %s\n", basename(path)))
  invisible(TRUE)
}

# =============================================================================
# 1) GEOBR -- geographic reference data
# =============================================================================

cat("\n1) geobr datasets ...\n")

prepare(
  file.path(raw_data_dir, "setores_censitarios_2010_brasil.rds"),
  "2010 census tract geometries (geobr::read_census_tract)",
  function() geobr_retry(
    geobr::read_census_tract,
    code_tract = "all", year = 2010, zone = "all",
    simplified = FALSE, showProgress = TRUE
  )
)

prepare(
  file.path(raw_data_dir, "sedes_municipais_geobr_1950_2010.rds"),
  "municipal seats 1950-2010 (geobr::read_municipal_seat)",
  function() {
    fallback_years <- c(1950, 1960, 1970, 1980, 1991, 2010)
    seats_by_year <- setNames(
      lapply(fallback_years, function(y)
        geobr_retry(geobr::read_municipal_seat, year = y, showProgress = TRUE)),
      as.character(fallback_years)
    )
    failed_years <- names(seats_by_year)[sapply(seats_by_year, is.null)]
    if (length(failed_years) > 0) {
      cat(sprintf("  FAILED for year(s): %s\n", paste(failed_years, collapse = ", ")))
      return(NULL)  # a partial cache would silently break 09_distance_to_seat.R's cascade
    }
    seats_by_year
  }
)

prepare(
  file.path(raw_data_dir, "brasil_pais_2020.rds"),
  "Brazil national outline (geobr::read_country)",
  function() geobr_retry(geobr::read_country, year = 2020, simplified = TRUE, showProgress = TRUE)
)

prepare(
  file.path(raw_data_dir, "malha_municipal_2022.rds"),
  "2022 municipal mesh (geobr::read_municipality)",
  function() geobr_retry(
    geobr::read_municipality,
    code_muni = "all", year = 2022, simplified = FALSE, showProgress = TRUE
  )
)

# =============================================================================
# 2) CENSOBR -- 2010 Census microdata
# =============================================================================

cat("\n2) censobr datasets ...\n")

prepare(
  file.path(raw_data_dir, "censo_domicilio_setores_2010.rds"),
  "2010 household tract aggregates (censobr::read_tracts, Domicilio)",
  function() censobr::read_tracts(year = 2010, dataset = "Domicilio", showProgress = TRUE) |> as.data.frame()
)

prepare(
  file.path(raw_data_dir, "censo_domicilios_2010.rds"),
  "2010 household microdata (censobr::read_households)",
  function() censobr::read_households(
    year = 2010, columns = c("code_muni", "V0201", "V2011", "V6531", "V0010"),
    as_data_frame = TRUE, showProgress = TRUE
  )
)

# Population column names: read separately since the mobility columns file
# below (cols_mob) depends on which of V4718/V6527 exists this census year --
# resolved once here, matching 11_inequality.R's own logic exactly.
pes_colnames_path <- file.path(raw_data_dir, "censo_populacao_colnames_2010.rds")
prepare(
  pes_colnames_path,
  "2010 population column names (censobr::read_population schema)",
  function() names(censobr::read_population(year = 2010, as_data_frame = FALSE, showProgress = FALSE))
)

if (file.exists(pes_colnames_path)) {
  pes_colnames  <- readRDS(pes_colnames_path)
  col_ind_income <- intersect(c("V4718", "V6527"), pes_colnames)[1]
  if (is.na(col_ind_income)) {
    cat("  WARNING: no individual income column (V4718/V6527) found in population schema -- skipping mobility download.\n")
  } else {
    cols_mob <- unique(c("code_muni", "V0662", "V6531", "V0010", col_ind_income))
    prepare(
      file.path(raw_data_dir, "censo_populacao_mobilidade_2010.rds"),
      sprintf("2010 population mobility columns (censobr::read_population, %s)", col_ind_income),
      function() censobr::read_population(
        year = 2010, columns = cols_mob, as_data_frame = TRUE, showProgress = TRUE
      )
    )
  }
} else {
  cat("  Skipping mobility download: population column names not available.\n")
}

# =============================================================================
# 3) SUMMARY
# =============================================================================

targets <- c(
  "setores_censitarios_2010_brasil.rds", "sedes_municipais_geobr_1950_2010.rds",
  "brasil_pais_2020.rds", "malha_municipal_2022.rds",
  "censo_domicilio_setores_2010.rds", "censo_domicilios_2010.rds",
  "censo_populacao_colnames_2010.rds", "censo_populacao_mobilidade_2010.rds"
)
present <- file.exists(file.path(raw_data_dir, targets))

cat("\n", strrep("=", 60), "\n")
cat("DONE\n")
cat(strrep("=", 60), "\n")
cat(sprintf("  %d of %d reference files present in %s\n", sum(present), length(targets), raw_data_dir))
if (any(!present)) {
  cat("  Missing (place manually or re-run once the data server is reachable):\n")
  for (t in targets[!present]) cat(sprintf("    - %s\n", t))
}
