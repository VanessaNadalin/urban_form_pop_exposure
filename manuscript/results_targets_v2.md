# results_targets_v2.md — values, provenance, status

**GENERATED FILE. Do not edit by hand.** Produced by `05_exhibits/build_results_targets.R`;
every run overwrites it. Hand edits are lost. To change a value, change the pipeline and re-run.

This file holds values, their provenance and their status. It contains no interpretation.

## Run header

- Generated: **2026-10-06 17:32:57 -03**
- Repository commit: **55c3838** — working tree has uncommitted changes
- Stage-04 reference clock: **2026-10-02 10:10:56** (`data/processed_data/04_regression/model_objects_table2.rds`)
- Staleness tolerance: 3600 seconds
- `MIN_POP_RISCO_2010` (from `00_setup.R`): **200**

### Input manifest

| Input | Path | mtime | Position | State |
|---|---|---|---|---|
| OPTIONAL archived pre-6f ED Table 5 coefficients (supplied by hand, if at all) | `data/processed_data/04_regression/pre_6f_ed_table3_coefficients.csv` | — | exempt | MISSING |
| stage 02 municipal summary, high susceptibility (03_cross_grid_high_susceptibility.py) | `data/processed_data/02_hazard_zones/resumo_municipal_suscept_alta_agsn.csv` | 2026-08-25 22:49:27 | upstream | ok |
| stage 02 municipal summary, CPRM risk (04_cross_grid_cprm_risk.py) | `data/processed_data/02_hazard_zones/resumo_municipal_risco_agsn.csv` | 2026-08-26 01:46:30 | upstream | ok |
| stage 03 sample (01_define_sample.R) | `data/processed_data/03_urban_footprint/amostra_municipios.rds` | 2026-09-22 16:11:16 | upstream | ok |
| stage 03 classified grid (05_classify_growth_types.R) | `data/processed_data/03_urban_footprint/crescimento_urbano/grade_growth_types_2010_2022.parquet` | 2026-09-22 21:13:26 | upstream | ok |
| stage 03 arrangement metrics (07_aggregate_municipality_metrics.R) | `data/processed_data/03_urban_footprint/metricas/metricas_arranjo_2010_2022.csv` | 2026-09-22 22:31:58 | upstream | ok |
| stage 03 municipality metrics (07_aggregate_municipality_metrics.R) | `data/processed_data/03_urban_footprint/metricas/metricas_municipio_2010_2022.csv` | 2026-09-22 22:31:58 | upstream | ok |
| stage 04 qualified-arrangement members (01_compose_sample.R) | `data/processed_data/04_regression/amostra_arr.csv` | 2026-09-23 08:45:45 | upstream | ok |
| stage 04 municipality sample (01_compose_sample.R) | `data/processed_data/04_regression/amostra_mun.csv` | 2026-09-23 08:45:45 | upstream | ok |
| stage 04 processing universe (01_compose_sample.R) | `data/processed_data/04_regression/amostra_universo.csv` | 2026-09-23 08:45:46 | upstream | ok |
| stage 04 arrangement regression dataset (15_final_dataset.R) | `data/processed_data/04_regression/tables/dataset_regressao_arranjo.csv` | 2026-10-01 17:35:36 | upstream | ok |
| stage 04 municipality regression dataset (15_final_dataset.R) | `data/processed_data/04_regression/tables/dataset_regressao_municipio.csv` | 2026-10-01 17:35:36 | upstream | ok |
| stage 04 fitted models + metadata (16_estimate_models.R) | `data/processed_data/04_regression/model_objects_table2.rds` | 2026-10-02 10:10:56 | upstream | ok |
| stage 04 isolated municipalities (01_compose_sample.R) | `data/processed_data/04_regression/mun_isol.csv` | 2026-09-23 08:45:45 | upstream | ok |
| ED Table 2 descriptives, arrangement level (ed_table_descriptive_statistics.R) | `output/ed_table2_descriptives_arrangement.csv` | 2026-10-06 17:25:16 | downstream | ok |
| ED Table 2 descriptives, municipality level (ed_table_descriptive_statistics.R) | `output/ed_table2_descriptives_municipality.csv` | 2026-10-06 17:25:16 | downstream | ok |
| ED Figure standardized betas (ed_figure_standardized_coefficients.R) | `output/ed_figure_standardized_coefficients.csv` | 2026-10-06 17:25:14 | downstream | ok |
| Figure 1 layers (figure1_growth_type_layers.R) | `data/processed_data/03_urban_footprint/figuras/figura1_camadas.parquet` | 2026-10-06 17:22:37 | downstream | ok |
| Figure 2 statistics, variant '(a) the figure' and the §11 variants (figure2_exposure_scatter.R) | `output/figure2_statistics.csv` | 2026-10-06 17:24:49 | downstream | ok |
| Table 1a (table1_population_by_growth_type.R) | `output/tabela1a_populacao_totais_tipo.csv` | 2026-10-06 17:21:13 | downstream | ok |
| Table 1b (table1_population_by_growth_type.R) | `output/tabela1_populacao_risco_tipo.csv` | 2026-10-06 17:21:14 | downstream | ok |

**Entries: 464 total, 460 VERIFIED, 4 PENDING.**

### Consistency manifest

Model-building constants copied from `16_estimate_models.R`; diff this block against that source.

```
MIN_POP_RISCO_2010 : 200
trat_compact       : pct_area_densif_infill_0010
trat_periph        : pct_area_periph_ext_leap_0010
CTRL_ALTA (15)      : topo_prop_inclinado, pp_alta_2010, pct_nao_constru_fora_alta_2010_q1, pct_nao_constru_fora_alta_2010_q4_f, no_q4_cells_2010, palma_rent, palma_commute, median_rent, log_pib_pc, log_pop_total_2000, log_area_2000_km2, zero_area_2000, prop_favelas_2010, regiao, urban_class
MEDIATORS_HM (7)   : median_rent, palma_rent, palma_commute, pct_nao_constru_fora_alta_2010_q1, pct_nao_constru_fora_alta_2010_q4_f, no_q4_cells_2010, prop_favelas_2010
CTRL_ALTA_NO_MED (8): topo_prop_inclinado, pp_alta_2010, log_pib_pc, log_pop_total_2000, log_area_2000_km2, zero_area_2000, regiao, urban_class
vcov: municipalities = vcovCL(cluster = attr(mod, 'cluster_vec')); arrangements = vcovHC(HC3)
```


## Sample funnel

| Item | Value | Status | Source (file, mtime) | results_used.md (July) | Changed by | Note |
|---|---|---|---|---|---|---|
| Processing universe (municipalities) | 629 | VERIFIED | `data/processed_data/04_regression/amostra_universo.csv` (2026-09-23 08:45:46) | — | 6f.1 (CPRM union removed from stage 03's sample definition) |  |
| amostra_mun (tem_susceptibilidade == TRUE) | 395 | VERIFIED | `data/processed_data/04_regression/amostra_mun.csv` (2026-09-23 08:45:45) | — | — | `01_compose_sample.R:41` |
| Isolated municipalities | 110 | VERIFIED | `data/processed_data/04_regression/mun_isol.csv` (2026-09-23 08:45:45) | — | — | `01_compose_sample.R:42` |
| Qualified arrangements (CD_CIDADE) | 100 | VERIFIED | `data/processed_data/04_regression/amostra_arr.csv` (2026-09-23 08:45:45) | — | — | `01_compose_sample.R:75–87` |
| Members of qualified arrangements | 519 | VERIFIED | `data/processed_data/04_regression/amostra_arr.csv` (2026-09-23 08:45:45) | — | — |  |
| FUA entities (arrangements + isolated) | 210 | VERIFIED | `data/processed_data/04_regression/amostra_arr.csv` (2026-09-23 08:45:45) + `data/processed_data/04_regression/mun_isol.csv` (2026-09-23 08:45:45) | 206 (results_used.md L11) | 6b0, 6f.1 — `01_compose_sample.R:92–93` counts `n_distinct(CD_CIDADE) + nrow(mun_isol)` | counting `amostra_arr.csv` alone omits the isolated FUAs |
| dataset_regressao_municipio.csv rows | 395 | VERIFIED | `data/processed_data/04_regression/tables/dataset_regressao_municipio.csv` (2026-10-01 17:35:36) | 387 (results_used.md L11) | 6b0 — under the common grid every row has a valid `delta_pp_alta` |  |
| dataset_regressao_arranjo.csv rows | 210 | VERIFIED | `data/processed_data/04_regression/tables/dataset_regressao_arranjo.csv` (2026-10-01 17:35:36) | — | — |  |
| After pop_2010_risk_total > MIN_POP_RISCO_2010 (municipalities) | 350 | VERIFIED | `data/processed_data/04_regression/tables/dataset_regressao_municipio.csv` (2026-10-01 17:35:36) | — | 6c1 revised 2026-09-12; cut = 200 |  |
| After pop_2010_risk_total > MIN_POP_RISCO_2010 (arrangements) | 183 | VERIFIED | `data/processed_data/04_regression/tables/dataset_regressao_arranjo.csv` (2026-10-01 17:35:36) | — | 6c1 revised 2026-09-12; cut = 200 |  |
| MIN_POP_RISCO_2010 applied at estimation | 200 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | no cut (results_used.md states none) | 6c1, decided 2026-09-08 at 1000, revised 2026-09-12 to 200 |  |
| Municipalities before the cut (metadata) | 395 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| Municipalities after the cut (metadata) | 350 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| Centro-Oeste municipalities dropped (region columns) | 7 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | 6c2, decided 2026-09-10 |  |
| Estimation timestamp (metadata) | 2026-10-02 10:10:54 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |

## Table 1 — population and exposure by growth type

| Item | Value | Status | Source (file, mtime) | results_used.md (July) | Changed by | Note |
|---|---|---|---|---|---|---|
| Consolidated — pop_2010 | 59,398,950 | VERIFIED | `output/tabela1a_populacao_totais_tipo.csv` (2026-10-06 17:21:13) | 59,138,249 | 6b0 (common grid), 6e (exposure weighting), 6f.1/6f.2 |  |
| Consolidated — pop_2022 | 55,188,718 | VERIFIED | `output/tabela1a_populacao_totais_tipo.csv` (2026-10-06 17:21:13) | 55,634,711 | 6b0, 6e, 6f.1/6f.2 |  |
| Consolidated — risco_2010 | 7,021,298 | VERIFIED | `output/tabela1a_populacao_totais_tipo.csv` (2026-10-06 17:21:13) | 15,627,912 | 6e (area weighting replaces any-overlap) |  |
| Consolidated — risco_2022 | 6,505,323 | VERIFIED | `output/tabela1a_populacao_totais_tipo.csv` (2026-10-06 17:21:13) | 14,632,292 | 6e |  |
| Consolidated — % at risk 2010 | 11.8% | VERIFIED | `output/tabela1a_populacao_totais_tipo.csv` (2026-10-06 17:21:13) | 26.4% | 6e |  |
| Consolidated — % at risk 2022 | 11.8% | VERIFIED | `output/tabela1a_populacao_totais_tipo.csv` (2026-10-06 17:21:13) | 26.3% | 6e |  |
| Consolidated — change in risk pop. | -515,975 | VERIFIED | `output/tabela1a_populacao_totais_tipo.csv` (2026-10-06 17:21:13) | -995,620 (derived from its components) | 6e |  |
| Compact — pop_2010 | 27,215,535 | VERIFIED | `output/tabela1a_populacao_totais_tipo.csv` (2026-10-06 17:21:13) | 27,367,825 | 6b0 (common grid), 6e (exposure weighting), 6f.1/6f.2 |  |
| Compact — pop_2022 | 33,529,176 | VERIFIED | `output/tabela1a_populacao_totais_tipo.csv` (2026-10-06 17:21:13) | 36,107,824 | 6b0, 6e, 6f.1/6f.2 |  |
| Compact — risco_2010 | 3,515,050 | VERIFIED | `output/tabela1a_populacao_totais_tipo.csv` (2026-10-06 17:21:13) | 8,625,881 | 6e (area weighting replaces any-overlap) |  |
| Compact — risco_2022 | 4,313,988 | VERIFIED | `output/tabela1a_populacao_totais_tipo.csv` (2026-10-06 17:21:13) | 10,779,228 | 6e |  |
| Compact — % at risk 2010 | 12.9% | VERIFIED | `output/tabela1a_populacao_totais_tipo.csv` (2026-10-06 17:21:13) | 31.5% | 6e |  |
| Compact — % at risk 2022 | 12.9% | VERIFIED | `output/tabela1a_populacao_totais_tipo.csv` (2026-10-06 17:21:13) | 29.9% | 6e |  |
| Compact — change in risk pop. | 798,937 | VERIFIED | `output/tabela1a_populacao_totais_tipo.csv` (2026-10-06 17:21:13) | 2,153,347 | 6e |  |
| Sprawl — pop_2010 | 3,004,720 | VERIFIED | `output/tabela1a_populacao_totais_tipo.csv` (2026-10-06 17:21:13) | 2,900,879 | 6b0 (common grid), 6e (exposure weighting), 6f.1/6f.2 |  |
| Sprawl — pop_2022 | 9,135,551 | VERIFIED | `output/tabela1a_populacao_totais_tipo.csv` (2026-10-06 17:21:13) | 6,104,483 | 6b0, 6e, 6f.1/6f.2 |  |
| Sprawl — risco_2010 | 405,420 | VERIFIED | `output/tabela1a_populacao_totais_tipo.csv` (2026-10-06 17:21:13) | 988,462 | 6e (area weighting replaces any-overlap) |  |
| Sprawl — risco_2022 | 1,066,865 | VERIFIED | `output/tabela1a_populacao_totais_tipo.csv` (2026-10-06 17:21:13) | 1,908,404 | 6e |  |
| Sprawl — % at risk 2010 | 13.5% | VERIFIED | `output/tabela1a_populacao_totais_tipo.csv` (2026-10-06 17:21:13) | 34.1% | 6e |  |
| Sprawl — % at risk 2022 | 11.7% | VERIFIED | `output/tabela1a_populacao_totais_tipo.csv` (2026-10-06 17:21:13) | 31.3% | 6e |  |
| Sprawl — change in risk pop. | 661,445 | VERIFIED | `output/tabela1a_populacao_totais_tipo.csv` (2026-10-06 17:21:13) | 919,942 | 6e |  |
| Total — pop_2010 | 89,619,205 | VERIFIED | `output/tabela1a_populacao_totais_tipo.csv` (2026-10-06 17:21:13) | 89,406,953 | 6b0 (common grid), 6e (exposure weighting), 6f.1/6f.2 |  |
| Total — pop_2022 | 97,853,445 | VERIFIED | `output/tabela1a_populacao_totais_tipo.csv` (2026-10-06 17:21:13) | 97,847,018 | 6b0, 6e, 6f.1/6f.2 |  |
| Total — risco_2010 | 10,941,768 | VERIFIED | `output/tabela1a_populacao_totais_tipo.csv` (2026-10-06 17:21:13) | 25,242,255 | 6e (area weighting replaces any-overlap) |  |
| Total — risco_2022 | 11,886,175 | VERIFIED | `output/tabela1a_populacao_totais_tipo.csv` (2026-10-06 17:21:13) | 27,319,924 | 6e |  |
| Total — % at risk 2010 | 12.2% | VERIFIED | `output/tabela1a_populacao_totais_tipo.csv` (2026-10-06 17:21:13) | 28.2% (derived from its components) | 6e |  |
| Total — % at risk 2022 | 12.1% | VERIFIED | `output/tabela1a_populacao_totais_tipo.csv` (2026-10-06 17:21:13) | 27.9% (derived from its components) | 6e |  |
| Total — change in risk pop. | 944,407 | VERIFIED | `output/tabela1a_populacao_totais_tipo.csv` (2026-10-06 17:21:13) | 2,077,669 (derived from its components) | 6e |  |
| Compact — % of new residents going to risk | 12.7% | VERIFIED | `output/tabela1a_populacao_totais_tipo.csv` (2026-10-06 17:21:13) | 25% | 6b0, 6e | derived from the Table 1a CSV, same arithmetic as `table1_population_by_growth_type.R` |
| Sprawl — % of new residents going to risk | 10.8% | VERIFIED | `output/tabela1a_populacao_totais_tipo.csv` (2026-10-06 17:21:13) | 29% | 6b0, 6e | derived from the Table 1a CSV |
| Compact share of the net increase in at-risk pop. (Compact+Sprawl) | 54.7% | VERIFIED | `output/tabela1a_populacao_totais_tipo.csv` (2026-10-06 17:21:13) | 70% (2.2M of 3.1M) | 6b0, 6e | derived from the Table 1a CSV |
| Aggregate growth — total population | 9.2% | VERIFIED | `output/tabela1a_populacao_totais_tipo.csv` (2026-10-06 17:21:13) | +9.4% | 6b0 | derived from the Table 1a CSV |
| Aggregate growth — population at risk | 8.6% | VERIFIED | `output/tabela1a_populacao_totais_tipo.csv` (2026-10-06 17:21:13) | +8.2% | 6e | derived from the Table 1a CSV |
| Consolidated — change in high susceptibility (M) | -0.516 | VERIFIED | `output/tabela1_populacao_risco_tipo.csv` (2026-10-06 17:21:14) | -1.000 | 6b0, 6e |  |
| Consolidated — change outside high susceptibility (M) | -3.694 | VERIFIED | `output/tabela1_populacao_risco_tipo.csv` (2026-10-06 17:21:14) | -2.510 | 6b0, 6e |  |
| Consolidated — total change (M) | -4.210 | VERIFIED | `output/tabela1_populacao_risco_tipo.csv` (2026-10-06 17:21:14) | — | 6b0 |  |
| Compact — change in high susceptibility (M) | 0.799 | VERIFIED | `output/tabela1_populacao_risco_tipo.csv` (2026-10-06 17:21:14) | 2.150 | 6b0, 6e |  |
| Compact — change outside high susceptibility (M) | 5.515 | VERIFIED | `output/tabela1_populacao_risco_tipo.csv` (2026-10-06 17:21:14) | 6.590 | 6b0, 6e |  |
| Compact — total change (M) | 6.314 | VERIFIED | `output/tabela1_populacao_risco_tipo.csv` (2026-10-06 17:21:14) | — | 6b0 |  |
| Sprawl — change in high susceptibility (M) | 0.661 | VERIFIED | `output/tabela1_populacao_risco_tipo.csv` (2026-10-06 17:21:14) | 0.920 | 6b0, 6e |  |
| Sprawl — change outside high susceptibility (M) | 5.469 | VERIFIED | `output/tabela1_populacao_risco_tipo.csv` (2026-10-06 17:21:14) | 2.280 | 6b0, 6e |  |
| Sprawl — total change (M) | 6.131 | VERIFIED | `output/tabela1_populacao_risco_tipo.csv` (2026-10-06 17:21:14) | — | 6b0 |  |

## Figure 1 — growth-type layers

| Item | Value | Status | Source (file, mtime) | results_used.md (July) | Changed by | Note |
|---|---|---|---|---|---|---|
| Total cells | 3,092,892 | VERIFIED | `data/processed_data/03_urban_footprint/figuras/figura1_camadas.parquet` (2026-10-06 17:22:37) | — | — | recomputed here, not read from an exhibit output; mirrors `figure1_growth_type_layers.R` §2; source layer `data/processed_data/03_urban_footprint/figuras/figura1_camadas.parquet` |
| grupo_3tipos — consolidated | 180,611 | VERIFIED | `data/processed_data/03_urban_footprint/figuras/figura1_camadas.parquet` (2026-10-06 17:22:37) | — | — | recomputed here, not read from an exhibit output; mirrors `figure1_growth_type_layers.R` §2; source layer `data/processed_data/03_urban_footprint/figuras/figura1_camadas.parquet` |
| grupo_3tipos — compact | 154,183 | VERIFIED | `data/processed_data/03_urban_footprint/figuras/figura1_camadas.parquet` (2026-10-06 17:22:37) | — | — | recomputed here, not read from an exhibit output; mirrors `figure1_growth_type_layers.R` §2; source layer `data/processed_data/03_urban_footprint/figuras/figura1_camadas.parquet` |
| grupo_3tipos — sprawl | 91,736 | VERIFIED | `data/processed_data/03_urban_footprint/figuras/figura1_camadas.parquet` (2026-10-06 17:22:37) | — | — | recomputed here, not read from an exhibit output; mirrors `figure1_growth_type_layers.R` §2; source layer `data/processed_data/03_urban_footprint/figuras/figura1_camadas.parquet` |
| grupo_3tipos — NA | 2,666,362 | VERIFIED | `data/processed_data/03_urban_footprint/figuras/figura1_camadas.parquet` (2026-10-06 17:22:37) | — | — | recomputed here, not read from an exhibit output; mirrors `figure1_growth_type_layers.R` §2; source layer `data/processed_data/03_urban_footprint/figuras/figura1_camadas.parquet` |
| urban 2010 TRUE / 2020 TRUE | 361,396 | VERIFIED | `data/processed_data/03_urban_footprint/figuras/figura1_camadas.parquet` (2026-10-06 17:22:37) | — | — | recomputed here, not read from an exhibit output; mirrors `figure1_growth_type_layers.R` §2; source layer `data/processed_data/03_urban_footprint/figuras/figura1_camadas.parquet` |
| urban 2010 TRUE / 2020 FALSE | 10,505 | VERIFIED | `data/processed_data/03_urban_footprint/figuras/figura1_camadas.parquet` (2026-10-06 17:22:37) | — | — | recomputed here, not read from an exhibit output; mirrors `figure1_growth_type_layers.R` §2; source layer `data/processed_data/03_urban_footprint/figuras/figura1_camadas.parquet` |
| urban 2010 FALSE / 2020 TRUE | 55,527 | VERIFIED | `data/processed_data/03_urban_footprint/figuras/figura1_camadas.parquet` (2026-10-06 17:22:37) | — | — | recomputed here, not read from an exhibit output; mirrors `figure1_growth_type_layers.R` §2; source layer `data/processed_data/03_urban_footprint/figuras/figura1_camadas.parquet` |
| urban 2010 FALSE / 2020 FALSE | 2,665,464 | VERIFIED | `data/processed_data/03_urban_footprint/figuras/figura1_camadas.parquet` (2026-10-06 17:22:37) | — | — | recomputed here, not read from an exhibit output; mirrors `figure1_growth_type_layers.R` §2; source layer `data/processed_data/03_urban_footprint/figuras/figura1_camadas.parquet` |
| Derived-vs-real disagreement — urbano_2010 | 983 | VERIFIED | `data/processed_data/03_urban_footprint/figuras/figura1_camadas.parquet` (2026-10-06 17:22:37) | — | — | recomputed here, not read from an exhibit output; mirrors `figure1_growth_type_layers.R` §2; source layer `data/processed_data/03_urban_footprint/figuras/figura1_camadas.parquet` ; derived = tipo_crescimento in {consolidated, densification, peripheral} |
| Derived-vs-real disagreement — urbano_2020 | 11,307 | VERIFIED | `data/processed_data/03_urban_footprint/figuras/figura1_camadas.parquet` (2026-10-06 17:22:37) | — | — | recomputed here, not read from an exhibit output; mirrors `figure1_growth_type_layers.R` §2; source layer `data/processed_data/03_urban_footprint/figuras/figura1_camadas.parquet` ; derived = !is.na(tipo_crescimento) |
| Municipalities flagged em_amostra_regressao | 395 | VERIFIED | `data/processed_data/03_urban_footprint/figuras/figura1_camadas.parquet` (2026-10-06 17:22:37) | — | — | recomputed here, not read from an exhibit output; mirrors `figure1_growth_type_layers.R` §2; source layer `data/processed_data/03_urban_footprint/figuras/figura1_camadas.parquet` |

## Figure 2 — exposure scatter

| Item | Value | Status | Source (file, mtime) | results_used.md (July) | Changed by | Note |
|---|---|---|---|---|---|---|
| Sample rule | no pop_2010_risk_total cut; growth >= 200 in both types | VERIFIED | `output/figure2_statistics.csv` (2026-10-06 17:24:49) | — | decided 2026-09-21 (f8def75), reverses 6c2 | variant '(a) the figure' of the exhibit's own CSV; unclipped ratios |
| Metrics municipalities (before any filter) | 629 | VERIFIED | `output/figure2_statistics.csv` (2026-10-06 17:24:49) | — | — | variant '(a) the figure' of the exhibit's own CSV; unclipped ratios |
| Regression-dataset municipalities with metrics | 395 | VERIFIED | `output/figure2_statistics.csv` (2026-10-06 17:24:49) | — | — | variant '(a) the figure' of the exhibit's own CSV; unclipped ratios |
| Final N (growth threshold met in both types) | 338 | VERIFIED | `output/figure2_statistics.csv` (2026-10-06 17:24:49) | 341 (results_used.md L50, '43% of 341 cities') | 6b0, 6e, sample rule of 2026-09-21 | variant '(a) the figure' of the exhibit's own CSV; unclipped ratios |
| Dropped by the growth threshold | 57 | VERIFIED | `output/figure2_statistics.csv` (2026-10-06 17:24:49) | — | — | variant '(a) the figure' of the exhibit's own CSV; unclipped ratios |
| Dropped — compact only / sprawl only / both | 54 / 2 / 1 | VERIFIED | `output/figure2_statistics.csv` (2026-10-06 17:24:49) | — | — | variant '(a) the figure' of the exhibit's own CSV; unclipped ratios ; requiring growth in both types excludes municipalities that grew almost entirely one way |
| Ratios < 0 / > 1 — compact | 59 / 1 | VERIFIED | `output/figure2_statistics.csv` (2026-10-06 17:24:49) | — | — | variant '(a) the figure' of the exhibit's own CSV; unclipped ratios; out of 338 pairs; kept in every statistic |
| Ratios < 0 / > 1 — sprawl | 4 / 1 | VERIFIED | `output/figure2_statistics.csv` (2026-10-06 17:24:49) | — | — | variant '(a) the figure' of the exhibit's own CSV; unclipped ratios; out of 338 pairs; kept in every statistic |
| Both ratios < 0 | 2 | VERIFIED | `output/figure2_statistics.csv` (2026-10-06 17:24:49) | — | — | variant '(a) the figure' of the exhibit's own CSV; unclipped ratios; out of 338 pairs; kept in every statistic |
| Above the 45° line (sprawl > compact) | 200 (59.2%) | VERIFIED | `output/figure2_statistics.csv` (2026-10-06 17:24:49) | — | — | variant '(a) the figure' of the exhibit's own CSV; unclipped ratios ; tie = \|compact - sprawl\| < 1e-09 ; shares are of all pairs |
| Share below 45° line (compact > sprawl) | 131 (38.8%) | VERIFIED | `output/figure2_statistics.csv` (2026-10-06 17:24:49) | 43% | 6b0, 6e, sample rule of 2026-09-21 | variant '(a) the figure' of the exhibit's own CSV; unclipped ratios ; tie = \|compact - sprawl\| < 1e-09 ; shares are of all pairs |
| On the 45° line (ties) | 7 (2.1%); both ratios zero: 7 | VERIFIED | `output/figure2_statistics.csv` (2026-10-06 17:24:49) | — | — | variant '(a) the figure' of the exhibit's own CSV; unclipped ratios ; tie = \|compact - sprawl\| < 1e-09 ; shares are of all pairs |
| Median pct_risk_compact | 4.2% | VERIFIED | `output/figure2_statistics.csv` (2026-10-06 17:24:49) | 18.2% | 6b0, 6e, sample rule of 2026-09-21 | variant '(a) the figure' of the exhibit's own CSV; unclipped ratios |
| Median pct_risk_sprawl | 6.6% | VERIFIED | `output/figure2_statistics.csv` (2026-10-06 17:24:49) | 20.9% | 6b0, 6e, sample rule of 2026-09-21 | variant '(a) the figure' of the exhibit's own CSV; unclipped ratios |
| Median difference (compact − sprawl) | -0.006 | VERIFIED | `output/figure2_statistics.csv` (2026-10-06 17:24:49) | — | — | variant '(a) the figure' of the exhibit's own CSV; unclipped ratios ; positive = below the 45° line |
| Interquartile range of the difference | [-0.063, 0.028] | VERIFIED | `output/figure2_statistics.csv` (2026-10-06 17:24:49) | — | — | variant '(a) the figure' of the exhibit's own CSV; unclipped ratios ; compact − sprawl, quantile type 7 |
| Wilcoxon signed-rank p | 0.0049 | VERIFIED | `output/figure2_statistics.csv` (2026-10-06 17:24:49) | — | — | variant '(a) the figure' of the exhibit's own CSV; unclipped ratios ; paired, two-sided, normal approximation with continuity correction |
| Wilcoxon V and pairs used | V = 22572.0; 331 pairs | VERIFIED | `output/figure2_statistics.csv` (2026-10-06 17:24:49) | — | — | variant '(a) the figure' of the exhibit's own CSV; unclipped ratios ; V = rank sum of positive (compact − sprawl) differences; exactly-zero differences dropped |
| Spearman correlation | 0.677 (p = 0.0000) | VERIFIED | `output/figure2_statistics.csv` (2026-10-06 17:24:49) | — | — | variant '(a) the figure' of the exhibit's own CSV; unclipped ratios ; p by asymptotic t approximation (ties present, no exact p) |
| Pearson correlation | 0.693 (p = 0.0000) | VERIFIED | `output/figure2_statistics.csv` (2026-10-06 17:24:49) | — | — | variant '(a) the figure' of the exhibit's own CSV; unclipped ratios |
| OLS slope (the plotted line) | 0.530 (SE 0.030) | VERIFIED | `output/figure2_statistics.csv` (2026-10-06 17:24:49) | slope < 45° with positive intercept (no value stated) | 6b0, 6e, sample rule of 2026-09-21; unclipped since 2026-09-25 | variant '(a) the figure' of the exhibit's own CSV; unclipped ratios |
| OLS intercept | 0.074 | VERIFIED | `output/figure2_statistics.csv` (2026-10-06 17:24:49) | — | — | variant '(a) the figure' of the exhibit's own CSV; unclipped ratios |
| OLS R² | 0.481 | VERIFIED | `output/figure2_statistics.csv` (2026-10-06 17:24:49) | — | — | variant '(a) the figure' of the exhibit's own CSV; unclipped ratios |
| OLS p for H0: slope = 1 | 0.0000 | VERIFIED | `output/figure2_statistics.csv` (2026-10-06 17:24:49) | — | — | variant '(a) the figure' of the exhibit's own CSV; unclipped ratios |
| OLS crossing with the 45° line (compact ratio) | 0.157 (15.7%) | VERIFIED | `output/figure2_statistics.csv` (2026-10-06 17:24:49) | — | — | variant '(a) the figure' of the exhibit's own CSV; unclipped ratios ; intercept / (1 − slope) |
| Municipalities with compact ratio above the crossing point | 91 | VERIFIED | `output/figure2_statistics.csv` (2026-10-06 17:24:49) | — | — | variant '(a) the figure' of the exhibit's own CSV; unclipped ratios |

## Figure 2 — sample-definition variants

| Item | Value | Status | Source (file, mtime) | results_used.md (July) | Changed by | Note |
|---|---|---|---|---|---|---|
| (a) the figure | N = 338; above / below / ties = 200 / 131 / 7; median diff (compact − sprawl) = -0.006; Wilcoxon p = 0.0049; Spearman rho = 0.677 | VERIFIED | `output/figure2_statistics.csv` (2026-10-06 17:24:49) | — | — | no pop_2010_risk_total cut; growth >= 200 in both types ; unclipped ratios  |
| (b) G = 1 | N = 343; above / below / ties = 201 / 134 / 8; median diff (compact − sprawl) = -0.004; Wilcoxon p = 0.0110; Spearman rho = 0.663 | VERIFIED | `output/figure2_statistics.csv` (2026-10-06 17:24:49) | — | — | no pop_2010_risk_total cut; growth >= 1 in both types ; unclipped ratios  |
| (b) G = 100 | N = 340; above / below / ties = 201 / 131 / 8; median diff (compact − sprawl) = -0.005; Wilcoxon p = 0.0047; Spearman rho = 0.678 | VERIFIED | `output/figure2_statistics.csv` (2026-10-06 17:24:49) | — | — | no pop_2010_risk_total cut; growth >= 100 in both types ; unclipped ratios  |
| (b) G = 200 | N = 338; above / below / ties = 200 / 131 / 7; median diff (compact − sprawl) = -0.006; Wilcoxon p = 0.0049; Spearman rho = 0.677 | VERIFIED | `output/figure2_statistics.csv` (2026-10-06 17:24:49) | — | — | no pop_2010_risk_total cut; growth >= 200 in both types ; unclipped ratios  |
| (b) G = 500 | N = 324; above / below / ties = 193 / 125 / 6; median diff (compact − sprawl) = -0.006; Wilcoxon p = 0.0063; Spearman rho = 0.694 | VERIFIED | `output/figure2_statistics.csv` (2026-10-06 17:24:49) | — | — | no pop_2010_risk_total cut; growth >= 500 in both types ; unclipped ratios  |
| (b) G = 1000 | N = 302; above / below / ties = 173 / 124 / 5; median diff (compact − sprawl) = -0.004; Wilcoxon p = 0.0803; Spearman rho = 0.735 | VERIFIED | `output/figure2_statistics.csv` (2026-10-06 17:24:49) | — | — | no pop_2010_risk_total cut; growth >= 1000 in both types ; unclipped ratios  |
| (c) baseline cut + G = 200 | N = 303; above / below / ties = 179 / 124 / 0; median diff (compact − sprawl) = -0.010; Wilcoxon p = 0.0124; Spearman rho = 0.666 | VERIFIED | `output/figure2_statistics.csv` (2026-10-06 17:24:49) | — | — | pop_2010_risk_total > 200; growth >= 200 in both types ; unclipped ratios  |
| retired rule | N = 305; above / below / ties = 179 / 126 / 0; median diff (compact − sprawl) = -0.010; Wilcoxon p = 0.0205; Spearman rho = 0.664 | VERIFIED | `output/figure2_statistics.csv` (2026-10-06 17:24:49) | — | — | pop_2010_risk_total > 200, then growth > 0 in both types (until 2026-09-21) ; unclipped ratios  |

## Table 2 — main regressions (municipalities)

| Item | Value | Status | Source (file, mtime) | results_used.md (July) | Changed by | Note |
|---|---|---|---|---|---|---|
| (1) g_high — Compact — treatment coefficient | 0.0600 (SE 0.1405) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | −0.026 n.s. | 6b0 (common grid), 6e (exposure weighting), 6c1 (sample cut) | term `pct_area_densif_infill_0010` |
| (1) g_high — Compact — N | 327 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (1) g_high — Compact — R² | 0.412 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (2) g_high — Sprawl — treatment coefficient | 0.2113 (SE 0.1293) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | +0.103** | 6b0 (common grid), 6e (exposure weighting), 6c1 (sample cut) | term `pct_area_periph_ext_leap_0010` |
| (2) g_high — Sprawl — N | 327 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (2) g_high — Sprawl — R² | 0.417 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (3) Dpp_high — Compact — treatment coefficient | 0.0139* (SE 0.0078) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | +0.040*** | 6b0 (common grid), 6e (exposure weighting), 6c1 (sample cut) | term `pct_area_densif_infill_0010` |
| (3) Dpp_high — Compact — N | 327 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (3) Dpp_high — Compact — R² | 0.264 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (4) Dpp_high — Sprawl — treatment coefficient | 0.0224** (SE 0.0092) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | −0.021* | 6b0 (common grid), 6e (exposure weighting), 6c1 (sample cut) | term `pct_area_periph_ext_leap_0010` |
| (4) Dpp_high — Sprawl — N | 327 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (4) Dpp_high — Sprawl — R² | 0.273 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| Comparability note | not comparable to N = 317 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — | 317 was produced under the any-overlap rule with a cut of 1000, both superseded. 6e lowered pop_2010_risk_total; the cut moved to 200. The two differences pull in opposite directions and do not cancel (MIGRATION_PLAN.md, 'On Table 2's N'). |
| Listwise deletion rule | complete.cases over ALL formula variables | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | list-wise deletion on safe available land and steep terrain (results_used.md L11) | none — the code never did what results_used.md describes | `16_estimate_models.R:297–298`, applied per specification and AFTER the MIN_POP_RISCO_2010 cut (`:205–207`). This is why N varies by specification; results_used.md's Table 2 note names a narrower set than the code uses. |

## Table 2 — all other coefficients, columns (1)-(4)

| Item | Value | Status | Source (file, mtime) | results_used.md (July) | Changed by | Note |
|---|---|---|---|---|---|---|
| (1) g_high — Compact — `(Intercept)` | 2.9398 (SE 54.8985) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (1) g_high — Compact — `topo_prop_inclinado` | -0.1066 (SE 8.4280) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (1) g_high — Compact — `pp_alta_2010` | -0.6784** (SE 0.2632) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (1) g_high — Compact — `pct_nao_constru_fora_alta_2010_q1` | -0.8168*** (SE 0.2819) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (1) g_high — Compact — `pct_nao_constru_fora_alta_2010_q4_f` | -0.1693 (SE 0.2043) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (1) g_high — Compact — `no_q4_cells_2010` | 2.5843 (SE 15.7083) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (1) g_high — Compact — `palma_rent` | 4.9510* (SE 2.8731) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (1) g_high — Compact — `palma_commute` | 19.4265** (SE 9.3511) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (1) g_high — Compact — `median_rent` | 0.0229 (SE 0.0294) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (1) g_high — Compact — `log_pib_pc` | -2.9077 (SE 3.1594) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (1) g_high — Compact — `log_pop_total_2000` | 3.9287 (SE 3.8164) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (1) g_high — Compact — `log_area_2000_km2` | -5.8827* (SE 3.4311) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (1) g_high — Compact — `zero_area_2000` | -51.1115** (SE 25.2004) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (1) g_high — Compact — `prop_favelas_2010` | 13.1682 (SE 17.7250) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (1) g_high — Compact — `regiaoSul` | 15.0177** (SE 5.9002) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (1) g_high — Compact — `regiaoNordeste` | 0.7643 (SE 6.3635) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (1) g_high — Compact — `regiaoNorte` | 7.3089 (SE 9.8815) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (1) g_high — Compact — `regiaoCentro-Oeste` | 8.0262 (SE 10.4576) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (1) g_high — Compact — `urban_classMetropolises` | 4.4057 (SE 7.1223) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (1) g_high — Compact — `urban_classMetropolis Suburbs` | 6.1137 (SE 7.4324) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (1) g_high — Compact — `urban_classRegional Centers` | 7.9719 (SE 8.5145) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (1) g_high — Compact — `urban_classRegional Centers Suburbs` | 4.0594 (SE 7.4135) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (1) g_high — Compact — `g_fora_alta` | 1.3283*** (SE 0.2663) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (2) g_high — Sprawl — `(Intercept)` | 39.5572 (SE 48.4560) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (2) g_high — Sprawl — `topo_prop_inclinado` | -1.8104 (SE 7.6897) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (2) g_high — Sprawl — `pp_alta_2010` | -0.7995*** (SE 0.2467) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (2) g_high — Sprawl — `pct_nao_constru_fora_alta_2010_q1` | -0.9474*** (SE 0.2582) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (2) g_high — Sprawl — `pct_nao_constru_fora_alta_2010_q4_f` | -0.2400 (SE 0.1935) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (2) g_high — Sprawl — `no_q4_cells_2010` | -1.1747 (SE 14.8709) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (2) g_high — Sprawl — `palma_rent` | 4.6536 (SE 3.0153) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (2) g_high — Sprawl — `palma_commute` | 17.7907** (SE 8.9425) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (2) g_high — Sprawl — `median_rent` | 0.0172 (SE 0.0336) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (2) g_high — Sprawl — `log_pib_pc` | -3.8176 (SE 3.1274) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (2) g_high — Sprawl — `log_pop_total_2000` | 1.4412 (SE 3.3146) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (2) g_high — Sprawl — `log_area_2000_km2` | -1.9099 (SE 3.3513) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (2) g_high — Sprawl — `zero_area_2000` | -32.0365 (SE 24.5121) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (2) g_high — Sprawl — `prop_favelas_2010` | 10.0686 (SE 17.2298) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (2) g_high — Sprawl — `regiaoSul` | 14.3441** (SE 5.9377) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (2) g_high — Sprawl — `regiaoNordeste` | 1.2952 (SE 6.5215) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (2) g_high — Sprawl — `regiaoNorte` | 7.8994 (SE 10.5746) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (2) g_high — Sprawl — `regiaoCentro-Oeste` | 5.9363 (SE 10.0306) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (2) g_high — Sprawl — `urban_classMetropolises` | 3.2344 (SE 6.7999) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (2) g_high — Sprawl — `urban_classMetropolis Suburbs` | 6.0901 (SE 7.2265) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (2) g_high — Sprawl — `urban_classRegional Centers` | 8.0885 (SE 8.3423) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (2) g_high — Sprawl — `urban_classRegional Centers Suburbs` | 3.5916 (SE 7.2157) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (2) g_high — Sprawl — `g_fora_alta` | 1.2543*** (SE 0.2776) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (3) Dpp_high — Compact — `(Intercept)` | 7.3247 (SE 5.0801) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (3) Dpp_high — Compact — `topo_prop_inclinado` | 1.4245* (SE 0.7298) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (3) Dpp_high — Compact — `pp_alta_2010` | -0.1190*** (SE 0.0378) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (3) Dpp_high — Compact — `pct_nao_constru_fora_alta_2010_q1` | -0.0975*** (SE 0.0364) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (3) Dpp_high — Compact — `pct_nao_constru_fora_alta_2010_q4_f` | -0.0342 (SE 0.0229) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (3) Dpp_high — Compact — `no_q4_cells_2010` | -0.9936 (SE 1.7472) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (3) Dpp_high — Compact — `palma_rent` | 0.2451 (SE 0.1727) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (3) Dpp_high — Compact — `palma_commute` | 2.0884** (SE 0.9511) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (3) Dpp_high — Compact — `median_rent` | 0.0022 (SE 0.0022) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (3) Dpp_high — Compact — `log_pib_pc` | 0.0652 (SE 0.1959) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (3) Dpp_high — Compact — `log_pop_total_2000` | -0.1108 (SE 0.2556) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (3) Dpp_high — Compact — `log_area_2000_km2` | -0.1130 (SE 0.2357) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (3) Dpp_high — Compact — `zero_area_2000` | -0.5807 (SE 1.8982) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (3) Dpp_high — Compact — `prop_favelas_2010` | 3.2891** (SE 1.4272) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (3) Dpp_high — Compact — `regiaoSul` | 0.6861* (SE 0.3816) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (3) Dpp_high — Compact — `regiaoNordeste` | 0.7963 (SE 0.5228) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (3) Dpp_high — Compact — `regiaoNorte` | 0.3686 (SE 0.5779) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (3) Dpp_high — Compact — `regiaoCentro-Oeste` | 0.9860*** (SE 0.2937) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (3) Dpp_high — Compact — `urban_classMetropolises` | -0.4407 (SE 0.5127) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (3) Dpp_high — Compact — `urban_classMetropolis Suburbs` | -0.4425 (SE 0.5524) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (3) Dpp_high — Compact — `urban_classRegional Centers` | -0.3765 (SE 0.6629) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (3) Dpp_high — Compact — `urban_classRegional Centers Suburbs` | -0.8897 (SE 0.6794) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (4) Dpp_high — Sprawl — `(Intercept)` | 12.3143** (SE 5.8930) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (4) Dpp_high — Sprawl — `topo_prop_inclinado` | 1.2349* (SE 0.6834) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (4) Dpp_high — Sprawl — `pp_alta_2010` | -0.1332*** (SE 0.0392) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (4) Dpp_high — Sprawl — `pct_nao_constru_fora_alta_2010_q1` | -0.1146*** (SE 0.0371) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (4) Dpp_high — Sprawl — `pct_nao_constru_fora_alta_2010_q4_f` | -0.0434* (SE 0.0240) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (4) Dpp_high — Sprawl — `no_q4_cells_2010` | -1.4676 (SE 1.7905) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (4) Dpp_high — Sprawl — `palma_rent` | 0.2069 (SE 0.1818) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (4) Dpp_high — Sprawl — `palma_commute` | 1.8636** (SE 0.9122) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (4) Dpp_high — Sprawl — `median_rent` | 0.0008 (SE 0.0022) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (4) Dpp_high — Sprawl — `log_pib_pc` | -0.0881 (SE 0.2138) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (4) Dpp_high — Sprawl — `log_pop_total_2000` | -0.3988 (SE 0.3079) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (4) Dpp_high — Sprawl — `log_area_2000_km2` | 0.3735 (SE 0.3282) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (4) Dpp_high — Sprawl — `zero_area_2000` | 1.5350 (SE 2.3423) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (4) Dpp_high — Sprawl — `prop_favelas_2010` | 3.0320** (SE 1.3415) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (4) Dpp_high — Sprawl — `regiaoSul` | 0.5823 (SE 0.3706) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (4) Dpp_high — Sprawl — `regiaoNordeste` | 0.8078 (SE 0.5437) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (4) Dpp_high — Sprawl — `regiaoNorte` | 0.2548 (SE 0.5960) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (4) Dpp_high — Sprawl — `regiaoCentro-Oeste` | 0.6602** (SE 0.2970) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (4) Dpp_high — Sprawl — `urban_classMetropolises` | -0.5552 (SE 0.5035) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (4) Dpp_high — Sprawl — `urban_classMetropolis Suburbs` | -0.4571 (SE 0.5327) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (4) Dpp_high — Sprawl — `urban_classRegional Centers` | -0.3190 (SE 0.6454) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (4) Dpp_high — Sprawl — `urban_classRegional Centers Suburbs` | -0.8958 (SE 0.6566) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |

## ED Table 3 — horse race

| Item | Value | Status | Source (file, mtime) | results_used.md (July) | Changed by | Note |
|---|---|---|---|---|---|---|
| (1) g_high — Compact + Sprawl — pct_area_densif_infill_0010 | 0.1373 (SE 0.1476) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (1) g_high — Compact + Sprawl — pct_area_periph_ext_leap_0010 | 0.2502* (SE 0.1360) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (1) g_high — Compact + Sprawl — N | 327 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (1) g_high — Compact + Sprawl — R² | 0.418 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (2) Dpp_high — Compact + Sprawl — pct_area_densif_infill_0010 | 0.0246** (SE 0.0098) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (2) Dpp_high — Compact + Sprawl — pct_area_periph_ext_leap_0010 | 0.0298*** (SE 0.0110) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (2) Dpp_high — Compact + Sprawl — N | 327 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (2) Dpp_high — Compact + Sprawl — R² | 0.286 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |

## ED Table 3 — Wald test, beta_compact = beta_sprawl

| Item | Value | Status | Source (file, mtime) | results_used.md (July) | Changed by | Note |
|---|---|---|---|---|---|---|
| (1) g_high — Compact + Sprawl — beta_compact − beta_sprawl | -0.1129 (SE 0.1661) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — | `pct_area_densif_infill_0010` − `pct_area_periph_ext_leap_0010`; clustered vcov |
| (1) g_high — Compact + Sprawl — Wald F(1, 302) | 0.462 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (1) g_high — Compact + Sprawl — Wald p-value | 0.4973 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (2) Dpp_high — Compact + Sprawl — beta_compact − beta_sprawl | -0.0052 (SE 0.0081) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — | `pct_area_densif_infill_0010` − `pct_area_periph_ext_leap_0010`; clustered vcov |
| (2) Dpp_high — Compact + Sprawl — Wald F(1, 303) | 0.409 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (2) Dpp_high — Compact + Sprawl — Wald p-value | 0.5231 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |

## ED Table 4 — with / without housing-market mediators

| Item | Value | Status | Source (file, mtime) | results_used.md (July) | Changed by | Note |
|---|---|---|---|---|---|---|
| (1) g_high Compact — WITH mediators — treatment coefficient | 0.0600 (SE 0.1405) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — | term `pct_area_densif_infill_0010` |
| (1) g_high Compact — WITH mediators — N | 327 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (1) g_high Compact — WITH mediators — R² | 0.412 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (2) g_high Sprawl — WITH mediators — treatment coefficient | 0.2113 (SE 0.1293) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — | term `pct_area_periph_ext_leap_0010` |
| (2) g_high Sprawl — WITH mediators — N | 327 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (2) g_high Sprawl — WITH mediators — R² | 0.417 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (3) Dpp_high Compact — WITH mediators — treatment coefficient | 0.0139* (SE 0.0078) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — | term `pct_area_densif_infill_0010` |
| (3) Dpp_high Compact — WITH mediators — N | 327 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (3) Dpp_high Compact — WITH mediators — R² | 0.264 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (4) Dpp_high Sprawl — WITH mediators — treatment coefficient | 0.0224** (SE 0.0092) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — | term `pct_area_periph_ext_leap_0010` |
| (4) Dpp_high Sprawl — WITH mediators — N | 327 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (4) Dpp_high Sprawl — WITH mediators — R² | 0.273 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (5) g_high Compact — NO mediators — treatment coefficient | -0.0099 (SE 0.1662) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — | term `pct_area_densif_infill_0010` |
| (5) g_high Compact — NO mediators — N | 327 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (5) g_high Compact — NO mediators — R² | 0.362 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (6) g_high Sprawl — NO mediators — treatment coefficient | 0.0492 (SE 0.1559) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — | term `pct_area_periph_ext_leap_0010` |
| (6) g_high Sprawl — NO mediators — N | 327 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (6) g_high Sprawl — NO mediators — R² | 0.362 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (7) Dpp_high Compact — NO mediators — treatment coefficient | 0.0106 (SE 0.0091) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — | term `pct_area_densif_infill_0010` |
| (7) Dpp_high Compact — NO mediators — N | 327 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (7) Dpp_high Compact — NO mediators — R² | 0.086 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (8) Dpp_high Sprawl — NO mediators — treatment coefficient | -0.0024 (SE 0.0099) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — | term `pct_area_periph_ext_leap_0010` |
| (8) Dpp_high Sprawl — NO mediators — N | 327 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (8) Dpp_high Sprawl — NO mediators — R² | 0.084 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (9) g_high — Mediators ONLY (no treatment) — N | 327 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (9) g_high — Mediators ONLY (no treatment) — R² | 0.412 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (10) Dpp_high — Mediators ONLY (no treatment) — N | 327 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (10) Dpp_high — Mediators ONLY (no treatment) — R² | 0.259 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |

## ED Table 4 — all other coefficients, columns (5)-(10)

| Item | Value | Status | Source (file, mtime) | results_used.md (July) | Changed by | Note |
|---|---|---|---|---|---|---|
| (5) g_high Compact — NO mediators — `(Intercept)` | -21.7312 (SE 51.5127) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (5) g_high Compact — NO mediators — `topo_prop_inclinado` | 4.2373 (SE 9.0225) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (5) g_high Compact — NO mediators — `pp_alta_2010` | -0.0122 (SE 0.1061) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (5) g_high Compact — NO mediators — `log_pib_pc` | -1.2877 (SE 2.7762) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (5) g_high Compact — NO mediators — `log_pop_total_2000` | 2.1358 (SE 4.5988) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (5) g_high Compact — NO mediators — `log_area_2000_km2` | -2.5383 (SE 4.1886) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (5) g_high Compact — NO mediators — `zero_area_2000` | -24.5515 (SE 29.4654) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (5) g_high Compact — NO mediators — `regiaoSul` | 7.6428 (SE 6.0924) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (5) g_high Compact — NO mediators — `regiaoNordeste` | -3.5876 (SE 4.7782) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (5) g_high Compact — NO mediators — `regiaoNorte` | 2.4602 (SE 9.5544) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (5) g_high Compact — NO mediators — `regiaoCentro-Oeste` | -0.6017 (SE 9.9735) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (5) g_high Compact — NO mediators — `urban_classMetropolises` | 4.8719 (SE 7.6119) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (5) g_high Compact — NO mediators — `urban_classMetropolis Suburbs` | 10.0908 (SE 7.6697) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (5) g_high Compact — NO mediators — `urban_classRegional Centers` | 8.2373 (SE 9.0987) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (5) g_high Compact — NO mediators — `urban_classRegional Centers Suburbs` | 4.7750 (SE 7.6461) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (5) g_high Compact — NO mediators — `g_fora_alta` | 1.2645*** (SE 0.2454) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (6) g_high Sprawl — NO mediators — `(Intercept)` | -21.8217 (SE 36.0642) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (6) g_high Sprawl — NO mediators — `topo_prop_inclinado` | 3.5899 (SE 8.6124) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (6) g_high Sprawl — NO mediators — `pp_alta_2010` | -0.0127 (SE 0.1033) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (6) g_high Sprawl — NO mediators — `log_pib_pc` | -1.3903 (SE 2.7626) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (6) g_high Sprawl — NO mediators — `log_pop_total_2000` | 1.8868 (SE 3.7268) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (6) g_high Sprawl — NO mediators — `log_area_2000_km2` | -1.9074 (SE 3.8669) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (6) g_high Sprawl — NO mediators — `zero_area_2000` | -21.5000 (SE 27.7095) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (6) g_high Sprawl — NO mediators — `regiaoSul` | 7.6208 (SE 5.9219) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (6) g_high Sprawl — NO mediators — `regiaoNordeste` | -3.6722 (SE 4.7729) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (6) g_high Sprawl — NO mediators — `regiaoNorte` | 2.8175 (SE 10.0488) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (6) g_high Sprawl — NO mediators — `regiaoCentro-Oeste` | -0.8972 (SE 9.9569) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (6) g_high Sprawl — NO mediators — `urban_classMetropolises` | 4.6592 (SE 7.4196) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (6) g_high Sprawl — NO mediators — `urban_classMetropolis Suburbs` | 10.1090 (SE 7.6312) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (6) g_high Sprawl — NO mediators — `urban_classRegional Centers` | 8.1939 (SE 9.0345) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (6) g_high Sprawl — NO mediators — `urban_classRegional Centers Suburbs` | 4.6486 (SE 7.6457) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (6) g_high Sprawl — NO mediators — `g_fora_alta` | 1.2460*** (SE 0.2567) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (7) Dpp_high Compact — NO mediators — `(Intercept)` | -0.3198 (SE 3.1280) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (7) Dpp_high Compact — NO mediators — `topo_prop_inclinado` | 1.7021** (SE 0.8587) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (7) Dpp_high Compact — NO mediators — `pp_alta_2010` | -0.0274** (SE 0.0126) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (7) Dpp_high Compact — NO mediators — `log_pib_pc` | 0.2045 (SE 0.2212) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (7) Dpp_high Compact — NO mediators — `log_pop_total_2000` | -0.0648 (SE 0.2894) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (7) Dpp_high Compact — NO mediators — `log_area_2000_km2` | 0.0850 (SE 0.2736) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (7) Dpp_high Compact — NO mediators — `zero_area_2000` | 0.9261 (SE 2.0469) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (7) Dpp_high Compact — NO mediators — `regiaoSul` | -0.1328 (SE 0.4337) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (7) Dpp_high Compact — NO mediators — `regiaoNordeste` | 0.0783 (SE 0.4503) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (7) Dpp_high Compact — NO mediators — `regiaoNorte` | -0.1778 (SE 0.7393) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (7) Dpp_high Compact — NO mediators — `regiaoCentro-Oeste` | -0.0893 (SE 0.2565) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (7) Dpp_high Compact — NO mediators — `urban_classMetropolises` | -0.4007 (SE 0.6132) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (7) Dpp_high Compact — NO mediators — `urban_classMetropolis Suburbs` | 0.0578 (SE 0.6428) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (7) Dpp_high Compact — NO mediators — `urban_classRegional Centers` | -0.3553 (SE 0.7958) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (7) Dpp_high Compact — NO mediators — `urban_classRegional Centers Suburbs` | -0.8145 (SE 0.7519) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (8) Dpp_high Sprawl — NO mediators — `(Intercept)` | 1.2979 (SE 2.8837) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (8) Dpp_high Sprawl — NO mediators — `topo_prop_inclinado` | 1.7755** (SE 0.9004) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (8) Dpp_high Sprawl — NO mediators — `pp_alta_2010` | -0.0285** (SE 0.0131) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (8) Dpp_high Sprawl — NO mediators — `log_pib_pc` | 0.1497 (SE 0.2216) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (8) Dpp_high Sprawl — NO mediators — `log_pop_total_2000` | -0.1649 (SE 0.2865) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (8) Dpp_high Sprawl — NO mediators — `log_area_2000_km2` | 0.1684 (SE 0.3056) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (8) Dpp_high Sprawl — NO mediators — `zero_area_2000` | 1.2640 (SE 2.1391) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (8) Dpp_high Sprawl — NO mediators — `regiaoSul` | -0.1695 (SE 0.4403) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (8) Dpp_high Sprawl — NO mediators — `regiaoNordeste` | 0.1082 (SE 0.4779) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (8) Dpp_high Sprawl — NO mediators — `regiaoNorte` | -0.3363 (SE 0.7826) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (8) Dpp_high Sprawl — NO mediators — `regiaoCentro-Oeste` | -0.1623 (SE 0.2905) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (8) Dpp_high Sprawl — NO mediators — `urban_classMetropolises` | -0.4015 (SE 0.6046) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (8) Dpp_high Sprawl — NO mediators — `urban_classMetropolis Suburbs` | 0.0547 (SE 0.6420) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (8) Dpp_high Sprawl — NO mediators — `urban_classRegional Centers` | -0.3351 (SE 0.7914) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (8) Dpp_high Sprawl — NO mediators — `urban_classRegional Centers Suburbs` | -0.8150 (SE 0.7492) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (9) g_high — Mediators ONLY (no treatment) — `(Intercept)` | 13.7738 (SE 51.5465) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (9) g_high — Mediators ONLY (no treatment) — `topo_prop_inclinado` | 0.2927 (SE 7.9968) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (9) g_high — Mediators ONLY (no treatment) — `pp_alta_2010` | -0.6842** (SE 0.2661) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (9) g_high — Mediators ONLY (no treatment) — `pct_nao_constru_fora_alta_2010_q1` | -0.8181*** (SE 0.2842) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (9) g_high — Mediators ONLY (no treatment) — `pct_nao_constru_fora_alta_2010_q4_f` | -0.1713 (SE 0.2067) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (9) g_high — Mediators ONLY (no treatment) — `no_q4_cells_2010` | 2.8273 (SE 15.5220) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (9) g_high — Mediators ONLY (no treatment) — `palma_rent` | 4.8051 (SE 2.9329) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (9) g_high — Mediators ONLY (no treatment) — `palma_commute` | 19.4053** (SE 9.3066) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (9) g_high — Mediators ONLY (no treatment) — `median_rent` | 0.0192 (SE 0.0338) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (9) g_high — Mediators ONLY (no treatment) — `log_pib_pc` | -3.0394 (SE 3.0949) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (9) g_high — Mediators ONLY (no treatment) — `log_pop_total_2000` | 3.2191 (SE 3.3385) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (9) g_high — Mediators ONLY (no treatment) — `log_area_2000_km2` | -5.0804 (SE 3.0981) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (9) g_high — Mediators ONLY (no treatment) — `zero_area_2000` | -47.3506** (SE 23.8369) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (9) g_high — Mediators ONLY (no treatment) — `prop_favelas_2010` | 12.7029 (SE 17.2460) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (9) g_high — Mediators ONLY (no treatment) — `regiaoSul` | 14.8605*** (SE 5.7328) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (9) g_high — Mediators ONLY (no treatment) — `regiaoNordeste` | 0.7505 (SE 6.4365) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (9) g_high — Mediators ONLY (no treatment) — `regiaoNorte` | 6.3763 (SE 10.6190) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (9) g_high — Mediators ONLY (no treatment) — `regiaoCentro-Oeste` | 7.3866 (SE 10.3370) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (9) g_high — Mediators ONLY (no treatment) — `urban_classMetropolises` | 4.2728 (SE 7.0735) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (9) g_high — Mediators ONLY (no treatment) — `urban_classMetropolis Suburbs` | 6.0441 (SE 7.4221) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (9) g_high — Mediators ONLY (no treatment) — `urban_classRegional Centers` | 7.9950 (SE 8.4629) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (9) g_high — Mediators ONLY (no treatment) — `urban_classRegional Centers Suburbs` | 3.9966 (SE 7.3938) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (9) g_high — Mediators ONLY (no treatment) — `g_fora_alta` | 1.3201*** (SE 0.2560) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (10) Dpp_high — Mediators ONLY (no treatment) — `(Intercept)` | 9.7875* (SE 5.4853) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (10) Dpp_high — Mediators ONLY (no treatment) — `topo_prop_inclinado` | 1.5045** (SE 0.7410) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (10) Dpp_high — Mediators ONLY (no treatment) — `pp_alta_2010` | -0.1205*** (SE 0.0387) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (10) Dpp_high — Mediators ONLY (no treatment) — `pct_nao_constru_fora_alta_2010_q1` | -0.0985*** (SE 0.0370) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (10) Dpp_high — Mediators ONLY (no treatment) — `pct_nao_constru_fora_alta_2010_q4_f` | -0.0350 (SE 0.0232) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (10) Dpp_high — Mediators ONLY (no treatment) — `no_q4_cells_2010` | -0.9600 (SE 1.7386) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (10) Dpp_high — Mediators ONLY (no treatment) — `palma_rent` | 0.2137 (SE 0.1728) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (10) Dpp_high — Mediators ONLY (no treatment) — `palma_commute` | 2.0729** (SE 0.9415) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (10) Dpp_high — Mediators ONLY (no treatment) — `median_rent` | 0.0013 (SE 0.0022) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (10) Dpp_high — Mediators ONLY (no treatment) — `log_pib_pc` | 0.0259 (SE 0.1978) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (10) Dpp_high — Mediators ONLY (no treatment) — `log_pop_total_2000` | -0.2618 (SE 0.2891) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (10) Dpp_high — Mediators ONLY (no treatment) — `log_area_2000_km2` | 0.0658 (SE 0.2690) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (10) Dpp_high — Mediators ONLY (no treatment) — `zero_area_2000` | 0.2120 (SE 2.0951) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (10) Dpp_high — Mediators ONLY (no treatment) — `prop_favelas_2010` | 3.2088** (SE 1.4121) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (10) Dpp_high — Mediators ONLY (no treatment) — `regiaoSul` | 0.6468* (SE 0.3790) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (10) Dpp_high — Mediators ONLY (no treatment) — `regiaoNordeste` | 0.7839 (SE 0.5374) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (10) Dpp_high — Mediators ONLY (no treatment) — `regiaoNorte` | 0.1394 (SE 0.6106) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (10) Dpp_high — Mediators ONLY (no treatment) — `regiaoCentro-Oeste` | 0.8323*** (SE 0.2625) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (10) Dpp_high — Mediators ONLY (no treatment) — `urban_classMetropolises` | -0.4660 (SE 0.5100) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (10) Dpp_high — Mediators ONLY (no treatment) — `urban_classMetropolis Suburbs` | -0.4594 (SE 0.5471) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (10) Dpp_high — Mediators ONLY (no treatment) — `urban_classRegional Centers` | -0.3621 (SE 0.6543) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (10) Dpp_high — Mediators ONLY (no treatment) — `urban_classRegional Centers Suburbs` | -0.8933 (SE 0.6727) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |

## ED Table 5 — functional urban areas

| Item | Value | Status | Source (file, mtime) | results_used.md (July) | Changed by | Note |
|---|---|---|---|---|---|---|
| (1) g_high — Compact — N | 183 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (1) g_high — Compact — R² | 0.358 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (2) g_high — Sprawl — N | 183 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (2) g_high — Sprawl — R² | 0.358 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (3) Dpp_high — Compact — N | 183 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (3) Dpp_high — Compact — R² | 0.323 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (4) Dpp_high — Sprawl — N | 183 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (4) Dpp_high — Sprawl — R² | 0.335 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| N (reconciliation) | 183 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | 206 (results_used.md L81); VERIFICATION.md A2 found 202 | 6b0, 6c1, 6f.1/6f.2 | results_used.md (206) and VERIFICATION.md A2 (202) disagree with each other and both predate the current pipeline. The value in this row is the one the current models carry. Reconcile results_used.md to it. |
| (1) g_high — Compact — post-6f treatment coefficient | -0.2821 (SE 0.2143) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | 6f.2 (asymmetric arrangement aggregation) |  |
| (1) g_high — Compact — pre-6f treatment coefficient | — | PENDING | — | — | 6f.2 | not recoverable from the current pipeline: 6f.2 changed stage 03's arrangement denominators, so reproducing the pre-6f values means re-running stage 03 under the old rule. Supply data/processed_data/04_regression/pre_6f_ed_table3_coefficients.csv with columns spec,estimate,std_error,p_value,n_obs to fill this row |
| (2) g_high — Sprawl — post-6f treatment coefficient | 0.3349 (SE 0.2119) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | 6f.2 (asymmetric arrangement aggregation) |  |
| (2) g_high — Sprawl — pre-6f treatment coefficient | — | PENDING | — | — | 6f.2 | not recoverable from the current pipeline: 6f.2 changed stage 03's arrangement denominators, so reproducing the pre-6f values means re-running stage 03 under the old rule. Supply data/processed_data/04_regression/pre_6f_ed_table3_coefficients.csv with columns spec,estimate,std_error,p_value,n_obs to fill this row |
| (3) Dpp_high — Compact — post-6f treatment coefficient | -0.0048 (SE 0.0123) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | 6f.2 (asymmetric arrangement aggregation) |  |
| (3) Dpp_high — Compact — pre-6f treatment coefficient | — | PENDING | — | — | 6f.2 | not recoverable from the current pipeline: 6f.2 changed stage 03's arrangement denominators, so reproducing the pre-6f values means re-running stage 03 under the old rule. Supply data/processed_data/04_regression/pre_6f_ed_table3_coefficients.csv with columns spec,estimate,std_error,p_value,n_obs to fill this row |
| (4) Dpp_high — Sprawl — post-6f treatment coefficient | 0.0251 (SE 0.0156) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | 6f.2 (asymmetric arrangement aggregation) | SIGNIFICANCE FLAG: post-6f p = 0.1089 (stars ''); 6f.2's asymmetric arrangement denominator moved this coefficient across the 10% threshold |
| (4) Dpp_high — Sprawl — pre-6f treatment coefficient | — | PENDING | — | — | 6f.2 | not recoverable from the current pipeline: 6f.2 changed stage 03's arrangement denominators, so reproducing the pre-6f values means re-running stage 03 under the old rule. Supply data/processed_data/04_regression/pre_6f_ed_table3_coefficients.csv with columns spec,estimate,std_error,p_value,n_obs to fill this row |

## ED Table 6 — interactions

| Item | Value | Status | Source (file, mtime) | results_used.md (July) | Changed by | Note |
|---|---|---|---|---|---|---|
| (1) g_high — Compact × urban_class — N | 327 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (1) g_high — Compact × urban_class — R² | 0.425 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (2) Dpp_high — Compact × urban_class — N | 327 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (2) Dpp_high — Compact × urban_class — R² | 0.285 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (3) g_high — Compact × regiao — N | 320 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — | region columns exclude Centro-Oeste (6c2) |
| (3) g_high — Compact × regiao — R² | 0.421 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (4) Dpp_high — Compact × regiao — N | 320 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — | region columns exclude Centro-Oeste (6c2) |
| (4) Dpp_high — Compact × regiao — R² | 0.266 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (5) g_high — Sprawl × urban_class — N | 327 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (5) g_high — Sprawl × urban_class — R² | 0.421 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (6) Dpp_high — Sprawl × urban_class — N | 327 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (6) Dpp_high — Sprawl × urban_class — R² | 0.283 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (7) g_high — Sprawl × regiao — N | 320 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — | region columns exclude Centro-Oeste (6c2) |
| (7) g_high — Sprawl × regiao — R² | 0.434 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (8) Dpp_high — Sprawl × regiao — N | 320 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — | region columns exclude Centro-Oeste (6c2) |
| (8) Dpp_high — Sprawl × regiao — R² | 0.283 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |

## Path a — 2010 mediators on pre-period growth (no exhibit yet)

| Item | Value | Status | Source (file, mtime) | results_used.md (July) | Changed by | Note |
|---|---|---|---|---|---|---|
| (1) Q1 vacant safe land — Compact — treatment coefficient | 0.1079** (SE 0.0498) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — | term `pct_area_densif_infill_0010` |
| (1) Q1 vacant safe land — Compact — N | 327 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (1) Q1 vacant safe land — Compact — R² | 0.186 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (2) Q1 vacant safe land — Sprawl — treatment coefficient | 0.2185*** (SE 0.0623) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — | term `pct_area_periph_ext_leap_0010` |
| (2) Q1 vacant safe land — Sprawl — N | 327 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (2) Q1 vacant safe land — Sprawl — R² | 0.221 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (3) Q4 vacant safe land — Compact — treatment coefficient | 0.0502 (SE 0.0656) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — | term `pct_area_densif_infill_0010` |
| (3) Q4 vacant safe land — Compact — N | 314 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (3) Q4 vacant safe land — Compact — R² | 0.159 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (4) Q4 vacant safe land — Sprawl — treatment coefficient | 0.2495*** (SE 0.0525) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — | term `pct_area_periph_ext_leap_0010` |
| (4) Q4 vacant safe land — Sprawl — N | 314 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (4) Q4 vacant safe land — Sprawl — R² | 0.209 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (5) median rent — Compact — treatment coefficient | -2.4324*** (SE 0.3553) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — | term `pct_area_densif_infill_0010` |
| (5) median rent — Compact — N | 327 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (5) median rent — Compact — R² | 0.593 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (6) median rent — Sprawl — treatment coefficient | 0.7278* (SE 0.3888) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — | term `pct_area_periph_ext_leap_0010` |
| (6) median rent — Sprawl — N | 327 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (6) median rent — Sprawl — R² | 0.507 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (7) Palma ratio, rent — Compact — treatment coefficient | -0.0078*** (SE 0.0027) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — | term `pct_area_densif_infill_0010` |
| (7) Palma ratio, rent — Compact — N | 327 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (7) Palma ratio, rent — Compact — R² | 0.277 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (8) Palma ratio, rent — Sprawl — treatment coefficient | 0.0048 (SE 0.0032) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — | term `pct_area_periph_ext_leap_0010` |
| (8) Palma ratio, rent — Sprawl — N | 327 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (8) Palma ratio, rent — Sprawl — R² | 0.267 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (9) Palma ratio, commute — Compact — treatment coefficient | -0.0011 (SE 0.0008) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — | term `pct_area_densif_infill_0010` |
| (9) Palma ratio, commute — Compact — N | 327 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (9) Palma ratio, commute — Compact — R² | 0.296 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (10) Palma ratio, commute — Sprawl — treatment coefficient | 0.0023*** (SE 0.0009) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — | term `pct_area_periph_ext_leap_0010` |
| (10) Palma ratio, commute — Sprawl — N | 327 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (10) Palma ratio, commute — Sprawl — R² | 0.311 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (11) favela share — Compact — treatment coefficient | -0.0005 (SE 0.0004) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — | term `pct_area_densif_infill_0010` |
| (11) favela share — Compact — N | 327 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (11) favela share — Compact — R² | 0.268 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (12) favela share — Sprawl — treatment coefficient | 0.0001 (SE 0.0004) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — | term `pct_area_periph_ext_leap_0010` |
| (12) favela share — Sprawl — N | 327 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |
| (12) favela share — Sprawl — R² | 0.264 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-10-02 10:10:56) | — | — |  |

## ED Figure — standardized coefficients

| Item | Value | Status | Source (file, mtime) | results_used.md (July) | Changed by | Note |
|---|---|---|---|---|---|---|
| Rows in the standardized-coefficient CSV | 42 | VERIFIED | `output/ed_figure_standardized_coefficients.csv` (2026-10-06 17:25:14) | — | — |  |
| (1) g_high — Compact — largest \|standardized beta\| | Pop. growth outside risk zones = 0.610 (Other control) | VERIFIED | `output/ed_figure_standardized_coefficients.csv` (2026-10-06 17:25:14) | — | — |  |
| (1) g_high — Compact — treatment standardized beta | Compact growth = 0.027 | VERIFIED | `output/ed_figure_standardized_coefficients.csv` (2026-10-06 17:25:14) | — | — |  |
| (1) g_high — Compact — N | 327 | VERIFIED | `output/ed_figure_standardized_coefficients.csv` (2026-10-06 17:25:14) | — | — |  |
| (2) g_high — Sprawl — largest \|standardized beta\| | Pop. growth outside risk zones = 0.576 (Other control) | VERIFIED | `output/ed_figure_standardized_coefficients.csv` (2026-10-06 17:25:14) | — | — |  |
| (2) g_high — Sprawl — treatment standardized beta | Sprawl growth = 0.139 | VERIFIED | `output/ed_figure_standardized_coefficients.csv` (2026-10-06 17:25:14) | — | — |  |
| (2) g_high — Sprawl — N | 327 | VERIFIED | `output/ed_figure_standardized_coefficients.csv` (2026-10-06 17:25:14) | — | — |  |
| (3) Dpp_high — Compact — largest \|standardized beta\| | Pop. share in risk zones 2010 = -1.036 (Other control) | VERIFIED | `output/ed_figure_standardized_coefficients.csv` (2026-10-06 17:25:14) | — | — |  |
| (3) Dpp_high — Compact — treatment standardized beta | Compact growth = 0.098 | VERIFIED | `output/ed_figure_standardized_coefficients.csv` (2026-10-06 17:25:14) | — | — |  |
| (3) Dpp_high — Compact — N | 327 | VERIFIED | `output/ed_figure_standardized_coefficients.csv` (2026-10-06 17:25:14) | — | — |  |
| (4) Dpp_high — Sprawl — largest \|standardized beta\| | Pop. share in risk zones 2010 = -1.160 (Other control) | VERIFIED | `output/ed_figure_standardized_coefficients.csv` (2026-10-06 17:25:14) | — | — |  |
| (4) Dpp_high — Sprawl — treatment standardized beta | Sprawl growth = 0.230 | VERIFIED | `output/ed_figure_standardized_coefficients.csv` (2026-10-06 17:25:14) | — | — |  |
| (4) Dpp_high — Sprawl — N | 327 | VERIFIED | `output/ed_figure_standardized_coefficients.csv` (2026-10-06 17:25:14) | — | — |  |

## Stage 02 / stage 03 coverage

| Item | Value | Status | Source (file, mtime) | results_used.md (July) | Changed by | Note |
|---|---|---|---|---|---|---|
| Municipalities in the stage-02 high-susceptibility summary | 703 | VERIFIED | `data/processed_data/02_hazard_zones/resumo_municipal_suscept_alta_agsn.csv` (2026-08-25 22:49:27) | — | — |  |
| Exposed population 2010 (stage 02, area-weighted) | 13,341,594 | VERIFIED | `data/processed_data/02_hazard_zones/resumo_municipal_suscept_alta_agsn.csv` (2026-08-25 22:49:27) | — | — | `pop_suscept = populacao × prop_suscept`, national sum over the summary's municipalities |
| Exposed population 2022 (stage 02, area-weighted) | 14,192,370 | VERIFIED | `data/processed_data/02_hazard_zones/resumo_municipal_suscept_alta_agsn.csv` (2026-08-25 22:49:27) | — | — |  |
| Municipalities with CPRM mapped risk (stage 02) | 1,586 | VERIFIED | `data/processed_data/02_hazard_zones/resumo_municipal_risco_agsn.csv` (2026-08-26 01:46:30) | — | — | produced by stage 02; no live consumer since 6f.1 |
| Municipalities in stage-03 metrics | 629 | VERIFIED | `data/processed_data/03_urban_footprint/metricas/metricas_municipio_2010_2022.csv` (2026-09-22 22:31:58) | — | — |  |
| Arrangements emitted by stage-03 script 07 | 210 | VERIFIED | `data/processed_data/03_urban_footprint/metricas/metricas_arranjo_2010_2022.csv` (2026-09-22 22:31:58) | — | — | not the stage-04 arrangement count: `13_dependent_variables.R:80–83` filters to the qualified CD_CIDADEs and `15_final_dataset.R:123–127` re-adds the isolated ones |

## ED Table 2 — descriptive statistics

| Item | Value | Status | Source (file, mtime) | results_used.md (July) | Changed by | Note |
|---|---|---|---|---|---|---|
| Municipality — A. Estimation sample — N (max across variables) | 327 | VERIFIED | `output/ed_table2_descriptives_municipality.csv` (2026-10-06 17:25:16) | — | — | listwise deletion makes N vary by variable; the maximum is the block size |
| Municipality — B. Full sample — N (max across variables) | 395 | VERIFIED | `output/ed_table2_descriptives_municipality.csv` (2026-10-06 17:25:16) | — | — | listwise deletion makes N vary by variable; the maximum is the block size |
| Municipality — A. Estimation sample — Sprawl share of urban footprint | mean 33.5382, median 29.6715, range 0.0000 to 100.0000 (N 327) | VERIFIED | `output/ed_table2_descriptives_municipality.csv` (2026-10-06 17:25:16) | — | — |  |
| Municipality — B. Full sample — Sprawl share of urban footprint | mean 36.0339, median 30.4638, range 0.0000 to 100.0000 (N 395) | VERIFIED | `output/ed_table2_descriptives_municipality.csv` (2026-10-06 17:25:16) | — | — |  |
| Municipality — A. Estimation sample — Compact share of urban footprint | mean 38.7204, median 39.8515, range 0.0000 to 81.0757 (N 327) | VERIFIED | `output/ed_table2_descriptives_municipality.csv` (2026-10-06 17:25:16) | — | — |  |
| Municipality — B. Full sample — Compact share of urban footprint | mean 37.6562, median 39.6618, range 0.0000 to 81.0757 (N 395) | VERIFIED | `output/ed_table2_descriptives_municipality.csv` (2026-10-06 17:25:16) | — | — |  |
| Municipality — A. Estimation sample — Growth of exposed population, 2010–2022 | mean 19.9322, median 13.4086, range -40.3409 to 252.0244 (N 327) | VERIFIED | `output/ed_table2_descriptives_municipality.csv` (2026-10-06 17:25:16) | — | — |  |
| Municipality — B. Full sample — Growth of exposed population, 2010–2022 | mean 45.8397, median 14.1354, range -40.3409 to 3956.7037 (N 395) | VERIFIED | `output/ed_table2_descriptives_municipality.csv` (2026-10-06 17:25:16) | — | — |  |
| Municipality — A. Estimation sample — Change in exposed population share, 2010–2022 | mean -0.2108, median -0.0545, range -19.4242 to 9.2057 (N 327) | VERIFIED | `output/ed_table2_descriptives_municipality.csv` (2026-10-06 17:25:16) | — | — |  |
| Municipality — B. Full sample — Change in exposed population share, 2010–2022 | mean -0.1300, median -0.0016, range -19.4242 to 9.2057 (N 395) | VERIFIED | `output/ed_table2_descriptives_municipality.csv` (2026-10-06 17:25:16) | — | — |  |
| Arrangement — A. Estimation sample — N (max across variables) | 183 | VERIFIED | `output/ed_table2_descriptives_arrangement.csv` (2026-10-06 17:25:16) | — | — | listwise deletion makes N vary by variable; the maximum is the block size |
| Arrangement — B. Full sample — N (max across variables) | 210 | VERIFIED | `output/ed_table2_descriptives_arrangement.csv` (2026-10-06 17:25:16) | — | — | listwise deletion makes N vary by variable; the maximum is the block size |
| Arrangement — A. Estimation sample — Sprawl share of urban footprint | mean 33.5243, median 30.7827, range 8.6705 to 85.9819 (N 183) | VERIFIED | `output/ed_table2_descriptives_arrangement.csv` (2026-10-06 17:25:16) | — | — |  |
| Arrangement — B. Full sample — Sprawl share of urban footprint | mean 33.4299, median 30.3493, range 8.6705 to 98.4127 (N 210) | VERIFIED | `output/ed_table2_descriptives_arrangement.csv` (2026-10-06 17:25:16) | — | — |  |
| Arrangement — A. Estimation sample — Compact share of urban footprint | mean 38.7758, median 38.9623, range 11.2396 to 65.6598 (N 183) | VERIFIED | `output/ed_table2_descriptives_arrangement.csv` (2026-10-06 17:25:16) | — | — |  |
| Arrangement — B. Full sample — Compact share of urban footprint | mean 38.6038, median 38.8981, range 0.0000 to 65.6598 (N 210) | VERIFIED | `output/ed_table2_descriptives_arrangement.csv` (2026-10-06 17:25:16) | — | — |  |
| Arrangement — A. Estimation sample — Growth of exposed population, 2010–2022 | mean 14.5841, median 9.3743, range -40.3409 to 213.2675 (N 183) | VERIFIED | `output/ed_table2_descriptives_arrangement.csv` (2026-10-06 17:25:16) | — | — |  |
| Arrangement — B. Full sample — Growth of exposed population, 2010–2022 | mean 46.9249, median 10.0444, range -40.3409 to 3956.7037 (N 210) | VERIFIED | `output/ed_table2_descriptives_arrangement.csv` (2026-10-06 17:25:16) | — | — |  |
| Arrangement — A. Estimation sample — Change in exposed population share, 2010–2022 | mean -0.3559, median -0.0804, range -19.4242 to 3.7462 (N 183) | VERIFIED | `output/ed_table2_descriptives_arrangement.csv` (2026-10-06 17:25:16) | — | — |  |
| Arrangement — B. Full sample — Change in exposed population share, 2010–2022 | mean -0.2928, median -0.0355, range -19.4242 to 3.7462 (N 210) | VERIFIED | `output/ed_table2_descriptives_arrangement.csv` (2026-10-06 17:25:16) | — | — |  |

---

Regenerate: `Rscript 05_exhibits/build_results_targets.R` (commit 55c3838).
