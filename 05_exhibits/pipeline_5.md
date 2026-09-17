# Exhibits pipeline — `05_exhibits/`

> **A note on citations in this document.** It cites records kept in the project's private
> working repository — `MIGRATION_PLAN.md` (dated decisions), `METHODS_AUDIT.md`,
> `results_used.md` (the pre-rework target values), `AUDIT.md`, `VERIFICATION.md` and
> `CLAUDE.md` (the numbered conventions, restated in `README.md`) — together with commit
> hashes from that repository. Those files are not part of this deposit, and nothing here
> depends on them; the citations are kept so each decision can be traced to where it was
> recorded. Current values live in `manuscript/results_targets_v2.md`.

**Written 2026-09-10 as a design document**, before most of the stage existed. Six of its eight
scripts have since been written or corrected, so it now reads as this stage's
`PIPELINE.md`-equivalent (stage 4 uses that name; stage 3 uses `pipeline_urban_metrics.md`)
rather than as a proposal. The one script it describes that was never written is flagged in
its own section (§6.6) and produces no exhibit in the paper.

**Updated 2026-09-16** to remove result values — see below — and to reflect
`MIN_POP_RISCO_2010 = 200`, 6f.1 and 6f.2.

## Result values are not in this file

This document describes **what each script does and in what order**. It does not state counts,
coefficients or population totals. Every such value belongs in
**`manuscript/results_targets_v2.md`**, which is the single source of result values for the
whole pipeline.

> **`manuscript/results_targets_v2.md` is generated, not hand-written.**
> `05_exhibits/build_results_targets.R` rebuilds it from the current exhibit outputs; every
> value carries the file it came from, that file's mtime, and a VERIFIED/PENDING status.
> Nothing here is an authoritative figure for N at any funnel step or any specification, for
> any coefficient, R²
> or median, or for any population total — read them from that file, not from here and not
> from an older copy of this document.
>
> This matters more here than anywhere else in the pipeline, because stage 5 *is* the exhibits.
> Earlier copies of this file carried the funnel counts, the Table 2 coefficient row and the
> per-table N's inline, and every one of them was measured under a configuration that 6e
> (weighting), 6c1's 2026-09-12 revision (`MIN_POP_RISCO_2010` 1000 → 200) and 6f.1/6f.2 have
> since superseded. Repeating them is what desynchronised this month's documentation.
>
> The slot-by-slot specification the generator implements is kept with the project's other
> working records and is not part of this deposit; `build_results_targets.R`'s own header
> documents every slot it fills.

`MIGRATION_PLAN.md` 6b0, 6c1, 6c2 and 6e/6f remain the record of *why* each filter exists —
they are frozen as of 2026-09-16, and the figures inside them are likewise historical.

Parameters below that live in code (sample cuts, thresholds, plot settings) are stated with
their file and line, because they describe the script rather than a result.

---

## 1. What stage 5 is — and is not

Stage 5 is the **one place that turns already-computed results into the paper's exhibits**.
It reads the final outputs of stages 3 and 4 and writes the tables and figures listed in
`manuscript/results_used.md`, in the exact form the manuscript needs.

Three rules follow from that role:

1. **No estimation, no spatial processing.** Stage 5 never fits a model, never touches a
   raster or a geometry overlay. Stage 4 script 16 estimates and *saves* the models; stage 5
   only formats what was saved. This holds in code since 2026-09-11 (§6.4).
2. **No new analyses** (`CLAUDE.md` rule 6). Only exhibits in `results_used.md` — the
   `[IN DRAFT]`, `[PROMISED, NOT SHOWN]` and `[PLANNED]` items — get a script here.
3. **Everything final lands in top-level `output/`** (decided 2026-08-20). `output/` is
   tracked in git (`.gitignore`: `!output/**`), precisely so the deposited exhibits are
   versioned. The one exception is Figure 1's data layers (§6.2): hundreds of MB, an input to
   a manual GIS step, not a final exhibit — they stay under `data/processed_data/`.

**Not in stage 5** (decided 2026-08-20, Task 2(f)): Figure 5 (spatial allocation panels),
Figure 6 (footprint delimitation panels), Figure 7 (identification diagram) and ED Table 1
(variable definitions) are hand-made. Their underlying layers exist as byproducts of stages
2–3 for whoever builds them — mapped panel by panel in **Appendix A**.

**Kept live but outside the validated set:** `robustness/` (seven scripts, §6.8) — never run by
`00_run_all.R`, never promoted into `results_used.md`.

---

## 2. Where stage 5 sits

```
stage 3  03_urban_footprint_and_growth_types/
   07_aggregate_municipality_metrics.R  ──►  metricas_municipio_2010_2022.csv ──┐
   05_classify_growth_types.R           ──►  grade_growth_types_2010_2022.parquet ┤
                                                                                 │
stage 4  04_regression_dataset_and_models/                                       │
   01_compose_sample.R                  ──►  amostra_mun.csv                     │
   15_final_dataset.R                   ──►  dataset_regressao_municipio.csv      │
   16_estimate_models.R                 ──►  model_objects_table2.rds             │
                                                                                 ▼
stage 5  05_exhibits/  (this folder)                                        reads only
   table1_population_by_growth_type.R   ──►  Table 1 (1a levels + 1b change/bar chart)
   figure1_growth_type_layers.R         ──►  Figure 1 data layers (QGIS)
   figure2_exposure_scatter.R           ──►  Figure 2
   table2_and_ed_tables.R               ──►  Table 2, ED Tables 2–5
   ed_figure_standardized_coefficients.R ──►  ED Figure
   ed_sensitivity_leapfrog_threshold.R  ──►  ED sensitivity (orchestrates a re-run) [not written]
   00_run_all.R
                                                                                 ▼
                                                                          output/  (git-tracked)
```

---

## 3. Inputs

| File | Produced by | Read by (stage 5) |
|---|---|---|
| `data/processed_data/03_urban_footprint/metricas/metricas_municipio_2010_2022.csv` | stage 3, script 07 | Table 1, Figure 2 |
| `data/processed_data/03_urban_footprint/crescimento_urbano/grade_growth_types_2010_2022.parquet` | stage 3, script 05 | Figure 1 |
| `data/processed_data/04_regression/amostra_mun.csv` | stage 4, script 01 | Table 1 (sample cross-check only) |
| `data/processed_data/04_regression/tables/dataset_regressao_municipio.csv` | stage 4, script 15 | Table 1, Figure 1, Figure 2 (sample) |
| `data/processed_data/04_regression/model_objects_table2.rds` | stage 4, script 16 (`saveRDS` at `16_estimate_models.R:524–525`) | Table 2 / ED Tables, ED Figure |
| `data/processed_data/03_urban_footprint/tabelas/diagnostico_legacy_proxy_tabela1a.csv` (optional, **not reproducible from this repository** — see §6.1) | a diagnostic script that is not part of this deposit | Table 1 (cross-check, §6.1) |

Stage 5 reads nothing from stage 2 and nothing raw.

---

## 4. Which sample each exhibit uses

Not one flat list: **two funnels over municipalities and a third, independent one over
arrangements**, narrowing for different reasons. Arrangements are never a subset of the
municipality counts — an arrangement is a group of municipalities, counted from its own file.

**The counts at each step are not in this document.** They belong in
`manuscript/results_targets_v2.md`. What follows is the chain of filters, in the order the code
applies them, with the file and line of each — that is what describes the scripts.

### 4.1 The municipality funnel

| Step | Filter | Where |
|---|---|---|
| Processing universe | SGB high-susceptibility mapping, plus arrangement completion and the > 50,000 population cut | stage 3 `01_define_sample.R` |
| `amostra_mun` | `tem_susceptibilidade == TRUE` | stage 4 `01_compose_sample.R:41` |
| — | every row of `dataset_regressao_municipio.csv`; **Table 1 and Figure 1 stop here** | stage 4 `15_final_dataset.R` |
| Post-restriction | `pop_2010_risk_total > MIN_POP_RISCO_2010` | `16_estimate_models.R:201`, `:205` |
| Estimation sample | `complete.cases(Y, treatment, CTRL_ALTA)`, **per specification** | `16_estimate_models.R:298` |
| Region columns only | minus Centro-Oeste, whose region-interaction terms are not estimably precise (6c2) | `16_estimate_models.R`, the interaction fit |

Note the ordering: the population cut runs **before** listwise deletion, and listwise deletion
runs per specification, so ED Tables 2–5 do not all share one N.

### 4.2 The arrangement (FUA) funnel

| Step | Filter | Where |
|---|---|---|
| Arrangement entities | qualified arrangements (`CD_CIDADE`) **plus** isolated municipalities as singletons | stage 4 `01_compose_sample.R:92–93`, `15_final_dataset.R` |
| ED Table 3 | `pop_2010_risk_total > MIN_POP_RISCO_2010` | `16_estimate_models.R:201`, `:207` |

`13_dependent_variables.R:80–83` filters stage 3's arrangement metrics to the qualified
`CD_CIDADE`s, and `15_final_dataset.R:123–127` re-adds the isolated municipalities as singleton
arrangements built from the *municipality* metrics — not from script 07's arrangement block. So
the row count script 07 emits never reaches stage 04 as such, and 6f.1's change to the
arrangement count does not move ED Table 3's sample. (`MIGRATION_PLAN.md` 6f.2 records the
prediction this corrected.)

### 4.3 Do not read two equal N's as the same set

Figure 2's sample and ED Table 5's region-column sample are computed from **different filters**
and are not the same municipalities, even when the two counts coincide — which they have. ED
Table 5's is the estimation sample minus Centro-Oeste. Figure 2's is the post-`MIN_POP_RISCO_2010`
sample restricted to municipalities with positive 2010–2022 growth in *both* compact and sprawl
cells. Never assume membership of one from the other.

### 4.4 Decided 2026-09-10 (researcher): Table 1 uses the full `amostra_mun`, not the restricted sample

Reasons: (i) the published Table 1 numbers were produced on exactly that set — the researcher's
March 2026 log of `07_tabela_populacao_risco.R` reports "municipalities with susceptibility
mapping" and matched `results_used.md`'s totals to the person (Validate runbook, step 3, Test B);
`results_used.md` L11's sample line never was the sample behind those numbers. (ii) Every 6b0 /
Test A–B comparison (`diagnostico_legacy_proxy_*.csv`) was computed on that set, so the exhibit
script's output is directly comparable to them. (iii) `MIN_POP_RISCO_2010` is a fix for the
functional form of `g_alta` — a growth *rate* with a near-zero denominator — not a redefinition
of the study population; the municipalities it drops have real population and real, small, risk
population that belong in national totals.

**Figure 2 uses the restricted sample** (decided 2026-09-10, 6c2), consistent with its own
history: `results_used.md` describes it on the regression sample, not the full universe.
`figure2_exposure_scatter.R:32` sets its own `MIN_POP_RISCO_2010` and must be kept equal to
`16_estimate_models.R:201`.

**Figure 1's `em_amostra_regressao` flag follows Table 1**: it is a QGIS convenience filter, not
a value that must sum to anything.

**What this implies for the manuscript** (Validate, not now): `results_used.md` L11's sample
line, its Table 2 block, its Figure 2 numbers and its ED Table 3 N, and `CLAUDE.md`'s "Key
sample facts", all need reconciling to a validated clean run — per rule 2's `AUDIT.md` §4
exception, by updating the targets, not by adjusting the code. The values come from
`manuscript/results_targets_v2.md` once it is written.

---

## 5. Exhibit → script → output

| `results_used.md` item | Status there | Script | Output (in `output/` unless noted) |
|---|---|---|---|
| Table 1 — levels (1a) and change/bar chart (1b) | IN DRAFT | `table1_population_by_growth_type.R` | `tabela1a_populacao_totais_tipo.csv`, `tabela1_populacao_risco_tipo.{csv,pdf,png}` |
| Figure 1 — growth-type map layers | IN DRAFT | `figure1_growth_type_layers.R` | `figura1_camadas.{parquet,gpkg}` — **stays in `data/processed_data/03_urban_footprint/figuras/`** |
| Figure 2 — exposure scatter | IN DRAFT | `figure2_exposure_scatter.R` | `plot_pct_risk_sprawl_vs_compact_{pure,population}.{pdf,png}` |
| Table 2 — main regressions | IN DRAFT | `table2_and_ed_tables.R` | `table2_main_municipalities.{html,tex,docx}` |
| ED Table 2 — with/without mediators | PROMISED | `table2_and_ed_tables.R` | `ed_table2_mediators.{html,tex,docx}` |
| ED Table 3 — FUA-level | PROMISED | `table2_and_ed_tables.R` | `ed_table3_fua.{html,tex,docx}` |
| ED Table 4 — horse race | PROMISED | `table2_and_ed_tables.R` | `ed_table4_horserace.{html,tex,docx}` |
| ED Table 5 — interactions | PROMISED | `table2_and_ed_tables.R` | `ed_table5_interactions.{html,tex,docx}` |
| ED Figure — standardized coefficients | PLANNED | `ed_figure_standardized_coefficients.R` | `ed_figure_standardized_coefficients.{pdf,png}` + `.csv` |
| ED sensitivity — alternative threshold | PLANNED | `ed_sensitivity_leapfrog_threshold.R` | `ed_table_sensitivity_leapfrog_2000m.{html,tex}` |

File names for Table 1 / Figures 1–2 are the existing ones (they are what `MIGRATION_PLAN.md`
6d lists as "moving to `output/`"); the new tables get English names. Data *columns* inside
files are never renamed (rule 4); file names are not covered by that rule.

---

## 6. Script by script

Each entry: what it produces, what it reads, what it does, where it writes, its **state**, and
**how it is verified**. Verification is described as a *test* — what has to agree with what —
never as the numbers a past run returned. Those belong in `manuscript/results_targets_v2.md`.

### 6.1 `table1_population_by_growth_type.R` — Table 1

**Produces.** Table 1a (levels: total population and population in high-susceptibility zones,
2010 and 2022, by growth-type group, with % at risk and the headline share statistics) and
Table 1b (the 2010–2022 change per group split into inside/outside high susceptibility, as a
CSV and as the stacked bar chart).

**Reads.** `metricas_municipio_2010_2022.csv`; `dataset_regressao_municipio.csv` (sample);
`amostra_mun.csv` (cross-check); optionally `diagnostico_legacy_proxy_tabela1a.csv`, which this
repository cannot produce (see the note under **Verified by** below).

**Does.**
1. Load the metrics table — one row per municipality in the processing universe.
2. Restrict to the regression dataset's `cod_mun`, i.e. the full `amostra_mun` (§4.4), **not**
   the `MIN_POP_RISCO_2010`-restricted sample. Check that this set equals `amostra_mun.csv`'s
   and `stop()` if not.
3. Group the six growth types: Consolidated = consolidated; Compact = densification + infill;
   Sprawl = peripheral + extension + leapfrog.
4. Table 1a: per group, sum `pop_2010_<type>`, `pop_2022_<type>`, `pop_2010_risk_<type>`,
   `pop_2022_risk_<type>`; % at risk each year; change in risk population; a Total row.
5. Headline statistics: % of new residents going to risk (change in risk / change in
   population, Compact and Sprawl); Compact's share of the net increase in at-risk population
   (over Compact + Sprawl); aggregate growth of total vs. at-risk population.
6. Table 1b: per group, change in risk population and change outside risk (total change − risk
   change), in millions; stacked bar chart with the risk segment at the zero baseline.
7. Run the checks below, then save.

**Writes.** `output/tabela1a_populacao_totais_tipo.csv`,
`output/tabela1_populacao_risco_tipo.csv`, `output/tabela1_populacao_risco_tipo.{pdf,png}`.

**State.** Done. Column logic rewritten for the common-grid schema 2026-09-05 (`9cfc634`);
sample repointed to `data/processed_data/04_regression/tables/dataset_regressao_municipio.csv`
and the `amostra_mun.csv` cross-check added 2026-09-10 (`8fc27d2`); outputs moved to `output/`
via `output_path()`. The script applies **no susceptibility rule of its own** — it sums
`pop_*_risk_<type>` out of the metrics CSV — so 6e changed its numbers without changing a line
of it (`MIGRATION_PLAN.md` 6e.4 row 17).

**Verified by — two checks with different standing.**

- **The gating check**: the `baseline` variant of `diagnostico_legacy_proxy_tabela1a.csv`, an
  independent computation of the same aggregation on the same sample. Where that file is
  present, both sides must agree to the person, and a mismatch raises `warning()`. **The script
  that produces it is not part of this deposit** — it was a migration-era instrument that
  re-ran stage 03's scripts 04/05/07 against a superseded population proxy, and it has no role
  outside that comparison. Without it, `table1_population_by_growth_type.R` skips this check and
  says so on the console; Table 1 itself is unchanged, since the check reads no input that
  Table 1 does not already read.
- **The recorded, non-gating check**: the comparison against `results_used.md`'s pre-rework
  targets. Kept and printed, but a deviation there is **expected**, not a STOP — two documented
  decisions account for it, 6b0 (the common-grid rework) and 6e (exposure weighting), and 6f.1
  and 6f.2 have moved things again since. Rule 2 still applies to anything *outside* that
  documented pattern.

**A stale comment, fixed 2026-09-16.** The header used to describe the downstream cut as
`pop_2010_risk_total > 1000`; the pipeline's value is `200`. The comment is descriptive only —
this script applies no such cut — so nothing it produced was ever wrong, but the line
contradicted the code and now states the revision instead.

### 6.2 `figure1_growth_type_layers.R` — Figure 1 data layers

**Produces.** One cell-level layer (parquet + gpkg) carrying the columns the three panels of
Figure 1 are symbolized on, for a manual QGIS step: `urbano_2010`/`urbano_2020` (panel a),
`tipo_crescimento` (panel b), `grupo_3tipos` + `prop_suscept_alta` (panel c), plus
`em_amostra_regressao`.

**Reads.** `grade_growth_types_2010_2022.parquet`; `dataset_regressao_municipio.csv`.

**Does.** Load the grid; read `urbano_2010`/`urbano_2020` straight off it; print a one-time
crosstab of the old derivation against those real columns; recode `tipo_crescimento` into the
three groups; flag the sample municipalities; write parquet + gpkg.

**Writes.** `data/processed_data/03_urban_footprint/figuras/figura1_camadas.{parquet,gpkg}`
(**not** `output/`: hundreds of MB, and `output/` is git-tracked).

**State.** Done (`0b5b371`, `c361fb5`). Two fixes worth knowing:

- It **stopped re-deriving** `urbano_2010`/`urbano_2020` from `tipo_crescimento` and reads the
  grid's own columns (computed by stage-3 script 04, and required as an input by script 05, so
  guaranteed present). The old derivation marked a cell urban in 2022 whenever
  `tipo_crescimento` was non-NA, which is wrong for **shrinkage** cells — urban at t1, not at
  t2, folded into `consolidated`. Panel a would have drawn those cells wrong.
- Panel-c overlay path corrected to
  `data/processed_data/02_hazard_zones/susceptibilidade_unida.gpkg`.

**Verified by.** The script's own crosstab — classified cells = compact + consolidated + sprawl
= `urbano_2020 == TRUE` — and the derived-vs-real crosstab, where any disagreement should be
confined to shrinkage cells.

**6e leaves this exhibit alone** (`MIGRATION_PLAN.md` 6e.4 row 18): it carries
`prop_suscept_alta` as a **continuous** per-cell column for symbolization and computes no
exposure aggregate. Its only weighting-adjacent dependency is the `em_amostra_regressao` flag,
and the correction changes the *values* of `pop_*_risk_*`, not which municipalities are in the
dataset.

**One open, non-blocking observation.** `grupo_3tipos`'s `NA` count exceeds the real crosstab's
own "not urban either year" cell by a small margin — i.e. a few cells are urban in at least one
year per script 04's flags but never received a `tipo_crescimento` label from script 05. Figure
1 is illustrative and has no total to reproduce, so this blocks nothing; it is a script-04 /
script-05 boundary inconsistency worth a look if anyone chases it. Not investigated.

### 6.3 `figure2_exposure_scatter.R` — Figure 2

**Produces.** Scatter of the share of 2010–2022 growth going to high-susceptibility areas,
sprawl vs. compact, one point per municipality; plain and faceted by 2022 population quartile;
plus the summary statistics quoted in the text (medians, share below the 45° line, Wilcoxon,
correlations, fitted slope).

**Reads.** `metricas_municipio_2010_2022.csv`; `dataset_regressao_municipio.csv`.

**Does.** Per municipality, `pct_risk_sprawl` = Δ risk population in sprawl cells / Δ total
population in sprawl cells (likewise compact), deltas derived from the common-grid levels;
restrict to the regression dataset **with the `MIN_POP_RISCO_2010` cut** (L86) and then to
municipalities with positive growth in both types; clip to [0, 1]; plot; print statistics.

**Parameter, in code.** `MIN_POP_RISCO_2010 <- 200` at
`figure2_exposure_scatter.R:32`, with the comment *"must match 16_estimate_models.R"*. It does
(`16_estimate_models.R:201`). Both were `1000` until 2026-09-12; if either moves, both must.
The value is printed into both subtitles (L220–221, L271–272), so the figure states its own
sample rule.

**Writes.** `output/plot_pct_risk_sprawl_vs_compact_{pure,population}.{pdf,png}`.

**State.** Done (`918700b`): repointed, aligned to the restricted sample (6c2), destination
moved to `output/` via `output_path()`.

**Verified by.** The N printed in both subtitles agreeing with the restricted-sample-plus-
positive-growth count; medians and the 45°-line share are recorded for the
`results_targets_v2.md` / `results_used.md` update at Validate, not checked against the draft's
old values, which were produced under a superseded configuration.

### 6.4 `table2_and_ed_tables.R` — Table 2 and ED Tables 2–5

**Produces.** The five regression tables, formatted (`modelsummary` → HTML, TeX, DOCX).

**Reads.** `model_objects_table2.rds`, saved by stage-4 script 16 (`:492–493`): a named list of
the five fitted-model lists, plus the metadata the notes need — `min_pop_risco_2010`, the
pre/post-filter N, the Centro-Oeste drop count, an estimation timestamp.

| Object in script 16 | Exhibit | Columns |
|---|---|---|
| `tab_main_mun` | **Table 2** | 4: `g_high`/`Dpp_high` × compact/sprawl, municipalities |
| `tab_mediators_mun` | **ED Table 2** | 10: with / without mediators / mediators only |
| `tab_appA_arr` | **ED Table 3** | 4: same specs, functional urban areas, HC3 |
| `tab_horserace_mun` | **ED Table 4** | 2: compact and sprawl entered jointly |
| `tab_interact_mun` | **ED Table 5** | 8: × `urban_class`, and × `regiao` excluding Centro-Oeste |

Each model carries its cluster vector as `attr(mod, "cluster_vec")`, set by `fit_safe()` and
preserved by `saveRDS()`, so clustered SEs are recomputed after reload without the data.

**Does.** Load the `.rds`; per table apply the coefficient map, the `coef_omit` pattern, the GOF
map and the note (moved verbatim from the old script 16); compute SEs with the same functions
(`vcovCL` by `NM_CIDADE` for municipalities, HC3 for arrangements), **redefined here** rather
than serialized as closures; write the three formats. `MIN_POP_RISCO_2010` is read out of the
metadata (L66) and printed into every table note (L134, L216), so the notes cannot drift from
the value script 16 actually used.

**Writes.** `output/table2_main_municipalities.*`, `output/ed_table2_mediators.*`,
`output/ed_table3_fua.*`, `output/ed_table4_horserace.*`, `output/ed_table5_interactions.*` —
three formats each.

**State — the split is applied** (commit `57a5b95`, 2026-09-11). Script 16 loads, fits, runs its
diagnostics and `saveRDS()`s; no `modelsummary`/`flextable` call remains in stage 4. The tables
were renamed to the paper's actual numbering here: the old script's "Table 1" was always the
paper's **Table 2**, and its "Table 2" was always **ED Table 5**.

**Decided:** the `tab3b` mediator-coefficients-shown variant is **not** exported as a
deliverable — it is not in `results_used.md` and ED Table 2 already answers the with/without
question. Its coefficient map is kept commented out for later.

**Verified by.** The metadata round-tripping through the `.rds` (the pre/post-filter counts the
new script prints must equal what script 16 printed when it estimated), and all fifteen files
being written. The `zero_area_2000` rank-deficiency warning appears on the arrangement table
only — that variable is constant at arrangement level and dropped by `lm()`, documented as 6c2
finding 4, and is expected rather than new.

### 6.5 `ed_figure_standardized_coefficients.R` — ED Figure

**Produces.** A coefficient plot with standardized betas and confidence intervals for the four
Table 2 specifications, so that "housing-market variables matter more than urban form" is a
comparison of magnitudes on one scale rather than of significance stars across differently
scaled covariates (`results_used.md`, ED Figure).

**Reads.** `model_objects_table2.rds` (`tab_main_mun` only).

**Does — without re-estimating** (rule 1 of §1). Per model: take the estimation sample from the
model frame; for every non-factor regressor compute `beta_std = beta × sd(x) / sd(y)` and scale
the clustered standard error by the same factor for the CI; keep the treatment and the shown
controls (the housing-market block — safe empty land Q1, Palma commute, Palma rent, median
rent, slum share — plus steep terrain, population share in risk 2010, log population and
footprint 2000, growth outside risk zones); drop the region and urban-class dummies and the
intercept. Plot as dot-and-whisker, 95% CI, **one panel per specification**
(`facet_wrap(~ spec, scales = "free_x")`) — panels are on independent x-axis scales but stay
numerically comparable, since the unit is outcome-SD per 1-SD change in x, and the plot's own
caption says so. Treatment rows are labelled "Compact growth"/"Sprawl growth" rather than Table
2's shared "Treatment", since distinguishing them is the figure's purpose. Save the values as
CSV alongside the figure.

The alternative — refitting on `scale()`-transformed data, or `lm.beta` — gives the same point
estimates but re-estimates inside stage 5, and was rejected for that reason.

**Writes.** `output/ed_figure_standardized_coefficients.{pdf,png}` and `.csv`.

**State.** Written 2026-09-11 (`2cd937d`), with two rendering fixes (`fde0896`): the x-axis
label's subscript Unicode failed on the Windows PDF device (`mbcsToSbcs` conversion failure) and
was replaced with a plain β; `geom_pointrange()`'s `fatten` is deprecated in ggplot2 4.0.0 and
was switched to `size`.

**Verified by.** A self-check built into the script: standardization must not change any
t-statistic, so the script computes `max(abs(t_original - t_check))` and `warning()`s above
1e-8. A failure there means an arithmetic bug, not a result.

### 6.6 `ed_sensitivity_leapfrog_threshold.R` — ED sensitivity **[not written; scope to confirm]**

**Produces.** Table 2 re-estimated under an alternative classification threshold — `AUDIT.md` §2
settled on the extension/leapfrog distance at **2,000 m instead of 1,000 m**
(`results_used.md` allows any of built-up share, density cutoff or leapfrog distance).

**Nature.** Unlike every other script here this is an **orchestrator of a cross-stage re-run**,
because the threshold lives upstream: `LIMIAR_EXTENSION` at
`05_classify_growth_types.R:62` (2010–2022 window, descriptives) and
`06_classify_growth_types_2000_2010.R:80` (2000–2010 window, the regression treatment). The
chain is stage 3 scripts 05 → 06 → 07 with the alternative threshold and an output suffix (e.g.
`_leap2000`), then stage 4 scripts 13 → 14 → 15 → 16 on the suffixed files, then the Table 2
formatting. Stage-3 scripts 03/04 are not threshold-dependent and are not re-run. Cost is
dominated by stage-3 scripts 05/06 (`AUDIT.md` §2 estimates a few hours).

**Design.** Parameterize the threshold and the output suffix in the stage-3/4 scripts through an
option or environment variable — the mechanism the stage-3 diagnostics already use with
`LEGACY_TEST` — defaulting to today's values so the main pipeline is unaffected; this script
sets them, sources the chain, and formats the resulting Table 2 next to the main one. Only the
treatment window (script 06) strictly needs re-running for Table 2; re-running the 2010–2022
window too also refreshes Table 1 under the alternative threshold, at extra cost.

**Writes.** `output/ed_table_sensitivity_leapfrog_2000m.{html,tex}`.

**State.** Not started; skipped for now (researcher's call, 2026-09-11). **Decide before
implementing:** which threshold(s); treatment window only or both; whether it is worth the
re-run before submission.

**Verified by.** The main-pipeline outputs must be byte-identical with and without the
parameterization at default values — the parameterization has to be a no-op by default.

### 6.7 `00_run_all.R`

Sources the five written scripts, each in a clean environment, mirroring stage 4's own
`00_run_all.R`: `table1_population_by_growth_type.R` → `figure1_growth_type_layers.R` →
`figure2_exposure_scatter.R` → `table2_and_ed_tables.R` →
`ed_figure_standardized_coefficients.R`. **Excludes** `ed_sensitivity_leapfrog_threshold.R` (a
multi-hour cross-stage re-run, launched deliberately) and `robustness/`.

Preconditions printed at the top: stages 3 and 4 have been run, so that
`metricas_municipio_2010_2022.csv`, `dataset_regressao_municipio.csv` and
`model_objects_table2.rds` exist.

**State.** Written 2026-09-11 (`c853b5d`) and confirmed end to end against real data the same
day: full clean run, all five scripts, zero errors, every per-script check agreeing with what
each had produced standalone.

### 6.8 `robustness/` — seven scripts, kept live, not part of the exhibit set

| Script | Pre-Migrate name | What it does | Notes |
|---|---|---|---|
| `minimum_population_filter.R` | `12b_regressao_preperiodo_base_minima.R` | Table 2 under a minimum-baseline cut on `pop_2010_risk_total` | Proposed the same restriction 6c1 later adopted; now largely redundant with script 16 — **but see the threshold note below** |
| `outlier_diagnostics.R` | `12a_diagnostico_outliers.R` | `g_alta` distribution, Cook's D, winsorization, min-base cuts | Same problem 6c1 diagnosed; corroborating |
| `double_filter_pp80.R` | `12c_regressao_preperiodo_pp80.R` | The baseline cut **plus** `pp_alta_2010 ≤ 80%` | The extra cut is not adopted anywhere — open |
| `steep_terrain_in_susceptibility.R` | `12b_regressao_topo_suscept.R` | Table 2 with `topo_prop_inclinado_em_alta` as the terrain control | — |
| `correlations.R` | `13_correlacoes.R` | Correlation matrices, municipalities and arrangements | — |
| `dag_test.R` | `14_dag_test.R` | DAG conditional-independence tests (`dagitty`, `localTests`) | Writes `dag_local_tests.csv`, `dag_triage_external_vars.csv`, `dag_causal.png` |
| `case_study.R` | `15_estudo_de_caso.R` | Comparison table for selected municipalities | — |

**State — repointed 2026-09-11 (`d8c0a2b`).** All seven: `setwd()` dropped;
`source("regression2/00_setup.R")` → `source("04_regression_dataset_and_models/00_setup.R")`;
`tabelas_dir`/`figuras_dir` → `tables_dir`/`figures_dir`; `outlier_diagnostics.R`'s
`reg_data_dir` → `data_dir`. The four carrying medium-susceptibility content
(`minimum_population_filter.R`, `double_filter_pp80.R`: `CTRL_MEDIO`/`CTRL_ALTA_MEDIO`,
`y_med`/`y_hm`, Appendix B/C; `correlations.R`: medium label entries; `dag_test.R`: the
`g_medio_slums_1022` candidate) had those blocks removed, matching rule 9. Six of the seven have
since been run against real data; `case_study.R` has not been run at all.

**The threshold mismatch is resolved (2026-09-16).** Both scripts used to hardcode
`MIN_POP_RISCO <- 1000` against `16_estimate_models.R:201`'s `200` (`METHODS_AUDIT.md` §8 item
4) — a second, undeclared configuration rather than a deliberate alternative. Neither hardcodes
it any more:

- `MIN_POP_RISCO_2010` is now declared once, in
  `04_regression_dataset_and_models/00_setup.R`, which both scripts already source.
- `double_filter_pp80.R` reads it, so its baseline cut always equals the pipeline's and only
  its `pp_alta_2010 <= 80%` cut is its own contribution. Both filters are printed into the
  table note from the constants actually applied.
- `minimum_population_filter.R` no longer applies one cut at all. It **sweeps** `CUTS <- c(100,
  200, 500, 1000)` and produces a sensitivity table — the four treatment coefficients, their
  SEs and N per cut, at both municipality and arrangement level — with the pipeline's own value
  marked as the reference row. It `stop()`s if `MIN_POP_RISCO_2010` is not among `CUTS`, so the
  sweep can never silently exclude the configuration the paper reports. That is what makes it a
  robustness check rather than a redundant re-run of script 16.

Its outputs changed accordingly: `sensitivity_min_pop_risco.csv` (tidy, both levels, all cuts),
`sensitivity_min_pop_risco_sample_sizes.csv`, and one formatted table per cut per level
(`tab1b_main_municipios_high_cut<CUT>.*`, `tabA1b_arranjos_high_cut<CUT>.*`), replacing the
single `*_base_min.*` pair.

**Confirmed against real data 2026-09-17.** The sweep ran clean over
`CUTS = c(100, 200, 500, 1000)` at both levels. At the pipeline cut it reproduces
`model_objects_table2.rds` exactly — all eight treatment coefficients, SEs, N and R², at both
municipality and arrangement level — which is an independent check that the copied
`prep()`/`CTRL_ALTA`/`fit_safe()`/vcov block has not drifted from `16_estimate_models.R`. The
values themselves are in `manuscript/results_targets_v2.md`, including per-specification
stability rows recording whether each sign and significance tier holds across the four cuts.

**Two further things noticed while repointing.**

- `outlier_diagnostics.R` calls `library(DescTools)` and `moments::skewness()`/
  `moments::kurtosis()` with no `requireNamespace()`/`install.packages()` guard, unlike every
  other package load in this codebase. This was flagged as a risk and then **happened** on the
  researcher's own run — the script failed outright and succeeded only after a manual install,
  with no code change. Adding the guard (matching `correlations.R`'s
  `for (pkg in c(...)) { if (!requireNamespace(...)) install.packages(...); library(...) }`
  pattern) is one line per package. Open for the researcher to request.
- `case_study.R`'s target-municipality list (`alvo`, ten named cities with hardcoded `cod_mun`)
  was not cross-checked against the current sample. The script does its own presence check
  against `amostra_municipios.rds` and warns if any are missing, which is the right mechanism;
  noting only that it was not independently re-verified, and that the script still has not run.

---

## 7. `output/` — final layout

```
output/
  tabela1a_populacao_totais_tipo.csv            Table 1a
  tabela1_populacao_risco_tipo.csv              Table 1b (values)
  tabela1_populacao_risco_tipo.pdf / .png       Table 1b (bar chart)
  plot_pct_risk_sprawl_vs_compact_pure.pdf/.png Figure 2
  plot_pct_risk_sprawl_vs_compact_population.pdf/.png
  table2_main_municipalities.html/.tex/.docx    Table 2
  ed_table2_mediators.*                         ED Table 2
  ed_table3_fua.*                               ED Table 3
  ed_table4_horserace.*                         ED Table 4
  ed_table5_interactions.*                      ED Table 5
  ed_figure_standardized_coefficients.pdf/.png/.csv
  ed_table_sensitivity_leapfrog_2000m.*         (if the re-run is done)
```

Not here: Figure 1's layers (`data/processed_data/03_urban_footprint/figuras/`);
`model_objects_table2.rds` (an intermediate, `data/processed_data/04_regression/`).

---

## 8. Validate checklist for this stage (runbook steps 6–7)

Each row is a **test**, not a target. The numbers each exhibit must reproduce live in
`manuscript/results_targets_v2.md`; the point of this table is what has to agree with what.

| Exhibit | Compare against | The test |
|---|---|---|
| Table 1a/1b | `diagnostico_legacy_proxy_tabela1a.csv`, baseline variant (skipped when absent, as it is here — see §6.1) | Exact match to the person. Diffs against the pre-rework targets are reported, not a STOP |
| Figure 1 | the script's own crosstab | classified cells = compact + consolidated + sprawl = `urbano_2020 == TRUE`; the flagged-municipality count equals Table 1's sample |
| Figure 2 | the script's own summary | The N printed in both subtitles equals the restricted-sample-plus-positive-growth count; medians and the 45°-line share recorded for the `results_used.md` update |
| Table 2 | `model_objects_table2.rds` metadata | The pre/post-filter counts printed by `table2_and_ed_tables.R` equal those printed by `16_estimate_models.R` at estimation |
| ED Table 2 | the same metadata | The with/without-mediator N's differ as the differing `complete.cases` sets require |
| ED Table 3 | the same metadata | `zero_area_2000` is dropped as constant at arrangement level and footnoted (6c2 finding 4) |
| ED Table 4 | the same metadata | N equals Table 2's — same sample, joint specification |
| ED Table 5 | the same metadata | The region columns' N equals the urban-class columns' N minus the Centro-Oeste municipalities, and the two `× Center-West` rows are absent |
| ED Figure | `tab_main_mun` | The script's own self-check: `max|t_original − t_check|` below 1e-8 |

Then, and only then, `manuscript/results_targets_v2.md` is written from the exhibit files by
`build_results_targets.R`, and the manuscript's numbers are updated from it.

Three of the items it carries come from this stage: Figure 2's two filters counted separately,
ED Table 3's pre-6f and post-6f treatment coefficients side by side with the Δpp Sprawl
significance change flagged, and the funnel note recording that `complete.cases` runs over all
formula variables.

**One item is already known to need a manuscript change, not just a target update.** 6f.2's
asymmetric arrangement denominator moved ED Table 3's Δpp Sprawl coefficient across the 10%
threshold, so the draft's claim of a significant sprawl effect on the exposed-share change *at
FUA level* needs softening. `MIGRATION_PLAN.md`'s "Open questions still not resolved" item 1
holds the before/after; it is a writing task and nothing in the pipeline will flag it.

---

## 9. State and open decisions

| # | Item | State |
|---|---|---|
| 1 | Table 1 (§6.1) | **Done** — `8fc27d2`; confirmed against real data 2026-09-10, baseline cross-check exact |
| 2 | Figure 1 (§6.2) | **Done** — `c361fb5`; confirmed 2026-09-10. The `urbano_*` fix was not cosmetic: the old derivation drew shrinkage cells wrong in panel a |
| 3 | Figure 2 (§6.3) | **Done** — `918700b` |
| 4 | Script 16 saves / `table2_and_ed_tables.R` formats (§6.4) | **Done** — `57a5b95`; confirmed 2026-09-11, the split preserved every number and the VIF table |
| 5 | ED Figure (§6.5) | **Done** — `2cd937d`, `fde0896`; self-check exact, two rendering bugs fixed |
| 6 | ED sensitivity (§6.6) | **Not written** — skipped 2026-09-11 (researcher's call); scope still open |
| 7 | `robustness/` repointing (§6.8) | **Done** — `d8c0a2b`; six of seven confirmed against real data, `case_study.R` still unrun |
| 8 | `00_run_all.R` (§6.7) | **Done** — `c853b5d`; confirmed end to end 2026-09-11 |

**Open for the researcher:**

- The `requireNamespace()`/`install.packages()` guard on `outlier_diagnostics.R`'s
  `DescTools`/`moments` loads, now that the gap has caused a real failure.
- Whether `16_estimate_models.R:201` and `figure2_exposure_scatter.R:32` should also read
  `MIN_POP_RISCO_2010` from `00_setup.R` (§6.8). They still declare their own, at the same
  value; `00_setup.R` now carries the canonical one, so there are three declarations that agree
  today and could drift tomorrow. A one-line change each, on the estimation path — left for the
  researcher to approve rather than made as part of a cleanup.
- Running the rewritten `minimum_population_filter.R` (§6.8) and `double_filter_pp80.R`, neither
  of which has been executed since the change.
- ED sensitivity scope: which threshold, which windows, whether at all before submission.
- Export of the `tab3b` mediator-coefficient variant (proposal: no).
- The `pp_alta_2010 ≤ 80%` idea in `double_filter_pp80.R` (proposal: leave it a robustness
  script, not adopted).

---

## Appendix A — inputs for Figures 5 and 6 (hand-made, no script per Task 2(f))

Neither figure gets a stage-5 script — decided 2026-08-20, they are built by hand in QGIS —
but nothing maps their panels to actual files yet, so here it is, panel by panel, from reading
the producing scripts directly. This is an input map, not a build script.

### Figure 5 — spatial allocation of population to hazard zones

> *(manuscript legend, quoted in the request this section answers)* Panel a: original
> susceptibility layers for flood and landslides across three classes (low/medium/high),
> covering the entire municipal territory. Panel b: dissolved high-susceptibility layer, flood
> and landslides combined, overlaid on the urban footprint. Panel c: total population density.
> Panel d: resulting population-at-risk density for cells intersecting high susceptibility.

| Panel | Content | Source | Status |
|---|---|---|---|
| **a** | Raw susceptibility, all 3 classes, flood + landslides, whole municipal territory | — | **Not retained anywhere in the current data layout.** See below. |
| **b** (susceptibility half) | Dissolved high-susceptibility polygon, flood + landslides combined | `data/processed_data/02_hazard_zones/susceptibilidade_unida.gpkg` — stage 2, `02_prepare_high_susceptibility_layer.py` (concatenates the already high-only `suscet_massa_br.gpkg` + `suscet_inundacao_br.gpkg`, clips to municipal boundary, dissolves by `COD_MUNICIPIO`) | Exists |
| **b** (urban-footprint half) | Urban footprint, for the overlay | `urbano_2010`/`urbano_2020` on stage 3's common grid (script 04) — this is exactly Figure 6's own subject | Exists (Figure 6 draws the same flag) |
| **c** | Total population density per grid cell | `data/processed_data/02_hazard_zones/grade_2022_BR_com_suscept_alta_agsn.gpkg` — stage 2, `03_cross_grid_high_susceptibility.py`. Column `populacao` (already renamed from whichever IBGE population field it found); density = `populacao / (cell area in km²)`. 2010 file exists in parallel (`grade_2010_BR_com_suscept_alta_agsn.gpkg`) if the 2010 snapshot is wanted instead. | Column exists; density itself is computed at plot time |
| **d** | Population-at-risk density per grid cell | Same file, column `prop_suscept` (fraction of the cell inside the dissolved high-susceptibility polygon, 0–1). `pop_suscept = populacao × prop_suscept`; density = `pop_suscept / (cell area in km²)`. | **`pop_suscept` is not itself a stored column** — script 03 only carries `populacao` and `prop_suscept` on the per-cell file; the product is computed just before it's summed into `resumo_municipal_suscept_alta_agsn.csv` (the *municipal* summary), not written back per-cell. One extra `mutate()` at plotting time. |

**Panel d and the exposure-weighting rule (MIGRATION_PLAN.md 6e, decided 2026-09-11).** Panel d
is **area-weighted**: `pop_suscept = populacao × prop_suscept`, as the table row above says. That
was always stage 2's rule, and since 2026-09-11 it is the whole pipeline's rule — stage 3's
`07_aggregate_municipality_metrics.R` was corrected to weight the same way, retiring the
any-overlap rule (`LIMIAR_SUSCEPT <- 0`: every resident of a cell counted as exposed if any part
of the cell intersected the hazard layer) that produced the `pop_*_risk_*` columns behind Table 1,
Figure 2 and Table 2. So panel d and the tabular exhibits now measure the same quantity; before
the correction they did not, and differed substantially. The magnitude is in
`MIGRATION_PLAN.md` 6e, as of its own date.

One wording consequence for the manuscript, flagged here and not acted on: the legend quoted
above describes panel d as "population-at-risk density **for cells intersecting** high
susceptibility". That phrasing is the any-overlap rule, and it does not describe what panel d
plots or what the pipeline now computes — the density is of the population in the
high-susceptibility *fraction* of each cell. Manuscript text is out of scope for this file; the
correction is recorded in MIGRATION_PLAN.md 6e and the numbers land in
`manuscript/results_targets_v2.md`.

**Panel a's real gap.** The three-class layer is discarded on purpose, early, by design: stage 1
script `04_dissolve_high_susceptibility.R` filters every polygon to the high class before
dissolving (L152–176) — medium and low never reach any
`data/processed_data/` file, consistent with rule 9. `data/raw_data/01_download_susceptibility_maps/`
is empty here (just `.gitkeep`) — the raw, all-classes per-municipality shapefiles only ever
existed on whichever machine ran stage 1's scraping, in a local `saida/script1_objetos_sf.RData`
that was never migrated into the `data/` skeleton. This is expected under `CLAUDE.md`'s
"Definition of done" (stage 1 is documented-and-deposited, not reviewer-runnable), not a bug to
fix in this pipeline. Two ways to get panel a, neither of them a stage-5 script:
(a) if that `.RData` (or the raw per-municipality `.shp`/`.gpkg` files themselves) still exists
on the researcher's machine from the original scraping run, panel a comes straight from it —
pick one illustrative municipality and plot its `CLASSE` column directly (the same column
`04_dissolve_high_susceptibility.R:153` reads: `names(sfobj)` matching `classe|nivel|grau|risco`);
(b) re-scrape just that one municipality fresh from RIGEO with stage 1 scripts 01–03 pointed at
it alone — small and fast, unlike a full-Brazil re-run, since illustration needs one city, not
the whole universe.

### Figure 6 — urban footprint delimitation

> *(manuscript legend, quoted in the request this section answers)* Panel a: GHSL built-up
> density layer. Panel b: aggregated from its 100 m grid into the 200 m IBGE statistical grid
> (rotated relative to the GHSL grid). Panel c: statistical-grid cells with population density
> at or above 300 inhabitants/km². Panel d: resulting urban footprint, both criteria jointly.

| Panel | Content | Source | Status |
|---|---|---|---|
| **a** | Raw GHS-BUILT-S, 100 m, built-up surface per cell | `data/raw_data/03_urban_footprint/ghsl_raw/GHS_BUILT_S_E2020*.tif` — stage 3, script 02. **Decided (researcher, 2026-09-10): epoch E2020**, matching the 2010→2022 outcome-window delimitation scripts 03–04 actually compute (feeds `urbano_2020`); script 02 also downloads E2000/E2010, kept for the 2000–2010 treatment branch, not used for this figure. | Exists on disk once script 02 has run |
| **b** | Same built-up surface, aggregated onto the 200 m IBGE grid | `built_pct_2010` / `built_pct_2020` columns on the common grid (`grade_common_grid_2010_2022.parquet`/`.gpkg`, or `grade_urban_form_2010_2022.parquet` after script 04) — stage 3, script 03, via `exact_extract()` (sum + count of the 100 m pixels inside each 200 m/1 km cell) | Exists |
| **c** | Grid cells at or above 300 inhabitants/km² **alone** (one criterion in isolation, for illustration — not script 04's actual joint rule) | **Not a stored column.** Compute `dens_hab_km2 = populacao / (area_total / 1e6) >= 300` from the same grid's `populacao` (or `pop_2010_alocada` for the 2010 side) and `area_total` — both already on it, per script 04's `classificar_urbano(built_pct, populacao, area_total_m2, LIMIAR_BUILT, LIMIAR_DENS)` signature | One-off derived cut at plot time |
| **d** | Final urban footprint, `built_pct ≥ 10%` AND `density ≥ 300/km²` jointly | `urbano_2010`/`urbano_2020` — stage 3, script 04, `classificar_urbano()` (`LIMIAR_BUILT = 10`, `LIMIAR_DENS = 300`) | Exists |

Panel c is the only genuinely new derived quantity for either figure (a single-criterion
density cut nothing in the pipeline computes on its own, since the pipeline only ever needs
the two criteria jointly) — everything else in both figures is an existing column, read
straight off an existing file.
