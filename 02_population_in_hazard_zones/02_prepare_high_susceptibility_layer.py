# ============================================================
# 02_preparar_susceptibilidade_alta.py
#
# Versão ALTA de 02_preparar_susceptibilidade.py
#
# Prepara dados de susceptibilidade ALTA (todas as classes):
# - Une susceptibilidade (movimento de massa + inundação)
# - CLIP pelas fronteiras municipais (corrige transbordamento)
# - Dissolve por município
# - Padroniza CRS (EPSG:5880) e geometrias
#
# Lê: data/raw_data/02_hazard_zones/suscet_massa_br.gpkg
#      data/raw_data/02_hazard_zones/suscet_inundacao_br.gpkg
# Grava: data/processed_data/02_hazard_zones/susceptibilidade_unida.gpkg
# ============================================================

import geopandas as gpd
import pandas as pd
from pathlib import Path
import warnings
warnings.filterwarnings('ignore')

# ------------------------------------------------------------
# Configurações
# ------------------------------------------------------------
DATA_RAW = Path("data/raw_data/02_hazard_zones")   # inputs manuais (susceptibilidade)
CRS_PROJ = "EPSG:5880"
OUT_DIR  = Path("data/processed_data/02_hazard_zones")

print("\n" + "="*60)
print("PREPARANDO SUSCEPTIBILIDADE ALTA - BRASIL")
print("="*60)

# ------------------------------------------------------------
# 1) Malha municipal
# ------------------------------------------------------------
print("\n1) Carregando malha municipal...")
malha_path = OUT_DIR / "malha_municipal_5880.gpkg"
if not malha_path.exists():
    # fallback para o shapefile raw (caso 01 ainda não tenha rodado)
    malha_path = Path("data/raw_data/02_hazard_zones") / "malha_municipal" / "BR_Municipios_2022.shp"
if not malha_path.exists():
    raise FileNotFoundError(
        "Malha municipal não encontrada. Execute primeiro: "
        "01_download_prepare_ibge_grid.py"
    )

malha = gpd.read_file(malha_path)
print(f"  Municípios: {len(malha)}")

col_cod_mun = None
for col in ['CD_MUN', 'CD_GEOCMU', 'GEOCODIGO', 'cod_mun', 'COD_MUNICIPIO']:
    if col in malha.columns:
        col_cod_mun = col
        break
if col_cod_mun is None:
    raise ValueError(f"Coluna de código municipal não encontrada. Colunas: {malha.columns.tolist()}")

malha = malha.to_crs(CRS_PROJ)
malha = malha[[col_cod_mun, 'geometry']].copy()
malha = malha.rename(columns={col_cod_mun: 'COD_MUNICIPIO'})
malha['COD_MUNICIPIO'] = malha['COD_MUNICIPIO'].astype(str)
malha['geometry'] = malha.geometry.make_valid()

# ------------------------------------------------------------
# 2) Susceptibilidade ALTA (arquivos completos, todas as classes)
# ------------------------------------------------------------
print("\n2) Carregando susceptibilidade ALTA...")

massa_path = DATA_RAW / "suscet_massa_br.gpkg"
inund_path = DATA_RAW / "suscet_inundacao_br.gpkg"
for p in [massa_path, inund_path]:
    if not p.exists():
        raise FileNotFoundError(
            f"Arquivo não encontrado: {p}\n"
            "Copie os arquivos de susceptibilidade ALTA para data/raw_data/02_hazard_zones/"
        )

print("  - Movimento de massa (suscet_massa_br.gpkg)")
gdf_massa = gpd.read_file(massa_path)
gdf_massa = gdf_massa[gdf_massa.geometry.type.isin(['Polygon', 'MultiPolygon'])].copy()
gdf_massa['COD_MUNICIPIO'] = gdf_massa['COD_MUNICIPIO'].astype(str)
print(f"    Polígonos: {len(gdf_massa)}")

print("  - Inundação (suscet_inundacao_br.gpkg)")
gdf_inundacao = gpd.read_file(inund_path)
gdf_inundacao = gdf_inundacao[gdf_inundacao.geometry.type.isin(['Polygon', 'MultiPolygon'])].copy()
gdf_inundacao['COD_MUNICIPIO'] = gdf_inundacao['COD_MUNICIPIO'].astype(str)
print(f"    Polígonos: {len(gdf_inundacao)}")

print(f"\n3) Reprojetando para {CRS_PROJ}...")
gdf_massa = gdf_massa.to_crs(CRS_PROJ)[['COD_MUNICIPIO', 'geometry']].copy()
gdf_inundacao = gdf_inundacao.to_crs(CRS_PROJ)[['COD_MUNICIPIO', 'geometry']].copy()

gdf_massa['geometry'] = gdf_massa.geometry.make_valid()
gdf_inundacao['geometry'] = gdf_inundacao.geometry.make_valid()

print("\n4) Concatenando movimento de massa e inundação...")
gdf_suscet_concat = pd.concat([gdf_massa, gdf_inundacao], ignore_index=True)
print(f"  Total registros: {len(gdf_suscet_concat)}")
print(f"  Municípios únicos: {gdf_suscet_concat['COD_MUNICIPIO'].nunique()}")

# ------------------------------------------------------------
# 5) CLIP pelas fronteiras municipais
# ------------------------------------------------------------
print("\n5) Cortando pela malha municipal (clip)...")
gdf_suscet_concat['geometry'] = gdf_suscet_concat.geometry.buffer(0)
malha['geometry'] = malha.geometry.buffer(0)

gdf_clipped = gpd.overlay(gdf_suscet_concat, malha, how='intersection')
print(f"  Polígonos após clip: {len(gdf_clipped)}")

if 'COD_MUNICIPIO_1' in gdf_clipped.columns and 'COD_MUNICIPIO_2' in gdf_clipped.columns:
    divergencias = (gdf_clipped['COD_MUNICIPIO_1'] != gdf_clipped['COD_MUNICIPIO_2']).sum()
    if divergencias > 0:
        print(f"  ⚠ {divergencias} polígonos com transbordamento corrigido")
    gdf_clipped = gdf_clipped.rename(columns={'COD_MUNICIPIO_2': 'COD_MUNICIPIO'})

gdf_clipped = gdf_clipped[['COD_MUNICIPIO', 'geometry']].copy()

# ------------------------------------------------------------
# 6) Dissolve e salvar
# ------------------------------------------------------------
print("\n6) Dissolve por município...")
gdf_suscet_unida = gdf_clipped.dissolve(by='COD_MUNICIPIO', as_index=False)
gdf_suscet_unida['geometry'] = gdf_suscet_unida.geometry.make_valid()
print(f"  Municípios: {len(gdf_suscet_unida)}")

print("\n7) Salvando...")
OUT_DIR.mkdir(exist_ok=True, parents=True)
out_file = OUT_DIR / "susceptibilidade_unida.gpkg"
gdf_suscet_unida.to_file(out_file, driver="GPKG")
print(f"\n✓ Arquivo salvo: {out_file.absolute()}")

print("\n" + "="*60)
print("RESUMO")
print("="*60)
print(f"CRS: {CRS_PROJ}")
print(f"Municípios com susceptibilidade ALTA: {len(gdf_suscet_unida)}")
print("  ✓ Filtro poligonal")
print("  ✓ Reprojeção EPSG:5880")
print("  ✓ CLIP pelas fronteiras municipais")
print("  ✓ Dissolve por COD_MUNICIPIO")
print("  ✓ make_valid() final")
print("\n✓ Preparação de susceptibilidade ALTA concluída!")
