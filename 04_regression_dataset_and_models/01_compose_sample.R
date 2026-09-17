# =============================================================================
# 01_compose_sample.R
# Defines the three selection bases for the regression sample:
#
#   amostra_mun      : municipalities with tem_susceptibilidade == TRUE (~395)
#   mun_isol         : subset of amostra_mun outside any arrangement (~110)
#   amostra_arr      : municipalities that are members of qualified arrangements (~519)
#     qualified arrangement = >= 1 member with susceptibility
#                              AND pop_arranjo > 50,000
#   amostra_universo : amostra_arr + mun_isol -- processing universe for
#                      scripts 02-09 (~629 municipalities)
#
# Inputs:
#   data/processed_data/03_urban_footprint/amostra_municipios.rds
#   data/raw_data/03_urban_footprint/DUR_Municipios.xlsx
#   data/raw_data/03_urban_footprint/tabela4709.xlsx
#
# Outputs (data/processed_data/04_regression/):
#   amostra_mun.csv
#   mun_isol.csv
#   amostra_arr.csv
#   amostra_universo.csv
# =============================================================================

source("04_regression_dataset_and_models/00_setup.R")

cat("\n", strrep("=", 60), "\n")
cat("01_COMPOSE_SAMPLE.R\n")
cat(strrep("=", 60), "\n")

# =============================================================================
# 1) MUNICIPAL SAMPLE
# =============================================================================

cat("\n1) Municipal sample\n")

amostra <- readRDS(amostra_rds)
if (inherits(amostra, "sf")) amostra <- sf::st_drop_geometry(amostra)
amostra <- amostra %>% mutate(cod_mun = as.character(cod_mun))

amostra_mun <- amostra %>% filter(tem_susceptibilidade == TRUE)
mun_isol    <- amostra_mun %>% filter(em_arranjo == FALSE)

cat(sprintf("  amostra_mun : %d municipalities\n",          nrow(amostra_mun)))
cat(sprintf("  mun_isol    : %d isolated municipalities\n", nrow(mun_isol)))

# =============================================================================
# 2) SAMPLE BY POPULATION ARRANGEMENT
# =============================================================================

cat("\n2) Sample by population arrangement\n")

# DUR: full municipality base with arrangement membership
DUR <- read_excel(file.path(stage03_raw_dir, "DUR_Municipios.xlsx")) %>%
  mutate(
    cod_mun    = as.character(COD_MUNICIPIO),
    em_arranjo = NOME_MUNICIPIO != NM_CIDADE
  )

# 2022 population (IBGE table 4709)
pop <- read_excel(file.path(stage03_raw_dir, "tabela4709.xlsx"),
                  skip = 4, col_names = FALSE)
colnames(pop) <- c("cod_mun", "nome_raw", "pop_2022")
pop <- pop %>%
  mutate(cod_mun  = as.character(cod_mun),
         pop_2022 = as.numeric(pop_2022)) %>%
  filter(nchar(cod_mun) == 7)

# Join population and susceptibility onto DUR
DUR <- DUR %>%
  left_join(pop %>% select(cod_mun, pop_2022),                    by = "cod_mun") %>%
  left_join(amostra_mun %>% select(cod_mun, tem_susceptibilidade), by = "cod_mun")

# Qualified arrangements: >= 1 member with susceptibility AND pop_arranjo > 50,000
amostra_arr <- DUR %>%
  filter(em_arranjo == TRUE) %>%
  group_by(CD_CIDADE) %>%
  mutate(pop_arranjo = sum(pop_2022, na.rm = TRUE)) %>%
  # Value test, not a presence test (6f.1). amostra_mun is already filtered to
  # tem_susceptibilidade == TRUE (L41), so the left_join above yields only TRUE
  # or NA and !is.na() happened to give the right answer -- but it tested
  # whether the join matched, not whether the member is mapped. Behaviour is
  # unchanged today; the predicate now says what it means and stays correct if
  # the joined column ever carries FALSE.
  filter(any(tem_susceptibilidade %in% TRUE)) %>%
  ungroup() %>%
  filter(pop_arranjo > 50000)

cat(sprintf("  qualified arrangements       : %d\n", n_distinct(amostra_arr$CD_CIDADE)))
cat(sprintf("  municipalities in amostra_arr: %d\n", nrow(amostra_arr)))
cat(sprintf("  isolated municipalities      : %d\n", nrow(mun_isol)))
cat(sprintf("  TOTAL arrangement entities   : %d\n",
            n_distinct(amostra_arr$CD_CIDADE) + nrow(mun_isol)))

# =============================================================================
# 3) PROCESSING UNIVERSE
# =============================================================================

cat("\n3) Processing universe\n")

amostra_universo <- bind_rows(
  amostra_arr %>%
    mutate(cod_mun   = as.character(cod_mun),
           CD_CIDADE = as.character(CD_CIDADE)) %>%
    select(cod_mun, CD_CIDADE, NM_CIDADE, em_arranjo, tem_susceptibilidade,
           pop_2022, pop_arranjo),
  mun_isol %>%
    mutate(
      cod_mun     = as.character(cod_mun),
      CD_CIDADE   = cod_mun,
      pop_arranjo = coalesce(pop_arranjo, pop_2022)
    ) %>%
    select(cod_mun, CD_CIDADE, NM_CIDADE, em_arranjo, tem_susceptibilidade,
           pop_2022, pop_arranjo)
)

cat(sprintf("  amostra_universo: %d municipalities (%d arrangement + %d isolated)\n",
            nrow(amostra_universo), nrow(amostra_arr), nrow(mun_isol)))

# =============================================================================
# 4) SAVE
# =============================================================================

cat("\n4) Saving\n")

write_csv(amostra_mun,      file.path(data_dir, "amostra_mun.csv"))
write_csv(mun_isol,         file.path(data_dir, "mun_isol.csv"))
write_csv(amostra_arr,      file.path(data_dir, "amostra_arr.csv"))
write_csv(amostra_universo, file.path(data_dir, "amostra_universo.csv"))

cat(sprintf("  - amostra_mun.csv      (%d rows)\n", nrow(amostra_mun)))
cat(sprintf("  - mun_isol.csv         (%d rows)\n", nrow(mun_isol)))
cat(sprintf("  - amostra_arr.csv      (%d rows)\n", nrow(amostra_arr)))
cat(sprintf("  - amostra_universo.csv (%d rows)\n", nrow(amostra_universo)))

cat(sprintf("\n%s\nDONE\n%s\n", strrep("=", 60), strrep("=", 60)))
