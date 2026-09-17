# =============================================================================
# 01_define_sample.R
# Define municipalities for the urban form analysis
#
# Logic:
# 1. Confirmed HIGH susceptibility in the national gpkg (SGB/CPRM, rule 9)
# 2. For DUR arrangements with >=1 exposed municipality -> include ALL members
# 3. Isolated municipalities: keep if exposed
# 4. Filter: population > 50k (arrangement total, or individual for isolated)
#
# The CPRM risk layer (risco_preparado.gpkg) was unioned into the exposed set
# until MIGRATION_PLAN.md 6f.1 (decided 2026-09-13) retired stage 03's
# consumption of it. Stage 02 is frozen and still produces the layer; only this
# stage's use of it was dropped. The removed code is preserved verbatim in the
# private working repository, not here.
#
# Output: processed_data/amostra_municipios.rds + .csv
#
# Note (translation pass, no logic change): the output data frame/CSV column
# names (cod_mun, CD_CIDADE, NM_CIDADE, em_arranjo, tem_susceptibilidade,
# pop_2022, pop_arranjo) are kept as-is per CLAUDE.md rule 4 --
# amostra_municipios.rds/.csv is an already-generated file read by column
# name throughout the rest of this pipeline stage. Only in-script
# identifiers, comments and console messages are translated here.
# =============================================================================

source("03_urban_footprint_and_growth_types/00_setup.R")

# -- 1. Confirmed susceptibility in the gpkg -------------------------------------
# High susceptibility only (CLAUDE.md rule 9): susceptibilidade_unida_medio.gpkg
# (the medium-susceptibility counterpart) is legacy and intentionally not read
# here -- see MIGRATION_PLAN.md Task 1d. NOTE: Task 1d's empirical no-op check
# was argued partly through the CPRM risk union ("no municipality reaches the
# sample via medium susceptibility alone that isn't already captured by CPRM
# risk"). 6f.1 removed that union, so the original argument no longer stands on
# its own terms. Dropping medium remains the decision under rule 9; what lapsed
# is one supporting check, not the decision. Flagged in 6f.1 for re-checking.
risk_proc_dir <- processed_data_path("02_hazard_zones")
gpkg_files <- c("susceptibilidade_unida.gpkg")

cod_gpkg <- lapply(gpkg_files, \(f) {
  fp <- file.path(risk_proc_dir, f)
  if (!file.exists(fp)) { cat("WARNING:", f, "not found\n"); return(NULL) }
  tmp <- st_read(fp, quiet = TRUE)
  col_mun <- intersect(c("COD_MUNICIPIO", "cd_geocmun", "cod_mun"), names(tmp))[1]
  cat(f, ":", nrow(tmp), "geometries,", length(unique(tmp[[col_mun]])), "municipalities\n")
  as.character(tmp[[col_mun]])
}) |> unlist() |> unique()
cod_gpkg <- cod_gpkg[!is.na(cod_gpkg) & nchar(cod_gpkg) == 7]
cat("Municipalities with confirmed susceptibility:", length(cod_gpkg), "\n")

# -- 1b. Filter out spillover municipalities ------------------------------------
# Municipalities that appear in susceptibilidade_unida.gpkg only because a
# neighbor's geometry spilled over its administrative border during the
# script 02 Python overlay.
# Source of truth: data/processed_data/02_hazard_zones/municipios_transbordamento.csv
# (generated automatically when the raw CPRM files are available)
risk_raw_dir     <- raw_data_path("02_hazard_zones")
transbord_csv    <- file.path(risk_proc_dir, "municipios_transbordamento.csv")

# High susceptibility only, matching cod_gpkg's scope above (rule 9) -- the
# medium-susceptibility raw files are excluded here too, since comparing
# cod_gpkg (high-only) against a cod_raw that still includes medium would
# under-count spillover-only municipalities (a high-susceptibility spillover
# artifact could wrongly survive setdiff() just because it also happens to
# have real medium-susceptibility raw data).
raw_files <- c("suscet_massa_br.gpkg", "suscet_inundacao_br.gpkg")
raw_available  <- all(file.exists(file.path(risk_raw_dir, raw_files)))

if (raw_available) {
  cod_raw <- lapply(raw_files, \(f) {
    tmp <- st_read(file.path(risk_raw_dir, f), quiet = TRUE) |> st_drop_geometry()
    col <- intersect(c("COD_MUNICIPIO", "cod_mun"), names(tmp))[1]
    as.character(tmp[[col]])
  }) |> unlist() |> unique()
  cod_raw <- cod_raw[!is.na(cod_raw) & nchar(cod_raw) == 7]

  cod_spillover_only <- setdiff(cod_gpkg, cod_raw)

  # Save for future use (without needing the raw files)
  write_csv(
    data.frame(cod_mun = cod_spillover_only),
    transbord_csv
  )
  cat("Spillover municipalities computed from the raw files and saved to municipios_transbordamento.csv\n")

} else if (file.exists(transbord_csv)) {
  cod_spillover_only <- read_csv(transbord_csv, col_types = "c") |> pull(cod_mun)
  cat("Spillover municipalities read from municipios_transbordamento.csv\n")

} else {
  warning(
    "\n",
    "================================================================================\n",
    "WARNING: municipios_transbordamento.csv not found and the raw CPRM files are\n",
    "missing. The spillover filter will NOT be applied -- neighboring municipalities\n",
    "that received susceptibility via geometric spillover may wrongly enter the sample.\n",
    "To fix: generate municipios_transbordamento.csv by running script 01 with the raw\n",
    "CPRM files available in data/raw_data/02_hazard_zones/, and save the CSV to\n",
    "data/processed_data/02_hazard_zones/.\n",
    "================================================================================\n",
    call. = FALSE
  )
  cod_spillover_only <- character(0)
}

cat("Municipalities removed as spillover-only:", length(cod_spillover_only), "\n")
if (length(cod_spillover_only) > 0)
  cat("Codes:", paste(cod_spillover_only, collapse = ", "), "\n")

cod_gpkg <- setdiff(cod_gpkg, cod_spillover_only)

# -- 2. DUR (population arrangements) and population -----------------------------
# DUR_Municipios.xlsx has a stable download link -- downloaded automatically
# if not already in data/raw_data/03_urban_footprint/.
# Source: IBGE, Divisao Urbano-Regional 2021
dur_path <- file.path(raw_data_dir, "DUR_Municipios.xlsx")
if (!file.exists(dur_path)) {
  cat("Downloading DUR_Municipios.xlsx...\n")
  # On Windows, libcurl uses the Schannel backend, which fails with
  # "CRYPT_E_REVOCATION_OFFLINE" when the certificate revocation server is
  # unreachable (common behind a corporate proxy/firewall) -- browsers don't
  # perform this check the same way. ssl_options = 2L is libcurl's raw flag
  # (CURLSSLOPT_NO_REVOKE) -- used instead of the ssl_no_revoke shortcut
  # because that shortcut only exists in newer versions of the curl package,
  # while ssl_options has been supported for much longer. This only skips
  # the revocation check, not certificate validation.
  curl::curl_download(
    paste0(
      "https://geoftp.ibge.gov.br/organizacao_do_territorio/divisao_regional/",
      "divisao_urbano_regional/2021/base_tabular/DUR_Municipios.xlsx"
    ),
    dur_path,
    handle = curl::new_handle(ssl_options = 2L)
  )
}
DUR <- read_excel(dur_path) |>
  mutate(
    cod_mun    = as.character(COD_MUNICIPIO),
    em_arranjo = NOME_MUNICIPIO != NM_CIDADE  # isolated when names match
  )

# tabela4709.xlsx comes from SIDRA (https://sidra.ibge.gov.br/Tabela/4709), an
# interactive query with no direct download link -- must be placed manually
# in data/raw_data/03_urban_footprint/.
pop_path <- file.path(raw_data_dir, "tabela4709.xlsx")
if (!file.exists(pop_path)) {
  stop(
    "tabela4709.xlsx not found in ", raw_data_dir, ". Download it manually from ",
    "https://sidra.ibge.gov.br/Tabela/4709 (interactive query, no direct link) ",
    "and place the file in that folder before running this script."
  )
}
pop <- read_excel(pop_path, skip = 4, col_names = FALSE)
colnames(pop) <- c("cod_mun", "nome_raw", "pop_2022")
pop <- pop |>
  mutate(cod_mun = as.character(cod_mun), pop_2022 = as.numeric(pop_2022)) |>
  filter(nchar(cod_mun) == 7)

# -- 3. Build the sample -----------------------------------------------------------
# Exposure is susceptibility-only (6f.1): the CPRM union was removed here.
exposed <- cod_gpkg

# Arrangements with >=1 exposed member -> include all members
exposed_arrangements <- DUR |> filter(em_arranjo, cod_mun %in% exposed) |>
  pull(CD_CIDADE) |> unique()

sample_df <- bind_rows(
  # All members of arrangements with >=1 exposed municipality
  DUR |> filter(em_arranjo, CD_CIDADE %in% exposed_arrangements) |>
    select(cod_mun, CD_CIDADE, NM_CIDADE, em_arranjo),
  # Isolated exposed municipalities
  DUR |> filter(!em_arranjo, cod_mun %in% exposed) |>
    select(cod_mun, CD_CIDADE, NM_CIDADE, em_arranjo)
) |>
  distinct(cod_mun, .keep_all = TRUE) |>
  mutate(tem_susceptibilidade = cod_mun %in% cod_gpkg) |>
  left_join(pop |> select(cod_mun, pop_2022), by = "cod_mun")

# -- 4. Drop water-body codes carried in the municipal mesh (6f.1) ------------------
# 4300002 (Lagoa Mirim) and 4300001 (Lagoa dos Patos) are water bodies that
# appear in the IBGE municipal mesh with no name and no population. They are
# removed before the population filter, so they can neither be counted in the
# universe nor contribute to an arrangement's pop_arranjo. Which of the two is
# actually present is reported rather than assumed.
COD_WATER_BODIES <- c("4300001", "4300002")
found_water <- intersect(COD_WATER_BODIES, sample_df$cod_mun)
if (length(found_water) > 0) {
  cat("\nWater-body codes found in the sample and removed:",
      paste(found_water, collapse = ", "), "\n")
  print(sample_df |> filter(cod_mun %in% found_water) |>
          select(cod_mun, CD_CIDADE, NM_CIDADE, em_arranjo, pop_2022))
  sample_df <- sample_df |> filter(!cod_mun %in% COD_WATER_BODIES)
} else {
  cat("\nWater-body codes (", paste(COD_WATER_BODIES, collapse = ", "),
      ") not present in the sample -- nothing removed.\n")
}

# -- 5. Population > 50k filter ------------------------------------------------------
sample_df <- bind_rows(
  sample_df |> filter(!em_arranjo, pop_2022 > 50000),
  sample_df |> filter(em_arranjo) |>
    group_by(CD_CIDADE) |> mutate(pop_arranjo = sum(pop_2022, na.rm = TRUE)) |>
    ungroup() |> filter(pop_arranjo > 50000)
)

# -- 6. Summary -----------------------------------------------------------------------
cat("\n=== FINAL SAMPLE SUMMARY ===\n")
cat("Total municipalities:", nrow(sample_df), "\n")
cat("  With susceptibility:", sum(sample_df$tem_susceptibilidade), "\n")
cat("  No mapping (complete an arrangement):",
    sum(!sample_df$tem_susceptibilidade), "\n")
cat("  In arrangements:", sum(sample_df$em_arranjo),
    "(", n_distinct(sample_df$CD_CIDADE[sample_df$em_arranjo]), "arrangements)\n")
cat("  Isolated:", sum(!sample_df$em_arranjo), "\n")
cat("Total population:", format(sum(sample_df$pop_2022, na.rm = TRUE), big.mark = "."), "\n")

# -- 7. Save ----------------------------------------------------------------------------
saveRDS(sample_df, file.path(processed_data_dir, "amostra_municipios.rds"))
write_csv(sample_df, file.path(processed_data_dir, "amostra_municipios.csv"))
cat("Saved to:", file.path(processed_data_dir, "amostra_municipios.rds/csv"), "\n")
