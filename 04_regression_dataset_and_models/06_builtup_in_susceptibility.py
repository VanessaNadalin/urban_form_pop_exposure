# ============================================================
# 06_builtup_in_susceptibility.py
#
# Regression variable: total GHSL Built-S area, and the portion of it
# inside high-susceptibility zones, per statistical-grid cell -- for
# the 2010 and 2020 epochs.
#
# Columns produced per grid cell:
#   ghsl_total_2010          total GHSL built-up area, 2010 (m2)
#   ghsl_total_2020          total GHSL built-up area, 2020 (m2)
#   ghsl_suscept_alta_2010   built-up area in HIGH susceptibility, GHSL 2010 (m2)
#   ghsl_suscept_alta_2020   built-up area in HIGH susceptibility, GHSL 2020 (m2)
#   cod_mun_ghsl             IBGE municipality code (7 digits)
#
# High susceptibility only (CLAUDE.md rule 9): medium susceptibility is a
# legacy branch archived under MIGRATION_PLAN.md Task 1 and is not
# computed here.
#
# The "built-up area outside susceptibility" variable is derived in
# script 07 as:
#   ghsl_fora_alta = ghsl_total - ghsl_suscept_alta
#
# --- FILTERS -----------------------------------------------------
#   UF_FILTER    : "41" = Parana (test); None = all of Brazil.
#   SAMPLE_PATH  : path to an .rds or .csv file with a 'cod_mun' column.
#                  None = no sample filter.
# -------------------------------------------------------------------
#
# Run from the project root:
#   python 04_regression_dataset_and_models/06_builtup_in_susceptibility.py
# ============================================================

import geopandas as gpd
import pandas as pd
import numpy as np
from pathlib import Path
from tqdm import tqdm
import warnings
import re

import rasterio
import rasterio.windows
from rasterio.features import rasterize as rio_rasterize
from rasterio.warp import transform_bounds
import rasterstats

warnings.filterwarnings('ignore')

# ══════════════════════════════════════════════════════════════
# CONFIGURATION -- edit here
# ══════════════════════════════════════════════════════════════

UF_FILTER: str | None = None
# .csv avoids an optional pyreadr dependency for reading .rds from Python.
SAMPLE_PATH: str | None = (
    "data/processed_data/03_urban_footprint/amostra_municipios.csv"
)

# ══════════════════════════════════════════════════════════════
# Paths (relative to the project root), matching R/paths.R's
# data/raw_data and data/processed_data stage layout
# ══════════════════════════════════════════════════════════════
GHSL_DIR   = Path("data/raw_data/03_urban_footprint/ghsl_raw")
STAGE02_DIR = Path("data/processed_data/02_hazard_zones")
OUT_DIR    = Path("data/processed_data/04_regression/ghsl_susceptibility")

GHSL_PATHS = {
    2010: GHSL_DIR / "GHS_BUILT_S_E2010_GLOBE_R2023A_54009_100_V1_0.tif",
    2020: GHSL_DIR / "GHS_BUILT_S_E2020_GLOBE_R2023A_54009_100_V1_0.tif",
}
# High susceptibility only -- see module docstring.
SUSCEPT_PATH = STAGE02_DIR / "susceptibilidade_unida.gpkg"
GRID_PATHS = {
    2010: STAGE02_DIR / "grade_2010_BR.gpkg",
    2022: STAGE02_DIR / "grade_2022_BR.gpkg",
}
MESH_PATH = STAGE02_DIR / "malha_municipal_5880.gpkg"

CRS_PROJ = "EPSG:5880"

EPOCHS = list(GHSL_PATHS.keys())    # [2010, 2020]

GHSL_COLS = (
    [f'ghsl_total_{ep}' for ep in EPOCHS] +
    [f'ghsl_suscept_alta_{ep}' for ep in EPOCHS]
)


def normalize_code(cod):
    # Keep only digits, then left-pad/truncate to IBGE's 7-digit municipality code.
    s = re.sub(r'\D', '', str(cod))
    return s[:7] if len(s) >= 7 else s.zfill(7)


def load_sample(path_str: str | None) -> set | None:
    if path_str is None:
        return None
    p = Path(path_str)
    if not p.exists():
        print(f"  Warning: SAMPLE_PATH not found: {p} -- processing all municipalities")
        return None
    if p.suffix.lower() == '.rds':
        try:
            import pyreadr
            obj = pyreadr.read_r(str(p))
            df = obj[None] if None in obj else next(iter(obj.values()))
        except ImportError:
            print(
                "  Warning: pyreadr not installed (pip install pyreadr). "
                "Export the sample to .csv instead:\n"
                "    write.csv(amostra['cod_mun'], 'amostra_municipios.csv', "
                "row.names=FALSE)\n"
                "  Processing all municipalities."
            )
            return None
    elif p.suffix.lower() == '.csv':
        df = pd.read_csv(p)
    else:
        print(f"  Warning: unsupported format: {p.suffix}. Use .rds or .csv.")
        return None

    col = next((c for c in ['cod_mun', 'COD_MUN', 'cod_municipio'] if c in df.columns), None)
    if col is None:
        print(f"  Warning: 'cod_mun' column not found. Columns: {df.columns.tolist()}")
        return None
    return {normalize_code(c) for c in df[col].dropna()}


print("\n" + "=" * 60)
print("06_BUILTUP_IN_SUSCEPTIBILITY -- BUILT-UP AREA x SUSCEPTIBILITY")
print("=" * 60)

mode = []
if UF_FILTER:    mode.append(f"UF={UF_FILTER}")
if SAMPLE_PATH:  mode.append(f"sample={Path(SAMPLE_PATH).name}")
print(f"Mode: {'FILTER ' + ' + '.join(mode) if mode else 'all of Brazil'}")

# ──────────────────────────────────────────────────────────────
# 1) Check input files
# ──────────────────────────────────────────────────────────────
print("\n1) Checking input files ...")
for year, p in GHSL_PATHS.items():
    if not p.exists():
        raise FileNotFoundError(f"GHSL {year} not found: {p}")
    print(f"  OK GHSL {year}: {p.name} ({p.stat().st_size/1024**2:.0f} MB)")

if not SUSCEPT_PATH.exists():
    raise FileNotFoundError(f"Susceptibility layer not found: {SUSCEPT_PATH}")
print(f"  OK susceptibility: {SUSCEPT_PATH.name}")

for year, p in GRID_PATHS.items():
    if not p.exists():
        raise FileNotFoundError(f"Grid {year} not found: {p}")
    print(f"  OK grid {year}: {p.name}")

if not MESH_PATH.exists():
    raise FileNotFoundError(f"Municipal mesh not found: {MESH_PATH}")
print(f"  OK municipal mesh: {MESH_PATH.name}")

OUT_DIR.mkdir(parents=True, exist_ok=True)

# ──────────────────────────────────────────────────────────────
# 2) Detect CRS of the GHSL rasters
# ──────────────────────────────────────────────────────────────
print("\n2) Detecting GHSL raster CRS ...")
with rasterio.open(GHSL_PATHS[EPOCHS[0]]) as src:
    CRS_GHSL = src.crs.to_string()
print(f"  GHSL CRS: {CRS_GHSL}")

# ──────────────────────────────────────────────────────────────
# 3) Load sample and define municipalities to process
# ──────────────────────────────────────────────────────────────
print("\n3) Defining municipalities to process ...")
sample_cods = load_sample(SAMPLE_PATH)
if sample_cods:
    print(f"  Municipalities in sample: {len(sample_cods)}")
else:
    print("  No sample filter -- all municipalities with susceptibility")

# ──────────────────────────────────────────────────────────────
# 4) Load susceptibility
# ──────────────────────────────────────────────────────────────
print("\n4) Loading susceptibility ...")
suscept_gdf = gpd.read_file(SUSCEPT_PATH).to_crs(CRS_PROJ)
suscept_gdf['COD_MUNICIPIO'] = suscept_gdf['COD_MUNICIPIO'].apply(normalize_code)
suscept_gdf['geometry'] = suscept_gdf.geometry.make_valid()
susceptibility = suscept_gdf.set_index('COD_MUNICIPIO')['geometry'].to_dict()
print(f"  {len(susceptibility)} municipalities with mapped susceptibility")

municipalities_to_process = set(susceptibility)
if sample_cods is not None:
    municipalities_to_process = municipalities_to_process & sample_cods
    print(f"  After sample filter: {len(municipalities_to_process)} municipalities")
if UF_FILTER:
    municipalities_to_process = {c for c in municipalities_to_process if c.startswith(UF_FILTER)}
    print(f"  After UF={UF_FILTER} filter: {len(municipalities_to_process)} municipalities")

print(f"  -> Total to process: {len(municipalities_to_process)} municipalities")

# ──────────────────────────────────────────────────────────────
# 5) Load municipal mesh
# ──────────────────────────────────────────────────────────────
print("\n5) Loading municipal mesh ...")
mesh = gpd.read_file(MESH_PATH).to_crs(CRS_PROJ)
code_col = next(
    (c for c in ['COD_MUNICIPIO', 'CD_MUN', 'cod_mun'] if c in mesh.columns), None
)
if code_col is None:
    raise ValueError(f"Municipal code column not found: {mesh.columns.tolist()}")
mesh = mesh.rename(columns={code_col: 'COD_MUNICIPIO'})
mesh['COD_MUNICIPIO'] = mesh['COD_MUNICIPIO'].astype(str).str[:7]
mesh['geometry'] = mesh.geometry.make_valid()
mesh_dict = dict(zip(mesh['COD_MUNICIPIO'], mesh['geometry']))

# ──────────────────────────────────────────────────────────────
# 6) Load IBGE grids
# ──────────────────────────────────────────────────────────────
print("\n6) Loading IBGE grids ...")
grids = {}
for year, p in GRID_PATHS.items():
    g = gpd.read_file(p).to_crs(CRS_PROJ)
    g['id_celula'] = g['id_celula'].astype(str)
    grids[year] = g
    print(f"  Grid {year}: {len(g):,} cells")

print("\n  Building spatial index ...")
# A spatial index lets us look up, per municipality, only the grid cells
# whose bounding box overlaps it, instead of testing every cell in Brazil.
grid_sindex = {year: g.sindex for year, g in grids.items()}
print("  OK ready")

# ──────────────────────────────────────────────────────────────
# 7) Main loop over municipalities
# ──────────────────────────────────────────────────────────────
print(f"\n7) Processing {len(municipalities_to_process)} municipalities ...")

results = {year: {} for year in GRID_PATHS}
ghsl_src = {ep: rasterio.open(p) for ep, p in GHSL_PATHS.items()}

for cod_mun in tqdm(sorted(municipalities_to_process), desc="Municipalities"):
    mesh_geom = mesh_dict.get(cod_mun)
    if mesh_geom is None:
        continue

    suscept_geom = susceptibility.get(cod_mun)

    # Reproject the municipality's susceptibility polygon into GHSL's CRS
    # once per municipality, rather than once per grid cell.
    suscept_geom_ghsl = None
    if suscept_geom is not None and not suscept_geom.is_empty:
        try:
            suscept_geom_ghsl = (
                gpd.GeoDataFrame([{'geometry': suscept_geom}], crs=CRS_PROJ)
                .to_crs(CRS_GHSL)
                .geometry.iloc[0]
                .buffer(0)  # buffer(0) fixes self-intersections without changing the shape
            )
        except Exception:
            pass

    try:
        bounds_ghsl = transform_bounds(
            CRS_PROJ, CRS_GHSL, *mesh_geom.bounds, densify_pts=21
        )
    except Exception:
        continue

    for grid_year, grid in grids.items():
        possible_idx = list(grid_sindex[grid_year].intersection(mesh_geom.bounds))
        if not possible_idx:
            continue
        subset = grid.iloc[possible_idx]
        # A cell belongs to this municipality if its centroid falls inside it;
        # border cells whose centroid falls just outside are added back if
        # they still intersect the municipality, so no cell is double-counted
        # but none right on the boundary is dropped either.
        core_mask = subset.geometry.centroid.within(mesh_geom)
        cells = subset[core_mask].copy()
        edge = subset[~core_mask]
        if len(edge) > 0:
            cells = pd.concat([cells, edge[edge.intersects(mesh_geom)]])
        cells = cells.drop_duplicates('id_celula').reset_index(drop=True)
        if len(cells) == 0:
            continue

        cell_ids = cells['id_celula'].values
        try:
            cells_ghsl = cells.to_crs(CRS_GHSL).reset_index(drop=True)
        except Exception:
            continue

        for ghsl_year, src in ghsl_src.items():
            try:
                win = rasterio.windows.from_bounds(*bounds_ghsl, transform=src.transform)
                win_c = win.intersection(
                    rasterio.windows.Window(0, 0, src.width, src.height)
                )
                if win_c.width < 1 or win_c.height < 1:
                    continue
                ghsl_arr = src.read(1, window=win_c).astype(np.float32)
                win_transform = src.window_transform(win_c)
                nodata_val = src.nodata if src.nodata is not None else -1
                ghsl_arr = np.where(
                    (ghsl_arr == nodata_val) | (ghsl_arr < 0), 0.0, ghsl_arr
                )
            except Exception:
                continue

            if ghsl_arr.size == 0:
                continue

            h, w = ghsl_arr.shape
            col_total = f'ghsl_total_{ghsl_year}'
            stats_total = rasterstats.zonal_stats(
                cells_ghsl, ghsl_arr, affine=win_transform, stats=['sum'],
                nodata=0, all_touched=False, geojson_out=False,
            )
            for i, id_cel in enumerate(cell_ids):
                r = results[grid_year].setdefault(id_cel, {})
                r['cod_mun_ghsl'] = cod_mun
                r[col_total] = float(stats_total[i].get('sum') or 0.0)

            col_s = f'ghsl_suscept_alta_{ghsl_year}'
            if suscept_geom_ghsl is None or suscept_geom_ghsl.is_empty:
                for id_cel in cell_ids:
                    results[grid_year].setdefault(id_cel, {}).setdefault(col_s, 0.0)
                continue
            try:
                suscept_mask = rio_rasterize(
                    [(suscept_geom_ghsl.__geo_interface__, 1)],
                    out_shape=(h, w), transform=win_transform,
                    fill=0, dtype=np.uint8, all_touched=False,
                )
            except Exception:
                suscept_mask = np.zeros((h, w), dtype=np.uint8)

            stats_s = rasterstats.zonal_stats(
                cells_ghsl, ghsl_arr * suscept_mask,
                affine=win_transform, stats=['sum'],
                nodata=0, all_touched=False, geojson_out=False,
            )
            for i, id_cel in enumerate(cell_ids):
                r = results[grid_year].setdefault(id_cel, {})
                r.setdefault('cod_mun_ghsl', cod_mun)
                r[col_s] = float(stats_s[i].get('sum') or 0.0)

for src_obj in ghsl_src.values():
    src_obj.close()

# ──────────────────────────────────────────────────────────────
# 8) Build and save output grids
# ──────────────────────────────────────────────────────────────
print("\n8) Building output grids ...")

suffix = f"_UF{UF_FILTER}" if UF_FILTER else ""

for grid_year, grid in grids.items():
    r_dict = results[grid_year]
    if not r_dict:
        print(f"  Warning: no results for grid {grid_year} -- skipping")
        continue

    df_res = pd.DataFrame.from_dict(r_dict, orient='index')
    df_res.index.name = 'id_celula'
    df_res = df_res.reset_index()

    for col in GHSL_COLS:
        if col not in df_res.columns:
            df_res[col] = 0.0
    if 'cod_mun_ghsl' not in df_res.columns:
        df_res['cod_mun_ghsl'] = ''

    grid_out = grid[grid['id_celula'].isin(df_res['id_celula'])].copy()
    grid_out = grid_out.merge(df_res, on='id_celula', how='left')
    for col in GHSL_COLS:
        grid_out[col] = grid_out[col].fillna(0.0)
    grid_out['cod_mun_ghsl'] = grid_out['cod_mun_ghsl'].fillna('')

    fname = f"grade_{grid_year}_com_ghsl_suscept{suffix}.gpkg"
    grid_out.to_file(OUT_DIR / fname, driver="GPKG")
    ref_ep = EPOCHS[-1]
    n_with_ghsl    = (grid_out[f'ghsl_total_{ref_ep}'] > 0).sum()
    n_with_suscept = (grid_out.get(f'ghsl_suscept_alta_{ref_ep}', pd.Series(0)) > 0).sum()
    print(
        f"  OK {fname}  "
        f"({len(grid_out):,} cells, {n_with_ghsl:,} with GHSL > 0, "
        f"{n_with_suscept:,} with built-up in high susceptibility)"
    )

    base_cols = ['id_celula']
    if 'ID_UNICO' in grid_out.columns:
        base_cols.append('ID_UNICO')
    base_cols.append('cod_mun_ghsl')
    df_parquet = grid_out.drop(columns='geometry')[base_cols + GHSL_COLS].copy()
    fname_parquet = f"grade_{grid_year}_ghsl_suscept{suffix}.parquet"
    df_parquet.to_parquet(OUT_DIR / fname_parquet, index=False)
    print(f"  OK {fname_parquet}  ({len(df_parquet):,} rows)")

# ──────────────────────────────────────────────────────────────
# 9) Municipal summary
# ──────────────────────────────────────────────────────────────
print("\n9) Generating municipal summary ...")

summaries = []
for grid_year, r_dict in results.items():
    if not r_dict:
        continue
    df = pd.DataFrame.from_dict(r_dict, orient='index')
    df.index.name = 'id_celula'
    df = df.reset_index()
    for col in GHSL_COLS:
        if col not in df.columns:
            df[col] = 0.0
    summary = df.groupby('cod_mun_ghsl').agg({col: 'sum' for col in GHSL_COLS}).reset_index()
    summary.columns = ['cod_mun'] + [f'{c}_grade{grid_year}' for c in GHSL_COLS]
    summaries.append(summary)

if summaries:
    from functools import reduce
    final_summary = reduce(
        lambda l, r: l.merge(r, on='cod_mun', how='outer'), summaries
    ).fillna(0)
    fname_csv = f"resumo_municipal_ghsl_suscept{suffix}.csv"
    final_summary.to_csv(OUT_DIR / fname_csv, index=False)
    print(f"  OK {fname_csv}  ({len(final_summary)} municipalities)")

print("\n" + "=" * 60)
print("DONE")
print("=" * 60)
print(f"Municipalities processed: {len(municipalities_to_process)}")
print(f"Files in: {OUT_DIR}")
print("  *.gpkg    -> GeoPackage with geometry (for the spatial join in script 07)")
print("  *.parquet -> no geometry, join by id_celula")
print("  *.csv     -> summary aggregated by municipality")
