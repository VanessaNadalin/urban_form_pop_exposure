# urban_form_pop_exposure

**Urban form and exposure to disaster in Brazilian cities**

Replication code for a study of whether the pattern of urban growth — compact or sprawling —
shapes how many people come to live in areas susceptible to floods and rainfall-triggered
landslides. It combines the susceptibility maps with the IBGE statistical grid for the 2010 and
2022 Censuses.

The analysis covers Brazilian cities between 2010 and 2022 and also asks whether housing-market
mechanisms explain the change in exposure better than urban form does. Its three data sources are
the IBGE Statistical Grid (2010 and 2022), the SGB/CPRM national susceptibility mapping, and the
GHSL built-up surface (2000, 2010, 2020), combined at the level of municipalities and of
functional urban areas.

**Exposure is defined on high susceptibility only**, and area-weighted: a grid cell contributes
`population × (fraction of the cell inside the hazard polygon)`.

---

## Pipeline

Five stages, run in order. Each of stages 02–05 has a `00_run_all` script that runs its own
chain; stage 01 has none, and its four scripts are run one at a time.

| Stage | What it does |
|---|---|
| `01_download_susceptibility_maps/` | Retrieves the municipal susceptibility maps from the SGB/CPRM RIGEO repository, filters them to the high class, and dissolves them into two national layers (flood and mass movement). |
| `02_population_in_hazard_zones/` | Prepares the IBGE population grids and the national susceptibility layer, then crosses grid against hazard to obtain area-weighted exposed population per cell and per municipality. |
| `03_urban_footprint_and_growth_types/` | Delimits the urban footprint from GHSL, classifies each newly built cell into a growth type (densification, infill, peripheral, extension, leapfrog) for 2000–2010 and 2010–2022, and aggregates to municipalities and functional urban areas. |
| `04_regression_dataset_and_models/` | Assembles the regression dataset (urban form, housing-market, topographic and census covariates) and estimates the models, saving the fitted objects. It does not format any table. |
| `05_exhibits/` | Reads the saved results and produces the final tables and figures in `output/`, then regenerates `manuscript/results_targets_v2.md`. |

Growth typology: **compact** = densification + infill; **sprawl** = peripheral + extension +
leapfrog. Treatment window 2000–2010; outcome window 2010–2022.

Each stage folder carries its own pipeline document describing every script, its inputs, its
outputs and the parameters it applies:

- `01_download_susceptibility_maps/making_suscep_national.md`
- `02_population_in_hazard_zones/PIPELINE.md`
- `03_urban_footprint_and_growth_types/pipeline_urban_metrics.md`
- `04_regression_dataset_and_models/PIPELINE.md`
- `05_exhibits/pipeline_5.md`

---

## Where the numbers live

**`manuscript/results_targets_v2.md` is the single source for every number the manuscript uses.**

It is a generated file. `05_exhibits/build_results_targets.R` reads the exhibit outputs and the
saved model objects and writes it; each run overwrites it. Hand edits are lost.

Two properties of the generator matter when reading it:

- **Every value carries its provenance** — the file it was read from and that file's
  modification time.
- **It never substitutes a value it cannot source.** A missing or stale input produces a line
  marked `PENDING` with the reason, not a number. Lines marked `VERIFIED` were read or
  recomputed from a named file in this pipeline.

The pipeline documents listed above describe *what each script does*; they deliberately carry no
result values, so that a number can never be current in one place and stale in another.

---

## Running it

Run everything from the repository root. All paths go through `R/paths.R`
(`raw_data_path()`, `processed_data_path()`, `output_path()`), which resolves against the
repository root via `here::here()`; no script sets its own working directory, with the one
exception noted below for stage 01.

```r
source("03_urban_footprint_and_growth_types/00_run_all.R")
source("04_regression_dataset_and_models/00_run_all.R")
source("05_exhibits/00_run_all.R")   # ends by regenerating manuscript/results_targets_v2.md
```

```bash
python 02_population_in_hazard_zones/00_run_all.py
```

### What is executable from a clean clone, and what is not

**Stage 01 is a record of the scraping procedure, not a runnable step.** It is included so the
provenance of the susceptibility layer is documented, but it cannot be re-run from this
repository. It reads state pages saved by hand from the SGB website, downloads per-municipality
archives from RIGEO, and expects a working directory holding those files and the
`suscet_sig_processado/` and `saida/` trees — none of which is versioned here. Its three
`setwd()` calls were machine-specific and have been removed; see "Working directory" in
`making_suscep_national.md`. A reader is not expected to re-scrape RIGEO.

> **The dissolved national susceptibility layer that stage 01 produces, and that stage 02 needs,
> will be part of the data deposit described under "Data availability".** Place
> `suscet_inundacao_br.gpkg` and `suscet_massa_br.gpkg` in `data/raw_data/02_hazard_zones/`
> (create the folder) to run stage 02 without re-scraping.

**Stage 02 is runnable but very expensive.** Each of its two grid × hazard crossings (high
susceptibility, and CPRM mapped risk) takes roughly 18–24 h, about 36–48 h for the stage; it needs
8–16 GB of RAM and has no skip-if-already-computed logic, so a re-run is a full re-run. The
CPRM risk crossing feeds no exhibit; it is kept so that stage 02 matches its recorded outputs.
Stage 02's outputs will be part of the data deposit; a reader is not expected to re-run the
overlays.

**Stages 03, 04 and 05 run cleanly from the deposited intermediates**, in the order above, and
are where every published table and figure is produced.

### Software

- **R** — see `R_requirements.md` for the version and the packages, listed by stage.
- **Python** — see `requirements.txt`. Used by stage 02 in full and by
  `04_regression_dataset_and_models/06_builtup_in_susceptibility.py`.
- A system GDAL / GEOS / PROJ stack is required by `sf`, `terra` and `geopandas`.

---

## Layout

```
01_download_susceptibility_maps/    stage 01 scripts and its pipeline document
02_population_in_hazard_zones/      stage 02 (Python)
03_urban_footprint_and_growth_types/  stage 03
04_regression_dataset_and_models/   stage 04
05_exhibits/                        stage 05
R/paths.R                           the single place data paths are defined
R/docx_tables.R                     the shared Word (.docx) format of the tables
manuscript/results_targets_v2.md    the generated source for every number
```

Two folders are not in the repository and are created by the scripts on first use:
`data/raw_data/<stage>/` and `data/processed_data/<stage>/` (inputs and intermediates; see "Data
availability") and `output/` (the final tables and figures, written by stage 05). Both are
excluded from version control by `.gitignore`.

The deposit holds only the scripts that produce the paper's exhibits and the numbers it reports.
Diagnostic and robustness scripts (the stages' `diagnostics/` folders and `05_exhibits/robustness/`)
are kept in the project's working repository; no exhibit or reported number depends on them.

---

## A note on language

The analysis was written in Portuguese and progressively translated. Script names, comments and
console messages are in English; **column names inside the generated data files are not**. They
are kept exactly as the files were written, often in Portuguese (`populacao`, `pop_risco`,
`prop_suscept`, `cod_mun`), because renaming a column in code that reads an existing file is a
way to break a pipeline silently. Read the pipeline documents for what each column means.

## References in comments to files that are not here

This repository is a subset of a larger working repository. Comments and provenance notes
sometimes cite documents that are kept there and are not part of this deposit — `CLAUDE.md`,
`MIGRATION_HISTORY.md` and `MIGRATION_PLAN.md` (dated decisions, cited by entry ID such as 6e or
6f.2), `METHODS_AUDIT.md`, `AUDIT.md`, `VERIFICATION.md`, `results_used.md`,
`results_targets_v2_REQUIREMENTS.md` — along with the diagnostic and robustness scripts, named
where they are mentioned. They are records of how the analysis was reorganised and checked, not
descriptions of how it runs; nothing here depends on them. Likewise, the commit hash in the header
of `manuscript/results_targets_v2.md` is that of the working repository at the time of the run.

Comments citing a numbered "rule" refer to the conventions the code was written to, which are:

| Rule | What it says |
|---|---|
| 2 | Outputs must reproduce the recorded targets. A rebuilt output that differs is traced and explained, never forced to match. |
| 4 | The analysis is in R; Python steps are isolated with their own requirements. Column names in existing data files are never renamed. |
| 5 | Tidyverse conventions; `library()` calls at the top; relative paths from the repository root; seeds set wherever anything is stochastic. |
| 6 | No analyses beyond those the paper reports. |
| 7 | Spatial steps use EPSG:5880 and repair geometry (`st_make_valid()` / zero-width buffer) before any overlay; slow layers are cached as named intermediates. |
| 9 | The analysis is restricted to **high** susceptibility throughout. Medium-susceptibility branches were retired and are not part of this repository. |

---

## Licence

MIT — see [`LICENSE`](LICENSE). The licence covers the code in this repository. The source data
(IBGE, SGB/CPRM, GHSL) is redistributed under its own terms; see "Data availability".

## Data availability

No data are distributed in this repository. All source data are public:

- **IBGE**: the Statistical Grid of the 2010 and 2022 Censuses, municipal boundaries, census-tract
  data (2010 Census), urban-concentration arrangements and municipal GDP (2010);
- **SGB/CPRM**: the municipal susceptibility maps to floods and mass movements (RIGEO repository)
  and the mapped risk sectors;
- **European Commission JRC**: GHSL built-up surface and population grids (2000, 2010, 2020) and
  the Global Surface Water layer;
- **Elevation**: digital elevation tiles retrieved with the R package `elevatr` (AWS Terrain
  Tiles).

The scripts download most of these at run time (see each stage's pipeline document). A deposit of
the derived data needed to run the pipeline without re-scraping or re-running stage 02 — the
dissolved national susceptibility layer, the stage-02 crossing outputs and the stage-03/04
intermediates — is in preparation; its DOI will be added here on publication. Until then these
data are available from the corresponding author on request. Source data remain subject to their
providers' terms of use.

## Citation

Please cite the article (reference to be added on publication) and this repository at the tag
used for the submission: `VanessaNadalin/urban_form_pop_exposure`, tag `v1.0-submission`.
