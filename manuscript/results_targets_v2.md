# results_targets_v2.md — values, provenance, status

**GENERATED FILE. Do not edit by hand.** Produced by `05_exhibits/build_results_targets.R`;
every run overwrites it. Hand edits are lost. To change a value, change the pipeline and re-run.

This file holds values, their provenance and their status. It contains no interpretation.

## Run header

- Generated: **2026-09-17 11:54:23 -03**
- Repository commit: **ffd2656** — working tree has uncommitted changes
- Stage-04 reference clock: **2026-09-15 14:51:29** (`data/processed_data/04_regression/model_objects_table2.rds`)
- Staleness tolerance: 3600 seconds
- `MIN_POP_RISCO_2010` (from `00_setup.R`): **200**

### Input manifest

| Input | Path | mtime | Position | State |
|---|---|---|---|---|
| OPTIONAL archived pre-6f ED Table 3 coefficients (supplied by hand, if at all) | `data/processed_data/04_regression/pre_6f_ed_table3_coefficients.csv` | — | exempt | MISSING |
| minimum-baseline sweep, sample sizes (robustness/minimum_population_filter.R) | `data/processed_data/04_regression/figures/sensitivity_min_pop_risco_sample_sizes.csv` | 2026-09-17 11:17:22 | downstream | ok |
| minimum-baseline sweep (robustness/minimum_population_filter.R) | `data/processed_data/04_regression/figures/sensitivity_min_pop_risco.csv` | 2026-09-17 11:17:22 | downstream | ok |
| stage 02 municipal summary, high susceptibility (03_cross_grid_high_susceptibility.py) | `data/processed_data/02_hazard_zones/resumo_municipal_suscept_alta_agsn.csv` | 2026-08-25 22:49:27 | upstream | ok |
| stage 02 municipal summary, CPRM risk (04_cross_grid_cprm_risk.py) | `data/processed_data/02_hazard_zones/resumo_municipal_risco_agsn.csv` | 2026-08-26 01:46:30 | upstream | ok |
| stage 03 sample (01_define_sample.R) | `data/processed_data/03_urban_footprint/amostra_municipios.rds` | 2026-09-14 15:13:05 | upstream | ok |
| stage 03 classified grid (05_classify_growth_types.R) | `data/processed_data/03_urban_footprint/crescimento_urbano/grade_growth_types_2010_2022.parquet` | 2026-09-14 17:29:10 | upstream | ok |
| stage 03 arrangement metrics (07_aggregate_municipality_metrics.R) | `data/processed_data/03_urban_footprint/metricas/metricas_arranjo_2010_2022.csv` | 2026-09-14 18:20:04 | upstream | ok |
| stage 03 municipality metrics (07_aggregate_municipality_metrics.R) | `data/processed_data/03_urban_footprint/metricas/metricas_municipio_2010_2022.csv` | 2026-09-14 18:20:03 | upstream | ok |
| stage 04 qualified-arrangement members (01_compose_sample.R) | `data/processed_data/04_regression/amostra_arr.csv` | 2026-09-15 14:51:05 | upstream | ok |
| stage 04 municipality sample (01_compose_sample.R) | `data/processed_data/04_regression/amostra_mun.csv` | 2026-09-15 14:51:04 | upstream | ok |
| stage 04 processing universe (01_compose_sample.R) | `data/processed_data/04_regression/amostra_universo.csv` | 2026-09-15 14:51:05 | upstream | ok |
| stage 04 arrangement regression dataset (15_final_dataset.R) | `data/processed_data/04_regression/tables/dataset_regressao_arranjo.csv` | 2026-09-15 14:51:23 | upstream | ok |
| stage 04 municipality regression dataset (15_final_dataset.R) | `data/processed_data/04_regression/tables/dataset_regressao_municipio.csv` | 2026-09-15 14:51:23 | upstream | ok |
| stage 04 fitted models + metadata (16_estimate_models.R) | `data/processed_data/04_regression/model_objects_table2.rds` | 2026-09-15 14:51:29 | upstream | ok |
| stage 04 isolated municipalities (01_compose_sample.R) | `data/processed_data/04_regression/mun_isol.csv` | 2026-09-15 14:51:05 | upstream | ok |
| ED Figure standardized betas (ed_figure_standardized_coefficients.R) | `output/ed_figure_standardized_coefficients.csv` | 2026-09-17 11:01:32 | downstream | ok |
| Figure 1 layers (figure1_growth_type_layers.R) | `data/processed_data/03_urban_footprint/figuras/figura1_camadas.parquet` | 2026-09-17 11:00:04 | downstream | ok |
| Table 1a (table1_population_by_growth_type.R) | `output/tabela1a_populacao_totais_tipo.csv` | 2026-09-17 11:05:02 | downstream | ok |
| Table 1b (table1_population_by_growth_type.R) | `output/tabela1_populacao_risco_tipo.csv` | 2026-09-17 11:05:02 | downstream | ok |

**Entries: 232 total, 228 VERIFIED, 4 PENDING.**

### Consistency manifest

Model-building constants copied from `16_estimate_models.R`; diff this block against that source.

```
MIN_POP_RISCO_2010 : 200
trat_compact       : pct_area_densif_infill_0010
trat_periph        : pct_area_periph_ext_leap_0010
CTRL_ALTA (14)      : topo_prop_inclinado, pp_alta_2010, pct_nao_constru_fora_alta_2010_q1, pct_nao_constru_fora_alta_2010_q4, palma_rent, palma_commute, median_rent, log_pib_pc, log_pop_total_2000, log_area_2000_km2, zero_area_2000, prop_favelas_2010, regiao, urban_class
CTRL_ALTA_NO_MED (9): topo_prop_inclinado, pp_alta_2010, log_pib_pc, log_pop_total_2000, log_area_2000_km2, zero_area_2000, prop_favelas_2010, regiao, urban_class
vcov: municipalities = vcovCL(cluster = attr(mod, 'cluster_vec')); arrangements = vcovHC(HC3)
```


## Sample funnel

| Item | Value | Status | Source (file, mtime) | results_used.md (July) | Changed by | Note |
|---|---|---|---|---|---|---|
| Processing universe (municipalities) | 629 | VERIFIED | `data/processed_data/04_regression/amostra_universo.csv` (2026-09-15 14:51:05) | — | 6f.1 (CPRM union removed from stage 03's sample definition) |  |
| amostra_mun (tem_susceptibilidade == TRUE) | 395 | VERIFIED | `data/processed_data/04_regression/amostra_mun.csv` (2026-09-15 14:51:04) | — | — | `01_compose_sample.R:41` |
| Isolated municipalities | 110 | VERIFIED | `data/processed_data/04_regression/mun_isol.csv` (2026-09-15 14:51:05) | — | — | `01_compose_sample.R:42` |
| Qualified arrangements (CD_CIDADE) | 100 | VERIFIED | `data/processed_data/04_regression/amostra_arr.csv` (2026-09-15 14:51:05) | — | — | `01_compose_sample.R:75–87` |
| Members of qualified arrangements | 519 | VERIFIED | `data/processed_data/04_regression/amostra_arr.csv` (2026-09-15 14:51:05) | — | — |  |
| FUA entities (arrangements + isolated) | 210 | VERIFIED | `data/processed_data/04_regression/amostra_arr.csv` (2026-09-15 14:51:05) + `data/processed_data/04_regression/mun_isol.csv` (2026-09-15 14:51:05) | 206 (results_used.md L11) | 6b0, 6f.1 — `01_compose_sample.R:92–93` counts `n_distinct(CD_CIDADE) + nrow(mun_isol)` | counting `amostra_arr.csv` alone omits the isolated FUAs |
| dataset_regressao_municipio.csv rows | 395 | VERIFIED | `data/processed_data/04_regression/tables/dataset_regressao_municipio.csv` (2026-09-15 14:51:23) | 387 (results_used.md L11) | 6b0 — under the common grid every row has a valid `delta_pp_alta` |  |
| dataset_regressao_arranjo.csv rows | 210 | VERIFIED | `data/processed_data/04_regression/tables/dataset_regressao_arranjo.csv` (2026-09-15 14:51:23) | — | — |  |
| After pop_2010_risk_total > MIN_POP_RISCO_2010 (municipalities) | 350 | VERIFIED | `data/processed_data/04_regression/tables/dataset_regressao_municipio.csv` (2026-09-15 14:51:23) | — | 6c1 revised 2026-09-12; cut = 200 |  |
| After pop_2010_risk_total > MIN_POP_RISCO_2010 (arrangements) | 183 | VERIFIED | `data/processed_data/04_regression/tables/dataset_regressao_arranjo.csv` (2026-09-15 14:51:23) | — | 6c1 revised 2026-09-12; cut = 200 |  |
| MIN_POP_RISCO_2010 applied at estimation | 200 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-15 14:51:29) | no cut (results_used.md states none) | 6c1, decided 2026-09-08 at 1000, revised 2026-09-12 to 200 |  |
| Municipalities before the cut (metadata) | 395 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-15 14:51:29) | — | — |  |
| Municipalities after the cut (metadata) | 350 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-15 14:51:29) | — | — |  |
| Centro-Oeste municipalities dropped (region columns) | 7 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-15 14:51:29) | — | 6c2, decided 2026-09-10 |  |
| Estimation timestamp (metadata) | 2026-09-15 14:51:26 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-15 14:51:29) | — | — |  |

## Table 1 — population and exposure by growth type

| Item | Value | Status | Source (file, mtime) | results_used.md (July) | Changed by | Note |
|---|---|---|---|---|---|---|
| Consolidated — pop_2010 | 59,398,950 | VERIFIED | `output/tabela1a_populacao_totais_tipo.csv` (2026-09-17 11:05:02) | 59,138,249 | 6b0 (common grid), 6e (exposure weighting), 6f.1/6f.2 |  |
| Consolidated — pop_2022 | 55,188,718 | VERIFIED | `output/tabela1a_populacao_totais_tipo.csv` (2026-09-17 11:05:02) | 55,634,711 | 6b0, 6e, 6f.1/6f.2 |  |
| Consolidated — risco_2010 | 7,021,298 | VERIFIED | `output/tabela1a_populacao_totais_tipo.csv` (2026-09-17 11:05:02) | 15,627,912 | 6e (area weighting replaces any-overlap) |  |
| Consolidated — risco_2022 | 6,505,323 | VERIFIED | `output/tabela1a_populacao_totais_tipo.csv` (2026-09-17 11:05:02) | 14,632,292 | 6e |  |
| Consolidated — % at risk 2010 | 11.8% | VERIFIED | `output/tabela1a_populacao_totais_tipo.csv` (2026-09-17 11:05:02) | 26.4% | 6e |  |
| Consolidated — % at risk 2022 | 11.8% | VERIFIED | `output/tabela1a_populacao_totais_tipo.csv` (2026-09-17 11:05:02) | 26.3% | 6e |  |
| Consolidated — change in risk pop. | -515,975 | VERIFIED | `output/tabela1a_populacao_totais_tipo.csv` (2026-09-17 11:05:02) | -995,620 (derived from its components) | 6e |  |
| Compact — pop_2010 | 27,215,535 | VERIFIED | `output/tabela1a_populacao_totais_tipo.csv` (2026-09-17 11:05:02) | 27,367,825 | 6b0 (common grid), 6e (exposure weighting), 6f.1/6f.2 |  |
| Compact — pop_2022 | 33,529,176 | VERIFIED | `output/tabela1a_populacao_totais_tipo.csv` (2026-09-17 11:05:02) | 36,107,824 | 6b0, 6e, 6f.1/6f.2 |  |
| Compact — risco_2010 | 3,515,050 | VERIFIED | `output/tabela1a_populacao_totais_tipo.csv` (2026-09-17 11:05:02) | 8,625,881 | 6e (area weighting replaces any-overlap) |  |
| Compact — risco_2022 | 4,313,988 | VERIFIED | `output/tabela1a_populacao_totais_tipo.csv` (2026-09-17 11:05:02) | 10,779,228 | 6e |  |
| Compact — % at risk 2010 | 12.9% | VERIFIED | `output/tabela1a_populacao_totais_tipo.csv` (2026-09-17 11:05:02) | 31.5% | 6e |  |
| Compact — % at risk 2022 | 12.9% | VERIFIED | `output/tabela1a_populacao_totais_tipo.csv` (2026-09-17 11:05:02) | 29.9% | 6e |  |
| Compact — change in risk pop. | 798,937 | VERIFIED | `output/tabela1a_populacao_totais_tipo.csv` (2026-09-17 11:05:02) | 2,153,347 | 6e |  |
| Sprawl — pop_2010 | 3,004,720 | VERIFIED | `output/tabela1a_populacao_totais_tipo.csv` (2026-09-17 11:05:02) | 2,900,879 | 6b0 (common grid), 6e (exposure weighting), 6f.1/6f.2 |  |
| Sprawl — pop_2022 | 9,135,551 | VERIFIED | `output/tabela1a_populacao_totais_tipo.csv` (2026-09-17 11:05:02) | 6,104,483 | 6b0, 6e, 6f.1/6f.2 |  |
| Sprawl — risco_2010 | 405,420 | VERIFIED | `output/tabela1a_populacao_totais_tipo.csv` (2026-09-17 11:05:02) | 988,462 | 6e (area weighting replaces any-overlap) |  |
| Sprawl — risco_2022 | 1,066,865 | VERIFIED | `output/tabela1a_populacao_totais_tipo.csv` (2026-09-17 11:05:02) | 1,908,404 | 6e |  |
| Sprawl — % at risk 2010 | 13.5% | VERIFIED | `output/tabela1a_populacao_totais_tipo.csv` (2026-09-17 11:05:02) | 34.1% | 6e |  |
| Sprawl — % at risk 2022 | 11.7% | VERIFIED | `output/tabela1a_populacao_totais_tipo.csv` (2026-09-17 11:05:02) | 31.3% | 6e |  |
| Sprawl — change in risk pop. | 661,445 | VERIFIED | `output/tabela1a_populacao_totais_tipo.csv` (2026-09-17 11:05:02) | 919,942 | 6e |  |
| Total — pop_2010 | 89,619,205 | VERIFIED | `output/tabela1a_populacao_totais_tipo.csv` (2026-09-17 11:05:02) | 89,406,953 | 6b0 (common grid), 6e (exposure weighting), 6f.1/6f.2 |  |
| Total — pop_2022 | 97,853,445 | VERIFIED | `output/tabela1a_populacao_totais_tipo.csv` (2026-09-17 11:05:02) | 97,847,018 | 6b0, 6e, 6f.1/6f.2 |  |
| Total — risco_2010 | 10,941,768 | VERIFIED | `output/tabela1a_populacao_totais_tipo.csv` (2026-09-17 11:05:02) | 25,242,255 | 6e (area weighting replaces any-overlap) |  |
| Total — risco_2022 | 11,886,175 | VERIFIED | `output/tabela1a_populacao_totais_tipo.csv` (2026-09-17 11:05:02) | 27,319,924 | 6e |  |
| Total — % at risk 2010 | 12.2% | VERIFIED | `output/tabela1a_populacao_totais_tipo.csv` (2026-09-17 11:05:02) | 28.2% (derived from its components) | 6e |  |
| Total — % at risk 2022 | 12.1% | VERIFIED | `output/tabela1a_populacao_totais_tipo.csv` (2026-09-17 11:05:02) | 27.9% (derived from its components) | 6e |  |
| Total — change in risk pop. | 944,407 | VERIFIED | `output/tabela1a_populacao_totais_tipo.csv` (2026-09-17 11:05:02) | 2,077,669 (derived from its components) | 6e |  |
| Compact — % of new residents going to risk | 12.7% | VERIFIED | `output/tabela1a_populacao_totais_tipo.csv` (2026-09-17 11:05:02) | 25% | 6b0, 6e | derived from the Table 1a CSV, same arithmetic as `table1_population_by_growth_type.R` |
| Sprawl — % of new residents going to risk | 10.8% | VERIFIED | `output/tabela1a_populacao_totais_tipo.csv` (2026-09-17 11:05:02) | 29% | 6b0, 6e | derived from the Table 1a CSV |
| Compact share of the net increase in at-risk pop. (Compact+Sprawl) | 54.7% | VERIFIED | `output/tabela1a_populacao_totais_tipo.csv` (2026-09-17 11:05:02) | 70% (2.2M of 3.1M) | 6b0, 6e | derived from the Table 1a CSV |
| Aggregate growth — total population | 9.2% | VERIFIED | `output/tabela1a_populacao_totais_tipo.csv` (2026-09-17 11:05:02) | +9.4% | 6b0 | derived from the Table 1a CSV |
| Aggregate growth — population at risk | 8.6% | VERIFIED | `output/tabela1a_populacao_totais_tipo.csv` (2026-09-17 11:05:02) | +8.2% | 6e | derived from the Table 1a CSV |
| Consolidated — change in high susceptibility (M) | -0.516 | VERIFIED | `output/tabela1_populacao_risco_tipo.csv` (2026-09-17 11:05:02) | -1.000 | 6b0, 6e |  |
| Consolidated — change outside high susceptibility (M) | -3.694 | VERIFIED | `output/tabela1_populacao_risco_tipo.csv` (2026-09-17 11:05:02) | -2.510 | 6b0, 6e |  |
| Consolidated — total change (M) | -4.210 | VERIFIED | `output/tabela1_populacao_risco_tipo.csv` (2026-09-17 11:05:02) | — | 6b0 |  |
| Compact — change in high susceptibility (M) | 0.799 | VERIFIED | `output/tabela1_populacao_risco_tipo.csv` (2026-09-17 11:05:02) | 2.150 | 6b0, 6e |  |
| Compact — change outside high susceptibility (M) | 5.515 | VERIFIED | `output/tabela1_populacao_risco_tipo.csv` (2026-09-17 11:05:02) | 6.590 | 6b0, 6e |  |
| Compact — total change (M) | 6.314 | VERIFIED | `output/tabela1_populacao_risco_tipo.csv` (2026-09-17 11:05:02) | — | 6b0 |  |
| Sprawl — change in high susceptibility (M) | 0.661 | VERIFIED | `output/tabela1_populacao_risco_tipo.csv` (2026-09-17 11:05:02) | 0.920 | 6b0, 6e |  |
| Sprawl — change outside high susceptibility (M) | 5.469 | VERIFIED | `output/tabela1_populacao_risco_tipo.csv` (2026-09-17 11:05:02) | 2.280 | 6b0, 6e |  |
| Sprawl — total change (M) | 6.131 | VERIFIED | `output/tabela1_populacao_risco_tipo.csv` (2026-09-17 11:05:02) | — | 6b0 |  |

## Figure 1 — growth-type layers

| Item | Value | Status | Source (file, mtime) | results_used.md (July) | Changed by | Note |
|---|---|---|---|---|---|---|
| Total cells | 3,092,892 | VERIFIED | `data/processed_data/03_urban_footprint/figuras/figura1_camadas.parquet` (2026-09-17 11:00:04) | — | — | recomputed here, not read from an exhibit output; mirrors `figure1_growth_type_layers.R` §2; source layer `data/processed_data/03_urban_footprint/figuras/figura1_camadas.parquet` |
| grupo_3tipos — consolidated | 180,611 | VERIFIED | `data/processed_data/03_urban_footprint/figuras/figura1_camadas.parquet` (2026-09-17 11:00:04) | — | — | recomputed here, not read from an exhibit output; mirrors `figure1_growth_type_layers.R` §2; source layer `data/processed_data/03_urban_footprint/figuras/figura1_camadas.parquet` |
| grupo_3tipos — compact | 154,183 | VERIFIED | `data/processed_data/03_urban_footprint/figuras/figura1_camadas.parquet` (2026-09-17 11:00:04) | — | — | recomputed here, not read from an exhibit output; mirrors `figure1_growth_type_layers.R` §2; source layer `data/processed_data/03_urban_footprint/figuras/figura1_camadas.parquet` |
| grupo_3tipos — sprawl | 91,736 | VERIFIED | `data/processed_data/03_urban_footprint/figuras/figura1_camadas.parquet` (2026-09-17 11:00:04) | — | — | recomputed here, not read from an exhibit output; mirrors `figure1_growth_type_layers.R` §2; source layer `data/processed_data/03_urban_footprint/figuras/figura1_camadas.parquet` |
| grupo_3tipos — NA | 2,666,362 | VERIFIED | `data/processed_data/03_urban_footprint/figuras/figura1_camadas.parquet` (2026-09-17 11:00:04) | — | — | recomputed here, not read from an exhibit output; mirrors `figure1_growth_type_layers.R` §2; source layer `data/processed_data/03_urban_footprint/figuras/figura1_camadas.parquet` |
| urban 2010 TRUE / 2020 TRUE | 361,396 | VERIFIED | `data/processed_data/03_urban_footprint/figuras/figura1_camadas.parquet` (2026-09-17 11:00:04) | — | — | recomputed here, not read from an exhibit output; mirrors `figure1_growth_type_layers.R` §2; source layer `data/processed_data/03_urban_footprint/figuras/figura1_camadas.parquet` |
| urban 2010 TRUE / 2020 FALSE | 10,505 | VERIFIED | `data/processed_data/03_urban_footprint/figuras/figura1_camadas.parquet` (2026-09-17 11:00:04) | — | — | recomputed here, not read from an exhibit output; mirrors `figure1_growth_type_layers.R` §2; source layer `data/processed_data/03_urban_footprint/figuras/figura1_camadas.parquet` |
| urban 2010 FALSE / 2020 TRUE | 55,527 | VERIFIED | `data/processed_data/03_urban_footprint/figuras/figura1_camadas.parquet` (2026-09-17 11:00:04) | — | — | recomputed here, not read from an exhibit output; mirrors `figure1_growth_type_layers.R` §2; source layer `data/processed_data/03_urban_footprint/figuras/figura1_camadas.parquet` |
| urban 2010 FALSE / 2020 FALSE | 2,665,464 | VERIFIED | `data/processed_data/03_urban_footprint/figuras/figura1_camadas.parquet` (2026-09-17 11:00:04) | — | — | recomputed here, not read from an exhibit output; mirrors `figure1_growth_type_layers.R` §2; source layer `data/processed_data/03_urban_footprint/figuras/figura1_camadas.parquet` |
| Derived-vs-real disagreement — urbano_2010 | 983 | VERIFIED | `data/processed_data/03_urban_footprint/figuras/figura1_camadas.parquet` (2026-09-17 11:00:04) | — | — | recomputed here, not read from an exhibit output; mirrors `figure1_growth_type_layers.R` §2; source layer `data/processed_data/03_urban_footprint/figuras/figura1_camadas.parquet` ; derived = tipo_crescimento in {consolidated, densification, peripheral} |
| Derived-vs-real disagreement — urbano_2020 | 11,307 | VERIFIED | `data/processed_data/03_urban_footprint/figuras/figura1_camadas.parquet` (2026-09-17 11:00:04) | — | — | recomputed here, not read from an exhibit output; mirrors `figure1_growth_type_layers.R` §2; source layer `data/processed_data/03_urban_footprint/figuras/figura1_camadas.parquet` ; derived = !is.na(tipo_crescimento) |
| Municipalities flagged em_amostra_regressao | 395 | VERIFIED | `data/processed_data/03_urban_footprint/figuras/figura1_camadas.parquet` (2026-09-17 11:00:04) | — | — | recomputed here, not read from an exhibit output; mirrors `figure1_growth_type_layers.R` §2; source layer `data/processed_data/03_urban_footprint/figuras/figura1_camadas.parquet` |

## Figure 2 — exposure scatter

| Item | Value | Status | Source (file, mtime) | results_used.md (July) | Changed by | Note |
|---|---|---|---|---|---|---|
| Metrics municipalities (before any filter) | 629 | VERIFIED | `data/processed_data/03_urban_footprint/metricas/metricas_municipio_2010_2022.csv` (2026-09-14 18:20:03) + `data/processed_data/04_regression/tables/dataset_regressao_municipio.csv` (2026-09-15 14:51:23) | — | — | recomputed here, not read from an exhibit output; mirrors `figure2_exposure_scatter.R` §3–§5 and §10 |
| Filter 1 — after pop_2010_risk_total > MIN_POP_RISCO_2010 | 350 | VERIFIED | `data/processed_data/03_urban_footprint/metricas/metricas_municipio_2010_2022.csv` (2026-09-14 18:20:03) + `data/processed_data/04_regression/tables/dataset_regressao_municipio.csv` (2026-09-15 14:51:23) | — | 6c1 revised 2026-09-12; cut = 200 | recomputed here, not read from an exhibit output; mirrors `figure2_exposure_scatter.R` §3–§5 and §10 ; `figure2_exposure_scatter.R:86` |
| Filter 2 — after positive growth in both types (final N) | 305 | VERIFIED | `data/processed_data/03_urban_footprint/metricas/metricas_municipio_2010_2022.csv` (2026-09-14 18:20:03) + `data/processed_data/04_regression/tables/dataset_regressao_municipio.csv` (2026-09-15 14:51:23) | 341 (results_used.md L50, '43% of 341 cities') | 6b0, 6c1, 6e | recomputed here, not read from an exhibit output; mirrors `figure2_exposure_scatter.R` §3–§5 and §10 ; this is the N printed in both subtitles |
| Dropped by filter 2 | 45 | VERIFIED | `data/processed_data/03_urban_footprint/metricas/metricas_municipio_2010_2022.csv` (2026-09-14 18:20:03) + `data/processed_data/04_regression/tables/dataset_regressao_municipio.csv` (2026-09-15 14:51:23) | — | — | recomputed here, not read from an exhibit output; mirrors `figure2_exposure_scatter.R` §3–§5 and §10 |
| Median pct_risk_compact | 6.1% | VERIFIED | `data/processed_data/03_urban_footprint/metricas/metricas_municipio_2010_2022.csv` (2026-09-14 18:20:03) + `data/processed_data/04_regression/tables/dataset_regressao_municipio.csv` (2026-09-15 14:51:23) | 18.2% | 6b0, 6c1, 6e | recomputed here, not read from an exhibit output; mirrors `figure2_exposure_scatter.R` §3–§5 and §10 |
| Median pct_risk_sprawl | 7.9% | VERIFIED | `data/processed_data/03_urban_footprint/metricas/metricas_municipio_2010_2022.csv` (2026-09-14 18:20:03) + `data/processed_data/04_regression/tables/dataset_regressao_municipio.csv` (2026-09-15 14:51:23) | 20.9% | 6b0, 6c1, 6e | recomputed here, not read from an exhibit output; mirrors `figure2_exposure_scatter.R` §3–§5 and §10 |
| Median difference (compact − sprawl) | -0.010 | VERIFIED | `data/processed_data/03_urban_footprint/metricas/metricas_municipio_2010_2022.csv` (2026-09-14 18:20:03) + `data/processed_data/04_regression/tables/dataset_regressao_municipio.csv` (2026-09-15 14:51:23) | — | — | recomputed here, not read from an exhibit output; mirrors `figure2_exposure_scatter.R` §3–§5 and §10 |
| Share below 45° line (compact > sprawl) | 41.3% | VERIFIED | `data/processed_data/03_urban_footprint/metricas/metricas_municipio_2010_2022.csv` (2026-09-14 18:20:03) + `data/processed_data/04_regression/tables/dataset_regressao_municipio.csv` (2026-09-15 14:51:23) | 43% | 6b0, 6c1, 6e | recomputed here, not read from an exhibit output; mirrors `figure2_exposure_scatter.R` §3–§5 and §10 |
| Wilcoxon signed-rank p | 0.0205 | VERIFIED | `data/processed_data/03_urban_footprint/metricas/metricas_municipio_2010_2022.csv` (2026-09-14 18:20:03) + `data/processed_data/04_regression/tables/dataset_regressao_municipio.csv` (2026-09-15 14:51:23) | — | — | recomputed here, not read from an exhibit output; mirrors `figure2_exposure_scatter.R` §3–§5 and §10 |
| Pearson correlation | 0.233 (p = 0.0000) | VERIFIED | `data/processed_data/03_urban_footprint/metricas/metricas_municipio_2010_2022.csv` (2026-09-14 18:20:03) + `data/processed_data/04_regression/tables/dataset_regressao_municipio.csv` (2026-09-15 14:51:23) | — | — | recomputed here, not read from an exhibit output; mirrors `figure2_exposure_scatter.R` §3–§5 and §10 |
| Spearman correlation | 0.664 (p = 0.0000) | VERIFIED | `data/processed_data/03_urban_footprint/metricas/metricas_municipio_2010_2022.csv` (2026-09-14 18:20:03) + `data/processed_data/04_regression/tables/dataset_regressao_municipio.csv` (2026-09-15 14:51:23) | — | — | recomputed here, not read from an exhibit output; mirrors `figure2_exposure_scatter.R` §3–§5 and §10 |
| Fitted slope | 0.602 | VERIFIED | `data/processed_data/03_urban_footprint/metricas/metricas_municipio_2010_2022.csv` (2026-09-14 18:20:03) + `data/processed_data/04_regression/tables/dataset_regressao_municipio.csv` (2026-09-15 14:51:23) | slope < 45° with positive intercept (no value stated) | 6b0, 6c1, 6e | recomputed here, not read from an exhibit output; mirrors `figure2_exposure_scatter.R` §3–§5 and §10 ; fitted on the [0,1]-clipped variables |
| Fitted slope SE | 0.032 | VERIFIED | `data/processed_data/03_urban_footprint/metricas/metricas_municipio_2010_2022.csv` (2026-09-14 18:20:03) + `data/processed_data/04_regression/tables/dataset_regressao_municipio.csv` (2026-09-15 14:51:23) | — | — | recomputed here, not read from an exhibit output; mirrors `figure2_exposure_scatter.R` §3–§5 and §10 |
| Fitted intercept | 0.060 | VERIFIED | `data/processed_data/03_urban_footprint/metricas/metricas_municipio_2010_2022.csv` (2026-09-14 18:20:03) + `data/processed_data/04_regression/tables/dataset_regressao_municipio.csv` (2026-09-15 14:51:23) | — | — | recomputed here, not read from an exhibit output; mirrors `figure2_exposure_scatter.R` §3–§5 and §10 |
| Fitted R² | 0.538 | VERIFIED | `data/processed_data/03_urban_footprint/metricas/metricas_municipio_2010_2022.csv` (2026-09-14 18:20:03) + `data/processed_data/04_regression/tables/dataset_regressao_municipio.csv` (2026-09-15 14:51:23) | — | — | recomputed here, not read from an exhibit output; mirrors `figure2_exposure_scatter.R` §3–§5 and §10 |

## Table 2 — main regressions (municipalities)

| Item | Value | Status | Source (file, mtime) | results_used.md (July) | Changed by | Note |
|---|---|---|---|---|---|---|
| (1) g_high — Compact — treatment coefficient | 0.0700 (SE 0.1502) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-15 14:51:29) | −0.026 n.s. | 6b0 (common grid), 6e (exposure weighting), 6c1 (sample cut) | term `pct_area_densif_infill_0010` |
| (1) g_high — Compact — N | 314 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-15 14:51:29) | — | — |  |
| (1) g_high — Compact — R² | 0.361 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-15 14:51:29) | — | — |  |
| (2) g_high — Sprawl — treatment coefficient | 0.2396* (SE 0.1405) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-15 14:51:29) | +0.103** | 6b0 (common grid), 6e (exposure weighting), 6c1 (sample cut) | term `pct_area_periph_ext_leap_0010` |
| (2) g_high — Sprawl — N | 314 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-15 14:51:29) | — | — |  |
| (2) g_high — Sprawl — R² | 0.366 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-15 14:51:29) | — | — |  |
| (3) Dpp_high — Compact — treatment coefficient | 0.0135* (SE 0.0081) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-15 14:51:29) | +0.040*** | 6b0 (common grid), 6e (exposure weighting), 6c1 (sample cut) | term `pct_area_densif_infill_0010` |
| (3) Dpp_high — Compact — N | 314 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-15 14:51:29) | — | — |  |
| (3) Dpp_high — Compact — R² | 0.275 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-15 14:51:29) | — | — |  |
| (4) Dpp_high — Sprawl — treatment coefficient | 0.0223** (SE 0.0097) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-15 14:51:29) | −0.021* | 6b0 (common grid), 6e (exposure weighting), 6c1 (sample cut) | term `pct_area_periph_ext_leap_0010` |
| (4) Dpp_high — Sprawl — N | 314 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-15 14:51:29) | — | — |  |
| (4) Dpp_high — Sprawl — R² | 0.284 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-15 14:51:29) | — | — |  |
| Comparability note | not comparable to N = 317 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-15 14:51:29) | — | — | 317 was produced under the any-overlap rule with a cut of 1000, both superseded. 6e lowered pop_2010_risk_total; the cut moved to 200. The two differences pull in opposite directions and do not cancel (MIGRATION_PLAN.md, 'On Table 2's N'). |
| Listwise deletion rule | complete.cases over ALL formula variables | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-15 14:51:29) | list-wise deletion on safe available land and steep terrain (results_used.md L11) | none — the code never did what results_used.md describes | `16_estimate_models.R:297–298`, applied per specification and AFTER the MIN_POP_RISCO_2010 cut (`:205–207`). This is why N varies by specification; results_used.md's Table 2 note names a narrower set than the code uses. |

## ED Table 2 — with / without housing-market mediators

| Item | Value | Status | Source (file, mtime) | results_used.md (July) | Changed by | Note |
|---|---|---|---|---|---|---|
| (1) g_high Compact — WITH mediators — treatment coefficient | 0.0700 (SE 0.1502) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-15 14:51:29) | — | — | term `pct_area_densif_infill_0010` |
| (1) g_high Compact — WITH mediators — N | 314 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-15 14:51:29) | — | — |  |
| (1) g_high Compact — WITH mediators — R² | 0.361 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-15 14:51:29) | — | — |  |
| (2) g_high Sprawl — WITH mediators — treatment coefficient | 0.2396* (SE 0.1405) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-15 14:51:29) | — | — | term `pct_area_periph_ext_leap_0010` |
| (2) g_high Sprawl — WITH mediators — N | 314 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-15 14:51:29) | — | — |  |
| (2) g_high Sprawl — WITH mediators — R² | 0.366 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-15 14:51:29) | — | — |  |
| (3) Dpp_high Compact — WITH mediators — treatment coefficient | 0.0135* (SE 0.0081) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-15 14:51:29) | — | — | term `pct_area_densif_infill_0010` |
| (3) Dpp_high Compact — WITH mediators — N | 314 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-15 14:51:29) | — | — |  |
| (3) Dpp_high Compact — WITH mediators — R² | 0.275 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-15 14:51:29) | — | — |  |
| (4) Dpp_high Sprawl — WITH mediators — treatment coefficient | 0.0223** (SE 0.0097) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-15 14:51:29) | — | — | term `pct_area_periph_ext_leap_0010` |
| (4) Dpp_high Sprawl — WITH mediators — N | 314 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-15 14:51:29) | — | — |  |
| (4) Dpp_high Sprawl — WITH mediators — R² | 0.284 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-15 14:51:29) | — | — |  |
| (5) g_high Compact — NO mediators — treatment coefficient | -0.0045 (SE 0.1660) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-15 14:51:29) | — | — | term `pct_area_densif_infill_0010` |
| (5) g_high Compact — NO mediators — N | 327 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-15 14:51:29) | — | — |  |
| (5) g_high Compact — NO mediators — R² | 0.364 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-15 14:51:29) | — | — |  |
| (6) g_high Sprawl — NO mediators — treatment coefficient | 0.0418 (SE 0.1577) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-15 14:51:29) | — | — | term `pct_area_periph_ext_leap_0010` |
| (6) g_high Sprawl — NO mediators — N | 327 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-15 14:51:29) | — | — |  |
| (6) g_high Sprawl — NO mediators — R² | 0.364 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-15 14:51:29) | — | — |  |
| (7) Dpp_high Compact — NO mediators — treatment coefficient | 0.0112 (SE 0.0088) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-15 14:51:29) | — | — | term `pct_area_densif_infill_0010` |
| (7) Dpp_high Compact — NO mediators — N | 327 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-15 14:51:29) | — | — |  |
| (7) Dpp_high Compact — NO mediators — R² | 0.109 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-15 14:51:29) | — | — |  |
| (8) Dpp_high Sprawl — NO mediators — treatment coefficient | -0.0028 (SE 0.0104) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-15 14:51:29) | — | — | term `pct_area_periph_ext_leap_0010` |
| (8) Dpp_high Sprawl — NO mediators — N | 327 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-15 14:51:29) | — | — |  |
| (8) Dpp_high Sprawl — NO mediators — R² | 0.106 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-15 14:51:29) | — | — |  |
| (9) g_high — Mediators ONLY (no treatment) — N | 314 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-15 14:51:29) | — | — |  |
| (9) g_high — Mediators ONLY (no treatment) — R² | 0.360 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-15 14:51:29) | — | — |  |
| (10) Dpp_high — Mediators ONLY (no treatment) — N | 314 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-15 14:51:29) | — | — |  |
| (10) Dpp_high — Mediators ONLY (no treatment) — R² | 0.270 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-15 14:51:29) | — | — |  |

## ED Table 3 — functional urban areas

| Item | Value | Status | Source (file, mtime) | results_used.md (July) | Changed by | Note |
|---|---|---|---|---|---|---|
| (1) g_high — Compact — N | 183 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-15 14:51:29) | — | — |  |
| (1) g_high — Compact — R² | 0.358 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-15 14:51:29) | — | — |  |
| (2) g_high — Sprawl — N | 183 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-15 14:51:29) | — | — |  |
| (2) g_high — Sprawl — R² | 0.358 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-15 14:51:29) | — | — |  |
| (3) Dpp_high — Compact — N | 183 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-15 14:51:29) | — | — |  |
| (3) Dpp_high — Compact — R² | 0.323 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-15 14:51:29) | — | — |  |
| (4) Dpp_high — Sprawl — N | 183 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-15 14:51:29) | — | — |  |
| (4) Dpp_high — Sprawl — R² | 0.335 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-15 14:51:29) | — | — |  |
| N (reconciliation) | 183 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-15 14:51:29) | 206 (results_used.md L81); CLAUDE.md L151–155 carries 202 from VERIFICATION.md A2 | 6b0, 6c1, 6f.1/6f.2 | results_used.md and CLAUDE.md disagree with each other (206 vs 202) and both predate the current pipeline. The value in this row is the one the current models carry. Reconcile to it, in results_used.md and CLAUDE.md's Key sample facts. |
| (1) g_high — Compact — post-6f treatment coefficient | -0.2821 (SE 0.2143) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-15 14:51:29) | — | 6f.2 (asymmetric arrangement aggregation) |  |
| (1) g_high — Compact — pre-6f treatment coefficient | — | PENDING | — | — | 6f.2 | not recoverable from the current pipeline: 6f.2 changed stage 03's arrangement denominators, so reproducing the pre-6f values means re-running stage 03 under the old rule. Supply data/processed_data/04_regression/pre_6f_ed_table3_coefficients.csv with columns spec,estimate,std_error,p_value,n_obs to fill this row |
| (2) g_high — Sprawl — post-6f treatment coefficient | 0.3349 (SE 0.2119) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-15 14:51:29) | — | 6f.2 (asymmetric arrangement aggregation) |  |
| (2) g_high — Sprawl — pre-6f treatment coefficient | — | PENDING | — | — | 6f.2 | not recoverable from the current pipeline: 6f.2 changed stage 03's arrangement denominators, so reproducing the pre-6f values means re-running stage 03 under the old rule. Supply data/processed_data/04_regression/pre_6f_ed_table3_coefficients.csv with columns spec,estimate,std_error,p_value,n_obs to fill this row |
| (3) Dpp_high — Compact — post-6f treatment coefficient | -0.0048 (SE 0.0123) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-15 14:51:29) | — | 6f.2 (asymmetric arrangement aggregation) |  |
| (3) Dpp_high — Compact — pre-6f treatment coefficient | — | PENDING | — | — | 6f.2 | not recoverable from the current pipeline: 6f.2 changed stage 03's arrangement denominators, so reproducing the pre-6f values means re-running stage 03 under the old rule. Supply data/processed_data/04_regression/pre_6f_ed_table3_coefficients.csv with columns spec,estimate,std_error,p_value,n_obs to fill this row |
| (4) Dpp_high — Sprawl — post-6f treatment coefficient | 0.0251 (SE 0.0156) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-15 14:51:29) | — | 6f.2 (asymmetric arrangement aggregation) | SIGNIFICANCE FLAG: post-6f p = 0.1089 (stars ''); 6f.2's asymmetric arrangement denominator moved this coefficient across the 10% threshold |
| (4) Dpp_high — Sprawl — pre-6f treatment coefficient | — | PENDING | — | — | 6f.2 | not recoverable from the current pipeline: 6f.2 changed stage 03's arrangement denominators, so reproducing the pre-6f values means re-running stage 03 under the old rule. Supply data/processed_data/04_regression/pre_6f_ed_table3_coefficients.csv with columns spec,estimate,std_error,p_value,n_obs to fill this row |

## ED Table 4 — horse race

| Item | Value | Status | Source (file, mtime) | results_used.md (July) | Changed by | Note |
|---|---|---|---|---|---|---|
| (1) g_high — Compact + Sprawl — pct_area_densif_infill_0010 | 0.1523 (SE 0.1517) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-15 14:51:29) | — | — |  |
| (1) g_high — Compact + Sprawl — pct_area_periph_ext_leap_0010 | 0.2816** (SE 0.1413) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-15 14:51:29) | — | — |  |
| (1) g_high — Compact + Sprawl — N | 314 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-15 14:51:29) | — | — |  |
| (1) g_high — Compact + Sprawl — R² | 0.368 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-15 14:51:29) | — | — |  |
| (2) Dpp_high — Compact + Sprawl — pct_area_densif_infill_0010 | 0.0233** (SE 0.0098) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-15 14:51:29) | — | — |  |
| (2) Dpp_high — Compact + Sprawl — pct_area_periph_ext_leap_0010 | 0.0290** (SE 0.0112) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-15 14:51:29) | — | — |  |
| (2) Dpp_high — Compact + Sprawl — N | 314 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-15 14:51:29) | — | — |  |
| (2) Dpp_high — Compact + Sprawl — R² | 0.296 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-15 14:51:29) | — | — |  |

## ED Table 5 — interactions

| Item | Value | Status | Source (file, mtime) | results_used.md (July) | Changed by | Note |
|---|---|---|---|---|---|---|
| (1) g_high — Compact × urban_class — N | 314 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-15 14:51:29) | — | — |  |
| (1) g_high — Compact × urban_class — R² | 0.379 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-15 14:51:29) | — | — |  |
| (2) Dpp_high — Compact × urban_class — N | 314 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-15 14:51:29) | — | — |  |
| (2) Dpp_high — Compact × urban_class — R² | 0.293 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-15 14:51:29) | — | — |  |
| (3) g_high — Compact × regiao — N | 307 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-15 14:51:29) | — | — | region columns exclude Centro-Oeste (6c2) |
| (3) g_high — Compact × regiao — R² | 0.371 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-15 14:51:29) | — | — |  |
| (4) Dpp_high — Compact × regiao — N | 307 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-15 14:51:29) | — | — | region columns exclude Centro-Oeste (6c2) |
| (4) Dpp_high — Compact × regiao — R² | 0.276 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-15 14:51:29) | — | — |  |
| (5) g_high — Sprawl × urban_class — N | 314 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-15 14:51:29) | — | — |  |
| (5) g_high — Sprawl × urban_class — R² | 0.370 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-15 14:51:29) | — | — |  |
| (6) Dpp_high — Sprawl × urban_class — N | 314 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-15 14:51:29) | — | — |  |
| (6) Dpp_high — Sprawl × urban_class — R² | 0.301 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-15 14:51:29) | — | — |  |
| (7) g_high — Sprawl × regiao — N | 307 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-15 14:51:29) | — | — | region columns exclude Centro-Oeste (6c2) |
| (7) g_high — Sprawl × regiao — R² | 0.390 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-15 14:51:29) | — | — |  |
| (8) Dpp_high — Sprawl × regiao — N | 307 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-15 14:51:29) | — | — | region columns exclude Centro-Oeste (6c2) |
| (8) Dpp_high — Sprawl × regiao — R² | 0.305 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-15 14:51:29) | — | — |  |

## ED Figure — standardized coefficients

| Item | Value | Status | Source (file, mtime) | results_used.md (July) | Changed by | Note |
|---|---|---|---|---|---|---|
| Rows in the standardized-coefficient CSV | 42 | VERIFIED | `output/ed_figure_standardized_coefficients.csv` (2026-09-17 11:01:32) | — | — |  |
| (1) g_high — Compact — largest \|standardized beta\| | Pop. growth outside risk zones = 0.584 (Other control) | VERIFIED | `output/ed_figure_standardized_coefficients.csv` (2026-09-17 11:01:32) | — | — |  |
| (1) g_high — Compact — treatment standardized beta | Compact growth = 0.030 | VERIFIED | `output/ed_figure_standardized_coefficients.csv` (2026-09-17 11:01:32) | — | — |  |
| (1) g_high — Compact — N | 314 | VERIFIED | `output/ed_figure_standardized_coefficients.csv` (2026-09-17 11:01:32) | — | — |  |
| (2) g_high — Sprawl — largest \|standardized beta\| | Pop. growth outside risk zones = 0.544 (Other control) | VERIFIED | `output/ed_figure_standardized_coefficients.csv` (2026-09-17 11:01:32) | — | — |  |
| (2) g_high — Sprawl — treatment standardized beta | Sprawl growth = 0.152 | VERIFIED | `output/ed_figure_standardized_coefficients.csv` (2026-09-17 11:01:32) | — | — |  |
| (2) g_high — Sprawl — N | 314 | VERIFIED | `output/ed_figure_standardized_coefficients.csv` (2026-09-17 11:01:32) | — | — |  |
| (3) Dpp_high — Compact — largest \|standardized beta\| | Pop. share in risk zones 2010 = -1.053 (Other control) | VERIFIED | `output/ed_figure_standardized_coefficients.csv` (2026-09-17 11:01:32) | — | — |  |
| (3) Dpp_high — Compact — treatment standardized beta | Compact growth = 0.089 | VERIFIED | `output/ed_figure_standardized_coefficients.csv` (2026-09-17 11:01:32) | — | — |  |
| (3) Dpp_high — Compact — N | 314 | VERIFIED | `output/ed_figure_standardized_coefficients.csv` (2026-09-17 11:01:32) | — | — |  |
| (4) Dpp_high — Sprawl — largest \|standardized beta\| | Pop. share in risk zones 2010 = -1.162 (Other control) | VERIFIED | `output/ed_figure_standardized_coefficients.csv` (2026-09-17 11:01:32) | — | — |  |
| (4) Dpp_high — Sprawl — treatment standardized beta | Sprawl growth = 0.215 | VERIFIED | `output/ed_figure_standardized_coefficients.csv` (2026-09-17 11:01:32) | — | — |  |
| (4) Dpp_high — Sprawl — N | 314 | VERIFIED | `output/ed_figure_standardized_coefficients.csv` (2026-09-17 11:01:32) | — | — |  |

## Stage 02 / stage 03 coverage

| Item | Value | Status | Source (file, mtime) | results_used.md (July) | Changed by | Note |
|---|---|---|---|---|---|---|
| Municipalities in the stage-02 high-susceptibility summary | 703 | VERIFIED | `data/processed_data/02_hazard_zones/resumo_municipal_suscept_alta_agsn.csv` (2026-08-25 22:49:27) | — | — |  |
| Exposed population 2010 (stage 02, area-weighted) | 13,341,594 | VERIFIED | `data/processed_data/02_hazard_zones/resumo_municipal_suscept_alta_agsn.csv` (2026-08-25 22:49:27) | — | — | `pop_suscept = populacao × prop_suscept`, national sum over the summary's municipalities |
| Exposed population 2022 (stage 02, area-weighted) | 14,192,370 | VERIFIED | `data/processed_data/02_hazard_zones/resumo_municipal_suscept_alta_agsn.csv` (2026-08-25 22:49:27) | — | — |  |
| Municipalities with CPRM mapped risk (stage 02) | 1,586 | VERIFIED | `data/processed_data/02_hazard_zones/resumo_municipal_risco_agsn.csv` (2026-08-26 01:46:30) | — | — | produced by stage 02; no live consumer since 6f.1 |
| Municipalities in stage-03 metrics | 629 | VERIFIED | `data/processed_data/03_urban_footprint/metricas/metricas_municipio_2010_2022.csv` (2026-09-14 18:20:03) | — | — |  |
| Arrangements emitted by stage-03 script 07 | 210 | VERIFIED | `data/processed_data/03_urban_footprint/metricas/metricas_arranjo_2010_2022.csv` (2026-09-14 18:20:04) | — | — | not the stage-04 arrangement count: `13_dependent_variables.R:80–83` filters to the qualified CD_CIDADEs and `15_final_dataset.R:123–127` re-adds the isolated ones |

## Robustness — minimum-baseline sweep

| Item | Value | Status | Source (file, mtime) | results_used.md (July) | Changed by | Note |
|---|---|---|---|---|---|---|
| cut > 100 — arrangement — (1) g_high — Compact | -0.2933 (SE 0.2137), N = 188 | VERIFIED | `data/processed_data/04_regression/figures/sensitivity_min_pop_risco.csv` (2026-09-17 11:17:22) | — | — |  |
| cut > 200 — arrangement — (1) g_high — Compact | -0.2821 (SE 0.2143), N = 183 | VERIFIED | `data/processed_data/04_regression/figures/sensitivity_min_pop_risco.csv` (2026-09-17 11:17:22) | — | — | pipeline reference cut |
| cut > 500 — arrangement — (1) g_high — Compact | -0.2664 (SE 0.2103), N = 169 | VERIFIED | `data/processed_data/04_regression/figures/sensitivity_min_pop_risco.csv` (2026-09-17 11:17:22) | — | — |  |
| cut > 1000 — arrangement — (1) g_high — Compact | -0.1283 (SE 0.1789), N = 148 | VERIFIED | `data/processed_data/04_regression/figures/sensitivity_min_pop_risco.csv` (2026-09-17 11:17:22) | — | — |  |
| cut > 100 — arrangement — (2) g_high — Sprawl | 0.3716* (SE 0.2131), N = 188 | VERIFIED | `data/processed_data/04_regression/figures/sensitivity_min_pop_risco.csv` (2026-09-17 11:17:22) | — | — |  |
| cut > 200 — arrangement — (2) g_high — Sprawl | 0.3349 (SE 0.2119), N = 183 | VERIFIED | `data/processed_data/04_regression/figures/sensitivity_min_pop_risco.csv` (2026-09-17 11:17:22) | — | — | pipeline reference cut |
| cut > 500 — arrangement — (2) g_high — Sprawl | 0.2908 (SE 0.2049), N = 169 | VERIFIED | `data/processed_data/04_regression/figures/sensitivity_min_pop_risco.csv` (2026-09-17 11:17:22) | — | — |  |
| cut > 1000 — arrangement — (2) g_high — Sprawl | 0.4081** (SE 0.2018), N = 148 | VERIFIED | `data/processed_data/04_regression/figures/sensitivity_min_pop_risco.csv` (2026-09-17 11:17:22) | — | — |  |
| cut > 100 — arrangement — (3) Dpp_high — Compact | -0.0035 (SE 0.0120), N = 188 | VERIFIED | `data/processed_data/04_regression/figures/sensitivity_min_pop_risco.csv` (2026-09-17 11:17:22) | — | — |  |
| cut > 200 — arrangement — (3) Dpp_high — Compact | -0.0048 (SE 0.0123), N = 183 | VERIFIED | `data/processed_data/04_regression/figures/sensitivity_min_pop_risco.csv` (2026-09-17 11:17:22) | — | — | pipeline reference cut |
| cut > 500 — arrangement — (3) Dpp_high — Compact | -0.0066 (SE 0.0132), N = 169 | VERIFIED | `data/processed_data/04_regression/figures/sensitivity_min_pop_risco.csv` (2026-09-17 11:17:22) | — | — |  |
| cut > 1000 — arrangement — (3) Dpp_high — Compact | -0.0110 (SE 0.0151), N = 148 | VERIFIED | `data/processed_data/04_regression/figures/sensitivity_min_pop_risco.csv` (2026-09-17 11:17:22) | — | — |  |
| cut > 100 — arrangement — (4) Dpp_high — Sprawl | 0.0250 (SE 0.0156), N = 188 | VERIFIED | `data/processed_data/04_regression/figures/sensitivity_min_pop_risco.csv` (2026-09-17 11:17:22) | — | — |  |
| cut > 200 — arrangement — (4) Dpp_high — Sprawl | 0.0251 (SE 0.0156), N = 183 | VERIFIED | `data/processed_data/04_regression/figures/sensitivity_min_pop_risco.csv` (2026-09-17 11:17:22) | — | — | pipeline reference cut |
| cut > 500 — arrangement — (4) Dpp_high — Sprawl | 0.0272 (SE 0.0166), N = 169 | VERIFIED | `data/processed_data/04_regression/figures/sensitivity_min_pop_risco.csv` (2026-09-17 11:17:22) | — | — |  |
| cut > 1000 — arrangement — (4) Dpp_high — Sprawl | 0.0265 (SE 0.0189), N = 148 | VERIFIED | `data/processed_data/04_regression/figures/sensitivity_min_pop_risco.csv` (2026-09-17 11:17:22) | — | — |  |
| cut > 100 — municipality — (1) g_high — Compact | 0.0608 (SE 0.1527), N = 320 | VERIFIED | `data/processed_data/04_regression/figures/sensitivity_min_pop_risco.csv` (2026-09-17 11:17:22) | — | — |  |
| cut > 200 — municipality — (1) g_high — Compact | 0.0700 (SE 0.1502), N = 314 | VERIFIED | `data/processed_data/04_regression/figures/sensitivity_min_pop_risco.csv` (2026-09-17 11:17:22) | — | — | pipeline reference cut |
| cut > 500 — municipality — (1) g_high — Compact | 0.0163 (SE 0.1380), N = 295 | VERIFIED | `data/processed_data/04_regression/figures/sensitivity_min_pop_risco.csv` (2026-09-17 11:17:22) | — | — |  |
| cut > 1000 — municipality — (1) g_high — Compact | 0.1012 (SE 0.1240), N = 265 | VERIFIED | `data/processed_data/04_regression/figures/sensitivity_min_pop_risco.csv` (2026-09-17 11:17:22) | — | — |  |
| cut > 100 — municipality — (2) g_high — Sprawl | 0.2473* (SE 0.1402), N = 320 | VERIFIED | `data/processed_data/04_regression/figures/sensitivity_min_pop_risco.csv` (2026-09-17 11:17:22) | — | — |  |
| cut > 200 — municipality — (2) g_high — Sprawl | 0.2396* (SE 0.1405), N = 314 | VERIFIED | `data/processed_data/04_regression/figures/sensitivity_min_pop_risco.csv` (2026-09-17 11:17:22) | — | — | pipeline reference cut |
| cut > 500 — municipality — (2) g_high — Sprawl | 0.3056*** (SE 0.1058), N = 295 | VERIFIED | `data/processed_data/04_regression/figures/sensitivity_min_pop_risco.csv` (2026-09-17 11:17:22) | — | — |  |
| cut > 1000 — municipality — (2) g_high — Sprawl | 0.3177*** (SE 0.0979), N = 265 | VERIFIED | `data/processed_data/04_regression/figures/sensitivity_min_pop_risco.csv` (2026-09-17 11:17:22) | — | — |  |
| cut > 100 — municipality — (3) Dpp_high — Compact | 0.0132* (SE 0.0080), N = 320 | VERIFIED | `data/processed_data/04_regression/figures/sensitivity_min_pop_risco.csv` (2026-09-17 11:17:22) | — | — |  |
| cut > 200 — municipality — (3) Dpp_high — Compact | 0.0135* (SE 0.0081), N = 314 | VERIFIED | `data/processed_data/04_regression/figures/sensitivity_min_pop_risco.csv` (2026-09-17 11:17:22) | — | — | pipeline reference cut |
| cut > 500 — municipality — (3) Dpp_high — Compact | 0.0136 (SE 0.0087), N = 295 | VERIFIED | `data/processed_data/04_regression/figures/sensitivity_min_pop_risco.csv` (2026-09-17 11:17:22) | — | — |  |
| cut > 1000 — municipality — (3) Dpp_high — Compact | 0.0136 (SE 0.0096), N = 265 | VERIFIED | `data/processed_data/04_regression/figures/sensitivity_min_pop_risco.csv` (2026-09-17 11:17:22) | — | — |  |
| cut > 100 — municipality — (4) Dpp_high — Sprawl | 0.0220** (SE 0.0096), N = 320 | VERIFIED | `data/processed_data/04_regression/figures/sensitivity_min_pop_risco.csv` (2026-09-17 11:17:22) | — | — |  |
| cut > 200 — municipality — (4) Dpp_high — Sprawl | 0.0223** (SE 0.0097), N = 314 | VERIFIED | `data/processed_data/04_regression/figures/sensitivity_min_pop_risco.csv` (2026-09-17 11:17:22) | — | — | pipeline reference cut |
| cut > 500 — municipality — (4) Dpp_high — Sprawl | 0.0251** (SE 0.0103), N = 295 | VERIFIED | `data/processed_data/04_regression/figures/sensitivity_min_pop_risco.csv` (2026-09-17 11:17:22) | — | — |  |
| cut > 1000 — municipality — (4) Dpp_high — Sprawl | 0.0269** (SE 0.0115), N = 265 | VERIFIED | `data/processed_data/04_regression/figures/sensitivity_min_pop_risco.csv` (2026-09-17 11:17:22) | — | — |  |
| STABILITY — arrangement — (1) g_high — Compact | sign STABLE (−); significance STABLE (n.s. at every cut) | VERIFIED | `data/processed_data/04_regression/figures/sensitivity_min_pop_risco.csv` (2026-09-17 11:17:22) | — | — | per cut — 100: -0.2933 n.s.; 200: -0.2821 n.s.; 500: -0.2664 n.s.; 1000: -0.1283 n.s.. Estimate range -0.2933 to -0.1283 across cuts 100–1000. |
| STABILITY — arrangement — (2) g_high — Sprawl | sign STABLE (+); significance CHANGES (10% / n.s. / 5%) | VERIFIED | `data/processed_data/04_regression/figures/sensitivity_min_pop_risco.csv` (2026-09-17 11:17:22) | — | — | per cut — 100: 0.3716 10%; 200: 0.3349 n.s.; 500: 0.2908 n.s.; 1000: 0.4081 5%. Estimate range 0.2908 to 0.4081 across cuts 100–1000. |
| STABILITY — arrangement — (3) Dpp_high — Compact | sign STABLE (−); significance STABLE (n.s. at every cut) | VERIFIED | `data/processed_data/04_regression/figures/sensitivity_min_pop_risco.csv` (2026-09-17 11:17:22) | — | — | per cut — 100: -0.0035 n.s.; 200: -0.0048 n.s.; 500: -0.0066 n.s.; 1000: -0.0110 n.s.. Estimate range -0.0110 to -0.0035 across cuts 100–1000. |
| STABILITY — arrangement — (4) Dpp_high — Sprawl | sign STABLE (+); significance STABLE (n.s. at every cut) | VERIFIED | `data/processed_data/04_regression/figures/sensitivity_min_pop_risco.csv` (2026-09-17 11:17:22) | — | — | per cut — 100: 0.0250 n.s.; 200: 0.0251 n.s.; 500: 0.0272 n.s.; 1000: 0.0265 n.s.. Estimate range 0.0250 to 0.0272 across cuts 100–1000. |
| STABILITY — municipality — (1) g_high — Compact | sign STABLE (+); significance STABLE (n.s. at every cut) | VERIFIED | `data/processed_data/04_regression/figures/sensitivity_min_pop_risco.csv` (2026-09-17 11:17:22) | — | — | per cut — 100: 0.0608 n.s.; 200: 0.0700 n.s.; 500: 0.0163 n.s.; 1000: 0.1012 n.s.. Estimate range 0.0163 to 0.1012 across cuts 100–1000. |
| STABILITY — municipality — (2) g_high — Sprawl | sign STABLE (+); significance CHANGES (10% / 1%) | VERIFIED | `data/processed_data/04_regression/figures/sensitivity_min_pop_risco.csv` (2026-09-17 11:17:22) | — | — | per cut — 100: 0.2473 10%; 200: 0.2396 10%; 500: 0.3056 1%; 1000: 0.3177 1%. Estimate range 0.2396 to 0.3177 across cuts 100–1000. |
| STABILITY — municipality — (3) Dpp_high — Compact | sign STABLE (+); significance CHANGES (10% / n.s.) | VERIFIED | `data/processed_data/04_regression/figures/sensitivity_min_pop_risco.csv` (2026-09-17 11:17:22) | — | — | per cut — 100: 0.0132 10%; 200: 0.0135 10%; 500: 0.0136 n.s.; 1000: 0.0136 n.s.. Estimate range 0.0132 to 0.0136 across cuts 100–1000. |
| STABILITY — municipality — (4) Dpp_high — Sprawl | sign STABLE (+); significance STABLE (5% at every cut) | VERIFIED | `data/processed_data/04_regression/figures/sensitivity_min_pop_risco.csv` (2026-09-17 11:17:22) | — | — | per cut — 100: 0.0220 5%; 200: 0.0223 5%; 500: 0.0251 5%; 1000: 0.0269 5%. Estimate range 0.0220 to 0.0269 across cuts 100–1000. |
| Specifications whose SIGN changes across the sweep | 0 of 8 | VERIFIED | `data/processed_data/04_regression/figures/sensitivity_min_pop_risco.csv` (2026-09-17 11:17:22) | — | — | cuts swept: 100, 200, 500, 1000 |
| Specifications whose SIGNIFICANCE TIER changes across the sweep | 3 of 8 | VERIFIED | `data/processed_data/04_regression/figures/sensitivity_min_pop_risco.csv` (2026-09-17 11:17:22) | — | — | tier = the star the tables print (1%, 5%, 10%, n.s.). A tier change can be a precision effect rather than an estimate moving -- the per-cut estimates are in the STABILITY rows above. |
| cut > 100 — sample retained | municipalities 358, arrangements 188 | VERIFIED | `data/processed_data/04_regression/figures/sensitivity_min_pop_risco_sample_sizes.csv` (2026-09-17 11:17:22) | — | — |  |
| cut > 200 — sample retained | municipalities 350, arrangements 183 | VERIFIED | `data/processed_data/04_regression/figures/sensitivity_min_pop_risco_sample_sizes.csv` (2026-09-17 11:17:22) | — | — |  |
| cut > 500 — sample retained | municipalities 324, arrangements 169 | VERIFIED | `data/processed_data/04_regression/figures/sensitivity_min_pop_risco_sample_sizes.csv` (2026-09-17 11:17:22) | — | — |  |
| cut > 1000 — sample retained | municipalities 288, arrangements 148 | VERIFIED | `data/processed_data/04_regression/figures/sensitivity_min_pop_risco_sample_sizes.csv` (2026-09-17 11:17:22) | — | — |  |

---

Regenerate: `Rscript 05_exhibits/build_results_targets.R` (commit ffd2656).
