# ============================================================
# 03_cruzamento_completo_alta.py
#
# Script unificado para susceptibilidade ALTA.
# Substitui os scripts 04, 05 e 10 (versão alta).
#
# Em um único loop por município com susceptibilidade ALTA:
#   1. Encontra células da grade dentro do município
#   2. Calcula prop_suscept (fração coberta pela susceptibilidade)
#   3. Se município tem AGSN:
#      - Calcula prop_agsn_com_suscept (AGSN ∩ suscept)
#      - Calcula prop_agsn_sem_suscept (AGSN − suscept)
#
# Atenção: nem todos os municípios com susceptibilidade têm AGSN.
# Células em municípios sem AGSN recebem prop_agsn* = 0.
#
# Pré-requisitos:
#   - 01_download_prepare_ibge_grid.py → processed_data/
#   - 02_prepare_high_susceptibility_layer.py → susceptibilidade_unida.gpkg
#
# Saídas (em data/processed_data/02_hazard_zones/):
#   - grade_2010_BR_com_suscept_alta_agsn.gpkg
#   - grade_2022_BR_com_suscept_alta_agsn.gpkg
#   - AGSN_com_suscept_alta.gpkg
#   - AGSN_sem_suscept_alta.gpkg
#   - resumo_municipal_suscept_alta_agsn.csv
#
# Execute na raiz do projeto:
#   python 02_population_in_hazard_zones/03_cross_grid_high_susceptibility.py
# ============================================================

import geopandas as gpd
import pandas as pd
import numpy as np
from pathlib import Path
from tqdm import tqdm
import warnings
import re
warnings.filterwarnings('ignore')

# ------------------------------------------------------------
# Configurações
# ------------------------------------------------------------
SUFIXO    = "alta"
DATA_RAW  = Path("data/raw_data/02_hazard_zones")         # inputs manuais
PREPARADO = Path("data/processed_data/02_hazard_zones")
BASE_DIR  = Path("data/raw_data/02_hazard_zones")
CRS_PROJ  = "EPSG:5880"

# Susceptibilidade alta: copiados para data_raw/ pelo usuário
SUSCET_ORIG_MASSA = DATA_RAW  / "suscet_massa_br.gpkg"
SUSCET_ORIG_INUND = DATA_RAW  / "suscet_inundacao_br.gpkg"
SUSCET_UNIDA      = PREPARADO / "susceptibilidade_unida.gpkg"

def normalizar_cod(cod):
    s = re.sub(r'\D', '', str(cod))
    return s[:7] if len(s) >= 7 else s.zfill(7)

print("\n" + "="*60)
print(f"CRUZAMENTO COMPLETO – SUSCEPTIBILIDADE {SUFIXO.upper()}")
print("="*60)

# ------------------------------------------------------------
# 1) Municípios com susceptibilidade ALTA (códigos originais)
# ------------------------------------------------------------
print("\n1) Carregando susceptibilidade ALTA …")

for p in [SUSCET_ORIG_MASSA, SUSCET_ORIG_INUND]:
    if not p.exists():
        raise FileNotFoundError(f"Arquivo não encontrado: {p}")
if not SUSCET_UNIDA.exists():
    raise FileNotFoundError(
        f"Execute primeiro: 02_prepare_high_susceptibility_layer.py\n{SUSCET_UNIDA}"
    )

codigos_orig = set()
for p in [SUSCET_ORIG_MASSA, SUSCET_ORIG_INUND]:
    gdf = gpd.read_file(p, include_fields=['COD_MUNICIPIO'])
    codigos_orig |= {normalizar_cod(c) for c in gdf['COD_MUNICIPIO'].unique()}
print(f"  Municípios com susceptibilidade ALTA (originais): {len(codigos_orig)}")

suscept = gpd.read_file(SUSCET_UNIDA)
suscept['COD_MUNICIPIO'] = suscept['COD_MUNICIPIO'].apply(normalizar_cod)
suscept = suscept[suscept['COD_MUNICIPIO'].isin(codigos_orig)].copy()
suscept = suscept.to_crs(CRS_PROJ)
suscept['geometry'] = suscept.geometry.make_valid()
print(f"  Municípios na susceptibilidade unida: {len(suscept)}")

suscept_dict = dict(zip(suscept['COD_MUNICIPIO'], suscept['geometry']))

# ------------------------------------------------------------
# 2) Malha municipal
# ------------------------------------------------------------
print("\n2) Carregando malha municipal …")

malha_gpkg = PREPARADO / "malha_municipal_5880.gpkg"
if malha_gpkg.exists():
    malha = gpd.read_file(malha_gpkg)
else:
    malha_shp = BASE_DIR / "malha_municipal" / "BR_Municipios_2022.shp"
    malha = gpd.read_file(malha_shp)
    col = next((c for c in ['CD_MUN', 'CD_GEOCMU', 'GEOCODIGO', 'cod_mun']
                if c in malha.columns), None)
    malha = malha.rename(columns={col: 'COD_MUNICIPIO'})
    malha = malha.to_crs(CRS_PROJ)

malha['COD_MUNICIPIO'] = malha['COD_MUNICIPIO'].astype(str).str[:7]
malha_dict = dict(zip(malha['COD_MUNICIPIO'], malha['geometry']))
print(f"  Municípios: {len(malha_dict)}")

# ------------------------------------------------------------
# 3) AGSN preparada
# ------------------------------------------------------------
print("\n3) Carregando AGSN …")

agsn_gpkg = PREPARADO / "AGSN_preparada.gpkg"
if not agsn_gpkg.exists():
    raise FileNotFoundError(
        f"Execute primeiro: 01_download_prepare_ibge_grid.py\n{agsn_gpkg}"
    )

agsn = gpd.read_file(agsn_gpkg)
agsn = agsn.to_crs(CRS_PROJ)
agsn['cod_mun_7dig'] = agsn['cod_mun_7dig'].astype(str).str[:7]

# Filtrar para municípios com susceptibilidade ALTA
n_antes = len(agsn)
agsn = agsn[agsn['cod_mun_7dig'].isin(suscept_dict.keys())].copy()
print(f"  AGSN com susceptibilidade ALTA: {len(agsn):,} polígonos "
      f"(de {n_antes:,} total)")

municipios_com_agsn = set(agsn['cod_mun_7dig'].unique())
print(f"  Municípios com AGSN e susceptibilidade ALTA: {len(municipios_com_agsn)}")

agsn_por_mun = {cod: grp for cod, grp in agsn.groupby('cod_mun_7dig')}

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
# Funções auxiliares
# ------------------------------------------------------------
def encontrar_celulas_mun(geom_malha, pontos, grade_dict, grade_ids):
    """Retorna set de id_celula dentro do município.
    grade_ids: set(grade_dict.index) pré-computado uma vez fora do loop.
    """
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
            geom_gdf = gpd.GeoDataFrame([{'geometry': geom_clip}], crs=celulas_subset.crs)
            clipped = gpd.overlay(celulas_subset.reset_index(), geom_gdf,
                                  how='intersection').set_index('id_celula')
        except Exception:
            return {}
    if len(clipped) == 0:
        return {}
    # Vetorizado: agrupa por célula (caso clip produza fragmentos), divide por área total
    areas = clipped.geometry.area.groupby(clipped.index).sum()
    totals = celulas_subset.loc[areas.index, 'area_total']
    props = (areas / totals).clip(upper=1.0)
    return props[props > 0].to_dict()


def acumular(destino, novo):
    """Acumula proporções (somando, capped em 1.0)."""
    for id_cel, prop in novo.items():
        destino[id_cel] = min(1.0, destino.get(id_cel, 0.0) + prop)


# ------------------------------------------------------------
# 5) Loop principal por município
# ------------------------------------------------------------
print(f"\n5) Processando {len(suscept)} municípios …")

# Pré-computar sets de IDs das grades (evita recriar a cada iteração do loop)
print("  Pré-computando índices das grades …")
grade_ids_2010 = set(grade2010_dict.index)
grade_ids_2022 = set(grade2022_dict.index)

prop_suscept_2010   = {}
prop_suscept_2022   = {}
cod_mun_celula_2010 = {}
cod_mun_celula_2022 = {}
prop_agsn_com_2010  = {}
prop_agsn_sem_2010  = {}
prop_agsn_com_2022  = {}
prop_agsn_sem_2022  = {}
celulas_mun_2010 = set()
celulas_mun_2022 = set()

agsn_com_geoms = []
agsn_sem_geoms = []
agsn_com_attrs = []
agsn_sem_attrs = []

for _, row in tqdm(suscept.iterrows(), total=len(suscept), desc="Municípios"):
    cod_mun      = row['COD_MUNICIPIO']
    geom_suscept = row['geometry']

    geom_malha = malha_dict.get(cod_mun)
    if geom_malha is None:
        continue

    # ── Encontrar células do município ──────────────────────
    ids_2010 = encontrar_celulas_mun(geom_malha, pontos2010, grade2010_dict, grade_ids_2010)
    ids_2022 = encontrar_celulas_mun(geom_malha, pontos2022, grade2022_dict, grade_ids_2022)
    celulas_mun_2010.update(ids_2010)
    celulas_mun_2022.update(ids_2022)

    for id_cel in ids_2010:
        if id_cel not in cod_mun_celula_2010:
            cod_mun_celula_2010[id_cel] = cod_mun
    for id_cel in ids_2022:
        if id_cel not in cod_mun_celula_2022:
            cod_mun_celula_2022[id_cel] = cod_mun

    # ── Susceptibilidade: clip grade × suscept ───────────────
    # cel2010/cel2022 são reutilizados no bloco AGSN abaixo
    if ids_2010:
        cel2010 = grade2010_dict.loc[list(ids_2010)]
        acumular(prop_suscept_2010, clip_proporcoes(geom_suscept, cel2010))
    else:
        cel2010 = grade2010_dict.iloc[0:0]

    if ids_2022:
        cel2022 = grade2022_dict.loc[list(ids_2022)]
        acumular(prop_suscept_2022, clip_proporcoes(geom_suscept, cel2022))
    else:
        cel2022 = grade2022_dict.iloc[0:0]

    # ── AGSN (apenas se município tem AGSN) ─────────────────
    if cod_mun not in agsn_por_mun:
        continue

    for _, agsn_row in agsn_por_mun[cod_mun].iterrows():
        geom_agsn = agsn_row['geometry']
        if geom_agsn is None or geom_agsn.is_empty:
            continue

        try:
            geom_com = geom_agsn.intersection(geom_suscept)
            geom_sem = geom_agsn.difference(geom_suscept)
        except Exception:
            continue

        attrs = {'cod_mun': cod_mun}

        if geom_com is not None and not geom_com.is_empty:
            acumular(prop_agsn_com_2010, clip_proporcoes(geom_com, cel2010))
            acumular(prop_agsn_com_2022, clip_proporcoes(geom_com, cel2022))
            agsn_com_geoms.append(geom_com)
            agsn_com_attrs.append(attrs)

        if geom_sem is not None and not geom_sem.is_empty:
            acumular(prop_agsn_sem_2010, clip_proporcoes(geom_sem, cel2010))
            acumular(prop_agsn_sem_2022, clip_proporcoes(geom_sem, cel2022))
            agsn_sem_geoms.append(geom_sem)
            agsn_sem_attrs.append(attrs)

print(f"\n  Células 2010 em municípios processados: {len(celulas_mun_2010):,}")
print(f"  Células 2022 em municípios processados: {len(celulas_mun_2022):,}")
print(f"  Células 2010 com suscept ALTA: {len(prop_suscept_2010):,}")
print(f"  Células 2022 com suscept ALTA: {len(prop_suscept_2022):,}")
print(f"  Células 2010 com AGSN∩suscept: {len(prop_agsn_com_2010):,}")
print(f"  Células 2022 com AGSN∩suscept: {len(prop_agsn_com_2022):,}")

# ------------------------------------------------------------
# 6) Montar proporção total AGSN (com + sem suscept)
# ------------------------------------------------------------
def unir_props(d1, d2):
    resultado = d1.copy()
    for k, v in d2.items():
        resultado[k] = min(1.0, resultado.get(k, 0.0) + v)
    return resultado

prop_agsn_2010 = unir_props(prop_agsn_com_2010, prop_agsn_sem_2010)
prop_agsn_2022 = unir_props(prop_agsn_com_2022, prop_agsn_sem_2022)

# ------------------------------------------------------------
# 7) Construir grades com colunas novas e salvar
# ------------------------------------------------------------
print("\n6) Construindo e salvando grades …")

def montar_grade(grade_base, celulas_ids, prop_suscept, cod_mun_map,
                 prop_agsn_com, prop_agsn_sem, prop_agsn):
    g = grade_base[grade_base['id_celula'].isin(celulas_ids)].copy()
    g['prop_suscept']              = g['id_celula'].map(prop_suscept).fillna(0.0)
    g['cod_mun_suscept']           = g['id_celula'].map(cod_mun_map).fillna('')
    g[f'prop_agsn_com_suscept_{SUFIXO}'] = g['id_celula'].map(prop_agsn_com).fillna(0.0)
    g[f'prop_agsn_sem_suscept_{SUFIXO}'] = g['id_celula'].map(prop_agsn_sem).fillna(0.0)
    g[f'prop_agsn_{SUFIXO}']             = g['id_celula'].map(prop_agsn).fillna(0.0)
    return g

grade2010_out = montar_grade(grade2010, celulas_mun_2010, prop_suscept_2010,
                              cod_mun_celula_2010, prop_agsn_com_2010,
                              prop_agsn_sem_2010, prop_agsn_2010)
grade2022_out = montar_grade(grade2022, celulas_mun_2022, prop_suscept_2022,
                              cod_mun_celula_2022, prop_agsn_com_2022,
                              prop_agsn_sem_2022, prop_agsn_2022)

out_g10 = PREPARADO / f"grade_2010_BR_com_suscept_{SUFIXO}_agsn.gpkg"
out_g22 = PREPARADO / f"grade_2022_BR_com_suscept_{SUFIXO}_agsn.gpkg"
grade2010_out.to_file(out_g10, driver="GPKG")
print(f"  ✓ {out_g10.name}  ({out_g10.stat().st_size/1024**2:.1f} MB)")
grade2022_out.to_file(out_g22, driver="GPKG")
print(f"  ✓ {out_g22.name}  ({out_g22.stat().st_size/1024**2:.1f} MB)")

# ------------------------------------------------------------
# 8) Salvar AGSN dividido
# ------------------------------------------------------------
print("\n7) Salvando AGSN dividido …")

if agsn_com_geoms:
    gdf_com = gpd.GeoDataFrame(agsn_com_attrs, geometry=agsn_com_geoms, crs=CRS_PROJ)
    out_com = PREPARADO / f"AGSN_com_suscept_{SUFIXO}.gpkg"
    gdf_com.to_file(out_com, driver="GPKG")
    print(f"  ✓ {out_com.name}  ({len(gdf_com):,} polígonos)")

if agsn_sem_geoms:
    gdf_sem = gpd.GeoDataFrame(agsn_sem_attrs, geometry=agsn_sem_geoms, crs=CRS_PROJ)
    out_sem = PREPARADO / f"AGSN_sem_suscept_{SUFIXO}.gpkg"
    gdf_sem.to_file(out_sem, driver="GPKG")
    print(f"  ✓ {out_sem.name}  ({len(gdf_sem):,} polígonos)")

# ------------------------------------------------------------
# 9) CSV de resultados municipais
# ------------------------------------------------------------
print("\n8) Gerando CSV municipal …")

def resumo_municipal(grade, ano):
    pop_col = 'populacao'
    cod_col = 'cod_mun_suscept'
    g = grade[grade[cod_col].notna() & (grade[cod_col] != '')].copy()
    pop = g[pop_col].fillna(0)

    p_s   = g['prop_suscept'].fillna(0)
    p_ac  = g[f'prop_agsn_com_suscept_{SUFIXO}'].fillna(0)
    p_as  = g[f'prop_agsn_sem_suscept_{SUFIXO}'].fillna(0)
    p_at  = g[f'prop_agsn_{SUFIXO}'].fillna(0)

    g['pop_suscept']               = pop * p_s
    g['pop_agsn_total']            = pop * p_at
    g['pop_agsn_com_suscept']      = pop * p_ac
    g['pop_agsn_sem_suscept']      = pop * p_as
    # população em suscept mas fora de AGSN
    g['pop_suscept_sem_agsn']      = np.where((p_s > 0) & (p_at == 0), pop * p_s, 0)
    # sobreposição suscept e AGSN (mínimo das duas proporções)
    g['pop_suscept_e_agsn']        = np.where((p_s > 0) & (p_at > 0),
                                               pop * np.minimum(p_s, p_at), 0)

    resumo = g.groupby(cod_col).agg(
        pop_total=('populacao', 'sum'),
        pop_suscept=('pop_suscept', 'sum'),
        pop_agsn_total=('pop_agsn_total', 'sum'),
        pop_agsn_com_suscept=('pop_agsn_com_suscept', 'sum'),
        pop_agsn_sem_suscept=('pop_agsn_sem_suscept', 'sum'),
        pop_suscept_sem_agsn=('pop_suscept_sem_agsn', 'sum'),
        pop_suscept_e_agsn=('pop_suscept_e_agsn', 'sum'),
    ).reset_index()

    resumo.columns = ['cod_mun'] + [
        f'{c}_{SUFIXO}_{ano}' for c in resumo.columns[1:]
    ]
    return resumo

res2010 = resumo_municipal(grade2010_out, '2010')
res2022 = resumo_municipal(grade2022_out, '2022')
resumo = res2010.merge(res2022, on='cod_mun', how='outer').fillna(0)
resumo = resumo.sort_values(f'pop_suscept_{SUFIXO}_2022', ascending=False)

out_csv = PREPARADO / f"resumo_municipal_suscept_{SUFIXO}_agsn.csv"
resumo.to_csv(out_csv, index=False)
print(f"  ✓ {out_csv.name}  ({len(resumo)} municípios)")

# ------------------------------------------------------------
# 10) Resumo final
# ------------------------------------------------------------
print("\n" + "="*60)
print(f"RESUMO FINAL – SUSCEPTIBILIDADE {SUFIXO.upper()}")
print("="*60)
print(f"\nMunicípios com susceptibilidade {SUFIXO.upper()}: {len(suscept)}")
print(f"Municípios com AGSN e susceptibilidade:         {len(municipios_com_agsn)}")
print(f"\nGrade 2010 – células salvas:    {len(grade2010_out):,}")
print(f"  com suscept > 0:              {(grade2010_out['prop_suscept'] > 0).sum():,}")
print(f"  com AGSN total > 0:           {(grade2010_out[f'prop_agsn_{SUFIXO}'] > 0).sum():,}")
print(f"\nGrade 2022 – células salvas:    {len(grade2022_out):,}")
print(f"  com suscept > 0:              {(grade2022_out['prop_suscept'] > 0).sum():,}")
print(f"  com AGSN total > 0:           {(grade2022_out[f'prop_agsn_{SUFIXO}'] > 0).sum():,}")

if len(res2022) > 0:
    col_s = f'pop_suscept_{SUFIXO}_2022'
    col_a = f'pop_agsn_com_suscept_{SUFIXO}_2022'
    print(f"\nPop. em suscept ALTA 2022:     {resumo[col_s].sum():,.0f}")
    print(f"Pop. em AGSN∩suscept ALTA 2022: {resumo[col_a].sum():,.0f}")

print("\nNovas colunas nas grades:")
print("  prop_suscept                        – fração da célula em suscept ALTA")
print("  cod_mun_suscept                     – código do município")
print(f"  prop_agsn_com_suscept_{SUFIXO}       – fração em AGSN ∩ suscept")
print(f"  prop_agsn_sem_suscept_{SUFIXO}       – fração em AGSN − suscept")
print(f"  prop_agsn_{SUFIXO}                   – fração em AGSN total")

print("\n✓ Processamento concluído!")
