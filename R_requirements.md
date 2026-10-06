# R requirements

The analysis is written in R, with two Python steps (see `requirements.txt`).

## R version

**R 4.3 or later.** The code uses the native pipe `|>` (R ≥ 4.1) and relies on R ≥ 4.3
semantics for `||` with scalar operands. It has not been tested on earlier versions.

**Recorded run.** The exhibits and `manuscript/results_targets_v2.md` of the submission were
produced on 2026-10-06 with **R 4.6.1** (x86_64-w64-mingw32, Windows Server 2022). Package
versions attached in that stage-05 session:

| Package | Version | Package | Version |
|---|---|---|---|
| `arrow` | 25.0.1 | `readr` | 2.2.0 |
| `dplyr` | 1.2.1 | `readxl` | 1.5.0.1 |
| `flextable` | 0.10.1 | `sandwich` | 3.1-3 |
| `geobr` | 2.1.0 | `scales` | 1.4.0 |
| `ggplot2` | 4.0.3 | `sf` | 1.1-3 |
| `here` | 1.0.2 | `sfarrow` | 0.4.1 |
| `lmtest` | 0.9-40 | `stringi` | 1.8.9 |
| `modelsummary` | 2.6.0 | `stringr` | 1.6.0 |
| `officer` | 0.7.6 | `terra` | 1.9-50 |
| `purrr` | 1.2.2 | `tidyr` | 1.3.2 |
| `tinytable` | 0.19.0 | `zoo` | 1.9-0 |

The package lists below are extracted from the code; versions of packages used only by stages
01–04 were not recorded.

## Packages by stage

Installed from CRAN unless noted.

| Stage | Packages |
|---|---|
| **01** susceptibility maps | `data.table`, `dplyr`, `fs`, `future.apply`, `httr`, `lwgeom`, `progress`, `purrr`, `readr`, `readxl`, `rvest`, `sf`, `stringr`, `tidyr` |
| **02** population in hazard zones | *(Python only — see `requirements.txt`)* |
| **03** urban footprint and growth types | `arrow`, `curl`, `dplyr`, `exactextractr`, `geobr`, `here`, `purrr`, `readr`, `readxl`, `sf`, `sfarrow`, `stringi`, `stringr`, `terra`, `tibble`, `tidyr` |
| **04** regression dataset and models | `arrow`, `car`, `censobr`, `cli`, `curl`, `dplyr`, `elevatr`, `fs`, `geobr`, `here`, `httr`, `lmtest`, `rappdirs`, `readr`, `readxl`, `rvest`, `sandwich`, `sf`, `sfarrow`, `stringr`, `terra`, `tibble`, `tidyr`, `xml2` |
| **05** exhibits | `arrow`, `car`, `dplyr`, `flextable`, `ggplot2`, `here`, `lmtest`, `modelsummary`, `officer`, `purrr`, `readr`, `sandwich`, `scales`, `sf`, `sfarrow`, `tibble`, `tinytable` |

`R/paths.R` requires `here`; `R/docx_tables.R` requires `flextable` and `officer`. Base and recommended packages used explicitly (`stats`, `tools`,
`utils`) ship with R.

## Notes

- `geobr` and `censobr` (IPEA) download IBGE geographies and census microdata at run time and
  cache them locally; they need network access on a first run.
- `terra` and `exactextractr` need a system GDAL/GEOS/PROJ stack, as does `sf`. On Linux these
  are the usual `libgdal-dev`, `libgeos-dev`, `libproj-dev`, `libudunits2-dev` packages.
- `sfarrow` is used to read and write GeoParquet; `arrow` must be installed with Parquet
  support (the default CRAN binary has it).
