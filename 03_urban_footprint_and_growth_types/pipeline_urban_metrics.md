# Pipeline: Urban Form Metrics (`03_urban_footprint_and_growth_types/`)

> **A note on citations in this document.** It cites records kept in the project's private
> working repository — `MIGRATION_PLAN.md` (dated decisions), `METHODS_AUDIT.md`,
> `results_used.md` (the pre-rework target values), `AUDIT.md`, `VERIFICATION.md` and
> `CLAUDE.md` (the numbered conventions, restated in `README.md`) — together with commit
> hashes from that repository. Those files are not part of this deposit, and nothing here
> depends on them; the citations are kept so each decision can be traced to where it was
> recorded. Current values live in `manuscript/results_targets_v2.md`.

R pipeline that computes urban footprint and growth-type metrics for the Brazilian
municipalities/functional urban areas ("arranjos") mapped by **SGB high susceptibility**,
integrating IBGE Census population (2010, 2022) with GHSL built-up and population rasters.

**Rewritten 2026-09-05** to match the pipeline as it exists after the 6b0 common-grid
unification (`MIGRATION_PLAN.md`, decided 2026-08-28) and the Migrate rename/translate
pass. The previous version of this document described the pre-rework dual-grid
("M-family") design under the old script names (`03_integrar_grade_ghsl.R`,
`06_metricas_municipio.R`, etc.) — that design no longer exists on disk. If you are
reading a cached or printed copy of this file dated before 2026-09-05, it is stale;
this copy reflects the actual scripts in this folder.

**Updated 2026-09-16** for 6f.1 (CPRM risk retired from this stage's sample definition and
common grid) and 6f.2 (asymmetric arrangement aggregation), and to remove result values —
see the next section.

## Result values are not in this file

This document describes **what each script does and in what order**. It does not state counts,
coefficients or population totals. Every such value belongs in
**`manuscript/results_targets_v2.md`**, which is the single source of result values for the
whole pipeline.

> **`manuscript/results_targets_v2.md` is generated, not hand-written.**
> `05_exhibits/build_results_targets.R` rebuilds it from the current exhibit outputs; every
> value carries the file it came from, that file's mtime, and a VERIFIED/PENDING status.
> Nothing here is an authoritative figure for the processing universe, the number of
> arrangements, the sample at
> any funnel step, or any population total — read them from that file, not from here and not
> from an older copy of this document.
>
> **What it must contain is specified** in
> `manuscript/results_targets_v2_REQUIREMENTS.md` — the slot-by-slot specification the
> generator implements.

Parameters below that live in code (thresholds, connectivity rules, resolutions, CRS codes) are
stated with their file and line, because they describe the script rather than a result.

**Main analysis window**: 2010 → 2020 (built-up), with population variation 2010 → 2022
(scripts 01–07, on the unified common grid). Script 06 extends the growth-type
classification to a **third window, 2000 → 2010**, using GHS-POP/GHS-BUILT-S E2000 for
the regression treatment variable — see its own section below.

**Base spatial unit**: 2022 IBGE statistical grid (200m × 200m cells in areas urban at
2022; 1km × 1km cells elsewhere) — see "The common-grid framework" below.
**Built-up**: GHS-BUILT-S R2023A (100m, Copernicus/JRC).

---

## The common-grid framework (6b0)

Before 2026-08-28, this pipeline processed 2010 and 2022 as **two separate grids** (each
in its own native geometry), reconciling them afterward via a cross-grid centroid join
whenever a metric needed both years at once (the "M-family": M1–M8 metrics, some
same-grid, some cross-grid). That design is retired.

The current design unifies everything onto **one geometry — the 2022 statistical
grid**. To make that possible, 2010 population is **allocated** onto the 2022 grid
once, in script 03:

1. Every 2022 cell's centroid is matched to the 2010 "mother cell" that contains it
   (`st_within`; a 2010 cell can contain up to ~25 2022 subcells at 200m resolution).
2. The mother cell's 2010 population is redistributed across **all** of its matched
   2022 subcells, proportional to each subcell's GHSL `built_m2_2010` (built-up area as
   a proxy for where the population actually lived). Fallback: uniform `1/n` weight
   when every subcell's `built_m2_2010` is 0.
3. 2022 cells whose centroid falls outside any 2010 mother cell (grid-expansion areas
   with no 2010 coverage) get no `pop_2010_alocada`.

This produces `pop_2010_alocada` — a real, correctly-scaled t1 population column that
lives on the 2022 grid geometry. Root-cause fix (documented in script 03's own header):
the pre-rework code performed this same allocation but filtered subcells to the
`tipo_crescimento`-classified subset **before** normalizing weights, over-concentrating
100% of a mother cell's population onto whichever small share of subcells happened to carry a
growth-type label. The current code allocates over every subcell first, with no
upstream filter; any later restriction (urban flag, growth type, susceptibility) is
applied as a plain filter on an already-correctly-allocated column. The script's own
validation is that the national `pop_2010_alocada` total equals `grade_ibge_2010.parquet`'s
native population total — an identity check, not a target; the totals themselves belong in
`manuscript/results_targets_v2.md`.

With `pop_2010_alocada` available, urban classification, patch sizing, and growth-type
classification all run **once**, on one grid, instead of twice with a cross-grid
reconciliation step. The old M2–M8 taxonomy is retired along with the design that
motivated it (see script 07's section).

**Consequence for patch sizing** (script 05): Major/Minor patches are classified using
`pop_2010_alocada` — the correct t1 population — instead of the pre-rework proxy
(2022 population standing in for t1, because no real t1 population existed on the
working grid before this rework). This is a disclosed, intended methodological change,
not a bug: patches are a t1 concept, and the manuscript's own Methods text describes
patches as identified "at t1". It measurably changed Table 1's Compact/Sprawl
breakdown relative to the pre-rework numbers (see `MIGRATION_PLAN.md` 6b0 for the
comparison as it stood on 2026-08-28 and the researcher's decision to keep the corrected
version — 6b0's figures predate 6e and 6f and are not current values).

**What stays outside the unification**: the 2000→2010 window (script 06) has no 2010
statistical-grid equivalent for the year 2000, so it keeps using GHS-POP as its own
population source at both ends, on the 2010 IBGE grid geometry (script 03's
`grade_ibge_2010.parquet`, still produced unchanged for this sole purpose).

---

## File structure

```
03_urban_footprint_and_growth_types/
├── 00_setup.R                              # packages, paths (via R/paths.R), helpers
├── 00_run_all.R                            # runs 01-07 in sequence
├── 01_define_sample.R                      # municipality/arrangement sample
├── 02_download_ghsl_data.R                 # download GHSL BUILT-S + POP (E2000/E2010/E2020)
├── 03_integrate_grid_with_ghsl.R           # build the common grid + GHSL + pop_2010_alocada
├── 04_delimit_urban_extent.R               # urbano_2010 / urbano_2020 flags
├── 05_classify_growth_types.R              # 6-type growth classification (2010->2020)
├── 06_classify_growth_types_2000_2010.R    # growth classification, 2000->2010 window
├── 07_aggregate_municipality_metrics.R     # municipality/arrangement metrics
└── pipeline_urban_metrics.md               # this file
```

**Run order**: `01 → 02 → 03 → 04 → 05 → 06 → 07`, all orchestrated by `00_run_all.R`.
Table 1 and Figure 1 are **not** part of this pipeline — they live in `05_exhibits/`
(`table1_population_by_growth_type.R`, `figure1_growth_type_layers.R`), reading this
pipeline's outputs without re-estimating anything. Superseded and orphan scripts from the
pre-migration `urban_form_metrics/` folder (two diagnostic scripts, two alternative table
scripts, a superseded growth script) are not part of this pipeline and are not included in
this repository.

---

## Script 00 — Setup

**File**: `00_setup.R`, sourced at the top of every other script in this folder.

Loads packages (`sf`, `terra`, `dplyr`, `tidyr`, `readxl`, `readr`, `stringr`,
`stringi`, `geobr`, `purrr`), sources `R/paths.R` for the shared
`raw_data_path()`/`processed_data_path()`/`output_path()` helpers, sets
`raw_data_dir`/`processed_data_dir` to this stage's subfolders
(`data/raw_data/03_urban_footprint/`, `data/processed_data/03_urban_footprint/`),
creates the `ghsl_raw/`, `crescimento_urbano/`, `metricas/` subfolders, and defines
`fmt()` (thousands-separator number formatting for console output).

---

## Script 01 — Define the sample

**File**: `01_define_sample.R` · **Output**: `amostra_municipios.rds`/`.csv`

Defines which municipalities enter the analysis:

1. Reads confirmed-susceptibility municipality codes from the single consolidated national
   gpkg, `data/processed_data/02_hazard_zones/susceptibilidade_unida.gpkg`
   (`gpkg_files`, L39). Codes are kept only if 7 characters long (L49).
2. Filters out "spillover-only" municipalities — those that entered
   `susceptibilidade_unida.gpkg` only because a neighbour's geometry crossed an
   administrative border during the stage-02 Python overlay — via
   `municipios_transbordamento.csv` (L59). The script recomputes that file from the raw
   CPRM gpkgs when they are present and falls back to the cached CSV otherwise.
3. Loads DUR (`DUR_Municipios.xlsx`, auto-downloaded from IBGE if missing) and flags
   `em_arranjo` (isolated municipalities have `NOME_MUNICIPIO == NM_CIDADE`).
4. Loads 2022 population (`tabela4709.xlsx`, must be placed manually — SIDRA has no
   direct download link for this table), read with `skip = 4` (L154).
5. **Exposure is susceptibility-only**: `exposed <- cod_gpkg` (L161–162). Any DUR
   arrangement with ≥ 1 exposed member contributes **all** of its members, including
   members with no mapping of their own; isolated exposed municipalities enter alone
   (L164–178). `tem_susceptibilidade` records which is which (L177).
6. Drops the two water-body codes carried in the municipal mesh —
   `COD_WATER_BODIES <- c("4300001", "4300002")` (L186), Lagoa dos Patos and Lagoa Mirim:
   no name, no population. Removed **before** the population filter, so they can neither
   enter the universe nor inflate an arrangement's `pop_arranjo`. Which of the two is
   actually present is reported rather than assumed (L187–197).
7. Population filter: isolated municipalities need `pop_2022 > 50,000`; arrangements need
   the **sum over members** `pop_arranjo > 50,000`, so a small member rides in on the
   arrangement total (L199–205).

### CPRM risk retired from the sample definition (6f.1, decided 2026-09-13)

Step 5 used to be a **union**: `exposed <- union(cod_gpkg, cod_risco)`, where `cod_risco`
came from `risco_preparado.gpkg`. That union is gone, and with it this script's read of the
risk layer and the `tem_risco` output column. Stage 02 still produces
`risco_preparado.gpkg` unchanged — what was retired is stage 03's *consumption* of it (see
`02_population_in_hazard_zones/PIPELINE.md`).

The union governed the **processing universe and arrangement composition**, not regression
membership: stage 04's `01_compose_sample.R:41` already filtered to
`tem_susceptibilidade == TRUE`, so no municipality with CPRM risk and no susceptibility was
ever in the regression dataset. Dropping the union therefore shrinks the universe and the
arrangement count while leaving the regression sample unchanged. For the funnel counts
before and after, see `manuscript/results_targets_v2.md`.

**One supporting argument lapsed with it**, flagged in the script's own header (L32–37):
`MIGRATION_PLAN.md` Task 1d's empirical check that dropping *medium* susceptibility here is
a no-op was argued partly through the CPRM union ("no municipality reaches the sample via
medium alone that isn't already captured by CPRM risk"). With no union, that check no longer
stands on its own terms. Dropping medium remains the decision under `CLAUDE.md` rule 9; what
lapsed is one piece of supporting evidence, not the decision. Open for re-checking.

**Output columns**: `cod_mun`, `CD_CIDADE`, `NM_CIDADE`, `em_arranjo`,
`tem_susceptibilidade`, `pop_2022`, `pop_arranjo`. (`tem_risco` is gone — 6f.1.)

---

## Script 02 — Download GHSL data

**File**: `02_download_ghsl_data.R` · **Output**: `data/raw_data/03_urban_footprint/ghsl_raw/*.tif`

Downloads 5 global rasters (GHS-BUILT-S R2023A epochs E2000/E2010/E2020; GHS-POP
R2023A epochs E2000/E2010) from JRC/Copernicus, ~1.5–2 GB each. Skips files whose TIF
already exists; retries failed downloads with exponential backoff (up to 4 attempts).
Native CRS: World Mollweide (ESRI:54009).

Usage downstream: BUILT-S E2010/E2020 feed script 03 (joined onto the common grid);
BUILT-S E2000 + POP E2000/E2010 feed script 06 (2000→2010 window only) — the main
2010→2022 chain (scripts 03–05, 07) never touches E2000 or GHS-POP.

---

## Script 03 — Integrate the grid with GHSL, build the common grid

**File**: `03_integrate_grid_with_ghsl.R`

The most complex script in this pipeline. Builds **two** outputs:

- `grade_ibge_2010.gpkg`/`.parquet` — the raw 2010 grid (population, susceptibility,
  AGSN, `built_pct_2010` only). Unchanged in content/purpose by the 6b0 rework; its
  sole remaining consumer is script 06 (2000→2010 window).
- `grade_common_grid_2010_2022.gpkg`/`.parquet` — **the interface scripts 04/05/07
  build on**: 2022 cell geometry, `populacao` (2022 census), `pop_2010_alocada`
  (allocated 2010 population — see "The common-grid framework" above),
  high-susceptibility and AGSN values, `built_pct_2010`/`built_pct_2020`. **No CPRM-risk
  columns** — `prop_risco` and `prop_agsn_com_risco` stopped being carried onto the common
  grid under 6f.1 (`03_integrate_grid_with_ghsl.R:235`, `:390`).

**Steps**:
1. Load the sample (script 01) and split into municipalities with confirmed
   susceptibility vs. without.
2. Load the base grid geometry + high-susceptibility values for 2010 and 2022 from
   `data/processed_data/02_hazard_zones/grade_20XX_BR_com_suscept_alta_agsn.gpkg`
   (stage 02's own output — same file supplies both geometry and values). Medium
   susceptibility is **not** read here (dropped 2026-08-21 per rule 9);
   `prop_suscept_total`/`prop_agsn_suscept_total` are kept as column names for
   downstream compatibility but now simply equal the `_alta` values.
3. *(Retired by 6f.1.)* This step used to join CPRM mapped-risk data (`prop_risco`,
   `prop_agsn_com_risco`) onto the grid by `ID_UNICO`. It no longer runs — see `:235`.
4. Expand the grid for municipalities with no susceptibility mapping of their own — the
   members that complete a susceptibility arrangement — located via the points geoparquet
   (fast spatial join) with a bbox-read fallback. These cells get `prop_suscept_* = 0`
   (`replace_na`, not `NA`, so "no overlap" and "not measured" are indistinguishable
   downstream — a deliberate but undocumented choice, `METHODS_AUDIT.md` §10.3 row 16).
   Under 6f.1 no CPRM column is joined in here either (`:390`).
5. Concatenate the susceptibility and expanded grids, recover any still-missing sample
   municipalities via direct bbox reads, run `exact_extract` to join GHSL built-up
   (2010 grid: E2010 only; 2022 grid: E2010 + E2020 — the 2010 grid no longer needs
   E2020, since the old cross-grid classification pass it used to feed is gone).
6. Allocate 2010 population onto the 2022 grid (see framework section above).
7. Save both outputs.

**⚠️ Slow step**: `exact_extract` over the national grid, 3 raster passes total (down
from 4 under the pre-rework dual-grid design, since the 2010 grid no longer needs
E2020). No up-to-date reference runtime is recorded for the post-rework version as of
this writing — the pre-rework reference (~129 min for 4 passes) is no longer directly
comparable; record a fresh figure on the next full run.

---

## Script 04 — Delimit urban extent

**File**: `04_delimit_urban_extent.R`

Classifies each common-grid cell as urban/non-urban at both points in time, using an
AND criterion (excludes built-up-but-unpopulated cells like sheds/airports, and dense
but unbuilt cells):

```
urban = built_pct >= LIMIAR_BUILT (10%)  AND  dens_hab_km2 >= LIMIAR_DENS (300)
```

**Parameters, in code** — both are constants in this script and both are reused verbatim by
script 06 (`METHODS_AUDIT.md` §10.4 row 30):

| Constant | Value | Line | Comment in the code |
|---|---|---|---|
| `LIMIAR_BUILT` | `10` (% built-up) | `04_delimit_urban_extent.R:49` | *"lowered from 20% to capture dense/informal housing"* — the comment records the change, not who decided it |
| `LIMIAR_DENS` | `300` (inhab/km²) | `04_delimit_urban_extent.R:54` | *"300 inhab/km² is a standard minimum-urban-density reference"* — no reference is given |

**NA handling — a missing value makes a cell non-urban, silently.** The criterion as written
(`classificar_urbano()`, L63–64) is

```r
!is.na(built_pct) & built_pct >= lim_built & !is.na(dens) & dens >= lim_dens
```

so a cell with no built-up measurement, or no population to form a density, returns `FALSE`
rather than `NA`. "Not urban" and "not measured" are therefore the same value in
`urbano_2010`/`urbano_2020`, and everything downstream that filters on the flag inherits that.
This is undocumented as a decision anywhere else (`METHODS_AUDIT.md` §10.3 row 17); it is
recorded here because it changes what the footprint means at the margin.

`urbano_2010` uses `built_pct_2010` + `pop_2010_alocada`; `urbano_2020` uses
`built_pct_2020` + `populacao` (2022 census) — both computed on the same (2022) grid
geometry, each with its own year's population. This replaces the pre-unification
design, where each native grid only carried the flag matching its own census year and
the complementary flag was a downstream proxy using the other year's population;
`pop_2010_alocada` makes a real allocated 2010 population available, so that proxy is
no longer needed.

Density is computed as `population / (area_total_m2 / 1e6)`, keeping the criterion
consistent across the grid's two cell sizes (200m × 200m urban cells, 1km × 1km
elsewhere).

**Output**: `grade_urban_form_2010_2022.gpkg`/`.parquet` (common grid +
`urbano_2010` + `urbano_2020`).

---

## Script 05 — Classify growth types (2010→2020)

**File**: `05_classify_growth_types.R`

For every cell that was or became urban between 2010 and 2020, assigns one of 6
growth types. Runs once per analysis unit (arrangement or isolated municipality) —
processing each unit independently is what lets the algorithm detect topological holes
correctly within multi-municipality arrangements.

**Methodology** — per-polygon rasterization (not centroid) onto a 200m raster
template per unit, with a 2-cell buffer:

1. Rasterize `urbano_2010`/`urbano_2020` (max) and `built_pct_2010`/`built_pct_2020`
   (mean) onto the template.
2. Identify t1 urban patches (Queen/8-connectivity); classify each as **Major**
   (patch total `pop_2010_alocada` > 5,000 **and** density ≥ 1,500 inhab/km² — both
   conditions) or **Minor** (everything else).
3. Shrinkage (urban t1 → non-urban t2) → folded into `consolidated`.
4. Growth (non-urban t1 → urban t2) is split into:
   - **Infill**: falls inside a topological hole of a Major patch (Rook/4-connectivity
     hole detection — Rook avoids a diagonal gap in the urban ring destroying hole
     detection, which Queen connectivity would allow).
   - **Extension**: ≤ 1,000m from the nearest Major patch (`terra::distance()`).
   - **Leapfrog**: > 1,000m from the nearest Major patch.
5. Continuing Major patches (urban t1 and t2) split into **densification**
   (built-up delta > 1 percentage point) or **consolidated** (delta ≤ 1 p.p., or
   shrinkage, as above).
6. Continuing Minor patches (urban t1 and t2) → **peripheral**.

**Single-cell analysis units** (an arrangement/isolated municipality with only one
grid cell) go through a direct rule instead of the raster path, but apply the **same**
Major/Minor test: urban at both t1 and t2 checks whether the cell alone clears
`POP_PATCH_A`/`DENS_PATCH_B` — if so, classified by built-up delta
(densification/consolidated); otherwise `peripheral`. New cells become `leapfrog`;
cells that stop being urban become `consolidated` (shrinkage).

### Classification constants, in code

The six constants that define the classification, with the file and line each is set at.
Script 06 re-declares all six at the same values for the 2000–2010 window
(`06_classify_growth_types_2000_2010.R:79–84`, verified line by line —
`METHODS_AUDIT.md` §10.4 row 30), so a change here must be made twice.

| Constant | Value | Line (`05_classify_growth_types.R`) | What it decides |
|---|---|---|---|
| `LIMIAR_EXTENSION` | `1000` m | L62 | ≤ 1,000 m from a Major patch → extension; beyond → leapfrog |
| `LIMIAR_DENSIF` | `1` percentage point | L63 | Δ built-up > 1 p.p. → densification; ≤ 1 p.p. → consolidated |
| `RESOLUCAO` | `200` m | L64 | Raster template resolution; a 1 km grid cell rasterizes into ~5×5 pixels |
| `CONECTIVIDADE_HOLES` | `4` (Rook) | L65 | Connectivity for topological hole detection — **while patches use `directions = 8` (Queen, L289)**: two different connectivity rules in the same script |
| `POP_PATCH_A` | `5000` | L66 | Major-patch criterion A: patch total t1 population > 5,000 |
| `DENS_PATCH_B` | `1500` inhab/km² | L67 | Major-patch criterion B: patch density ≥ 1,500 — **five times** the urban threshold of 300, and applied at patch rather than cell level |

A patch is **Major** only if A **and** B hold; everything else is Minor.

Two further settings in the same block: `COL_POP_PATCH <- "pop_2010_alocada"` (L71) — patch
sizing uses t1 population, per `MIGRATION_PLAN.md` 6b0; and `FILTRO_UF <- NULL` (L73) — a
single-state restriction for testing, `NULL` for a full run.

None of the six values is attributed to a decision record anywhere: they exist only as code
(`METHODS_AUDIT.md` §10.3 rows 20–25). They are stated here as parameters of the script, not
as results.

**Output**: `crescimento_urbano/grade_growth_types_2010_2022.parquet` — the common
grid, filtered to the sample, plus `tipo_crescimento`. Susceptibility and AGSN columns are
carried through unchanged from script 03 (via 04) — this script validates they are present but
never re-reads the source gpkgs. The presence check it used to run on `prop_risco` /
`prop_agsn_com_risco` was removed with them under 6f.1 (`05_classify_growth_types.R:165`).

---

## Script 06 — Classify growth types (2000→2010)

**File**: `06_classify_growth_types_2000_2010.R`

Extends the same growth-type classification to the pre-period window that feeds the
regression treatment variable. Stays **outside** the common-grid unification — there
is no 2000 statistical grid — so it uses **GHS-POP** (not the Census) for population
at both ends, on the 2010 IBGE grid geometry (script 03's `grade_ibge_2010.parquet`):

```
urbano_2000      = built_pct_2000 >= LIMIAR_BUILT  AND  pop_ghsl_2000/area >= LIMIAR_DENS
urbano_2010_ghsl = built_pct_2010 >= LIMIAR_BUILT  AND  pop_ghsl_2010/area >= LIMIAR_DENS
```

Major/Minor patches are sized with `pop_ghsl_2000` (t1 population), matching script
05's use of t1 population for patch sizing. The `classificar_crescimento()` function
is functionally identical to script 05's (verified directly, cosmetic differences
only in variable names/comments) — same rasterization, same Major/Minor test, same
Rook hole detection, same extension/leapfrog/densification/consolidated/peripheral
logic.

**Updated 2026-09-05** (cross-window consistency check, researcher request): two points
where this script had drifted from script 05 were aligned to match it exactly —
single-cell analysis units now check the Major/Minor criterion before falling back to
`peripheral` (previously assumed Minor by definition), and the classification loop now
runs on the full sample grid instead of pre-filtering to cells urban at t1 or t2
(the pre-filter shrank the raster template's bounding box per unit, a risk for the
hole-detection interior/exterior edge test).

**Aggregates**, by municipality then by arrangement: area by growth type, and the two
synthetic treatment variables consumed downstream —
`pct_area_densif_infill_0010` (compact = densification + infill) and
`pct_area_periph_ext_leap_0010` (sprawl = peripheral + extension + leapfrog) — plus
the mean distance of densification/infill cells to the municipal centroid.

**Output**: `crescimento_urbano/grade_crescimento_2000_2010_g2010.parquet` (cell-level),
`metricas/metricas_crescimento_2000_2010.csv` / `_arranjo.csv` (aggregated), consumed
by stage 04's `14_independent_variables.R`.

---

## Script 07 — Aggregate municipality metrics

**File**: `07_aggregate_municipality_metrics.R`

Aggregates script 05's cell-level classification into municipality- and
arrangement-level metrics. Per the 6b0 unification, the old M2–M8 "M-family" taxonomy
is retired: it existed to name competing answers computed on two different grids (a
same-year population share on the grid's own geometry, vs. a cross-grid
re-aggregation to compare years). With one grid and one `tipo_crescimento`
classification, those are now the same computation, run once. Output schema, per
growth type (`consolidated`/`densification`/`infill`/`extension`/`leapfrog`/`peripheral`):

| Columns | Meaning |
|---|---|
| `n_cel_<type>`, `area_m2_<type>` | cells / area, 2022 urban extent only |
| `pop_2022_<type>`, `pop_2010_<type>` | population by type, both years |
| `pop_2022_risk_<type>`, `pop_2010_risk_<type>` | same, **area-weighted** into high susceptibility: `sum(pop × prop_suscept_total)` |

### Exposure weighting (MIGRATION_PLAN.md 6e, decided 2026-09-11)

The `_risk_` columns are an **area weighting**, not a filter: each cell's population is
multiplied by `prop_suscept_total`, the fraction of the cell the high-susceptibility layer
covers, and the products are summed over the *same* cells as the unweighted columns (urban in
the relevant year, carrying a `tipo_crescimento` label). A cell with `prop_suscept_total = 0`
contributes exactly 0, so no threshold is involved and none exists in the script.

This **replaces** the rule the script carried until 2026-09-11: `LIMIAR_SUSCEPT <- 0`
("any overlap"), which filtered to `prop_suscept_total > 0` and then summed those cells'
**full** population — counting every resident of a 1 km² cell as exposed if any part of the
cell intersected the hazard layer. That rule was never a decided methodology; it conflicts
with the manuscript's Methods (which describe areal interpolation), and it disagreed with
stage 02's own rule (`03_cross_grid_high_susceptibility.py`: `populacao × prop_suscept`) by
by a substantial factor nationally. The numbers in the July draft were produced under it —
see MIGRATION_PLAN.md 6e for the provenance evidence, the magnitude, and the full audit; the
current values belong in `manuscript/results_targets_v2.md`.

Before the multiplication the script validates `prop_suscept_total`: no NAs, within [0, 1],
and equal to `prop_suscept_alta`. The last check guards the medium-susceptibility retirement
(rule 9) — the column is a straight alias of `prop_suscept_alta` in both places that build it
(script 03 and script 05), never a sum with a medium term, and a sum of two overlapping
classes could exceed 1 and silently inflate every weighted total.

Column names are unchanged; their contents changed with this correction, so any
`metricas_municipio_2010_2022.csv` produced before 2026-09-11 carries the old rule.

Plus totals across the 6 types (`pop_2022_total`, `pop_2010_total`,
`pop_2022_risk_total`, `pop_2010_risk_total`), `delta_pop_total`,
`delta_pop_risk_total`, `pct_growth_pop_risk`, `area_urban_2022_m2`, and
`pct_urban_growth` (share of the 2022 urban footprint made of new cells:
infill + extension + leapfrog).

M6 (population in CPRM-mapped geological risk zones) and M7 (population in AGSN ∩
risk) from the old taxonomy are dropped entirely — confirmed against
`results_used.md` that neither feeds any published exhibit, consistent with this
repository's "only the analyses used in the final paper" scope.

### Arrangement aggregation is asymmetric (MIGRATION_PLAN.md 6f.2, decided 2026-09-13)

Arrangement-level metrics sum the absolute columns across an arrangement's member
municipalities, then recompute the derived shares/totals from those sums (never averaging
percentages). **The two column groups sum over different member sets, and the asymmetry is
deliberate.** Both groups are named explicitly in the code rather than implied by the join
(`07_aggregate_municipality_metrics.R:374–375`), and a column matching the aggregate pattern
but falling in neither group raises `stop()` (L377–384) instead of defaulting silently.

| Group | Member set | Selector | Columns |
|---|---|---|---|
| **Urban form** | **ALL** members | `COLS_FORM <- grep("^(n_cel_\|area_m2_)", …)` (L374) | `n_cel_<type>`, `area_m2_<type>`, and everything derived: `area_urban_2022_m2`, `pct_urban_growth`; downstream `area_urbana_2010_m2`, `pct_area_densif`, `pct_area_peripheral`, `pct_area_extension`, `pct_area_leapfrog`, `pct_crescimento_area` |
| **Population / exposure** | members with **mapped susceptibility only** | `COLS_POP <- grep("^(pop_2022_\|pop_2010_\|pop_mun_)", …)` (L375) | `pop_2022_<type>`, `pop_2010_<type>`, `pop_2022_risk_<type>`, `pop_2010_risk_<type>`, `pop_mun_2010`, `pop_mun_2022`, and everything derived: `pop_*_total`, `pop_*_risk_total`, `delta_pop_total`, `delta_pop_mun`, `delta_pop_risk_total`, `pct_growth_pop_risk`; downstream `pp_alta_*`, `delta_pp_alta`, `g_alta`, `pop_fora_alta_*`, `g_fora_alta` |

The reasoning, in the two directions:

- **The footprint is metropolitan.** An unmapped member's built-up area is still part of the
  arrangement's urban form, so the `pct_area_*` shares must describe the whole footprint.
- **An unmapped member contributes exactly zero to the exposure numerator** — no
  susceptibility layer exists there — so counting it in the denominator dilutes the share
  instead of measuring anything.

The `mapped` flag is `coalesce(tem_susceptibilidade, FALSE)` (L397), joined from
`amostra_municipios.rds`. A municipality present in `metricas` but **absent** from the sample
has no `tem_susceptibilidade` at all; it would be coalesced to unmapped and its population
would leave every arrangement total silently, so the script reports it explicitly instead
(L405–420) rather than letting that happen quietly. Expected to be empty, since the grid is
built from the sample.

The aggregation itself is `across(all_of(COLS_FORM), ~ sum(.x, na.rm = TRUE))` against
`across(all_of(COLS_POP), ~ sum(.x[mapped], na.rm = TRUE))` (L428–430). Before this change a
single regex-selected set was summed uniformly over all members, so the rule was symmetric and
the asymmetry was not expressible.

#### The one exception: `area_urbana_2010_m2_mapped`

The asymmetry creates a cross-group ratio in stage 04: `log_density_2010` pairs
`pop_urbana_2010_cg` (population group, mapped-only) with `area_urbana_2010_m2` (form group,
all members), which for a mixed arrangement is a mapped-only numerator over an all-members
denominator. **Decided 2026-09-14: the density estimator stays on the mapped units on both
sides.** The arrangement block emits an **additional** column,

```r
area_urbana_2010_m2_mapped =
  sum(area_m2_consolidated[mapped])  + sum(area_m2_densification[mapped]) +
  sum(area_m2_peripheral[mapped])                       # L439–442
```

— the mapped-only sum of the three 2010-footprint area columns. `13_dependent_variables.R`
carries it into both output files, falling back to `area_urbana_2010_m2` at **municipality**
level, where a unit is either mapped or not and the unmapped ones are already excluded
upstream, making the two columns identical there. Every density consumer then uses it
unconditionally.

This is additive: `area_m2_*` themselves are **unchanged** and stay all-members — they are
urban form — and `log_area_2010_km2`, a pure area measure, likewise stays all-members. Nothing
that already existed changes, so the all-members footprint metrics and the entire
municipality-level file are untouched.

**Output**: `metricas/metricas_municipio_2010_2022.csv`,
`metricas/metricas_arranjo_2010_2022.csv` — consumed by stage 04's
`13_dependent_variables.R` and by `05_exhibits/table1_population_by_growth_type.R`
(Table 1) and `05_exhibits/figure1_growth_type_layers.R` (Figure 1).

---

## Notes

**CRS**: EPSG:5880 (SIRGAS 2000 Polyconic) for area/distance calculations; Mollweide
(ESRI:54009) for `exact_extract` against GHSL rasters.

**`id_celula` vs. `ID_UNICO`**: `id_celula` is a sequential row number local to
whichever gpkg produced it — not comparable across pipelines. `ID_UNICO` (format
`200ME{easting}N{northing}`) is the real IBGE grid-cell identifier and the only safe join key
across stage-02 outputs. It was the key joining the susceptibility and CPRM-risk grids until
6f.1 retired that join (script 03 step 3).

**`FILTRO_UF`**: present in scripts 03, 05, 06, 07 to restrict processing to a single
state for testing (e.g. `FILTRO_UF <- "PR"`). Keep `NULL` for a full-Brazil run.

**High susceptibility only** (CLAUDE.md rule 9): every script in this folder reads
high-susceptibility values only, script 01 included since 6f.1. `prop_suscept_total` /
`prop_agsn_suscept_total` column names are kept for downstream compatibility but equal the
`_alta` values exactly, since there is no medium term left to add — and script 07 asserts that
identity at runtime before using the column as a weight (`:166–184`). One unreachable medium
branch survives at `03_integrate_grid_with_ghsl.R:183`, a ternary naming `prop_suscept_medio`
inside `read_susceptibility()`; the function is only ever called with `sufixo = "alta"`
(`METHODS_AUDIT.md` §1).

**CPRM risk** is no longer read anywhere in this stage (6f.1): not in the sample definition
(script 01), not on the common grid (script 03), and not in script 05's presence check. Stage
02 still produces `risco_preparado.gpkg` and the risk grids — see
`02_population_in_hazard_zones/PIPELINE.md`.
