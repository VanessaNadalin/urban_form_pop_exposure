# Stage 02 — Population in hazard zones (`02_population_in_hazard_zones/`)

> **A note on citations in this document.** It cites records kept in the project's private
> working repository — `MIGRATION_PLAN.md` (dated decisions), `METHODS_AUDIT.md`,
> `results_used.md` (the pre-rework target values), `AUDIT.md`, `VERIFICATION.md` and
> `CLAUDE.md` (the numbered conventions, restated in `README.md`) — together with commit
> hashes from that repository. Those files are not part of this deposit, and nothing here
> depends on them; the citations are kept so each decision can be traced to where it was
> recorded. Current values live in `manuscript/results_targets_v2.md`.

**Rewritten 2026-09-16 from the scripts on disk.** The previous version of this file described
the pre-Migrate `risk_exposure/` folder: Portuguese script names, `run_pipeline.py`, the
`03_cruzamento_completo_{alta,medio,risco}.py` family, a `data_raw/` + `processed_data/` tree
inside the stage folder, and a full medium-susceptibility branch. None of that exists. This copy
describes the four numbered scripts and `00_run_all.py` that are actually here, in run order,
naming inputs and outputs by path.

## Result values are not in this file

This document describes **what each script does and in what order**. It does not state counts,
coefficients or population totals. Every such value belongs in
**`manuscript/results_targets_v2.md`**, which is the single source of result values for the
whole pipeline.

> **`manuscript/results_targets_v2.md` is generated, not hand-written.**
> `05_exhibits/build_results_targets.R` rebuilds it from the current exhibit outputs; every
> value carries the file it came from, that file's mtime, and a VERIFIED/PENDING status.
> Nothing here is an authoritative figure for the number of grid cells, the number of
> municipalities with
> susceptibility or CPRM risk, the number of AGSN/FCU polygons, or any exposed-population
> total — read them from that file not from here and not from an older copy
> of this document.
>
> **What it must contain is specified** in
> `manuscript/results_targets_v2_REQUIREMENTS.md` — the slot-by-slot specification the
> generator implements.

Parameters below that live in code (CRS codes, class filters, caps, column-detection lists) are
stated with their file and line, because they describe the script rather than a result.

---

## What this stage produces, and who consumes it

All outputs land in `data/processed_data/02_hazard_zones/`.

| Output | Produced by | Consumed by |
|---|---|---|
| `malha_municipal_5880.gpkg` | 01 | 02, 03, 04 |
| `AGSN_preparada.gpkg` | 01 | 03, 04 |
| `grade_2010_BR.gpkg`, `grade_2022_BR.gpkg` | 01 | 03, 04 |
| `grade_2010_pontos_BR.parquet`, `grade_2022_pontos_BR.parquet` | 01 | 03, 04 |
| `risco_preparado.gpkg` | 01 | — (its only consumer, script 04, is not part of this deposit — see below) |
| `susceptibilidade_unida.gpkg` | 02 | 03; stage 03 `01_define_sample.R` |
| `grade_2010_BR_com_suscept_alta_agsn.gpkg` | 03 | stage 03 `03_integrate_grid_with_ghsl.R`; stage 04 `12_slum_growth.R` |
| `grade_2022_BR_com_suscept_alta_agsn.gpkg` | 03 | same |
| `AGSN_com_suscept_alta.gpkg`, `AGSN_sem_suscept_alta.gpkg` | 03 | — |
| `resumo_municipal_suscept_alta_agsn.csv` | 03 | — (municipal summary, reference) |

### The CPRM risk crossing is not part of this deposit

The exposure measure used throughout the paper is **SGB/CPRM high susceptibility**, not CPRM
mapped risk. A fourth script in this stage, `04_cross_grid_cprm_risk.py`, crossed the population
grid with the CPRM mapped-risk sectors; it is not included in the public repository, because no
analysis in the paper consumes its outputs.

`03_urban_footprint_and_growth_types/01_define_sample.R` once unioned the CPRM-risk
municipalities into the exposed set; it is susceptibility-only (`01_define_sample.R:161–162`).
`03_integrate_grid_with_ghsl.R` does not carry `prop_risco` / `prop_agsn_com_risco` onto the
common grid (`:235`, `:390`), and `05_classify_growth_types.R` has no presence-check on those
columns (`:165`). Stages 04 and 05 read no CPRM column at all.

Two consequences a reader should know about. First, `01_download_prepare_ibge_grid.py` still
downloads and prepares `risco_preparado.gpkg` (its Part E, below); that work is unused here, and
Part E can be skipped without affecting any result. Second, one descriptive statistic in
`manuscript/results_targets_v2.md` — the count of municipalities with CPRM mapped risk — was read
from `resumo_municipal_risco_agsn.csv`, which script 04 produced. Regenerating the targets file
from this repository reports that one line as PENDING with the reason "file not found" rather
than substituting a value. No table, figure or regression in the paper depends on it. The
stage-03 diagnostic `diagnostics/cprm_entrants_and_arrangement_denominators.R` reads
`risco_preparado.gpkg` directly, not script 04's outputs, so it is unaffected.

### The exposure rule was area-weighted here all along

Both crossing scripts weight population by the fraction of the cell inside the hazard polygon:

- `03_cross_grid_high_susceptibility.py:391` — `pop_suscept = populacao × prop_suscept`

This has never been anything else in this stage. The "any-overlap" rule that
`MIGRATION_PLAN.md` **6e** retired on 2026-09-11 lived in **stage 03**
(`07_aggregate_municipality_metrics.R`'s `LIMIAR_SUSCEPT <- 0`), not here; 6e's correction
brought stage 03 into line with what stage 02 was already doing. Nothing in this stage was
changed by 6e.

---

## Prerequisites

**Python packages** — the project's top-level `requirements.txt`:
`geopandas`, `pandas`, `numpy`, `tqdm`, `requests`, `openpyxl`, `pyarrow`.

**Manual inputs**, placed in `data/raw_data/02_hazard_zones/` before running:

| File | Source |
|---|---|
| `suscet_massa_br.gpkg` | Stage 01, `04_dissolve_high_susceptibility.R` — mass movement, high class |
| `suscet_inundacao_br.gpkg` | Stage 01, same script — flood, high class |

Both are already filtered to the high class upstream; this stage applies no class filter of its
own. **High susceptibility only** (`CLAUDE.md` rule 9): there is no `*_medio_br.gpkg` input, no
`susceptibilidade_unida_medio.gpkg` output, and no medium crossing script in this folder.

Everything else — the two statistical grids, the municipal mesh, the FCU/AGSN polygons and
`risco.gdb` — is downloaded automatically by script 01.

---

## Running the pipeline

From the **repository root**:

```bash
python 02_population_in_hazard_zones/00_run_all.py
```

`00_run_all.py` runs the three scripts in the order listed at `00_run_all.py:26–30`, times each
one, and exits on the first non-zero return code.

Individually:

```bash
python 02_population_in_hazard_zones/01_download_prepare_ibge_grid.py
python 02_population_in_hazard_zones/02_prepare_high_susceptibility_layer.py
python 02_population_in_hazard_zones/03_cross_grid_high_susceptibility.py
```

**Runtime** (`00_run_all.py:14–16`): script 01 ~1–3 h; script 03 ~18–24 h; ~20–28 h for the
stage as deposited here. The crossing script has no skip-if-already-computed logic on its
expensive outputs, so a re-run is a full re-run.

**Memory**: combining all grid tiles for Brazil needs ~8–16 GB of RAM
(`01_download_prepare_ibge_grid.py:17–18`).

**Reviewer-facing status.** Per `CLAUDE.md`'s "Definition of done", a reviewer is not expected
to re-run these overlays from scratch; the outputs are deposited. The researcher's own 2026-08
decision to re-run stage 02 was a validation of the deposited intermediates, not a change to
that bar.

---

## A note on the grid: it is not uniformly 200 m

The IBGE statistical grid is **mixed resolution** — roughly 200 m cells in denser areas and 1 km
cells elsewhere. No script here assumes one size: every proportion is computed against the
cell's own measured area (`area_total = g.geometry.area`,
`03_cross_grid_high_susceptibility.py:150`), and downstream
density criteria are per km² for the same reason (`04_delimit_urban_extent.R:15–20`). Any
statement that this pipeline works on "200 m × 200 m cells" is wrong; the previous version of
this file said so throughout.

---

## Script 01 — `01_download_prepare_ibge_grid.py`

Downloads and prepares every base spatial dataset. Must run once before anything else.

**Paths** (L34–36): `BASE_DIR = data/raw_data/02_hazard_zones`,
`OUT_DIR = data/processed_data/02_hazard_zones`, `CRS_PROJ = "EPSG:5880"`.

### Part A — downloads (L79–147)

| Dataset | Source | Lands in |
|---|---|---|
| Statistical grid 2010, tiles | IBGE geoftp `.../grade_estatistica/censo_2010/` (L88–91) | `raw_data/02_hazard_zones/grade_2010/` |
| Statistical grid 2022, tiles | IBGE geoftp `.../censo_2022/grade_estatistica/` (L111–114) | `.../grade_2022/` |
| Municipal mesh 2022 | IBGE geoftp `BR_Municipios_2022.zip` (L124–128) | `.../malha_municipal/` |
| Favelas e Comunidades Urbanas 2022 (FCU) | IBGE Censo 2022 `poligonos_FCUs_shp.zip` (L137–141) | `.../aglomerados_subnormais/FCUs_2022/` |

Tile IDs are tried over `range(1, 100)` (L101). The comment at L92–100 records why: the range was
extended from `(1, 57)` on 2026-08-24 after tiles with ID > 56 were found never to have been
attempted, which had silently dropped grid coverage concentrated in the Nordeste and part of the
Norte. 404s for IDs that genuinely do not exist are ignored by `download_zip()` (L45–66).

The FCU shapefile carries its own municipal code, so no DTB lookup is downloaded (L147).

### Part B — municipal mesh (L150–185)

Code column detected from `CD_MUN`/`CD_GEOCMU`/`GEOCODIGO`/`cod_mun` (L167–168), renamed
`COD_MUNICIPIO` and truncated to 7 digits (L172–173); reprojected to EPSG:5880 (L174); then
**`make_valid()` → `buffer(0)` → `make_valid()`** (L175–177). Saved as
`malha_municipal_5880.gpkg` (L183–184).

### Part C — FCU/AGSN polygons (L188–227)

Requires a `cd_mun` column and errors if absent (L209–213). Reprojected (L215), repaired with the
same triple `make_valid` → `buffer(0)` → `make_valid` (L216–218), then empty and still-invalid
geometries are dropped (L219). `cod_mun_7dig` is the first 7 characters of `cd_mun`, zero-padded
(L222). Saved as `AGSN_preparada.gpkg` (L225–226).

> The columns and files are named `AGSN` throughout for continuity with the 2019 Aglomerados
> Subnormais they replaced; the data are the **2022 FCU** polygons. Rule 4 keeps the column
> names as generated.

### Part D — statistical grids (L230–323)

`preparar_grade()` (L242–306), run once per year (L309–323):

1. Read every `*.shp` under the year's folder, skipping unreadable tiles with a warning
   (L244–259).
2. Concatenate into one national GeoDataFrame (L264–266).
3. Reproject to EPSG:5880 if needed (L269–272).
4. Detect the population column from a per-year candidate list — 2010:
   `['pop_2010','POP','Pop','pop']` (L314); 2022:
   `['pop_2022','TOTAL','Total','total','POP','Pop','pop']` (L322). Errors if none matches
   (L275–277).
5. Create `id_celula` as a string row index if absent (L281–283).
6. Repair: `make_valid()` → `buffer(0)` → `make_valid()`, then drop empty/invalid (L287–290).
7. Write `grade_<year>_BR.gpkg` (L295).
8. Write `grade_<year>_pontos_BR.parquet` — `representative_point()` per cell (L301), population
   renamed to `populacao` (L302). These points are the fast spatial index scripts 03 and 04 use.

### Part E — CPRM risk (L326–501)

Downloads `risco.gdb.zip` from `geoportal.sgb.gov.br` (L364), skipping the whole part if
`risco_preparado.gpkg` already exists (L369–370). Layers are listed through `pyogrio`, then
`fiona`, then `gpd.list_layers`, then a direct read (L340–362) and all concatenated (L427–430).

- Municipality column detected from `cd_geocmu`/`cd_geocmun`/`CD_GEOCMU`/`CD_GEOCMUN`/`CD_MUN`/
  `cod_mun` (L435–440) — `risco.gdb` ships it as `cd_geocmu`, without the trailing *n*.
- Risk-grade column detected from `grau_risco`/`GRAU_RISCO`/`grau`/`GRAU` (L447–451).
- **Filter: `grau_risco ∈ {"Alto", "Muito alto"}`** (L459–461). Medium and low grades are dropped.
- Municipal code normalised to 7 digits, zero-padded (L469–475); CRS assumed EPSG:4674 when the
  file declares none (L477–478), then reprojected to EPSG:5880 (L479).
- `fid` renamed `fid_orig` to avoid a GeoPackage conflict (L482–483); triple repair (L484–486);
  empty/invalid dropped (L487–489).

Saved as `risco_preparado.gpkg` (L497).

---

## Script 02 — `02_prepare_high_susceptibility_layer.py`

Merges the two high-susceptibility layers into one dissolved polygon per municipality.

**Reads.** `data/raw_data/02_hazard_zones/suscet_massa_br.gpkg` and `suscet_inundacao_br.gpkg`
(L70–71), and `malha_municipal_5880.gpkg` — falling back to the raw `BR_Municipios_2022.shp` if
script 01 has not run (L38–46).

**Does.**
1. Keep only Polygon/MultiPolygon features from each input (L81, L87).
2. Reproject both to EPSG:5880 (L92–93) and `make_valid()` (L95–96).
3. Concatenate mass movement and flood (L99) — the two hazard types are merged from here on.
4. `buffer(0)` both sides, then **clip to the municipal mesh**:
   `gpd.overlay(..., how='intersection')` (L107–110).
5. **Transbordamento correction** (L113–117): where the source file's own `COD_MUNICIPIO`
   disagrees with the mesh's, the **mesh's** code wins. This is the spillover fix applied at
   source; stage 03's `municipios_transbordamento.csv` exclusion is a second, separate pass over
   the same problem.
6. **Dissolve by `COD_MUNICIPIO`** (L125) — one geometry per municipality, flood and landslide
   merged — then `make_valid()` (L126).

**Writes.** `susceptibilidade_unida.gpkg` (L131–132).

---

## Script 03 — `03_cross_grid_high_susceptibility.py`

The main crossing. One loop over municipalities with high susceptibility; for each one it
computes the susceptibility fraction of every grid cell, and — where FCU/AGSN polygons exist —
the fractions inside and outside the hazard zone. `SUFIXO = "alta"` (L44) suffixes the outputs.

**Reads.** `susceptibilidade_unida.gpkg` (L82), the two raw susceptibility gpkgs (for the
municipality-code whitelist, L76–80), `malha_municipal_5880.gpkg` (L96–108),
`AGSN_preparada.gpkg` (L122), both `grade_<year>_BR.gpkg` (L153–160) and both
`grade_<year>_pontos_BR.parquet` (L168–171).

Municipal codes are normalised through `normalizar_cod()` (L55–57) — digits only, first 7,
zero-padded. The dissolved layer is restricted to municipalities present in the raw files
(L84), and AGSN polygons are restricted to municipalities that have susceptibility (L128).

### Cell-to-municipality attribution

Two rules, both in code and both worth knowing when reading any municipal total:

1. **`encontrar_celulas_mun()` (L177–189)** takes the cells whose **representative point falls
   within** the municipal polygon (`ids_core`, L183) **plus** every remaining cell in the
   bounding box whose **polygon merely intersects** it (`ids_borda`, L184–188). A cell straddling
   a boundary therefore belongs to both neighbours' cell sets.
2. **First writer wins (L260–265)**: `if id_cel not in cod_mun_celula_<year>` — a border cell is
   attributed to whichever municipality reaches it first in the `suscept` iteration order. It is
   **not** split between owners and **not** assigned by area majority. The `cod_mun_suscept`
   column on the output grids, and therefore every municipal sum in
   `resumo_municipal_suscept_alta_agsn.csv`, follows this rule.

### Proportions

`clip_proporcoes()` (L192–211) clips the cell subset against a geometry, sums the clipped area
per cell, divides by the cell's own `area_total`, and **caps the ratio at 1.0** (L210) —
`props = (areas / totals).clip(upper=1.0)`. `acumular()` (L214–217) sums a cell's proportions
across several polygons and applies **a second cap at 1.0** on the running total.

### Per-municipality loop (L246–308)

1. Find the municipality's 2010 and 2022 cells; record attribution (L255–265).
2. Clip those cells against the dissolved susceptibility geometry → `prop_suscept`, for each
   year (L269–277).
3. If the municipality has AGSN polygons, then **per polygon** (L285–308): split it into
   `geom_agsn.intersection(geom_suscept)` and `geom_agsn.difference(geom_suscept)` (L291–292) —
   an exact geometric partition, not a whole-polygon in/out flag — and clip the same cell subset
   against each, giving `prop_agsn_com_suscept_alta` and `prop_agsn_sem_suscept_alta`. The two
   fragment geometries are also accumulated for output.

Reusing the municipality's already-found cell subset for the AGSN step is what keeps the script
from re-querying the national grid per settlement polygon.

`prop_agsn_alta` is the capped sum of the two AGSN fractions (`unir_props()`, L320–327).

### Outputs

Grids (L344–356): `grade_2010_BR_com_suscept_alta_agsn.gpkg`,
`grade_2022_BR_com_suscept_alta_agsn.gpkg`. Columns added by `montar_grade()` (L334–342):

| Column | Meaning |
|---|---|
| `prop_suscept` | Fraction of the cell inside the dissolved high-susceptibility polygon, 0–1 |
| `cod_mun_suscept` | 7-digit IBGE code, under the first-writer-wins rule above |
| `prop_agsn_com_suscept_alta` | Fraction inside AGSN ∩ susceptibility |
| `prop_agsn_sem_suscept_alta` | Fraction inside AGSN − susceptibility |
| `prop_agsn_alta` | Fraction inside any AGSN polygon |

AGSN fragments (L363–373): `AGSN_com_suscept_alta.gpkg`, `AGSN_sem_suscept_alta.gpkg`.

Municipal summary (L380–423): `resumo_municipal_suscept_alta_agsn.csv`, one row per
municipality, both years side by side. Each quantity is population **weighted by a proportion**
(L391–399), then summed by `cod_mun_suscept`:

| Column (`_alta_<year>` suffixed) | Construction |
|---|---|
| `pop_total` | `sum(populacao)` |
| `pop_suscept` | `sum(populacao × prop_suscept)` |
| `pop_agsn_total` | `sum(populacao × prop_agsn_alta)` |
| `pop_agsn_com_suscept` | `sum(populacao × prop_agsn_com_suscept_alta)` |
| `pop_agsn_sem_suscept` | `sum(populacao × prop_agsn_sem_suscept_alta)` |
| `pop_suscept_sem_agsn` | `populacao × prop_suscept` where `prop_suscept > 0` and `prop_agsn_alta == 0`, else 0 (L396) |
| `pop_suscept_e_agsn` | `populacao × min(prop_suscept, prop_agsn_alta)` where both > 0, else 0 (L398–399) — the **minimum** of the two proportions, not their product |

Note that the per-cell product `pop × prop_suscept` is **not** stored on the grid files: they
carry `populacao` and `prop_suscept` separately, and the product is formed only here, on the way
into the municipal summary. Anything wanting per-cell exposed population computes it itself.

---

## Script 04 — not included in this deposit

`04_cross_grid_cprm_risk.py` applied script 03's method to the CPRM mapped-risk layer instead of
the susceptibility layer. It is not part of the public repository, for the reasons given under
"The CPRM risk crossing is not part of this deposit" above. Nothing documented below, and no
result in the paper, depends on it.

---

## Spatial conventions, stage-wide

- **CRS: EPSG:5880** (SIRGAS 2000 / Brazil Polyconic) for every overlay and every area
  calculation — `01_download_prepare_ibge_grid.py:36`,
  `02_prepare_high_susceptibility_layer.py:27`, `03_cross_grid_high_susceptibility.py:48`.
  Layers arriving in another CRS are reprojected on read.
- **Geometry repair: `make_valid()` → `buffer(0)` → `make_valid()`**, in that order, applied to
  the mesh, the FCU polygons, both grids and the risk layer
  (`01_download_prepare_ibge_grid.py:175–177`, `:216–218`, `:287–289`, `:484–486`). The
  repetition is not documented anywhere as a decision; it is what the code does.
- **Proportions are capped twice** — once per clip (`.clip(upper=1.0)`) and once on the running
  accumulation (`min(1.0, …)`).
- **Exposure is area-weighted**, everywhere in this stage: `population × proportion`. See "The
  exposure rule was area-weighted here all along" above.

---

## Data sources

| Dataset | Provider | Year | Notes |
|---|---|---|---|
| Susceptibility, high class (flood + mass movement) | SGB/CPRM | various | From stage 01; placed by hand in `data/raw_data/02_hazard_zones/` |
| Mapped risk sectors (`risco.gdb`) | SGB/CPRM | various | Auto-downloaded by script 01; filtered to `grau_risco ∈ {Alto, Muito alto}`. Unused in this deposit — see "The CPRM risk crossing is not part of this deposit" |
| Statistical grid | IBGE | 2010, 2022 | Mixed resolution — see the note above |
| Municipal mesh | IBGE | 2022 | `BR_Municipios_2022.shp` |
| Favelas e Comunidades Urbanas (FCU) | IBGE Censo 2022 | 2022 | `poligonos_FCUs_shp.zip`; `cd_mun` used directly |
