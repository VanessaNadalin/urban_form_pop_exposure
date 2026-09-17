# R requirements

The analysis is written in R, with two Python steps (see `requirements.txt`).

## R version

**R 4.3 or later.** The code uses the native pipe `|>` (R ≥ 4.1) and relies on R ≥ 4.3
semantics for `||` with scalar operands. It has not been tested on earlier versions.

> **To complete before deposit:** record the exact R version and `sessionInfo()` of the run that
> produced the deposited results, and pin package versions (for example with `renv::snapshot()`).
> The list below is extracted from the code, not from a resolved environment, so it carries no
> versions.

## Packages by stage

Installed from CRAN unless noted.

| Stage | Packages |
|---|---|
| **01** susceptibility maps | `data.table`, `dplyr`, `fs`, `future.apply`, `httr`, `lwgeom`, `progress`, `purrr`, `readr`, `readxl`, `rvest`, `sf`, `stringr`, `tidyr` |
| **02** population in hazard zones | *(Python only — see `requirements.txt`)* |
| **03** urban footprint and growth types | `arrow`, `curl`, `dplyr`, `exactextractr`, `geobr`, `here`, `purrr`, `readr`, `readxl`, `sf`, `sfarrow`, `stringi`, `stringr`, `terra`, `tibble`, `tidyr` |
| **04** regression dataset and models | `arrow`, `censobr`, `cli`, `curl`, `dplyr`, `elevatr`, `fs`, `geobr`, `here`, `httr`, `lmtest`, `rappdirs`, `readr`, `readxl`, `rvest`, `sandwich`, `sf`, `sfarrow`, `stringr`, `terra`, `tibble`, `tidyr`, `xml2` |
| **05** exhibits | `arrow`, `car`, `DescTools`, `dplyr`, `ggcorrplot`, `ggplot2`, `here`, `lmtest`, `moments`, `readr`, `sandwich`, `scales`, `sf`, `sfarrow`, `tibble`, `tidyr` |

`R/paths.R` requires `here`. Base and recommended packages used explicitly (`stats`, `tools`,
`utils`) ship with R.

## Notes

- `geobr` and `censobr` (IPEA) download IBGE geographies and census microdata at run time and
  cache them locally; they need network access on a first run.
- `terra` and `exactextractr` need a system GDAL/GEOS/PROJ stack, as does `sf`. On Linux these
  are the usual `libgdal-dev`, `libgeos-dev`, `libproj-dev`, `libudunits2-dev` packages.
- `sfarrow` is used to read and write GeoParquet; `arrow` must be installed with Parquet
  support (the default CRAN binary has it).
- `DescTools` is loaded by `05_exhibits/robustness/outlier_diagnostics.R` without a
  `requireNamespace()` guard: that one script errors on a clean install if the package is
  missing. Every other optional dependency is guarded.
