# Regression Dataset and Models Pipeline — `04_regression_dataset_and_models/`

> **A note on citations in this document.** It cites records kept in the project's private
> working repository — `MIGRATION_PLAN.md` (dated decisions), `METHODS_AUDIT.md`,
> `results_used.md` (the pre-rework target values), `AUDIT.md`, `VERIFICATION.md` and
> `CLAUDE.md` (the numbered conventions, restated in `README.md`) — together with commit
> hashes from that repository. Those files are not part of this deposit, and nothing here
> depends on them; the citations are kept so each decision can be traced to where it was
> recorded. Current values live in `manuscript/results_targets_v2.md`.

Builds the municipality- and functional-urban-area-level regression dataset and estimates the
pre-period regressions (urban form 2000–2010 vs. population growth in risk zones 2010–2022).

> This file is the source of truth for how stage 04 runs. It supersedes an earlier document
> describing the pre-migration `regression2/` version of this stage (old script numbers,
> pre-common-grid variable names, and the retired medium-susceptibility outcomes); that document
> is not part of this repository.

**Updated 2026-09-16** for 6f.1 (susceptibility-only sample upstream; the arrangement predicate
fix), 6f.2 (`area_urbana_2010_m2_mapped`), `MIN_POP_RISCO_2010 = 200`, and the completed
estimate/format split of script 16 — and to remove result values, see below.

## Result values are not in this file

This document describes **what each script does and in what order**. It does not state counts,
coefficients or population totals. Every such value belongs in
**`manuscript/results_targets_v2.md`**, which is the single source of result values for the
whole pipeline.

> **`manuscript/results_targets_v2.md` is generated, not hand-written.**
> `05_exhibits/build_results_targets.R` rebuilds it from the current exhibit outputs; every
> value carries the file it came from, that file's mtime, and a VERIFIED/PENDING status.
> Nothing here is an authoritative figure for the size of any sample file, for N at any
> specification, or for any
> coefficient — read them from that file not from here and not from an
> older copy of this document.
>
> **What it must contain is specified** in
> `manuscript/results_targets_v2_REQUIREMENTS.md` — the slot-by-slot specification the
> generator implements.

Parameters below that live in code (sample cuts, thresholds, CRS codes, package versions) are
stated with their file and line, because they describe the script rather than a result.

---

## Central hypothesis

Cities that grew in a compact form (densification + infill) near the urban center between 2000
and 2010 show different population growth in high-susceptibility zones between 2010 and 2022
than cities that sprawled (peripheral + extension + leapfrog growth), because the affordable
housing stock's location relative to hazard zones differs under the two growth patterns.

- **Treatment (compact):** `pct_area_densif_infill_0010` — densification + infill share of
  2000–2010 growth.
- **Comparison (sprawl):** `pct_area_periph_ext_leap_0010` — peripheral + extension + leapfrog
  share of 2000–2010 growth.
- **Outcomes:** `g_alta` (growth rate of the population within the high-susceptibility zone,
  2010–2022) and `delta_pp_alta` (change in percentage points of the population share in that
  zone).

High susceptibility only (CLAUDE.md rule 9): every script in this pipeline computes and reads
high-susceptibility variables exclusively. A medium-susceptibility branch existed earlier in the
pipeline's history; it has been fully retired (see "Medium-susceptibility retirement" below).

## Analytical samples

Two parallel datasets are built and carried through the whole pipeline:

- **Municipality** (`dataset_regressao_municipio.csv`): one row per municipality with mapped
  susceptibility data, restricted to a valid `delta_pp_alta`.
- **Arrangement / functional urban area** (`dataset_regressao_arranjo.csv`): one row per
  qualified population arrangement (`CD_CIDADE`) plus one row per isolated municipality treated
  as a single-member arrangement.

`01_compose_sample.R` defines both sample bases (`amostra_mun`/`amostra_arr`/`mun_isol`) that
every later script filters or joins against.

---

## Directory structure

```
04_regression_dataset_and_models/
├── 00_setup.R                          # packages, paths, helper functions
├── 00_run_all.R                        # runs 01-16 in order (Python script 06 run separately)
├── 01_compose_sample.R
├── 02_download_census_basic.R
├── 03_download_jrc_water.R
├── 04_download_geobr_censobr.R         # all geobr/censobr downloads for this stage, in one place
├── 05_prepare_gdp.R
├── 06_builtup_in_susceptibility.py     # Python -- run manually before 07
├── 07_housing_quality.R
├── 08_available_land.R
├── 09_distance_to_seat.R
├── 10_topography.R
├── 11_inequality.R
├── 12_slum_growth.R
├── 13_dependent_variables.R
├── 14_independent_variables.R
├── 15_final_dataset.R
└── 16_estimate_models.R
```

All data reads/writes go through `R/paths.R` (sourced by `00_setup.R`), not hardcoded paths:

| Variable (from `00_setup.R`) | Resolves to |
|---|---|
| `stage03_raw_dir` | `data/raw_data/03_urban_footprint/` |
| `stage03_data_dir` | `data/processed_data/03_urban_footprint/` |
| `amostra_rds` | `data/processed_data/03_urban_footprint/amostra_municipios.rds` |
| `growth_types_dir` | `data/processed_data/03_urban_footprint/crescimento_urbano/` |
| `metricas_dir` | `data/processed_data/03_urban_footprint/metricas/` |
| `stage02_data_dir` | `data/processed_data/02_hazard_zones/` |
| `raw_data_dir` | `data/raw_data/04_regression/` |
| `data_dir` | `data/processed_data/04_regression/` |
| `ghsl_susc_dir` | `data/processed_data/04_regression/ghsl_susceptibility/` |
| `housing_dir` | `data/processed_data/04_regression/housing_quality/` |
| `tables_dir` | `data/processed_data/04_regression/tables/` |
| `figures_dir` | `data/processed_data/04_regression/figures/` |

`06_builtup_in_susceptibility.py` is Python (its own `data/raw_data`/`data/processed_data` paths,
mirroring the same layout) and shares the project's top-level `requirements.txt`.

---

## Running the pipeline

From the **project root**:

```bash
Rscript 04_regression_dataset_and_models/00_run_all.R
```

`00_run_all.R` runs scripts 01–16 in order, each in an isolated environment, and stops on the
first error. **Script 06 is Python and must be run separately, before script 07**, since 07 reads
its output:

```bash
python 04_regression_dataset_and_models/06_builtup_in_susceptibility.py
```

`05_exhibits/robustness/`'s seven scripts (correlations, DAG tests, outlier diagnostics, minimum
population filter, double filter, steep terrain, case study) are kept live but unnumbered — they
read `dataset_regressao_{municipio,arranjo}.csv` after script 16 but are not part of
`00_run_all.R`. They were **repointed on 2026-09-11** (commit `d8c0a2b`): all seven now
`source("04_regression_dataset_and_models/00_setup.R")` and use this stage's current
`tables_dir`/`figures_dir` names, as does `05_exhibits/figure2_exposure_scatter.R:30`. Earlier
copies of this document said they could not run; that is no longer the case.

---

## Detailed script descriptions

### `00_setup.R` — Configuration
Loads packages (`sf`, `dplyr`, `tidyr`, `readxl`, `readr`, `stringr`, `arrow`, `sfarrow`, `here`),
sources `R/paths.R`, and defines every path variable listed above plus `fmt()` (thousands/decimal
formatting for console output).

It also carries the stage's one **analysis parameter**, `MIN_POP_RISCO_2010` (added 2026-09-16),
so scripts that need the cut read one value instead of each holding a copy — see script 16 below
for what it does and for the three declarations that currently exist.

### `01_compose_sample.R` — Sample composition
Reads `amostra_municipios.rds` (stage 03) plus `DUR_Municipios.xlsx`/`tabela4709.xlsx` (raw IBGE
files) and produces the four sample-definition CSVs:

| File | Definition | Line |
|---|---|---|
| `amostra_mun.csv` | `filter(tem_susceptibilidade == TRUE)` — municipalities with mapped susceptibility | L41 |
| `mun_isol.csv` | the isolated subset of the above, `em_arranjo == FALSE` | L42 |
| `amostra_arr.csv` | members of **qualified** arrangements: ≥ 1 mapped member **and** `pop_arranjo > 50,000` | L75–87 |
| `amostra_universo.csv` | `amostra_arr` + `mun_isol` — the processing universe for scripts 02–14 | — |

For the size of each, see `manuscript/results_targets_v2.md`.

**This is the filter 6f.1 turns on.** `01_define_sample.R` (stage 03) defines the processing
universe; L41 here is what decides regression membership, and it has always been
susceptibility-only. That is why retiring stage 03's CPRM union changed the universe and the
arrangement count while leaving the regression sample untouched — no municipality with CPRM
risk and no susceptibility was ever in this dataset.

**Arrangement qualification is a value test, not a presence test** (fixed under 6f.1, L79–85).
The predicate is now `filter(any(tem_susceptibilidade %in% TRUE))` (L85). It was
`filter(any(!is.na(tem_susceptibilidade)))`, which tested whether the `left_join` at L72
*matched*, not whether the member is mapped — it happened to give the right answer only because
`amostra_mun` is already filtered to `TRUE` at L41, so the joined column carries `TRUE` or `NA`
and never `FALSE`. Behaviour today is unchanged; the predicate now says what it means and stays
correct if that ever changes.

**One entity, two units.** A functional urban area is *either* a multi-municipality arrangement
*or* a single isolated municipality, so the arrangement total is
`n_distinct(amostra_arr$CD_CIDADE) + nrow(mun_isol)` (L92–93). Counting `amostra_arr.csv` alone
silently drops the isolated FUAs — a mistake worth knowing about, since it has been made before
(`MIGRATION_PLAN.md` 6f.2, "CHECK 2b, first run").

### `02_download_census_basic.R` — Census Basico 2010
Downloads the IBGE Census 2010 "Basico" universe zip files for all 27 states and extracts
`code_tract`, `V002` (residents in permanent private households), `V009` (average nominal
monthly income of householders), and the derived `renda_percapita = V009 / V002`. Uses this raw
download rather than `censobr`'s "Basico" dataset, whose `V009` is `NA` for most states.
**Output:** `basico_ibge_2010.parquet`.

### `03_download_jrc_water.R` — JRC Global Surface Water tiles
Downloads the JRC GSW v1.4 "occurrence" GeoTIFF tiles covering Brazil, used as a permanent-water
mask (occurrence ≥ 80%) in script 10. **Output:** `jrc_gsw/*.tif`.

### `04_download_geobr_censobr.R` — geobr/censobr reference data
Downloads and caches, as plain `.rds` files under `data/raw_data/04_regression/`, every
`geobr`/`censobr` dataset used later in this stage: 2010 census tract geometries and household
tract aggregates (script 07), municipal seats 1950–2010 (script 09), the national outline and
2022 municipal mesh (script 10), and household/population microdata (script 11). Consumer scripts
just `readRDS()` these files — no `geobr::`/`censobr::` calls or live-download logic anywhere else
in this stage.

**Why this exists as its own script**: `geobr`'s and `censobr`'s data servers were both confirmed
unreachable independent of network/proxy configuration during a real run — same failure from an
unrelated machine and network, ruling out anything fixable client-side. When that happens, this
script's header documents the exact call used for each dataset, so the same file can be generated
on a machine where it works and placed directly in `data/raw_data/04_regression/`; this script
then uses it as-is and skips that one live download. The old
`04_download_municipal_seats.R` (per-UF IBGE KML files) was **retired 2026-09-01** after IBGE
restructured its geoftp layout and broke its per-UF directory listing — it was already dead
weight (nothing downstream read its output; `09_distance_to_seat.R` had always used `geobr`'s
cascade instead), so this script now occupies the freed-up "04" slot instead of leaving a gap.

### `05_prepare_gdp.R` — GDP and population caches
Parses `pib_munic.xlsx`, `tabela200.xlsx`, `tabela202.xlsx` (raw IBGE Excel files) into cached
CSVs: **`pib_municipios_2010.csv`** (`cod_mun | pib_total_2010 | pop_total_2010 | pib_pc_2010`)
and **`pop_total_2000.csv`** (`cod_mun | pop_2000`).

### `06_builtup_in_susceptibility.py` — GHSL built-up area × susceptibility (Python)
Per statistical-grid cell (2010 and 2022 grids), computes total GHSL Built-S area and the
portion within high-susceptibility zones, for the 2010 and 2020 GHSL epochs. **Output:**
`ghsl_susceptibility/grade_{2010,2022}_com_ghsl_suscept.gpkg` (+ matching `.parquet`) and a
municipal summary CSV. Columns: `ghsl_total_{2010,2020}`, `ghsl_suscept_alta_{2010,2020}`,
`cod_mun_ghsl`.

### `07_housing_quality.R` — Housing quality and income quartiles
Builds two Census-2010-based independent variables — `prop_3mais_banheiros` (share of households
with 3+ exclusive-use bathrooms) and `renda_percapita` (household income per capita, from
script 02's output) — classified into quartiles within each arrangement. Census tract geometries
and household tract aggregates come from script 04's prepared files. Joins with script 06's
grid to compute `ghsl_fora_alta_{2010,2020}` (built-up area outside high susceptibility) by
quartile. **Outputs:** `housing_quality/setores_qualidade.{gpkg,parquet}`,
`housing_quality/resumo_quartis.csv`, `ghsl_susceptibility/grade_com_quartis.{gpkg,parquet}`,
`tables/builtup_nao_suscept_{banheiro,renda}.csv`.

### `08_available_land.R` — Safe available land
Computes area **not built up** and outside high susceptibility, by income quartile and growth
type: `area_nao_constru_fora_alta_{2010,2020} = pmax(0, area_fora_suscept_alta − ghsl_fora_alta_*)`.
**Outputs:** `ghsl_susceptibility/grade_safe_poor.{parquet,gpkg}`,
`tables/pct_nao_constru_{municipio,arranjo}.csv`, `tables/agregado_renda_crescimento.csv`.

### `09_distance_to_seat.R` — Distance to municipal seat
Euclidean distance (EPSG:5880) from each urban-footprint cell to its arrangement's reference seat
(the most populous member's municipal seat, using script 04's prepared 1950–2010 cascade of
`geobr::read_municipal_seat` results and two point overrides for BH and Tubarão). Aggregated by
quartile and by growth type (2010–2022 and 2000–2010). **Outputs:**
`tables/dist_sede_{municipio,arranjo}.csv`, `tables/dist_sede_tipo_arranjo{,_simples}.csv`,
`tables/sedes_municipios.gpkg`.

### `10_topography.R` — Topographic restriction
Within a reference circle per arrangement (center = seat, radius = 2.5× the equivalent radius of
the 2010 urban footprint, minimum 5 km), classifies SRTM-derived slope (via `elevatr`) and water
(JRC + ocean, via script 04's prepared national outline) pixels, restricted to each
municipality's share of the circle (municipal mesh also from script 04). `prop_restrita =
prop_agua + prop_inclinado`; `prop_inclinado_em_alta` restricts the slope calculation to
high-susceptibility zones. Slowest script in the pipeline (~2–4h for all of Brazil; SRTM tiles
cached under `srtm_cache/`). **Outputs:** `tables/topografia_{municipio,arranjo}.csv`.

**Parameters, in code:** `MIN_RADIUS_M <- 5000` m (L63); `SLOPE_STEEP <- 15` %, cited in the
code to **NBR 11682; CPRM 2014** (L64) — the one constant in this stage that carries a source;
reference-circle radius `pmax(2.5 × r_equiv_m, MIN_RADIUS_M)` (L173), a scaled buffer around the
seat rather than the municipal or urban polygon; water mask at JRC occurrence ≥ 80% (L14).

### `11_inequality.R` — Housing and mobility inequality
Census-2010 microdata (from script 04's prepared files) on rented dwellings and commuting
workers: weighted median rent, `palma_rent` (top-10%/bottom-40% rent ratio by household income),
mean/IQR commute time, `pct_long_commute` (>1h), and `palma_commute` (top-10%/bottom-40%
commute-time ratio by individual income) — the manuscript's key housing-market mechanism
variable. **Outputs:** `tables/housing_mobility_inequality_{municipio,arranjo}.csv`.

### `12_slum_growth.R` — Slum (AGSN) population growth
Reads the high-susceptibility AGSN grids (`data/processed_data/02_hazard_zones/`) for 2010 and
2022, computes `pop_alta_slums_*` (AGSN population within high susceptibility) and
`pop_total_slums_*` (total AGSN population, regardless of susceptibility), and derives
`g_slums_1022`, `g_alta_slums_1022` (2010–2022 growth rates; the outside-high-susceptibility
counterpart is not precomputed here — `16_estimate_models.R` derives it directly as
`g_slums_1022 - g_alta_slums_1022`). Reads only the flat columns it needs from each grid via an
OGR SQL query, avoiding a costly full-geometry parse of the national grid.
**Outputs:** `tables/slums_{municipio,arranjo}_BR.csv`.

### `13_dependent_variables.R` — Dependent variables and baseline urban form
Reads stage 03's common-grid metrics (`metricas_{municipio,arranjo}_2010_2022.csv`) and computes
the dependent variables — `pp_alta_{2010,2022}`, `delta_pp_alta`, `g_alta` (growth within high
susceptibility, normalized by the zone's own 2010 population) — plus 2010–2022 urban-form shares
(`pct_area_densif`, `_peripheral`, `_extension`, `_leapfrog`) and `g_fora_alta` (growth outside
the risk zone). **Outputs:** `tables/met_{municipio,arranjo}_com_y_BR.csv`.

**Inherits stage 03's asymmetric arrangement rule (6f.2).** Everything here derived from
`pop_*` is mapped-members-only at arrangement level; everything derived from `area_m2_*` is
all-members. `area_urbana_2010_m2 = area_m2_consolidated + area_m2_densification +
area_m2_peripheral` (L122) is therefore all-members, while `pop_urbana_2010_cg =
pop_2010_total` (L140) is mapped-only — which would make `log_density_2010` a cross-group
ratio for mixed arrangements.

The fix is a carried column, not a changed one. Script 07 emits
`area_urbana_2010_m2_mapped` on the **arrangement** file; a small helper here (L146–154)
passes it through when present and otherwise sets it equal to `area_urbana_2010_m2` — the
municipality-level fallback, correct there because a municipality is either mapped or not and
the unmapped ones are already excluded at `01_compose_sample.R:41`. `16_estimate_models.R:100–101`
then uses `area_urbana_2010_m2_mapped` unconditionally for `log_density_2010`, while
`log_area_2010_km2` (L95) stays on the all-members `area_urbana_2010_m2`, since it is a pure
area measure.

Scope: `log_density_2010` is **not** in `CTRL_ALTA` and no specification in script 16 uses it —
it is computed there and consumed only by the `05_exhibits/robustness/` scripts that build a
density. So 6f.2's density decision cannot move Table 2 or any ED table.

### `14_independent_variables.R` — Dataset assembly
Joins every prior script's output onto `13`'s dependent-variable table: safe available land (08),
topography (10), distance (09), region (from `cod_mun`'s UF prefix), GDP per capita (05), REGIC
2018 urban hierarchy (auto-downloaded from IBGE), 2010 slum population share (raw
`tabela3381.xlsx`), slum growth (12), 2000–2010 urban growth and 2000 urban density (stage 03's
`metricas_crescimento_2000_2010{,_arranjo}.csv`), and housing/mobility inequality (11).
**Outputs:** `tables/dataset_completo_{municipio,arranjo}.csv`.

The health facilities (2015 disaster-exposure) join that used to live here was removed:
`n_estab_saude` was a confirmed-dead column (never read by `16_estimate_models.R` or any
`05_exhibits/robustness/*.R` script) — see "Column selection" below.

### `15_final_dataset.R` — Final dataset
Selects the columns actually used downstream (see "Column selection" below) from `14`'s full
dataset, restricts the arrangement dataset to qualified arrangements + isolated municipalities,
and filters to rows with a valid `delta_pp_alta`. **Outputs:**
`tables/dataset_regressao_{municipio,arranjo}.csv` — the files every model and robustness script
reads.

### `16_estimate_models.R` — Pre-period regressions (estimation only)

**The estimate/format split is done** (commit `57a5b95`, applied 2026-09-11 per
MIGRATION_PLAN.md 6d). This script **estimates the models and saves the fitted objects; it
formats and exports nothing.** No `modelsummary`/`flextable` call is left in stage 04.
Coefficient labels, hidden-control notes, `coef_omit` patterns and the three output formats now
live in `05_exhibits/table2_and_ed_tables.R`, which reads the saved objects. Earlier copies of
this document described the split as a pending gap; it is not.

**Output:** `data/processed_data/04_regression/model_objects_table2.rds` (L524–525) — a named
list of the five fitted-model lists plus the metadata the table notes need
(`min_pop_risco_2010`, pre/post-filter N, the Centro-Oeste drop count, an estimation
timestamp), L509–522.

| Object saved here | Exhibit, in `05_exhibits/table2_and_ed_tables.R` |
|---|---|
| `tab_main_mun` | **Table 2** — municipalities, 4 columns: `g_high` × compact/sprawl, `Dpp_high` × compact/sprawl |
| `tab_mediators_mun` | **ED Table 2** — with / without / mediators-only |
| `tab_appA_arr` | **ED Table 3** — functional urban areas, same 4 specs, HC3 |
| `tab_horserace_mun` | **ED Table 4** — compact and sprawl entered jointly |
| `tab_interact_mun` | **ED Table 5** — treatment × `urban_class` and × `regiao` |

The old internal names (`tab1_main_municipios_high`, `tab2_interactions…`) predated the
manuscript's numbering and are gone; the exhibit numbering above is the paper's.

**Sample cut, in code: `MIN_POP_RISCO_2010 <- 200`** (L201), applied to both datasets at
L205–207. It was `1000` when first decided on 2026-09-08 and was **revised to 200 on
2026-09-12** — the weighting correction (6e) cut `pop_2010_risk_total` substantially, so the
unchanged nominal value had silently become a far more aggressive restriction than the one that
was decided. `MIGRATION_PLAN.md` 6c1 holds the rationale for both values; note that its heading
still reads `> 1000` and its revision paragraph is what applies.

**Five declarations of this constant exist, and they must stay equal.** Since 2026-09-16 the
canonical one is `00_setup.R:90` — `05_exhibits/robustness/`'s two threshold scripts read it
from there rather than hardcoding, which is what stopped them drifting to a second
configuration after the 2026-09-12 revision. Four others still declare their own, all at the
same value:

| Declaration | Status |
|---|---|
| `00_setup.R:90` | **canonical**; read by the two `robustness/` threshold scripts |
| `16_estimate_models.R:201` | the pipeline's own; a one-line repoint away |
| `05_exhibits/figure2_exposure_scatter.R:32` | same; comment already says it must match script 16 |
| `diagnostics/native_vs_allocated_pop_2010_risk.R:1108` | same |

`05_exhibits/table2_and_ed_tables.R:66` is the one consumer that does it right without a
declaration at all: it reads the value out of `model_objects_table2.rds`'s metadata, so its
table notes cannot disagree with the estimation that produced them.

Repointing script 16 and `figure2_exposure_scatter.R` to `00_setup.R` is a one-line change each
and would leave only the two diagnostics' intentional copies. That was left for the researcher
to approve rather than made as part of a cleanup, since it touches the estimation path.

The script's own header (L160–168) records an open empirical check that the run answers rather
than the code: the 2026-09-08 evidence *against* 200 was measured on the any-overlap
distribution and does not transfer, so whether `log_pop_total_2000` and `log_area_2000_km2`
come out inflated again at this cut has to be read off Table 2's output.

**Two ordering facts worth knowing when reading any N:**

1. **The population filter runs first, listwise deletion second.** `ds_mun` is cut at L205, and
   `fit_safe()` applies `complete.cases` per specification at L298 — so different
   specifications have different N, by construction.
2. **`complete.cases` runs over *all* formula variables** (L297–298): outcome, treatment and
   every `CTRL_ALTA` term, not a narrower fixed subset. `results_used.md`'s Table 2 note implies
   a narrower listwise set ("safe available land and steep terrain"); the script prints the gap
   between the two at L275–278 rather than hiding it.

**Standard errors** (L310–317): municipality models cluster by `NM_CIDADE`, the functional urban
area, via `vcovCL`, falling back to HC3 when no cluster vector is attached; arrangement models
use HC3 outright, since each row is already a unique cluster. The models carry their cluster
vector as `attr(mod, "cluster_vec")` (set in `fit_safe()`, L302–303), which `saveRDS()`
preserves — so `table2_and_ed_tables.R` recomputes clustered SEs after reload without needing
the data, and redefines `vcov_clust`/`vcov_hc3` itself rather than relying on serialized
closures.

**Medium and high+medium specs** (`y_med`, `y_hm`, formerly Appendix B/C) were removed; see
"Medium-susceptibility retirement" below.

---

## Medium-susceptibility retirement

CLAUDE.md rule 9 restricts the final analysis to high susceptibility. A medium-susceptibility
branch existed in scripts 06–08, 10, 12, and 14, computing parallel `*_medio`/`*_alta_medio`
variables. Its producing inputs (`grade_*_BR_com_suscept_medio_agsn.gpkg`,
`susceptibilidade_unida_medio.gpkg`) were archived and never migrated to
`data/processed_data/02_hazard_zones/`. Every stage-04 script that used to compute a medium
branch has had it removed, `16_estimate_models.R` included: its Appendix B/C specs (`y_med`,
`y_hm`) were **deleted**, not left in place — no `y_med`, `y_hm` or `CTRL_MEDIO` appears in the
script any more (header note, L44–51). They referenced columns no producing script generates,
and neither appendix table is referenced in `manuscript/results_used.md`, so no published
result is lost. The four `05_exhibits/robustness/` scripts that carried medium content had those
blocks removed in the same pass (`d8c0a2b`).

## Column selection (`15_final_dataset.R`)

The final regression datasets carry only the columns actually read by `16_estimate_models.R` or
by `05_exhibits/robustness/*.R`. Every medium-susceptibility column, and 28 further columns
confirmed by grep to have zero downstream references (raw population/area/GDP/health totals
whose only use was computing a share, log, or growth rate that *is* kept; unquartiled or level
variants of variables whose quartile/growth-rate form is what's actually used), were dropped from
the selection. See MIGRATION_PLAN.md §6c0 for the full list and the verification method.

---

## External data sources

| Source | Used by | Notes |
|---|---|---|
| IBGE Census 2010 "Basico" (raw universe zips) | 02 | Downloaded per state, cached |
| JRC Global Surface Water v1.4 (2021) | 03, 10 | Occurrence layer, 10° × 10° tiles |
| IBGE municipal GDP / Census 2010 & 2000 population tables | 05 | `pib_munic.xlsx`, `tabela200.xlsx`, `tabela202.xlsx` |
| GHSL BUILT-S (2010, 2020) | 06 | 100 m Mollweide rasters, downloaded in stage 03 |
| `data/processed_data/02_hazard_zones/` (susceptibility + grids) | 06, 08, 10, 12 | Stage 02's frozen outputs |
| `geobr` (census tracts, municipal seats, municipal mesh, country outline) | 04 | Downloaded once by script 04, read by 07/09/10 as `.rds` files |
| `censobr` (households, population microdata) | 04 | Downloaded once by script 04, read by 07/11 as `.rds` files |
| SRTM (via `elevatr`, AWS) | 10 | Per-state DEM download, cached under `srtm_cache/` |
| REGIC 2018 (IBGE urban hierarchy) | 14 | Auto-downloaded from the IBGE geoftp |
| IBGE Census 2010 table 3381 (slums) | 14 | Raw xlsx, manually placed |
