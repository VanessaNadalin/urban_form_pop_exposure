# Stage 01 — Download SGB/CPRM susceptibility maps and build the national high layer

> **A note on citations in this document.** It cites records kept in the project's private
> working repository — `MIGRATION_PLAN.md` (dated decisions), `METHODS_AUDIT.md`,
> `results_used.md` (the pre-rework target values), `AUDIT.md`, `VERIFICATION.md` and
> `CLAUDE.md` (the numbered conventions, restated in `README.md`) — together with commit
> hashes from that repository. Those files are not part of this deposit, and nothing here
> depends on them; the citations are kept so each decision can be traced to where it was
> recorded. Current values live in `manuscript/results_targets_v2.md`.

**Rewritten 2026-09-16 from the scripts on disk.** The previous version of this file described
a file tree that no longer exists (`raspagem_suceptibilidade_links_por_munic.R`, `rasp_3_dec.R`,
`01_leitura_sf_brutos_v3.R`, `pos_processamento_v5.R`, plus an alternative per-municipality
branch `02_03_04_processamento.R` that is not in this folder). This copy describes the four
numbered scripts that are actually here, in run order.

## Result values are not in this file

This document describes **what each script does and in what order**. It does not state counts,
coefficients or population totals. Every such value belongs in
**`manuscript/results_targets_v2.md`**, which is the single source of result values for the
whole pipeline.

> **`manuscript/results_targets_v2.md` is generated, not hand-written.**
> `05_exhibits/build_results_targets.R` rebuilds it from the current exhibit outputs; every
> value carries the file it came from, that file's mtime, and a VERIFIED/PENDING status.
> Nothing here is an authoritative figure for how many municipalities SGB has mapped, how many
> downloads
> succeeded, or how many polygons survive the class filter — read them from that file not from
> here and not from an older copy of this document.
>
> **What it must contain is specified** in
> `manuscript/results_targets_v2_REQUIREMENTS.md` — the slot-by-slot specification the
> generator implements.

Parameters below that live in code (thresholds, class-value lists, CRS codes, regular
expressions) are stated with their file and line, because they describe the script rather than
a result.

---

## What this stage produces

Two national GeoPackages, one polygon geometry per municipality, **high susceptibility class
only**, in EPSG:4674:

| Output | Contents |
|---|---|
| `saida/suscet_inundacao_br.gpkg` | Flood susceptibility, high class, dissolved by `COD_MUNICIPIO` |
| `saida/suscet_massa_br.gpkg` | Mass-movement susceptibility, high class, dissolved by `COD_MUNICIPIO` |
| `saida/log_falhas_municipios.csv` | One row per municipality skipped, with the reason |

These two `.gpkg` files are stage 02's manual raw inputs. Stage 02 reads them from
`data/raw_data/02_hazard_zones/` (`02_prepare_high_susceptibility_layer.py:70–71`), so they have
to be **copied there by hand** after this stage runs — nothing in either stage does that move.
That copy is the stage-01/stage-02 boundary.

Stage 01 produces no exhibit of its own. Per `CLAUDE.md`'s "Definition of done" it stays
**documented and deposited**, not reviewer-runnable end to end: a reviewer is not expected to
re-scrape RIGEO.

---

## Run order

```
[27 state pages saved as .html by hand]
        │
        ▼  01_scrape_municipality_links.R
municipios_suscetibilidade_SGB.csv          (UF | Municipio | Link)
        │
        ▼  02_download_susceptibility_zips.R          (~8 h, curl downloads)
suscet_sig_processado/<UF>/<Municipality>/  (extracted .shp / .gpkg)
        │
        ▼  03_read_raw_shapefiles.R
saida/script1_objetos_sf.RData              (lista_inundacao, lista_massa,
        │                                    municipios_pulados)
        │                                   pulados3.csv
        ▼  04_dissolve_high_susceptibility.R          + suc_codemun.xlsx
saida/suscet_inundacao_br.gpkg
saida/suscet_massa_br.gpkg
saida/log_falhas_municipios.csv
```

There is no `00_run_all` for this stage — the four scripts are run one at a time.

**Working directory.** Unlike stages 02–05, these scripts do **not** go through `R/paths.R`.
Each of scripts 01, 03 and 04 originally began with a hardcoded, machine-specific `setwd()`
(`01_scrape_municipality_links.R:2`, `03_read_raw_shapefiles.R:2`,
`04_dissolve_high_susceptibility.R:1`); those three lines were replaced by a comment for
publication, and every path after them is relative to the working directory. Script 02 has no
`setwd()` and assumes the same directory. All four must therefore be run with the working
directory set to one folder holding the saved state HTML pages, `suc_codemun.xlsx`, and the
`suscet_sig_processado/` and `saida/` trees. This is the one stage whose paths are not relative
to the repository root; it is left as-is because the stage is frozen and deposited rather than
re-run.

---

## Script 01 — `01_scrape_municipality_links.R`

Extracts the per-municipality RIGEO links from state pages saved from the browser.

**Input.** Every `*.html` file in the working directory (L18), one per state, saved by hand
beforehand from `sgb.gov.br/pt/web/guest/<state>-cartografia-de-suscetibilidade`. The script
reads them from disk; it does not fetch them.

**Does.**
1. Derives the UF from the filename through a hardcoded name→UF map (`extrair_uf()`, L23–41;
   the map covers 27 entries including `distrito-federal`).
2. Reads each file's `table tbody tr` rows, dropping the first (L52–56), and takes column 1 as
   the municipality name and the `<a href>` of column 2 as the link (L57–71).
3. Prefixes relative links with `https://rigeo.sgb.gov.br` (L88–92), then `distinct()` and sorts
   by UF and municipality (L93–94).
4. Drops rows with no link (L95).

**Output.** `municipios_suscetibilidade_SGB.csv` (L100) — columns `UF`, `Municipio`, `Link`.

---

## Script 02 — `02_download_susceptibility_zips.R`

Downloads one SIG ZIP per municipality from its RIGEO page and extracts the relevant layers.

**Input.** `municipios_suscetibilidade_SGB.csv` (`CSV_INPUT`, L19).

**Configuration, in code.**

| Constant | Value | Line |
|---|---|---|
| `plan(multisession, workers = 2)` | 2 parallel workers | L17 |
| `DIR_RAW` | `suscet_sig_processado` — extracted raw data | L20 |
| `DIR_GPKG` | `GPKG` — output of the abandoned §8 block, below | L21 |
| `LOG_FILE` | `pipeline_log.txt` — one line per event | L22 |

**Does.**
1. **Finds the SIG ZIP on the municipality's page** (`extrair_zip_sig()`, L73–89): keeps hrefs
   that end in `.zip` **and** contain `sig` (case-insensitive) **and** do not contain
   `mde|curva|base|imagem|img` (L84–86) — excluding elevation models, contour lines,
   cartographic bases and images.
2. **Downloads with `curl`** (`baixar_zip()`, L97–135): `curl -L --fail --retry 5 --retry-delay 5`
   with a browser user-agent (L109–112). If a valid ZIP is already on disk it skips the download
   (L96–104); after downloading it re-tests the archive and deletes it on corruption (L124–131).
3. **Extracts only the relevant members** (`extrair_relevantes()`, L140–171): file names matching
   `inund|massa|mov|susc`, case-insensitive (L151); everything else is ignored. The ZIP is
   deleted afterwards (L165).
4. **Sanitises folder names** (`sanitize_name()`, L51–56): strips `\ / : * ? " < > |` and squishes
   whitespace, so the municipality name is usable as a Windows directory name. The accented
   original is kept as the `Municipio` attribute, not in the path.
5. **Deletes defensively** (`safe_delete()`, L34–47): up to 5 attempts with a 1 s pause, for
   `EBUSY` on Windows.
6. Runs step 1–5 per municipality through `future_lapply` (L213–217); a failure on one
   municipality does not stop the rest.

**Output.** `suscet_sig_processado/<UF>/<Municipality>/` — the extracted shapefiles and
GeoPackages — plus `pipeline_log.txt`.

**Runtime.** ~8 hours for the full list (the script's own note, L220).

**Two things in this script that do not run as part of the pipeline.**

- **§8, "PÓS-PROCESSAMENTO → GPKG"** (L244–307) attempts to consolidate the raw files into
  municipal, then state, then national GeoPackages under `GPKG/`. The script's own comment at
  L242 records that it did not work (*"pos processamento nao funcionou. outro script"*).
  Consolidation is done by scripts 03 and 04 instead. The `GPKG/` tree is not an input to
  anything downstream.
- **The known-failure list** at L220–239 is a comment recording the original run's failures by
  name: no SIG published on SGB (Correia Pinto/SC, Coronel Fabriciano/MG, Curral de Dentro/MG,
  Extrema/MG, Poços de Caldas/MG), corrupted ZIP (Corupá/SC, Registro/SP), extraction failure
  (Resende/RJ). Kept here because it documents the coverage limit of the deposited data.

## Script 03 — `03_read_raw_shapefiles.R`

Reads every extracted layer and sorts it into flood or mass movement. No filtering by class
happens here — that is script 04.

**Input.** The `suscet_sig_processado/` tree (`base_dir`, L123).

**Setup.** `sf_use_s2(FALSE)` (L12) — the S2 spherical engine is disabled, since the source
geometries have topology problems. `padronizar_geometria()` (L17–28) casts POLYGON/MULTIPOLYGON
uniformly to MULTIPOLYGON and returns `NULL` for empty objects.

**Classification rules, per municipality folder** (`ler_camadas_municipio()`, L34–117):

1. **GeoPackages** — only SGB's two standardised layer names are read: `inundacao_a` → flood
   (L57–61), `movimento_de_massa_a` → mass movement (L63–67). Comparison is on `tolower(lay)`.
2. **Shapefiles** — first by file name:
   - skipped outright if the name matches `enxurr|corrida|relevo|eros` (L80) — flash floods,
     debris flows, terrain, erosion, all outside this study's scope;
   - name contains `inund` → flood (L85);
   - name contains `mov` **and** `massa` → mass movement (L86).
3. **Fallback, by content** (L93–110), when the name does not resolve the type: the first column
   whose name matches `classe|tipo|process` (L96) is inspected; values containing `inund` →
   flood (L101–102); values containing `mov` **and** `massa` → mass movement (L106–108).

The main loop (L133–156) walks UF folders then municipality folders, wraps each call in `try()`,
and keys results as `"<UF>_<Municipality>"` in two named lists.

**Output.**
- `saida/script1_objetos_sf.RData` (L164–165) — `lista_inundacao`, `lista_massa`,
  `municipios_pulados`.
- `pulados3.csv` (L170) — municipalities whose read failed.

---

## Script 04 — `04_dissolve_high_susceptibility.R`

Filters to the high class, attaches IBGE codes, reprojects, and dissolves into the two national
layers.

**Inputs.** `saida/script1_objetos_sf.RData` (L22) and `suc_codemun.xlsx` (L48) — the
municipality-name → 7-digit IBGE code lookup, which **is** versioned in this folder.

**Per-municipality processing** (`processar_um_municipio()`, L78–183), in this order:

1. Skip `NULL` and non-`sf` objects (L80–90).
2. Standardise the geometry column name `geom` → `geometry` (L93–98).
3. Validate: `st_is_valid()`, then `st_make_valid()` if anything is invalid, then re-check; an
   object still invalid is dropped and logged (L110–126).
4. Look up the IBGE code. The key is `normalizar_nome()` (L36–42): lowercase →
   `stri_trans_general("Latin-ASCII")` → strip everything but `[a-z0-9 ]` → squish. No match →
   dropped and logged (L128–137).
5. Reproject to **EPSG:4674** (SIRGAS 2000 geographic) — L145. A layer with no CRS is dropped
   (L140–143).
6. **High-class filter** (L152–176). The class column is the first whose name matches
   `classe|nivel|grau|risco` (L153). Its values are ASCII-folded, lowercased, stripped of
   non-letters and squished (L156–160), then kept if they satisfy any of (L163–167):
   `%in% c("alta", "alto", "risco alto")`, or word-match `\balta\b`, or word-match `\balto\b`,
   or match `nivel 3|grau 3|high|3$`. A layer with **no** class column at all skips this filter
   entirely and is kept whole — worth knowing when reading coverage.
7. Keep only `COD_MUNICIPIO` and `geometry` (L179–180).

**Dissolve** (`unir_por_municipio()`, L223–253): `st_make_valid()`, then `group_by(COD_MUNICIPIO)
|> summarise(geometry = st_make_valid(st_union(geometry)))` (L236–242), then `st_make_valid()`
again. One polygon per municipality, with internal boundaries between adjacent mapped areas
removed.

**Outputs.** `saida/suscet_inundacao_br.gpkg` (L265), `saida/suscet_massa_br.gpkg` (L268),
`saida/log_falhas_municipios.csv` (L270). The failure log's `motivo` values are the ones raised
above: `objeto_null`, `nao_e_sf`, `sem_geometry`, `sem_linhas`, `geometria_irrecuperavel`,
`geometria_invalida_pos_makevalid`, `sem_codigo_ibge`, `sem_CRS`, `erro_transformacao_crs`,
`sem_classe_alta`, `erro_grave_processamento`, `sem_dados_para_unir`, `erro_dissolve`.

---

## Notes

- **High susceptibility only** (`CLAUDE.md` rule 9). The filter is script 04's step 6; medium and
  low classes never leave this stage. There is no medium-susceptibility branch in this folder.
- **CRS.** Stage 01 outputs are EPSG:4674 (geographic). Every area calculation downstream happens
  after stage 02 reprojects to EPSG:5880 (`02_prepare_high_susceptibility_layer.py:27`).
- **Flood and mass movement stay separate here.** They are two files out of this stage; stage 02
  concatenates and dissolves them into one layer per municipality.
- **Coverage is partial by construction.** Not every Brazilian municipality has an SGB
  susceptibility map, and of those that do, some fail at download, read, code lookup or
  validation. Every drop is logged (`pipeline_log.txt`, `pulados3.csv`,
  `log_falhas_municipios.csv`). For how many municipalities survive to the processing universe,
  read `manuscript/results_targets_v2.md` once written.
- **Robustness to failure** is the design of all four scripts: a municipality that fails is
  logged or accumulated in a skipped list and the loop continues.
