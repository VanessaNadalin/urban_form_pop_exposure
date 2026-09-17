# =============================================================================
# 05_prepare_gdp.R
# Prepares 2010 GDP per capita and 2000/2010 total population tables from
# IBGE Excel files. Produces cached CSVs that the assembly scripts load
# directly, without re-reading the xlsx files on every run.
#
# Inputs (data/raw_data/04_regression/):
#   pib_munic.xlsx   -- IBGE municipal GDP; col 1 = year, col 4 = cod_mun (7 dig),
#                        col 16 = total GDP, current R$ thousand
#   tabela200.xlsx   -- 2010 Census: col 1 = cod_mun, col 4 = total resident pop
#   tabela202.xlsx   -- 2000 Census: col 1 = cod_mun, col 4 = total resident pop
#
# Outputs (data/processed_data/04_regression/):
#   pib_municipios_2010.csv   -- cod_mun | pib_total_2010 | pop_total_2010 | pib_pc_2010
#   pop_total_2000.csv        -- cod_mun | pop_2000
# =============================================================================

source("04_regression_dataset_and_models/00_setup.R")

cat("\n", strrep("=", 60), "\n")
cat("05_PREPARE_GDP.R\n")
cat(strrep("=", 60), "\n")

pib_path  <- file.path(data_dir, "pib_municipios_2010.csv")
pop0_path <- file.path(data_dir, "pop_total_2000.csv")

# =============================================================================
# 1) MUNICIPAL GDP 2010 + POPULATION 2010
# =============================================================================

cat("\n1) Municipal GDP 2010 (pib_munic.xlsx)...\n")

pib_xlsx <- file.path(raw_data_dir, "pib_munic.xlsx")
if (!file.exists(pib_xlsx))
  stop("pib_munic.xlsx not found at: ", pib_xlsx)

pib_raw <- readxl::read_excel(pib_xlsx, col_names = FALSE, col_types = "text")
cat(sprintf("  pib_munic.xlsx: %d rows x %d columns\n", nrow(pib_raw), ncol(pib_raw)))

pib_2010 <- pib_raw %>%
  filter(grepl("^\\d{7}$", trimws(as.character(...4))),
         trimws(as.character(...1)) == "2010") %>%
  transmute(
    cod_mun        = as.double(trimws(as.character(...4))),
    pib_total_2010 = as.numeric(gsub(",", ".", trimws(as.character(...16))))
  ) %>%
  filter(!is.na(pib_total_2010))

cat(sprintf("  %d municipalities with GDP 2010\n", nrow(pib_2010)))

cat("\n  Total population 2010 (tabela200.xlsx)...\n")

pop200_xlsx <- file.path(raw_data_dir, "tabela200.xlsx")
if (!file.exists(pop200_xlsx))
  stop("tabela200.xlsx not found at: ", pop200_xlsx)

pop_2010 <- readxl::read_excel(pop200_xlsx, skip = 6,
                                col_names = FALSE, col_types = "text") %>%
  transmute(
    cod_mun        = as.double(trimws(as.character(...1))),
    pop_total_2010 = as.numeric(trimws(as.character(...4)))
  ) %>%
  filter(!is.na(cod_mun), cod_mun >= 1000000, !is.na(pop_total_2010))

cat(sprintf("  %d municipalities with pop_total_2010\n", nrow(pop_2010)))

# GDP per capita = total GDP (current R$ thousand) / 2010 Census total population
pib_out <- pib_2010 %>%
  left_join(pop_2010, by = "cod_mun") %>%
  mutate(pib_pc_2010 = ifelse(!is.na(pop_total_2010) & pop_total_2010 > 0,
                               pib_total_2010 / pop_total_2010, NA_real_))

cat(sprintf("  Municipalities with pib_pc_2010: %d\n", sum(!is.na(pib_out$pib_pc_2010))))

write_csv(pib_out, pib_path)
cat(sprintf("  OK %s (%d rows)\n", basename(pib_path), nrow(pib_out)))

# =============================================================================
# 2) TOTAL POPULATION 2000
# =============================================================================

cat("\n2) Total population 2000 (tabela202.xlsx)...\n")

pop202_xlsx <- file.path(raw_data_dir, "tabela202.xlsx")
if (!file.exists(pop202_xlsx))
  stop("tabela202.xlsx not found at: ", pop202_xlsx)

pop_2000 <- readxl::read_excel(pop202_xlsx, skip = 6,
                                col_names = FALSE, col_types = "text") %>%
  transmute(
    cod_mun  = as.double(trimws(as.character(...1))),
    pop_2000 = as.numeric(trimws(as.character(...4)))
  ) %>%
  filter(!is.na(cod_mun), cod_mun >= 1000000, !is.na(pop_2000))

cat(sprintf("  %d municipalities with pop_2000\n", nrow(pop_2000)))

write_csv(pop_2000, pop0_path)
cat(sprintf("  OK %s (%d rows)\n", basename(pop0_path), nrow(pop_2000)))

# =============================================================================
# 3) SUMMARY
# =============================================================================

cat(sprintf("\n%s\nDONE\n%s\n", strrep("=", 60), strrep("=", 60)))
cat("Outputs:\n")
cat(sprintf("  %s\n    columns: cod_mun | pib_total_2010 | pop_total_2010 | pib_pc_2010\n",
            basename(pib_path)))
cat(sprintf("  %s\n    columns: cod_mun | pop_2000\n",
            basename(pop0_path)))
cat("Next step: script 14_independent_variables.R loads these CSVs directly.\n")
