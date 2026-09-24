# results_targets_v2.md — values, provenance, status

**GENERATED FILE. Do not edit by hand.** Produced by `05_exhibits/build_results_targets.R`;
every run overwrites it. Hand edits are lost. To change a value, change the pipeline and re-run.

This file holds values, their provenance and their status. It contains no interpretation.

## Run header

- Generated: **2026-09-23 18:33:01 -03**
- Repository commit: **130ee7f** — working tree has uncommitted changes
- Stage-04 reference clock: **2026-09-23 14:24:10** (`data/processed_data/04_regression/model_objects_table2.rds`)
- Staleness tolerance: 3600 seconds
- `MIN_POP_RISCO_2010` (from `00_setup.R`): **200**

### Input manifest

| Input | Path | mtime | Position | State |
|---|---|---|---|---|
| OPTIONAL archived pre-6f ED Table 3 coefficients (supplied by hand, if at all) | `data/processed_data/04_regression/pre_6f_ed_table3_coefficients.csv` | — | exempt | MISSING |
| minimum-baseline sweep, sample sizes (robustness/minimum_population_filter.R) | `data/processed_data/04_regression/figures/sensitivity_min_pop_risco_sample_sizes.csv` | 2026-09-17 11:17:22 | downstream | STALE |
| minimum-baseline sweep (robustness/minimum_population_filter.R) | `data/processed_data/04_regression/figures/sensitivity_min_pop_risco.csv` | 2026-09-17 11:17:22 | downstream | STALE |
| stage 02 municipal summary, high susceptibility (03_cross_grid_high_susceptibility.py) | `data/processed_data/02_hazard_zones/resumo_municipal_suscept_alta_agsn.csv` | 2026-08-25 22:49:27 | upstream | ok |
| stage 02 municipal summary, CPRM risk (04_cross_grid_cprm_risk.py) | `data/processed_data/02_hazard_zones/resumo_municipal_risco_agsn.csv` | 2026-08-26 01:46:30 | upstream | ok |
| stage 03 sample (01_define_sample.R) | `data/processed_data/03_urban_footprint/amostra_municipios.rds` | 2026-09-22 16:11:16 | upstream | ok |
| stage 03 classified grid (05_classify_growth_types.R) | `data/processed_data/03_urban_footprint/crescimento_urbano/grade_growth_types_2010_2022.parquet` | 2026-09-22 21:13:26 | upstream | ok |
| stage 03 arrangement metrics (07_aggregate_municipality_metrics.R) | `data/processed_data/03_urban_footprint/metricas/metricas_arranjo_2010_2022.csv` | 2026-09-22 22:31:58 | upstream | ok |
| stage 03 municipality metrics (07_aggregate_municipality_metrics.R) | `data/processed_data/03_urban_footprint/metricas/metricas_municipio_2010_2022.csv` | 2026-09-22 22:31:58 | upstream | ok |
| stage 04 qualified-arrangement members (01_compose_sample.R) | `data/processed_data/04_regression/amostra_arr.csv` | 2026-09-23 08:45:45 | upstream | ok |
| stage 04 municipality sample (01_compose_sample.R) | `data/processed_data/04_regression/amostra_mun.csv` | 2026-09-23 08:45:45 | upstream | ok |
| stage 04 processing universe (01_compose_sample.R) | `data/processed_data/04_regression/amostra_universo.csv` | 2026-09-23 08:45:46 | upstream | ok |
| stage 04 arrangement regression dataset (15_final_dataset.R) | `data/processed_data/04_regression/tables/dataset_regressao_arranjo.csv` | 2026-09-23 14:24:02 | upstream | ok |
| stage 04 municipality regression dataset (15_final_dataset.R) | `data/processed_data/04_regression/tables/dataset_regressao_municipio.csv` | 2026-09-23 14:24:02 | upstream | ok |
| stage 04 fitted models + metadata (16_estimate_models.R) | `data/processed_data/04_regression/model_objects_table2.rds` | 2026-09-23 14:24:10 | upstream | ok |
| stage 04 isolated municipalities (01_compose_sample.R) | `data/processed_data/04_regression/mun_isol.csv` | 2026-09-23 08:45:45 | upstream | ok |
| Appendix descriptives, arrangement level (ed_table_descriptive_statistics.R) | `output/ed_table_descriptives_arrangement.csv` | 2026-09-23 17:44:59 | downstream | ok |
| Appendix descriptives, municipality level (ed_table_descriptive_statistics.R) | `output/ed_table_descriptives_municipality.csv` | 2026-09-23 17:44:59 | downstream | ok |
| ED Figure standardized betas (ed_figure_standardized_coefficients.R) | `output/ed_figure_standardized_coefficients.csv` | 2026-09-23 17:44:55 | downstream | ok |
| Figure 1 layers (figure1_growth_type_layers.R) | `data/processed_data/03_urban_footprint/figuras/figura1_camadas.parquet` | 2026-09-23 17:41:51 | downstream | ok |
| Figure 2 statistics, row '(a) the figure' (figure2_exposure_scatter.R) | `output/figure2_sample_variants.csv` | 2026-09-23 17:44:20 | downstream | ok |
| Table 1a (table1_population_by_growth_type.R) | `output/tabela1a_populacao_totais_tipo.csv` | 2026-09-23 17:40:01 | downstream | ok |
| Table 1b (table1_population_by_growth_type.R) | `output/tabela1_populacao_risco_tipo.csv` | 2026-09-23 17:40:01 | downstream | ok |

**Entries: 211 total, 205 VERIFIED, 6 PENDING.**

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
| Processing universe (municipalities) | 629 | VERIFIED | `data/processed_data/04_regression/amostra_universo.csv` (2026-09-23 08:45:46) | — | 6f.1 (CPRM union removed from stage 03's sample definition) |  |
| amostra_mun (tem_susceptibilidade == TRUE) | 395 | VERIFIED | `data/processed_data/04_regression/amostra_mun.csv` (2026-09-23 08:45:45) | — | — | `01_compose_sample.R:41` |
| Isolated municipalities | 110 | VERIFIED | `data/processed_data/04_regression/mun_isol.csv` (2026-09-23 08:45:45) | — | — | `01_compose_sample.R:42` |
| Qualified arrangements (CD_CIDADE) | 100 | VERIFIED | `data/processed_data/04_regression/amostra_arr.csv` (2026-09-23 08:45:45) | — | — | `01_compose_sample.R:75–87` |
| Members of qualified arrangements | 519 | VERIFIED | `data/processed_data/04_regression/amostra_arr.csv` (2026-09-23 08:45:45) | — | — |  |
| FUA entities (arrangements + isolated) | 210 | VERIFIED | `data/processed_data/04_regression/amostra_arr.csv` (2026-09-23 08:45:45) + `data/processed_data/04_regression/mun_isol.csv` (2026-09-23 08:45:45) | 206 (results_used.md L11) | 6b0, 6f.1 — `01_compose_sample.R:92–93` counts `n_distinct(CD_CIDADE) + nrow(mun_isol)` | counting `amostra_arr.csv` alone omits the isolated FUAs |
| dataset_regressao_municipio.csv rows | 395 | VERIFIED | `data/processed_data/04_regression/tables/dataset_regressao_municipio.csv` (2026-09-23 14:24:02) | 387 (results_used.md L11) | 6b0 — under the common grid every row has a valid `delta_pp_alta` |  |
| dataset_regressao_arranjo.csv rows | 210 | VERIFIED | `data/processed_data/04_regression/tables/dataset_regressao_arranjo.csv` (2026-09-23 14:24:02) | — | — |  |
| After pop_2010_risk_total > MIN_POP_RISCO_2010 (municipalities) | 350 | VERIFIED | `data/processed_data/04_regression/tables/dataset_regressao_municipio.csv` (2026-09-23 14:24:02) | — | 6c1 revised 2026-09-12; cut = 200 |  |
| After pop_2010_risk_total > MIN_POP_RISCO_2010 (arrangements) | 183 | VERIFIED | `data/processed_data/04_regression/tables/dataset_regressao_arranjo.csv` (2026-09-23 14:24:02) | — | 6c1 revised 2026-09-12; cut = 200 |  |
| MIN_POP_RISCO_2010 applied at estimation | 200 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-23 14:24:10) | no cut (results_used.md states none) | 6c1, decided 2026-09-08 at 1000, revised 2026-09-12 to 200 |  |
| Municipalities before the cut (metadata) | 395 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-23 14:24:10) | — | — |  |
| Municipalities after the cut (metadata) | 350 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-23 14:24:10) | — | — |  |
| Centro-Oeste municipalities dropped (region columns) | 7 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-23 14:24:10) | — | 6c2, decided 2026-09-10 |  |
| Estimation timestamp (metadata) | 2026-09-23 14:24:06 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-23 14:24:10) | — | — |  |

## Table 1 — population and exposure by growth type

| Item | Value | Status | Source (file, mtime) | results_used.md (July) | Changed by | Note |
|---|---|---|---|---|---|---|
| Consolidated — pop_2010 | 59,398,950 | VERIFIED | `output/tabela1a_populacao_totais_tipo.csv` (2026-09-23 17:40:01) | 59,138,249 | 6b0 (common grid), 6e (exposure weighting), 6f.1/6f.2 |  |
| Consolidated — pop_2022 | 55,188,718 | VERIFIED | `output/tabela1a_populacao_totais_tipo.csv` (2026-09-23 17:40:01) | 55,634,711 | 6b0, 6e, 6f.1/6f.2 |  |
| Consolidated — risco_2010 | 7,021,298 | VERIFIED | `output/tabela1a_populacao_totais_tipo.csv` (2026-09-23 17:40:01) | 15,627,912 | 6e (area weighting replaces any-overlap) |  |
| Consolidated — risco_2022 | 6,505,323 | VERIFIED | `output/tabela1a_populacao_totais_tipo.csv` (2026-09-23 17:40:01) | 14,632,292 | 6e |  |
| Consolidated — % at risk 2010 | 11.8% | VERIFIED | `output/tabela1a_populacao_totais_tipo.csv` (2026-09-23 17:40:01) | 26.4% | 6e |  |
| Consolidated — % at risk 2022 | 11.8% | VERIFIED | `output/tabela1a_populacao_totais_tipo.csv` (2026-09-23 17:40:01) | 26.3% | 6e |  |
| Consolidated — change in risk pop. | -515,975 | VERIFIED | `output/tabela1a_populacao_totais_tipo.csv` (2026-09-23 17:40:01) | -995,620 (derived from its components) | 6e |  |
| Compact — pop_2010 | 27,215,535 | VERIFIED | `output/tabela1a_populacao_totais_tipo.csv` (2026-09-23 17:40:01) | 27,367,825 | 6b0 (common grid), 6e (exposure weighting), 6f.1/6f.2 |  |
| Compact — pop_2022 | 33,529,176 | VERIFIED | `output/tabela1a_populacao_totais_tipo.csv` (2026-09-23 17:40:01) | 36,107,824 | 6b0, 6e, 6f.1/6f.2 |  |
| Compact — risco_2010 | 3,515,050 | VERIFIED | `output/tabela1a_populacao_totais_tipo.csv` (2026-09-23 17:40:01) | 8,625,881 | 6e (area weighting replaces any-overlap) |  |
| Compact — risco_2022 | 4,313,988 | VERIFIED | `output/tabela1a_populacao_totais_tipo.csv` (2026-09-23 17:40:01) | 10,779,228 | 6e |  |
| Compact — % at risk 2010 | 12.9% | VERIFIED | `output/tabela1a_populacao_totais_tipo.csv` (2026-09-23 17:40:01) | 31.5% | 6e |  |
| Compact — % at risk 2022 | 12.9% | VERIFIED | `output/tabela1a_populacao_totais_tipo.csv` (2026-09-23 17:40:01) | 29.9% | 6e |  |
| Compact — change in risk pop. | 798,937 | VERIFIED | `output/tabela1a_populacao_totais_tipo.csv` (2026-09-23 17:40:01) | 2,153,347 | 6e |  |
| Sprawl — pop_2010 | 3,004,720 | VERIFIED | `output/tabela1a_populacao_totais_tipo.csv` (2026-09-23 17:40:01) | 2,900,879 | 6b0 (common grid), 6e (exposure weighting), 6f.1/6f.2 |  |
| Sprawl — pop_2022 | 9,135,551 | VERIFIED | `output/tabela1a_populacao_totais_tipo.csv` (2026-09-23 17:40:01) | 6,104,483 | 6b0, 6e, 6f.1/6f.2 |  |
| Sprawl — risco_2010 | 405,420 | VERIFIED | `output/tabela1a_populacao_totais_tipo.csv` (2026-09-23 17:40:01) | 988,462 | 6e (area weighting replaces any-overlap) |  |
| Sprawl — risco_2022 | 1,066,865 | VERIFIED | `output/tabela1a_populacao_totais_tipo.csv` (2026-09-23 17:40:01) | 1,908,404 | 6e |  |
| Sprawl — % at risk 2010 | 13.5% | VERIFIED | `output/tabela1a_populacao_totais_tipo.csv` (2026-09-23 17:40:01) | 34.1% | 6e |  |
| Sprawl — % at risk 2022 | 11.7% | VERIFIED | `output/tabela1a_populacao_totais_tipo.csv` (2026-09-23 17:40:01) | 31.3% | 6e |  |
| Sprawl — change in risk pop. | 661,445 | VERIFIED | `output/tabela1a_populacao_totais_tipo.csv` (2026-09-23 17:40:01) | 919,942 | 6e |  |
| Total — pop_2010 | 89,619,205 | VERIFIED | `output/tabela1a_populacao_totais_tipo.csv` (2026-09-23 17:40:01) | 89,406,953 | 6b0 (common grid), 6e (exposure weighting), 6f.1/6f.2 |  |
| Total — pop_2022 | 97,853,445 | VERIFIED | `output/tabela1a_populacao_totais_tipo.csv` (2026-09-23 17:40:01) | 97,847,018 | 6b0, 6e, 6f.1/6f.2 |  |
| Total — risco_2010 | 10,941,768 | VERIFIED | `output/tabela1a_populacao_totais_tipo.csv` (2026-09-23 17:40:01) | 25,242,255 | 6e (area weighting replaces any-overlap) |  |
| Total — risco_2022 | 11,886,175 | VERIFIED | `output/tabela1a_populacao_totais_tipo.csv` (2026-09-23 17:40:01) | 27,319,924 | 6e |  |
| Total — % at risk 2010 | 12.2% | VERIFIED | `output/tabela1a_populacao_totais_tipo.csv` (2026-09-23 17:40:01) | 28.2% (derived from its components) | 6e |  |
| Total — % at risk 2022 | 12.1% | VERIFIED | `output/tabela1a_populacao_totais_tipo.csv` (2026-09-23 17:40:01) | 27.9% (derived from its components) | 6e |  |
| Total — change in risk pop. | 944,407 | VERIFIED | `output/tabela1a_populacao_totais_tipo.csv` (2026-09-23 17:40:01) | 2,077,669 (derived from its components) | 6e |  |
| Compact — % of new residents going to risk | 12.7% | VERIFIED | `output/tabela1a_populacao_totais_tipo.csv` (2026-09-23 17:40:01) | 25% | 6b0, 6e | derived from the Table 1a CSV, same arithmetic as `table1_population_by_growth_type.R` |
| Sprawl — % of new residents going to risk | 10.8% | VERIFIED | `output/tabela1a_populacao_totais_tipo.csv` (2026-09-23 17:40:01) | 29% | 6b0, 6e | derived from the Table 1a CSV |
| Compact share of the net increase in at-risk pop. (Compact+Sprawl) | 54.7% | VERIFIED | `output/tabela1a_populacao_totais_tipo.csv` (2026-09-23 17:40:01) | 70% (2.2M of 3.1M) | 6b0, 6e | derived from the Table 1a CSV |
| Aggregate growth — total population | 9.2% | VERIFIED | `output/tabela1a_populacao_totais_tipo.csv` (2026-09-23 17:40:01) | +9.4% | 6b0 | derived from the Table 1a CSV |
| Aggregate growth — population at risk | 8.6% | VERIFIED | `output/tabela1a_populacao_totais_tipo.csv` (2026-09-23 17:40:01) | +8.2% | 6e | derived from the Table 1a CSV |
| Consolidated — change in high susceptibility (M) | -0.516 | VERIFIED | `output/tabela1_populacao_risco_tipo.csv` (2026-09-23 17:40:01) | -1.000 | 6b0, 6e |  |
| Consolidated — change outside high susceptibility (M) | -3.694 | VERIFIED | `output/tabela1_populacao_risco_tipo.csv` (2026-09-23 17:40:01) | -2.510 | 6b0, 6e |  |
| Consolidated — total change (M) | -4.210 | VERIFIED | `output/tabela1_populacao_risco_tipo.csv` (2026-09-23 17:40:01) | — | 6b0 |  |
| Compact — change in high susceptibility (M) | 0.799 | VERIFIED | `output/tabela1_populacao_risco_tipo.csv` (2026-09-23 17:40:01) | 2.150 | 6b0, 6e |  |
| Compact — change outside high susceptibility (M) | 5.515 | VERIFIED | `output/tabela1_populacao_risco_tipo.csv` (2026-09-23 17:40:01) | 6.590 | 6b0, 6e |  |
| Compact — total change (M) | 6.314 | VERIFIED | `output/tabela1_populacao_risco_tipo.csv` (2026-09-23 17:40:01) | — | 6b0 |  |
| Sprawl — change in high susceptibility (M) | 0.661 | VERIFIED | `output/tabela1_populacao_risco_tipo.csv` (2026-09-23 17:40:01) | 0.920 | 6b0, 6e |  |
| Sprawl — change outside high susceptibility (M) | 5.469 | VERIFIED | `output/tabela1_populacao_risco_tipo.csv` (2026-09-23 17:40:01) | 2.280 | 6b0, 6e |  |
| Sprawl — total change (M) | 6.131 | VERIFIED | `output/tabela1_populacao_risco_tipo.csv` (2026-09-23 17:40:01) | — | 6b0 |  |

## Figure 1 — growth-type layers

| Item | Value | Status | Source (file, mtime) | results_used.md (July) | Changed by | Note |
|---|---|---|---|---|---|---|
| Total cells | 3,092,892 | VERIFIED | `data/processed_data/03_urban_footprint/figuras/figura1_camadas.parquet` (2026-09-23 17:41:51) | — | — | recomputed here, not read from an exhibit output; mirrors `figure1_growth_type_layers.R` §2; source layer `data/processed_data/03_urban_footprint/figuras/figura1_camadas.parquet` |
| grupo_3tipos — consolidated | 180,611 | VERIFIED | `data/processed_data/03_urban_footprint/figuras/figura1_camadas.parquet` (2026-09-23 17:41:51) | — | — | recomputed here, not read from an exhibit output; mirrors `figure1_growth_type_layers.R` §2; source layer `data/processed_data/03_urban_footprint/figuras/figura1_camadas.parquet` |
| grupo_3tipos — compact | 154,183 | VERIFIED | `data/processed_data/03_urban_footprint/figuras/figura1_camadas.parquet` (2026-09-23 17:41:51) | — | — | recomputed here, not read from an exhibit output; mirrors `figure1_growth_type_layers.R` §2; source layer `data/processed_data/03_urban_footprint/figuras/figura1_camadas.parquet` |
| grupo_3tipos — sprawl | 91,736 | VERIFIED | `data/processed_data/03_urban_footprint/figuras/figura1_camadas.parquet` (2026-09-23 17:41:51) | — | — | recomputed here, not read from an exhibit output; mirrors `figure1_growth_type_layers.R` §2; source layer `data/processed_data/03_urban_footprint/figuras/figura1_camadas.parquet` |
| grupo_3tipos — NA | 2,666,362 | VERIFIED | `data/processed_data/03_urban_footprint/figuras/figura1_camadas.parquet` (2026-09-23 17:41:51) | — | — | recomputed here, not read from an exhibit output; mirrors `figure1_growth_type_layers.R` §2; source layer `data/processed_data/03_urban_footprint/figuras/figura1_camadas.parquet` |
| urban 2010 TRUE / 2020 TRUE | 361,396 | VERIFIED | `data/processed_data/03_urban_footprint/figuras/figura1_camadas.parquet` (2026-09-23 17:41:51) | — | — | recomputed here, not read from an exhibit output; mirrors `figure1_growth_type_layers.R` §2; source layer `data/processed_data/03_urban_footprint/figuras/figura1_camadas.parquet` |
| urban 2010 TRUE / 2020 FALSE | 10,505 | VERIFIED | `data/processed_data/03_urban_footprint/figuras/figura1_camadas.parquet` (2026-09-23 17:41:51) | — | — | recomputed here, not read from an exhibit output; mirrors `figure1_growth_type_layers.R` §2; source layer `data/processed_data/03_urban_footprint/figuras/figura1_camadas.parquet` |
| urban 2010 FALSE / 2020 TRUE | 55,527 | VERIFIED | `data/processed_data/03_urban_footprint/figuras/figura1_camadas.parquet` (2026-09-23 17:41:51) | — | — | recomputed here, not read from an exhibit output; mirrors `figure1_growth_type_layers.R` §2; source layer `data/processed_data/03_urban_footprint/figuras/figura1_camadas.parquet` |
| urban 2010 FALSE / 2020 FALSE | 2,665,464 | VERIFIED | `data/processed_data/03_urban_footprint/figuras/figura1_camadas.parquet` (2026-09-23 17:41:51) | — | — | recomputed here, not read from an exhibit output; mirrors `figure1_growth_type_layers.R` §2; source layer `data/processed_data/03_urban_footprint/figuras/figura1_camadas.parquet` |
| Derived-vs-real disagreement — urbano_2010 | 983 | VERIFIED | `data/processed_data/03_urban_footprint/figuras/figura1_camadas.parquet` (2026-09-23 17:41:51) | — | — | recomputed here, not read from an exhibit output; mirrors `figure1_growth_type_layers.R` §2; source layer `data/processed_data/03_urban_footprint/figuras/figura1_camadas.parquet` ; derived = tipo_crescimento in {consolidated, densification, peripheral} |
| Derived-vs-real disagreement — urbano_2020 | 11,307 | VERIFIED | `data/processed_data/03_urban_footprint/figuras/figura1_camadas.parquet` (2026-09-23 17:41:51) | — | — | recomputed here, not read from an exhibit output; mirrors `figure1_growth_type_layers.R` §2; source layer `data/processed_data/03_urban_footprint/figuras/figura1_camadas.parquet` ; derived = !is.na(tipo_crescimento) |
| Municipalities flagged em_amostra_regressao | 395 | VERIFIED | `data/processed_data/03_urban_footprint/figuras/figura1_camadas.parquet` (2026-09-23 17:41:51) | — | — | recomputed here, not read from an exhibit output; mirrors `figure1_growth_type_layers.R` §2; source layer `data/processed_data/03_urban_footprint/figuras/figura1_camadas.parquet` |

## Figure 2 — exposure scatter

| Item | Value | Status | Source (file, mtime) | results_used.md (July) | Changed by | Note |
|---|---|---|---|---|---|---|
| Sample rule | no pop_2010_risk_total cut; growth >= 200 in both types | VERIFIED | `output/figure2_sample_variants.csv` (2026-09-23 17:44:20) | — | decided 2026-09-21 (f8def75), reverses 6c2 | row '(a) the figure' of the exhibit's own CSV |
| Metrics municipalities (before any filter) | 629 | VERIFIED | `output/figure2_sample_variants.csv` (2026-09-23 17:44:20) | — | — | row '(a) the figure' of the exhibit's own CSV |
| Regression-dataset municipalities with metrics | 395 | VERIFIED | `output/figure2_sample_variants.csv` (2026-09-23 17:44:20) | — | — | row '(a) the figure' of the exhibit's own CSV |
| Final N (growth threshold met in both types) | 338 | VERIFIED | `output/figure2_sample_variants.csv` (2026-09-23 17:44:20) | 341 (results_used.md L50, '43% of 341 cities') | 6b0, 6e, sample rule of 2026-09-21 | row '(a) the figure' of the exhibit's own CSV ; this is the N printed in both subtitles |
| Dropped by the growth threshold | 57 | VERIFIED | `output/figure2_sample_variants.csv` (2026-09-23 17:44:20) | — | — | row '(a) the figure' of the exhibit's own CSV |
| Dropped — compact only / sprawl only / both | 54 / 2 / 1 | VERIFIED | `output/figure2_sample_variants.csv` (2026-09-23 17:44:20) | — | — | row '(a) the figure' of the exhibit's own CSV ; requiring growth in both types excludes municipalities that grew almost entirely one way |
| Median pct_risk_compact | 4.2% | VERIFIED | `output/figure2_sample_variants.csv` (2026-09-23 17:44:20) | 18.2% | 6b0, 6e, sample rule of 2026-09-21 | row '(a) the figure' of the exhibit's own CSV |
| Median pct_risk_sprawl | 6.6% | VERIFIED | `output/figure2_sample_variants.csv` (2026-09-23 17:44:20) | 20.9% | 6b0, 6e, sample rule of 2026-09-21 | row '(a) the figure' of the exhibit's own CSV |
| Median difference (compact − sprawl) | -0.006 | VERIFIED | `output/figure2_sample_variants.csv` (2026-09-23 17:44:20) | — | — | row '(a) the figure' of the exhibit's own CSV |
| Share below 45° line (compact > sprawl) | 38.8% | VERIFIED | `output/figure2_sample_variants.csv` (2026-09-23 17:44:20) | 43% | 6b0, 6e, sample rule of 2026-09-21 | row '(a) the figure' of the exhibit's own CSV |
| Wilcoxon signed-rank p | 0.0049 | VERIFIED | `output/figure2_sample_variants.csv` (2026-09-23 17:44:20) | — | — | row '(a) the figure' of the exhibit's own CSV |
| Fitted slope (clipped, the plotted line) | 0.639 | VERIFIED | `output/figure2_sample_variants.csv` (2026-09-23 17:44:20) | slope < 45° with positive intercept (no value stated) | 6b0, 6e, sample rule of 2026-09-21 | row '(a) the figure' of the exhibit's own CSV ; fitted on the [0,1]-clipped variables, as drawn |
| Fitted intercept (clipped) | 0.051 | VERIFIED | `output/figure2_sample_variants.csv` (2026-09-23 17:44:20) | — | — | row '(a) the figure' of the exhibit's own CSV |
| Fitted slope (unclipped) | 0.530 | VERIFIED | `output/figure2_sample_variants.csv` (2026-09-23 17:44:20) | — | — | row '(a) the figure' of the exhibit's own CSV ; the [0,1] clip is an open decision (pipeline_5.md §9) |
| Pearson correlation | 0.693 (p = 0.0000) | VERIFIED | `data/processed_data/03_urban_footprint/metricas/metricas_municipio_2010_2022.csv` (2026-09-22 22:31:58) + `data/processed_data/04_regression/tables/dataset_regressao_municipio.csv` (2026-09-23 14:24:02) | — | — | recomputed here (the CSV does not carry it) on growth >= 200 in both types; checked against the CSV's N and clipped slope ; on the unclipped ratios, as the script prints it |
| Spearman correlation | 0.677 (p = 0.0000) | VERIFIED | `data/processed_data/03_urban_footprint/metricas/metricas_municipio_2010_2022.csv` (2026-09-22 22:31:58) + `data/processed_data/04_regression/tables/dataset_regressao_municipio.csv` (2026-09-23 14:24:02) | — | — | recomputed here (the CSV does not carry it) on growth >= 200 in both types; checked against the CSV's N and clipped slope ; on the unclipped ratios, as the script prints it |
| Fitted slope SE (clipped) | 0.030 | VERIFIED | `data/processed_data/03_urban_footprint/metricas/metricas_municipio_2010_2022.csv` (2026-09-22 22:31:58) + `data/processed_data/04_regression/tables/dataset_regressao_municipio.csv` (2026-09-23 14:24:02) | — | — | recomputed here (the CSV does not carry it) on growth >= 200 in both types; checked against the CSV's N and clipped slope |
| Fitted R² (clipped) | 0.571 | VERIFIED | `data/processed_data/03_urban_footprint/metricas/metricas_municipio_2010_2022.csv` (2026-09-22 22:31:58) + `data/processed_data/04_regression/tables/dataset_regressao_municipio.csv` (2026-09-23 14:24:02) | — | — | recomputed here (the CSV does not carry it) on growth >= 200 in both types; checked against the CSV's N and clipped slope |

## Table 2 — main regressions (municipalities)

| Item | Value | Status | Source (file, mtime) | results_used.md (July) | Changed by | Note |
|---|---|---|---|---|---|---|
| (1) g_high — Compact — treatment coefficient | 0.0700 (SE 0.1502) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-23 14:24:10) | −0.026 n.s. | 6b0 (common grid), 6e (exposure weighting), 6c1 (sample cut) | term `pct_area_densif_infill_0010` |
| (1) g_high — Compact — N | 314 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-23 14:24:10) | — | — |  |
| (1) g_high — Compact — R² | 0.361 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-23 14:24:10) | — | — |  |
| (2) g_high — Sprawl — treatment coefficient | 0.2396* (SE 0.1405) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-23 14:24:10) | +0.103** | 6b0 (common grid), 6e (exposure weighting), 6c1 (sample cut) | term `pct_area_periph_ext_leap_0010` |
| (2) g_high — Sprawl — N | 314 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-23 14:24:10) | — | — |  |
| (2) g_high — Sprawl — R² | 0.366 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-23 14:24:10) | — | — |  |
| (3) Dpp_high — Compact — treatment coefficient | 0.0135* (SE 0.0081) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-23 14:24:10) | +0.040*** | 6b0 (common grid), 6e (exposure weighting), 6c1 (sample cut) | term `pct_area_densif_infill_0010` |
| (3) Dpp_high — Compact — N | 314 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-23 14:24:10) | — | — |  |
| (3) Dpp_high — Compact — R² | 0.275 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-23 14:24:10) | — | — |  |
| (4) Dpp_high — Sprawl — treatment coefficient | 0.0223** (SE 0.0097) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-23 14:24:10) | −0.021* | 6b0 (common grid), 6e (exposure weighting), 6c1 (sample cut) | term `pct_area_periph_ext_leap_0010` |
| (4) Dpp_high — Sprawl — N | 314 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-23 14:24:10) | — | — |  |
| (4) Dpp_high — Sprawl — R² | 0.284 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-23 14:24:10) | — | — |  |
| Comparability note | not comparable to N = 317 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-23 14:24:10) | — | — | 317 was produced under the any-overlap rule with a cut of 1000, both superseded. 6e lowered pop_2010_risk_total; the cut moved to 200. The two differences pull in opposite directions and do not cancel (MIGRATION_PLAN.md, 'On Table 2's N'). |
| Listwise deletion rule | complete.cases over ALL formula variables | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-23 14:24:10) | list-wise deletion on safe available land and steep terrain (results_used.md L11) | none — the code never did what results_used.md describes | `16_estimate_models.R:297–298`, applied per specification and AFTER the MIN_POP_RISCO_2010 cut (`:205–207`). This is why N varies by specification; results_used.md's Table 2 note names a narrower set than the code uses. |

## ED Table 2 — with / without housing-market mediators

| Item | Value | Status | Source (file, mtime) | results_used.md (July) | Changed by | Note |
|---|---|---|---|---|---|---|
| (1) g_high Compact — WITH mediators — treatment coefficient | 0.0700 (SE 0.1502) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-23 14:24:10) | — | — | term `pct_area_densif_infill_0010` |
| (1) g_high Compact — WITH mediators — N | 314 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-23 14:24:10) | — | — |  |
| (1) g_high Compact — WITH mediators — R² | 0.361 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-23 14:24:10) | — | — |  |
| (2) g_high Sprawl — WITH mediators — treatment coefficient | 0.2396* (SE 0.1405) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-23 14:24:10) | — | — | term `pct_area_periph_ext_leap_0010` |
| (2) g_high Sprawl — WITH mediators — N | 314 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-23 14:24:10) | — | — |  |
| (2) g_high Sprawl — WITH mediators — R² | 0.366 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-23 14:24:10) | — | — |  |
| (3) Dpp_high Compact — WITH mediators — treatment coefficient | 0.0135* (SE 0.0081) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-23 14:24:10) | — | — | term `pct_area_densif_infill_0010` |
| (3) Dpp_high Compact — WITH mediators — N | 314 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-23 14:24:10) | — | — |  |
| (3) Dpp_high Compact — WITH mediators — R² | 0.275 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-23 14:24:10) | — | — |  |
| (4) Dpp_high Sprawl — WITH mediators — treatment coefficient | 0.0223** (SE 0.0097) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-23 14:24:10) | — | — | term `pct_area_periph_ext_leap_0010` |
| (4) Dpp_high Sprawl — WITH mediators — N | 314 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-23 14:24:10) | — | — |  |
| (4) Dpp_high Sprawl — WITH mediators — R² | 0.284 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-23 14:24:10) | — | — |  |
| (5) g_high Compact — NO mediators — treatment coefficient | -0.0045 (SE 0.1660) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-23 14:24:10) | — | — | term `pct_area_densif_infill_0010` |
| (5) g_high Compact — NO mediators — N | 327 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-23 14:24:10) | — | — |  |
| (5) g_high Compact — NO mediators — R² | 0.364 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-23 14:24:10) | — | — |  |
| (6) g_high Sprawl — NO mediators — treatment coefficient | 0.0418 (SE 0.1577) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-23 14:24:10) | — | — | term `pct_area_periph_ext_leap_0010` |
| (6) g_high Sprawl — NO mediators — N | 327 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-23 14:24:10) | — | — |  |
| (6) g_high Sprawl — NO mediators — R² | 0.364 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-23 14:24:10) | — | — |  |
| (7) Dpp_high Compact — NO mediators — treatment coefficient | 0.0112 (SE 0.0088) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-23 14:24:10) | — | — | term `pct_area_densif_infill_0010` |
| (7) Dpp_high Compact — NO mediators — N | 327 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-23 14:24:10) | — | — |  |
| (7) Dpp_high Compact — NO mediators — R² | 0.109 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-23 14:24:10) | — | — |  |
| (8) Dpp_high Sprawl — NO mediators — treatment coefficient | -0.0028 (SE 0.0104) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-23 14:24:10) | — | — | term `pct_area_periph_ext_leap_0010` |
| (8) Dpp_high Sprawl — NO mediators — N | 327 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-23 14:24:10) | — | — |  |
| (8) Dpp_high Sprawl — NO mediators — R² | 0.106 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-23 14:24:10) | — | — |  |
| (9) g_high — Mediators ONLY (no treatment) — N | 314 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-23 14:24:10) | — | — |  |
| (9) g_high — Mediators ONLY (no treatment) — R² | 0.360 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-23 14:24:10) | — | — |  |
| (10) Dpp_high — Mediators ONLY (no treatment) — N | 314 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-23 14:24:10) | — | — |  |
| (10) Dpp_high — Mediators ONLY (no treatment) — R² | 0.270 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-23 14:24:10) | — | — |  |

## ED Table 3 — functional urban areas

| Item | Value | Status | Source (file, mtime) | results_used.md (July) | Changed by | Note |
|---|---|---|---|---|---|---|
| (1) g_high — Compact — N | 183 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-23 14:24:10) | — | — |  |
| (1) g_high — Compact — R² | 0.358 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-23 14:24:10) | — | — |  |
| (2) g_high — Sprawl — N | 183 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-23 14:24:10) | — | — |  |
| (2) g_high — Sprawl — R² | 0.358 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-23 14:24:10) | — | — |  |
| (3) Dpp_high — Compact — N | 183 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-23 14:24:10) | — | — |  |
| (3) Dpp_high — Compact — R² | 0.323 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-23 14:24:10) | — | — |  |
| (4) Dpp_high — Sprawl — N | 183 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-23 14:24:10) | — | — |  |
| (4) Dpp_high — Sprawl — R² | 0.335 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-23 14:24:10) | — | — |  |
| N (reconciliation) | 183 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-23 14:24:10) | 206 (results_used.md L81); VERIFICATION.md A2 found 202 | 6b0, 6c1, 6f.1/6f.2 | results_used.md (206) and VERIFICATION.md A2 (202) disagree with each other and both predate the current pipeline. The value in this row is the one the current models carry. Reconcile results_used.md to it. |
| (1) g_high — Compact — post-6f treatment coefficient | -0.2821 (SE 0.2143) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-23 14:24:10) | — | 6f.2 (asymmetric arrangement aggregation) |  |
| (1) g_high — Compact — pre-6f treatment coefficient | — | PENDING | — | — | 6f.2 | not recoverable from the current pipeline: 6f.2 changed stage 03's arrangement denominators, so reproducing the pre-6f values means re-running stage 03 under the old rule. Supply data/processed_data/04_regression/pre_6f_ed_table3_coefficients.csv with columns spec,estimate,std_error,p_value,n_obs to fill this row |
| (2) g_high — Sprawl — post-6f treatment coefficient | 0.3349 (SE 0.2119) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-23 14:24:10) | — | 6f.2 (asymmetric arrangement aggregation) |  |
| (2) g_high — Sprawl — pre-6f treatment coefficient | — | PENDING | — | — | 6f.2 | not recoverable from the current pipeline: 6f.2 changed stage 03's arrangement denominators, so reproducing the pre-6f values means re-running stage 03 under the old rule. Supply data/processed_data/04_regression/pre_6f_ed_table3_coefficients.csv with columns spec,estimate,std_error,p_value,n_obs to fill this row |
| (3) Dpp_high — Compact — post-6f treatment coefficient | -0.0048 (SE 0.0123) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-23 14:24:10) | — | 6f.2 (asymmetric arrangement aggregation) |  |
| (3) Dpp_high — Compact — pre-6f treatment coefficient | — | PENDING | — | — | 6f.2 | not recoverable from the current pipeline: 6f.2 changed stage 03's arrangement denominators, so reproducing the pre-6f values means re-running stage 03 under the old rule. Supply data/processed_data/04_regression/pre_6f_ed_table3_coefficients.csv with columns spec,estimate,std_error,p_value,n_obs to fill this row |
| (4) Dpp_high — Sprawl — post-6f treatment coefficient | 0.0251 (SE 0.0156) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-23 14:24:10) | — | 6f.2 (asymmetric arrangement aggregation) | SIGNIFICANCE FLAG: post-6f p = 0.1089 (stars ''); 6f.2's asymmetric arrangement denominator moved this coefficient across the 10% threshold |
| (4) Dpp_high — Sprawl — pre-6f treatment coefficient | — | PENDING | — | — | 6f.2 | not recoverable from the current pipeline: 6f.2 changed stage 03's arrangement denominators, so reproducing the pre-6f values means re-running stage 03 under the old rule. Supply data/processed_data/04_regression/pre_6f_ed_table3_coefficients.csv with columns spec,estimate,std_error,p_value,n_obs to fill this row |

## ED Table 4 — horse race

| Item | Value | Status | Source (file, mtime) | results_used.md (July) | Changed by | Note |
|---|---|---|---|---|---|---|
| (1) g_high — Compact + Sprawl — pct_area_densif_infill_0010 | 0.1523 (SE 0.1517) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-23 14:24:10) | — | — |  |
| (1) g_high — Compact + Sprawl — pct_area_periph_ext_leap_0010 | 0.2816** (SE 0.1413) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-23 14:24:10) | — | — |  |
| (1) g_high — Compact + Sprawl — N | 314 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-23 14:24:10) | — | — |  |
| (1) g_high — Compact + Sprawl — R² | 0.368 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-23 14:24:10) | — | — |  |
| (2) Dpp_high — Compact + Sprawl — pct_area_densif_infill_0010 | 0.0233** (SE 0.0098) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-23 14:24:10) | — | — |  |
| (2) Dpp_high — Compact + Sprawl — pct_area_periph_ext_leap_0010 | 0.0290** (SE 0.0112) | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-23 14:24:10) | — | — |  |
| (2) Dpp_high — Compact + Sprawl — N | 314 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-23 14:24:10) | — | — |  |
| (2) Dpp_high — Compact + Sprawl — R² | 0.296 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-23 14:24:10) | — | — |  |

## ED Table 5 — interactions

| Item | Value | Status | Source (file, mtime) | results_used.md (July) | Changed by | Note |
|---|---|---|---|---|---|---|
| (1) g_high — Compact × urban_class — N | 314 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-23 14:24:10) | — | — |  |
| (1) g_high — Compact × urban_class — R² | 0.379 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-23 14:24:10) | — | — |  |
| (2) Dpp_high — Compact × urban_class — N | 314 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-23 14:24:10) | — | — |  |
| (2) Dpp_high — Compact × urban_class — R² | 0.293 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-23 14:24:10) | — | — |  |
| (3) g_high — Compact × regiao — N | 307 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-23 14:24:10) | — | — | region columns exclude Centro-Oeste (6c2) |
| (3) g_high — Compact × regiao — R² | 0.371 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-23 14:24:10) | — | — |  |
| (4) Dpp_high — Compact × regiao — N | 307 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-23 14:24:10) | — | — | region columns exclude Centro-Oeste (6c2) |
| (4) Dpp_high — Compact × regiao — R² | 0.276 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-23 14:24:10) | — | — |  |
| (5) g_high — Sprawl × urban_class — N | 314 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-23 14:24:10) | — | — |  |
| (5) g_high — Sprawl × urban_class — R² | 0.370 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-23 14:24:10) | — | — |  |
| (6) Dpp_high — Sprawl × urban_class — N | 314 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-23 14:24:10) | — | — |  |
| (6) Dpp_high — Sprawl × urban_class — R² | 0.301 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-23 14:24:10) | — | — |  |
| (7) g_high — Sprawl × regiao — N | 307 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-23 14:24:10) | — | — | region columns exclude Centro-Oeste (6c2) |
| (7) g_high — Sprawl × regiao — R² | 0.390 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-23 14:24:10) | — | — |  |
| (8) Dpp_high — Sprawl × regiao — N | 307 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-23 14:24:10) | — | — | region columns exclude Centro-Oeste (6c2) |
| (8) Dpp_high — Sprawl × regiao — R² | 0.305 | VERIFIED | `data/processed_data/04_regression/model_objects_table2.rds` (2026-09-23 14:24:10) | — | — |  |

## ED Figure — standardized coefficients

| Item | Value | Status | Source (file, mtime) | results_used.md (July) | Changed by | Note |
|---|---|---|---|---|---|---|
| Rows in the standardized-coefficient CSV | 42 | VERIFIED | `output/ed_figure_standardized_coefficients.csv` (2026-09-23 17:44:55) | — | — |  |
| (1) g_high — Compact — largest \|standardized beta\| | Pop. growth outside risk zones = 0.584 (Other control) | VERIFIED | `output/ed_figure_standardized_coefficients.csv` (2026-09-23 17:44:55) | — | — |  |
| (1) g_high — Compact — treatment standardized beta | Compact growth = 0.030 | VERIFIED | `output/ed_figure_standardized_coefficients.csv` (2026-09-23 17:44:55) | — | — |  |
| (1) g_high — Compact — N | 314 | VERIFIED | `output/ed_figure_standardized_coefficients.csv` (2026-09-23 17:44:55) | — | — |  |
| (2) g_high — Sprawl — largest \|standardized beta\| | Pop. growth outside risk zones = 0.544 (Other control) | VERIFIED | `output/ed_figure_standardized_coefficients.csv` (2026-09-23 17:44:55) | — | — |  |
| (2) g_high — Sprawl — treatment standardized beta | Sprawl growth = 0.152 | VERIFIED | `output/ed_figure_standardized_coefficients.csv` (2026-09-23 17:44:55) | — | — |  |
| (2) g_high — Sprawl — N | 314 | VERIFIED | `output/ed_figure_standardized_coefficients.csv` (2026-09-23 17:44:55) | — | — |  |
| (3) Dpp_high — Compact — largest \|standardized beta\| | Pop. share in risk zones 2010 = -1.053 (Other control) | VERIFIED | `output/ed_figure_standardized_coefficients.csv` (2026-09-23 17:44:55) | — | — |  |
| (3) Dpp_high — Compact — treatment standardized beta | Compact growth = 0.089 | VERIFIED | `output/ed_figure_standardized_coefficients.csv` (2026-09-23 17:44:55) | — | — |  |
| (3) Dpp_high — Compact — N | 314 | VERIFIED | `output/ed_figure_standardized_coefficients.csv` (2026-09-23 17:44:55) | — | — |  |
| (4) Dpp_high — Sprawl — largest \|standardized beta\| | Pop. share in risk zones 2010 = -1.162 (Other control) | VERIFIED | `output/ed_figure_standardized_coefficients.csv` (2026-09-23 17:44:55) | — | — |  |
| (4) Dpp_high — Sprawl — treatment standardized beta | Sprawl growth = 0.215 | VERIFIED | `output/ed_figure_standardized_coefficients.csv` (2026-09-23 17:44:55) | — | — |  |
| (4) Dpp_high — Sprawl — N | 314 | VERIFIED | `output/ed_figure_standardized_coefficients.csv` (2026-09-23 17:44:55) | — | — |  |

## Stage 02 / stage 03 coverage

| Item | Value | Status | Source (file, mtime) | results_used.md (July) | Changed by | Note |
|---|---|---|---|---|---|---|
| Municipalities in the stage-02 high-susceptibility summary | 703 | VERIFIED | `data/processed_data/02_hazard_zones/resumo_municipal_suscept_alta_agsn.csv` (2026-08-25 22:49:27) | — | — |  |
| Exposed population 2010 (stage 02, area-weighted) | 13,341,594 | VERIFIED | `data/processed_data/02_hazard_zones/resumo_municipal_suscept_alta_agsn.csv` (2026-08-25 22:49:27) | — | — | `pop_suscept = populacao × prop_suscept`, national sum over the summary's municipalities |
| Exposed population 2022 (stage 02, area-weighted) | 14,192,370 | VERIFIED | `data/processed_data/02_hazard_zones/resumo_municipal_suscept_alta_agsn.csv` (2026-08-25 22:49:27) | — | — |  |
| Municipalities with CPRM mapped risk (stage 02) | 1,586 | VERIFIED | `data/processed_data/02_hazard_zones/resumo_municipal_risco_agsn.csv` (2026-08-26 01:46:30) | — | — | produced by stage 02; no live consumer since 6f.1 |
| Municipalities in stage-03 metrics | 629 | VERIFIED | `data/processed_data/03_urban_footprint/metricas/metricas_municipio_2010_2022.csv` (2026-09-22 22:31:58) | — | — |  |
| Arrangements emitted by stage-03 script 07 | 210 | VERIFIED | `data/processed_data/03_urban_footprint/metricas/metricas_arranjo_2010_2022.csv` (2026-09-22 22:31:58) | — | — | not the stage-04 arrangement count: `13_dependent_variables.R:80–83` filters to the qualified CD_CIDADEs and `15_final_dataset.R:123–127` re-adds the isolated ones |

## Robustness — minimum-baseline sweep

| Item | Value | Status | Source (file, mtime) | results_used.md (July) | Changed by | Note |
|---|---|---|---|---|---|---|
| Minimum-baseline sweep | — | PENDING | — | — | — | STALE: mtime 2026-09-17 11:17:22 predates the stage-04 run (2026-09-23 14:24:10) -- this exhibit was built from an earlier fit. Re-run stage 05. |
| Sweep sample sizes | — | PENDING | — | — | — | STALE: mtime 2026-09-17 11:17:22 predates the stage-04 run (2026-09-23 14:24:10) -- this exhibit was built from an earlier fit. Re-run stage 05. |

## Appendix table — descriptive statistics

| Item | Value | Status | Source (file, mtime) | results_used.md (July) | Changed by | Note |
|---|---|---|---|---|---|---|
| Municipality — A. Estimation sample — N (max across variables) | 314 | VERIFIED | `output/ed_table_descriptives_municipality.csv` (2026-09-23 17:44:59) | — | — | listwise deletion makes N vary by variable; the maximum is the block size |
| Municipality — B. Full sample — N (max across variables) | 395 | VERIFIED | `output/ed_table_descriptives_municipality.csv` (2026-09-23 17:44:59) | — | — | listwise deletion makes N vary by variable; the maximum is the block size |
| Municipality — A. Estimation sample — Sprawl growth share, 2000-2010 | mean 32.3932, median 28.8556, range 0.0000 to 100.0000 (N 314) | VERIFIED | `output/ed_table_descriptives_municipality.csv` (2026-09-23 17:44:59) | — | — |  |
| Municipality — B. Full sample — Sprawl growth share, 2000-2010 | mean 36.0339, median 30.4638, range 0.0000 to 100.0000 (N 395) | VERIFIED | `output/ed_table_descriptives_municipality.csv` (2026-09-23 17:44:59) | — | — |  |
| Municipality — A. Estimation sample — Compact growth share, 2000-2010 | mean 38.9965, median 39.9106, range 0.0000 to 70.0001 (N 314) | VERIFIED | `output/ed_table_descriptives_municipality.csv` (2026-09-23 17:44:59) | — | — |  |
| Municipality — B. Full sample — Compact growth share, 2000-2010 | mean 37.6562, median 39.6618, range 0.0000 to 81.0757 (N 395) | VERIFIED | `output/ed_table_descriptives_municipality.csv` (2026-09-23 17:44:59) | — | — |  |
| Municipality — A. Estimation sample — Growth of exposed population, 2010-2022 | mean 18.8202, median 12.7508, range -40.3409 to 252.0244 (N 314) | VERIFIED | `output/ed_table_descriptives_municipality.csv` (2026-09-23 17:44:59) | — | — |  |
| Municipality — B. Full sample — Growth of exposed population, 2010-2022 | mean 45.8397, median 14.1354, range -40.3409 to 3956.7037 (N 395) | VERIFIED | `output/ed_table_descriptives_municipality.csv` (2026-09-23 17:44:59) | — | — |  |
| Municipality — A. Estimation sample — Change in exposed population share, 2010-2022 | mean -0.2554, median -0.0549, range -19.4242 to 9.2057 (N 314) | VERIFIED | `output/ed_table_descriptives_municipality.csv` (2026-09-23 17:44:59) | — | — |  |
| Municipality — B. Full sample — Change in exposed population share, 2010-2022 | mean -0.1300, median -0.0016, range -19.4242 to 9.2057 (N 395) | VERIFIED | `output/ed_table_descriptives_municipality.csv` (2026-09-23 17:44:59) | — | — |  |
| Arrangement — A. Estimation sample — N (max across variables) | 183 | VERIFIED | `output/ed_table_descriptives_arrangement.csv` (2026-09-23 17:44:59) | — | — | listwise deletion makes N vary by variable; the maximum is the block size |
| Arrangement — B. Full sample — N (max across variables) | 210 | VERIFIED | `output/ed_table_descriptives_arrangement.csv` (2026-09-23 17:44:59) | — | — | listwise deletion makes N vary by variable; the maximum is the block size |
| Arrangement — A. Estimation sample — Sprawl growth share, 2000-2010 | mean 33.5243, median 30.7827, range 8.6705 to 85.9819 (N 183) | VERIFIED | `output/ed_table_descriptives_arrangement.csv` (2026-09-23 17:44:59) | — | — |  |
| Arrangement — B. Full sample — Sprawl growth share, 2000-2010 | mean 33.4299, median 30.3493, range 8.6705 to 98.4127 (N 210) | VERIFIED | `output/ed_table_descriptives_arrangement.csv` (2026-09-23 17:44:59) | — | — |  |
| Arrangement — A. Estimation sample — Compact growth share, 2000-2010 | mean 38.7758, median 38.9623, range 11.2396 to 65.6598 (N 183) | VERIFIED | `output/ed_table_descriptives_arrangement.csv` (2026-09-23 17:44:59) | — | — |  |
| Arrangement — B. Full sample — Compact growth share, 2000-2010 | mean 38.6038, median 38.8981, range 0.0000 to 65.6598 (N 210) | VERIFIED | `output/ed_table_descriptives_arrangement.csv` (2026-09-23 17:44:59) | — | — |  |
| Arrangement — A. Estimation sample — Growth of exposed population, 2010-2022 | mean 14.5841, median 9.3743, range -40.3409 to 213.2675 (N 183) | VERIFIED | `output/ed_table_descriptives_arrangement.csv` (2026-09-23 17:44:59) | — | — |  |
| Arrangement — B. Full sample — Growth of exposed population, 2010-2022 | mean 46.9249, median 10.0444, range -40.3409 to 3956.7037 (N 210) | VERIFIED | `output/ed_table_descriptives_arrangement.csv` (2026-09-23 17:44:59) | — | — |  |
| Arrangement — A. Estimation sample — Change in exposed population share, 2010-2022 | mean -0.3559, median -0.0804, range -19.4242 to 3.7462 (N 183) | VERIFIED | `output/ed_table_descriptives_arrangement.csv` (2026-09-23 17:44:59) | — | — |  |
| Arrangement — B. Full sample — Change in exposed population share, 2010-2022 | mean -0.2928, median -0.0355, range -19.4242 to 3.7462 (N 210) | VERIFIED | `output/ed_table_descriptives_arrangement.csv` (2026-09-23 17:44:59) | — | — |  |

---

Regenerate: `Rscript 05_exhibits/build_results_targets.R` (commit 130ee7f).
