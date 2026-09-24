# ============================================================
# 03_cruzamento_completo_risco.py
#
# Script unificado para RISCO CPRM (Alto e Muito alto combinados).
# Em um único loop por município processa o risco como camada única:
#
#   1. Encontra células da grade dentro do município
#   2. Calcula prop_risco (fração coberta por qualquer grau de risco)
#   3. Se município tem AGSN (union por município):
#      - Calcula prop_agsn_com_risco  (AGSN ∩ risco)
#      - Calcula prop_agsn_sem_risco  (AGSN − risco)
#
# O AGSN é dissolvido/unido por município antes do loop principal
# (igual ao padrão dos scripts 03_cruzamento_completo_alta/medio).
#
# Pré-requisitos:
#   - 01_download_prepare_ibge_grid.py → processed_data/risco_preparado.gpkg
#
# Saídas (em data/processed_data/02_hazard_zones/):
#   - grade_2010_BR_com_risco_agsn.gpkg
#   - grade_2022_BR_com_risco_agsn.gpkg
#   - AGSN_com_risco.gpkg
#   - resumo_municipal_risco_agsn.csv
#
# Execute na raiz do projeto:
#   python 02_population_in_hazard_zones/04_cross_grid_cprm_risk.py
# ============================================================

import geopandas as gpd
import pandas as pd
import numpy as np
from pathlib import Path
from tqdm import tqdm
from shapely.ops import unary_union
import warnings
import re
warnings.filterwarnings('ignore')

# ------------------------------------------------------------
# Configurações
# ------------------------------------------------------------
PREPARADO = Path("data/processed_data/02_hazard_zones")
CRS_PROJ  = "EPSG:5880"

RISCO_GPKG = PREPARADO / "risco_preparado.gpkg"

# Filtro de UF para testes rápidos (2 primeiros dígitos do código IBGE).
# Ex.: '26' = Pernambuco. Defina como None para processar o Brasil inteiro.
FILTRO_UF = None

def normalizar_cod(cod):
    s = re.sub(r'\D', '', str(cod))
    return s[:7] if len(s) >= 7 else s.zfill(7)

print("\n" + "="*60)
print("CRUZAMENTO COMPLETO – RISCO CPRM (CAMADA ÚNICA)")
print("="*60)

# ------------------------------------------------------------
# 1) Carregar e preparar risco
# ------------------------------------------------------------
print("\n1) Carregando risco_preparado.gpkg …")

if not RISCO_GPKG.exists():
    raise FileNotFoundError(
        f"Execute primeiro: 01_download_prepare_ibge_grid.py\n{RISCO_GPKG}"
    )

risco = gpd.read_file(RISCO_GPKG)
risco = risco.to_crs(CRS_PROJ)
risco['cd_geocmun'] = risco['cd_geocmun'].apply(normalizar_cod)
risco['geometry']   = risco.geometry.make_valid()

print(f"  Polígonos totais: {len(risco):,}")
print(f"  Por grau_risco:")
print(risco['grau_risco'].value_counts().to_string())

# Dissolver todos os graus por município em geometria única
print("\n  Dissolvendo por município (todos os graus) …")

risco_diss = (
    risco
    .dissolve(by='cd_geocmun', as_index=False)[['cd_geocmun', 'geometry']]
)
risco_diss['geometry'] = risco_diss.geometry.make_valid()
risco_diss = risco_diss[~risco_diss.geometry.is_empty].copy()

print(f"  Municípios com risco: {len(risco_diss):,}")

risco_dict = dict(zip(risco_diss['cd_geocmun'], risco_diss['geometry']))
municipios_com_risco = set(risco_dict)

if FILTRO_UF:
    municipios_com_risco = {c for c in municipios_com_risco if c.startswith(FILTRO_UF)}
    print(f"  >>> Filtro UF={FILTRO_UF}: {len(municipios_com_risco):,} municípios")

# ------------------------------------------------------------
# 2) Malha municipal
# ------------------------------------------------------------
print("\n2) Carregando malha municipal …")

malha_gpkg = PREPARADO / "malha_municipal_5880.gpkg"
if not malha_gpkg.exists():
    raise FileNotFoundError(
        f"Execute primeiro: 01_download_prepare_ibge_grid.py\n{malha_gpkg}"
    )

malha = gpd.read_file(malha_gpkg)
malha['COD_MUNICIPIO'] = malha['COD_MUNICIPIO'].astype(str).str[:7]
malha = malha[malha['COD_MUNICIPIO'].isin(municipios_com_risco)].copy()
malha_dict = dict(zip(malha['COD_MUNICIPIO'], malha['geometry']))
print(f"  Municípios: {len(malha_dict):,}")

# ------------------------------------------------------------
# 3) AGSN – union por município
# ------------------------------------------------------------
print("\n3) Carregando AGSN e dissolvendo por município …")

agsn_gpkg = PREPARADO / "AGSN_preparada.gpkg"
if not agsn_gpkg.exists():
    raise FileNotFoundError(
        f"Execute primeiro: 01_download_prepare_ibge_grid.py\n{agsn_gpkg}"
    )

agsn = gpd.read_file(agsn_gpkg)
agsn = agsn.to_crs(CRS_PROJ)
agsn['cod_mun_7dig'] = agsn['cod_mun_7dig'].astype(str).str[:7]

n_antes = len(agsn)
agsn = agsn[agsn['cod_mun_7dig'].isin(municipios_com_risco)].copy()
print(f"  AGSN em municípios com risco: {len(agsn):,} polígonos (de {n_antes:,})")

# Indexar polígonos AGSN individuais por município.
agsn['geometry'] = agsn.geometry.make_valid()

agsn_por_mun = {}
for cod, grp in agsn.groupby('cod_mun_7dig'):
    geoms = [g for g in grp.geometry.values if g is not None and not g.is_empty]
    if geoms:
        agsn_por_mun[cod] = geoms

municipios_com_agsn = set(agsn_por_mun.keys())
print(f"  Municípios com AGSN e risco: {len(municipios_com_agsn):,}")

# Área mínima (m²) para considerar sobreposição real entre AGSN e risco.
MIN_AREA_OVERLAP = 1.0

# ------------------------------------------------------------
# 4) Grades
# ------------------------------------------------------------
print("\n4) Carregando grades …")

def carregar_grade(gpkg_path, col_pop_candidatas):
    g = gpd.read_file(gpkg_path)
    g = g.to_crs(CRS_PROJ)
    col_pop = next((c for c in col_pop_candidatas if c in g.columns), None)
    if col_pop is None:
        raise ValueError(f"Coluna população não encontrada. Colunas: {g.columns.tolist()}")
    g = g.rename(columns={col_pop: 'populacao'})
    g['id_celula'] = g['id_celula'].astype(str)
    g['area_total'] = g.geometry.area
    return g

grade2010 = carregar_grade(
    PREPARADO / "grade_2010_BR.gpkg",
    ['pop_2010', 'POP', 'Pop', 'pop']
)
grade2022 = carregar_grade(
    PREPARADO / "grade_2022_BR.gpkg",
    ['pop_2022', 'TOTAL', 'Total', 'total', 'POP', 'Pop', 'pop']
)
print(f"  Grade 2010: {len(grade2010):,} células")
print(f"  Grade 2022: {len(grade2022):,} células")

grade2010_dict = grade2010.set_index('id_celula')
grade2022_dict = grade2022.set_index('id_celula')

print("\n  Carregando parquets de centroides …")
pontos2010 = gpd.read_parquet(PREPARADO / "grade_2010_pontos_BR.parquet")
pontos2010 = pontos2010.to_crs(CRS_PROJ)
pontos2022 = gpd.read_parquet(PREPARADO / "grade_2022_pontos_BR.parquet")
pontos2022 = pontos2022.to_crs(CRS_PROJ)
print(f"  Pontos 2010: {len(pontos2010):,}  |  Pontos 2022: {len(pontos2022):,}")

# ------------------------------------------------------------
# Funções auxiliares (idênticas aos scripts alta/medio)
# ------------------------------------------------------------
def encontrar_celulas_mun(geom_malha, pontos, grade_dict, grade_ids):
    """Retorna set de id_celula dentro do município (core + borda)."""
    bbox = geom_malha.bounds
    pts_bbox = pontos.cx[bbox[0]:bbox[2], bbox[1]:bbox[3]]
    ids_core = set(pts_bbox[pts_bbox.within(geom_malha)]['id_celula'].values)
    ids_candidatos = (set(pts_bbox['id_celula'].values) & grade_ids) - ids_core
    ids_borda = set()
    if ids_candidatos:
        cands = grade_dict.loc[list(ids_candidatos)]
        ids_borda = set(cands[cands.intersects(geom_malha)].index)
    return ids_core | ids_borda


def clip_proporcoes(geom_clip, celulas_subset):
    """Retorna {id_celula: proporção} para clip de geom_clip sobre subset."""
    if geom_clip is None or geom_clip.is_empty or len(celulas_subset) == 0:
        return {}
    try:
        clipped = gpd.clip(celulas_subset, geom_clip)
    except Exception:
        try:
            geom_gdf = gpd.GeoDataFrame(
                [{'geometry': geom_clip}], crs=celulas_subset.crs
            )
            clipped = gpd.overlay(
                celulas_subset.reset_index(), geom_gdf, how='intersection'
            ).set_index('id_celula')
        except Exception:
            return {}
    if len(clipped) == 0:
        return {}
    areas  = clipped.geometry.area.groupby(clipped.index).sum()
    totals = celulas_subset.loc[areas.index, 'area_total']
    props  = (areas / totals).clip(upper=1.0)
    return props[props > 0].to_dict()


def acumular(destino, novo):
    """Acumula proporções (somando, capped em 1.0)."""
    for id_cel, prop in novo.items():
        destino[id_cel] = min(1.0, destino.get(id_cel, 0.0) + prop)


# ------------------------------------------------------------
# 5) Loop principal por município
# ------------------------------------------------------------
municipios_loop = sorted(municipios_com_risco & set(malha_dict))
print(f"\n5) Processando {len(municipios_loop)} municípios …")

print("  Pré-computando índices das grades …")
grade_ids_2010 = set(grade2010_dict.index)
grade_ids_2022 = set(grade2022_dict.index)

prop_risco_2010 = {}
prop_risco_2022 = {}

cod_mun_celula_2010 = {}
cod_mun_celula_2022 = {}

prop_agsn_com_risco_2010 = {}
prop_agsn_com_risco_2022 = {}
prop_agsn_total_2010     = {}
prop_agsn_total_2022     = {}

celulas_mun_2010 = set()
celulas_mun_2022 = set()

agsn_com_risco_geoms = []
agsn_com_risco_attrs = []

for cod_mun in tqdm(municipios_loop, desc="Municípios"):
    geom_malha = malha_dict[cod_mun]

    # ── Encontrar células do município ───────────────────────
    ids_2010 = encontrar_celulas_mun(
        geom_malha, pontos2010, grade2010_dict, grade_ids_2010
    )
    ids_2022 = encontrar_celulas_mun(
        geom_malha, pontos2022, grade2022_dict, grade_ids_2022
    )
    celulas_mun_2010.update(ids_2010)
    celulas_mun_2022.update(ids_2022)

    for id_cel in ids_2010:
        if id_cel not in cod_mun_celula_2010:
            cod_mun_celula_2010[id_cel] = cod_mun
    for id_cel in ids_2022:
        if id_cel not in cod_mun_celula_2022:
            cod_mun_celula_2022[id_cel] = cod_mun

    cel2010 = grade2010_dict.loc[list(ids_2010)] if ids_2010 else grade2010_dict.iloc[0:0]
    cel2022 = grade2022_dict.loc[list(ids_2022)] if ids_2022 else grade2022_dict.iloc[0:0]

    # ── Risco (camada única) ──────────────────────────────────
    geom_risco = risco_dict.get(cod_mun)
    if geom_risco is not None:
        acumular(prop_risco_2010, clip_proporcoes(geom_risco, cel2010))
        acumular(prop_risco_2022, clip_proporcoes(geom_risco, cel2022))

    # ── AGSN (apenas se município tem AGSN) ──────────────────
    if cod_mun not in agsn_por_mun:
        continue

    attrs = {'cod_mun': cod_mun}

    for geom_agsn in agsn_por_mun[cod_mun]:
        # Total AGSN (sempre, independente do risco)
        acumular(prop_agsn_total_2010, clip_proporcoes(geom_agsn, cel2010))
        acumular(prop_agsn_total_2022, clip_proporcoes(geom_agsn, cel2022))

        # AGSN × risco (interseção)
        if geom_risco is not None:
            try:
                geom_inter = geom_agsn.intersection(geom_risco)
            except Exception:
                geom_inter = None
            if geom_inter is not None and not geom_inter.is_empty and geom_inter.area >= MIN_AREA_OVERLAP:
                acumular(prop_agsn_com_risco_2010, clip_proporcoes(geom_inter, cel2010))
                acumular(prop_agsn_com_risco_2022, clip_proporcoes(geom_inter, cel2022))
                agsn_com_risco_geoms.append(geom_inter)
                agsn_com_risco_attrs.append(attrs)

print(f"\n  Células 2010 em municípios processados: {len(celulas_mun_2010):,}")
print(f"  Células 2022 em municípios processados: {len(celulas_mun_2022):,}")
print(f"  Células 2010 com risco > 0: {len(prop_risco_2010):,}")
print(f"  Células 2022 com risco > 0: {len(prop_risco_2022):,}")

# ------------------------------------------------------------
# 6) Construir grades com colunas novas e salvar
# ------------------------------------------------------------
print("\n6) Construindo e salvando grades …")

def montar_grade(grade_base, celulas_ids,
                 p_risco, cod_mun_map,
                 p_agsn_com_risco, p_agsn_total):
    g = grade_base[grade_base['id_celula'].isin(celulas_ids)].copy()
    g['prop_risco']          = g['id_celula'].map(p_risco).fillna(0.0)
    g['cod_mun_risco']       = g['id_celula'].map(cod_mun_map).fillna('')
    g['prop_agsn_com_risco'] = g['id_celula'].map(p_agsn_com_risco).fillna(0.0)
    g['prop_agsn']           = g['id_celula'].map(p_agsn_total).fillna(0.0)
    g['prop_agsn_sem_risco'] = (g['prop_agsn'] - g['prop_agsn_com_risco']).clip(lower=0.0)
    return g

grade2010_out = montar_grade(
    grade2010, celulas_mun_2010,
    prop_risco_2010, cod_mun_celula_2010,
    prop_agsn_com_risco_2010, prop_agsn_total_2010,
)
grade2022_out = montar_grade(
    grade2022, celulas_mun_2022,
    prop_risco_2022, cod_mun_celula_2022,
    prop_agsn_com_risco_2022, prop_agsn_total_2022,
)

out_g10 = PREPARADO / "grade_2010_BR_com_risco_agsn.gpkg"
out_g22 = PREPARADO / "grade_2022_BR_com_risco_agsn.gpkg"
grade2010_out.to_file(out_g10, driver="GPKG")
print(f"  ✓ {out_g10.name}  ({out_g10.stat().st_size/1024**2:.1f} MB)")
grade2022_out.to_file(out_g22, driver="GPKG")
print(f"  ✓ {out_g22.name}  ({out_g22.stat().st_size/1024**2:.1f} MB)")

# ------------------------------------------------------------
# 7) Salvar AGSN dividido
# ------------------------------------------------------------
print("\n7) Salvando AGSN dividido …")

def salvar_agsn(geoms, attrs, path):
    if geoms:
        gdf = gpd.GeoDataFrame(attrs, geometry=geoms, crs=CRS_PROJ)
        gdf.to_file(path, driver="GPKG")
        print(f"  ✓ {path.name}  ({len(gdf):,} polígonos)")

salvar_agsn(agsn_com_risco_geoms, agsn_com_risco_attrs,
            PREPARADO / "AGSN_com_risco.gpkg")

# ------------------------------------------------------------
# 8) CSV de resultados municipais
# ------------------------------------------------------------
print("\n8) Gerando CSV municipal …")

def resumo_municipal(grade, ano):
    g = grade[grade['cod_mun_risco'].notna() & (grade['cod_mun_risco'] != '')].copy()
    pop = g['populacao'].fillna(0)

    g['pop_risco']          = pop * g['prop_risco'].fillna(0)
    g['pop_agsn']           = pop * g['prop_agsn'].fillna(0)
    g['pop_agsn_com_risco'] = pop * g['prop_agsn_com_risco'].fillna(0)

    resumo = g.groupby('cod_mun_risco').agg(
        pop_total         = ('populacao',        'sum'),
        pop_risco         = ('pop_risco',         'sum'),
        pop_agsn          = ('pop_agsn',          'sum'),
        pop_agsn_com_risco = ('pop_agsn_com_risco', 'sum'),
    ).reset_index()

    resumo['pop_agsn_sem_risco'] = (resumo['pop_agsn'] - resumo['pop_agsn_com_risco']).clip(lower=0)

    resumo.columns = ['cod_mun'] + [
        f'{c}_{ano}' for c in resumo.columns[1:]
    ]
    return resumo

res2010 = resumo_municipal(grade2010_out, '2010')
res2022 = resumo_municipal(grade2022_out, '2022')
resumo  = res2010.merge(res2022, on='cod_mun', how='outer').fillna(0)
resumo  = resumo.sort_values('pop_risco_2022', ascending=False)

out_csv = PREPARADO / "resumo_municipal_risco_agsn.csv"
resumo.to_csv(out_csv, index=False)
print(f"  ✓ {out_csv.name}  ({len(resumo)} municípios)")

# ------------------------------------------------------------
# 9) Resumo final
# ------------------------------------------------------------
print("\n" + "="*60)
print("RESUMO FINAL – RISCO CPRM")
print("="*60)

print(f"\nMunicípios com risco: {len(risco_dict):,}")
print(f"Municípios com AGSN e risco: {len(municipios_com_agsn):,}")

print(f"\nGrade 2010 – células salvas:  {len(grade2010_out):,}")
print(f"  com risco > 0:              {(grade2010_out['prop_risco'] > 0).sum():,}")

print(f"\nGrade 2022 – células salvas:  {len(grade2022_out):,}")
print(f"  com risco > 0:              {(grade2022_out['prop_risco'] > 0).sum():,}")

if len(res2022) > 0:
    print(f"\nPop. em risco 2022:           "
          f"{resumo['pop_risco_2022'].sum():,.0f}")
    print(f"Pop. em AGSN∩risco 2022:      "
          f"{resumo['pop_agsn_com_risco_2022'].sum():,.0f}")

print("\nColunas nas grades:")
print("  prop_risco          – fração da célula em risco (qualquer grau)")
print("  cod_mun_risco       – código do município")
print("  prop_agsn_com_risco – fração em AGSN ∩ risco")
print("  prop_agsn_sem_risco – fração em AGSN fora do risco")
print("  prop_agsn           – fração em qualquer AGSN")

print("\n✓ Processamento concluído!")
