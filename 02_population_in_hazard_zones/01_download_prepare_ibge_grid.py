# ============================================================
# 01_download_e_preparar_dados.py
#
# Baixa e prepara todos os dados base para o pipeline 02_population_in_hazard_zones:
#   - Grade estatística 2010 e 2022 (tiles por ID)
#   - Malha municipal Brasil 2022
#   - Aglomerados Subnormais (AGSN) 2019
#   - DTB 2010 (lookup código ↔ nome de município)
#
# Prepara e salva em data/processed_data/02_hazard_zones/:
#   - grade_2010_BR.gpkg + grade_2010_pontos_BR.parquet
#   - grade_2022_BR.gpkg + grade_2022_pontos_BR.parquet
#   - AGSN_preparada.gpkg  (com cod_mun_7dig, CRS 5880, make_valid)
#
# Execute na raiz do projeto: python 02_population_in_hazard_zones/01_download_prepare_ibge_grid.py
#
# Aviso de memória: a combinação dos tiles das grades pode exigir
# 8–16 GB de RAM. Certifique-se de ter espaço suficiente.
#
# Tempo estimado total: 1–3 horas (dependendo da conexão e CPU).
# ============================================================

import requests
import zipfile
import geopandas as gpd
import pandas as pd
from pathlib import Path
import warnings
warnings.filterwarnings('ignore')

# ------------------------------------------------------------
# Configurações
# ------------------------------------------------------------
BASE_DIR    = Path("data/raw_data/02_hazard_zones")
OUT_DIR     = Path("data/processed_data/02_hazard_zones")
CRS_PROJ    = "EPSG:5880"

OUT_DIR.mkdir(parents=True, exist_ok=True)
for d in ["grade_2010", "grade_2022", "malha_municipal", "aglomerados_subnormais"]:
    (BASE_DIR / d).mkdir(parents=True, exist_ok=True)

# ------------------------------------------------------------
# Utilitários
# ------------------------------------------------------------
def download_zip(url, destino, timeout=300):
    """Baixa um ZIP se ainda não existir; valida antes de retornar."""
    if destino.exists():
        return True
    print(f"    Baixando {destino.name} …")
    try:
        r = requests.get(url, stream=True, timeout=timeout)
        r.raise_for_status()
        with open(destino, "wb") as f:
            for chunk in r.iter_content(65536):
                if chunk:
                    f.write(chunk)
        if not zipfile.is_zipfile(destino):
            destino.unlink()
            print(f"    ⚠ {destino.name} não é ZIP válido – pulando")
            return False
        return True
    except Exception as e:
        print(f"    ⚠ Falhou ({destino.name}): {e}")
        if destino.exists():
            destino.unlink()
        return False


def unzip_safe(zip_path, pasta):
    """Descompacta ignorando erros de arquivos individuais."""
    try:
        with zipfile.ZipFile(zip_path, "r") as z:
            z.extractall(pasta)
    except Exception as e:
        print(f"    ⚠ Erro ao descompactar {zip_path.name}: {e}")



# ============================================================
# PARTE A – DOWNLOADS
# ============================================================
print("\n" + "="*60)
print("PARTE A – DOWNLOADS")
print("="*60)

# ── A1: Grade estatística 2010 ────────────────────────────
print("\nA1) Grade estatística – Censo 2010")
base_2010 = (
    "https://geoftp.ibge.gov.br/recortes_para_fins_estatisticos/"
    "grade_estatistica/censo_2010/"
)
# 2026-08-24: range estendido de (1, 57) para (1, 100). O range antigo parava
# em grade_id56.zip, mas o diretório real do IBGE tem tiles até grade_id93.zip
# (confirmado via listagem direta do servidor) -- os tiles com ID > 56 nunca
# eram sequer tentados (não é um 404 esperado, era um gap real no range).
# Isso deixava de baixar ~28 dos 56 tiles reais, concentrados nas regiões
# Nordeste e parte do Norte -- descoberto ao investigar municípios ausentes
# em grade_2022_BR_com_suscept_alta_agsn.gpkg (ver MIGRATION_PLAN.md).
# 404s para IDs realmente inexistentes continuam sendo ignorados normalmente
# pela lógica já existente em download_zip().
ids = [f"{i:02d}" for i in range(1, 100)]
for i in ids:
    url = f"{base_2010}grade_id{i}.zip"
    zip_path = BASE_DIR / "grade_2010" / f"grade_id{i}.zip"
    ok = download_zip(url, zip_path)
    if ok:
        unzip_safe(zip_path, BASE_DIR / "grade_2010")

# ── A2: Grade estatística 2022 ────────────────────────────
print("\nA2) Grade estatística – Censo 2022")
base_2022 = (
    "https://geoftp.ibge.gov.br/recortes_para_fins_estatisticos/"
    "grade_estatistica/censo_2022/grade_estatistica/"
)
for i in ids:
    url = f"{base_2022}grade_id{i}.zip"
    zip_path = BASE_DIR / "grade_2022" / f"grade_id{i}.zip"
    ok = download_zip(url, zip_path)
    if ok:
        unzip_safe(zip_path, BASE_DIR / "grade_2022")

# ── A3: Malha municipal 2022 ──────────────────────────────
print("\nA3) Malha municipal Brasil 2022")
url_malha = (
    "https://geoftp.ibge.gov.br/organizacao_do_territorio/"
    "malhas_territoriais/malhas_municipais/municipio_2022/Brasil/BR/"
    "BR_Municipios_2022.zip"
)
malha_zip = BASE_DIR / "malha_municipal" / "BR_Municipios_2022.zip"
ok = download_zip(url_malha, malha_zip)
if ok:
    unzip_safe(malha_zip, BASE_DIR / "malha_municipal")

# ── A4: Favelas e Comunidades Urbanas 2022 (FCU) ──────────
# Substitui AGSN 2019 — dados do Censo Demográfico 2022.
print("\nA4) Favelas e Comunidades Urbanas – Censo 2022 (FCU)")
url_agsn = (
    "https://ftp.ibge.gov.br/Censos/Censo_Demografico_2022/"
    "Favelas_e_comunidades_urbanas_Resultados_do_universo/"
    "arquivos_vetoriais/poligonos_FCUs_shp.zip"
)
agsn_zip = BASE_DIR / "aglomerados_subnormais" / "poligonos_FCUs_shp.zip"
ok = download_zip(url_agsn, agsn_zip)
if ok:
    unzip_safe(agsn_zip, BASE_DIR / "aglomerados_subnormais" / "FCUs_2022")

# DTB não é necessário: o FCU 2022 já contém a coluna cd_mun.


# ============================================================
# PARTE B – PREPARAR MALHA MUNICIPAL
# ============================================================
print("\n" + "="*60)
print("PARTE B – PREPARAR MALHA MUNICIPAL")
print("="*60)

malha_shp = BASE_DIR / "malha_municipal" / "BR_Municipios_2022.shp"
if not malha_shp.exists():
    raise FileNotFoundError(
        f"Malha municipal não encontrada: {malha_shp}\n"
        "Verifique se o download A3 concluiu corretamente."
    )

print(f"  Lendo {malha_shp.name} …")
malha = gpd.read_file(malha_shp)

col_cod = next((c for c in ['CD_MUN', 'CD_GEOCMU', 'GEOCODIGO', 'cod_mun']
                if c in malha.columns), None)
if col_cod is None:
    raise ValueError(f"Coluna de código municipal não encontrada. Colunas: {malha.columns.tolist()}")

malha = malha.rename(columns={col_cod: 'COD_MUNICIPIO'})
malha['COD_MUNICIPIO'] = malha['COD_MUNICIPIO'].astype(str).str[:7]
malha = malha.to_crs(CRS_PROJ)
malha['geometry'] = malha.geometry.make_valid()
malha['geometry'] = malha.geometry.buffer(0)
malha['geometry'] = malha.geometry.make_valid()

print(f"  Municípios: {len(malha)}")
print(f"  CRS: {malha.crs}")

# Salva versão preparada (útil para outros scripts)
out_malha = OUT_DIR / "malha_municipal_5880.gpkg"
malha.to_file(out_malha, driver="GPKG")
print(f"  ✓ Salvo: {out_malha}")


# ============================================================
# PARTE C – PREPARAR FCU (Favelas e Comunidades Urbanas 2022)
# ============================================================
print("\n" + "="*60)
print("PARTE C – PREPARAR FCU")
print("="*60)

agsn_dir = BASE_DIR / "aglomerados_subnormais"
agsn_shp_candidates = list(agsn_dir.rglob("*.shp"))
if not agsn_shp_candidates:
    raise FileNotFoundError(
        f"Shapefile FCU não encontrado em {agsn_dir}\n"
        "Verifique se o download A4 concluiu corretamente."
    )
agsn_shp = agsn_shp_candidates[0]
print(f"  Lendo {agsn_shp} …")

agsn = gpd.read_file(agsn_shp)
print(f"  Polígonos FCU: {len(agsn):,}")

# O FCU 2022 tem coluna cd_mun com o código IBGE do município (7 dígitos)
if 'cd_mun' not in agsn.columns:
    raise ValueError(
        f"Coluna 'cd_mun' não encontrada no FCU. "
        f"Colunas disponíveis: {agsn.columns.tolist()}"
    )

agsn = agsn.to_crs(CRS_PROJ)
agsn['geometry'] = agsn.geometry.make_valid()
agsn['geometry'] = agsn.geometry.buffer(0)
agsn['geometry'] = agsn.geometry.make_valid()
agsn = agsn[~agsn.geometry.is_empty & agsn.geometry.is_valid].copy()

# Código municipal já disponível diretamente — sem necessidade de lookup
agsn['cod_mun_7dig'] = agsn['cd_mun'].astype(str).str[:7].str.zfill(7)
print(f"  Municípios únicos: {agsn['cod_mun_7dig'].nunique():,}")

out_agsn = OUT_DIR / "AGSN_preparada.gpkg"
agsn.to_file(out_agsn, driver="GPKG")
print(f"  ✓ Salvo: {out_agsn} ({len(agsn):,} polígonos)")


# ============================================================
# PARTE D – PREPARAR GRADES ESTATÍSTICAS
# ============================================================
# Combina todos os tiles .shp, reprojecta para EPSG:5880,
# cria id_celula único, salva grade + parquet de centroides.
#
# Memória necessária: ~8–16 GB RAM para o Brasil completo.
# ============================================================
print("\n" + "="*60)
print("PARTE D – PREPARAR GRADES ESTATÍSTICAS")
print("="*60)

def preparar_grade(ano, grade_dir, out_gpkg, out_parquet, col_pop_candidatas):
    print(f"\n  Grade {ano}:")
    shp_files = sorted(grade_dir.rglob("*.shp"))
    if not shp_files:
        raise FileNotFoundError(
            f"Nenhum .shp encontrado em {grade_dir}\n"
            f"Verifique se o download das grades {ano} concluiu."
        )
    print(f"    Tiles encontrados: {len(shp_files)}")

    gdfs = []
    for shp in shp_files:
        try:
            g = gpd.read_file(shp)
            if len(g) > 0:
                gdfs.append(g)
        except Exception as e:
            print(f"    ⚠ Erro ao ler {shp.name}: {e}")

    if not gdfs:
        raise RuntimeError(f"Nenhum tile pôde ser lido para grade {ano}.")

    print(f"    Concatenando {len(gdfs)} tiles …")
    grade = pd.concat(gdfs, ignore_index=True)
    grade = gpd.GeoDataFrame(grade, crs=gdfs[0].crs)
    print(f"    Células totais: {len(grade):,}")

    # Reprojetar
    if str(grade.crs) != CRS_PROJ:
        print(f"    Reprojetando {grade.crs} → {CRS_PROJ} …")
        grade = grade.to_crs(CRS_PROJ)

    # Detectar coluna população
    col_pop = next((c for c in col_pop_candidatas if c in grade.columns), None)
    if col_pop is None:
        raise ValueError(f"Coluna população não encontrada. Colunas: {grade.columns.tolist()}")
    print(f"    Coluna população: {col_pop!r}")

    # Criar id_celula único
    if 'id_celula' not in grade.columns:
        grade['id_celula'] = range(len(grade))
    grade['id_celula'] = grade['id_celula'].astype(str)

    # Validar geometrias
    print("    Validando geometrias …")
    grade['geometry'] = grade.geometry.make_valid()
    grade['geometry'] = grade.geometry.buffer(0)
    grade['geometry'] = grade.geometry.make_valid()
    grade = grade[~grade.geometry.is_empty & grade.geometry.is_valid].copy()
    print(f"    Células válidas: {len(grade):,}")

    # Salvar grade
    print(f"    Salvando {out_gpkg.name} …")
    grade.to_file(out_gpkg, driver="GPKG")
    print(f"    ✓ {out_gpkg.stat().st_size / 1024**3:.2f} GB")

    # Criar e salvar centroides
    print(f"    Criando centroides → {out_parquet.name} …")
    pontos = grade[['id_celula', col_pop, 'geometry']].copy()
    pontos['geometry'] = pontos.geometry.representative_point()
    pontos = pontos.rename(columns={col_pop: 'populacao'})
    pontos.to_parquet(out_parquet)
    print(f"    ✓ {out_parquet.stat().st_size / 1024**2:.1f} MB  ({len(pontos):,} pontos)")

    return grade, pontos


grade2010, pontos2010 = preparar_grade(
    ano=2010,
    grade_dir=BASE_DIR / "grade_2010",
    out_gpkg=OUT_DIR / "grade_2010_BR.gpkg",
    out_parquet=OUT_DIR / "grade_2010_pontos_BR.parquet",
    col_pop_candidatas=['pop_2010', 'POP', 'Pop', 'pop']
)

grade2022, pontos2022 = preparar_grade(
    ano=2022,
    grade_dir=BASE_DIR / "grade_2022",
    out_gpkg=OUT_DIR / "grade_2022_BR.gpkg",
    out_parquet=OUT_DIR / "grade_2022_pontos_BR.parquet",
    col_pop_candidatas=['pop_2022', 'TOTAL', 'Total', 'total', 'POP', 'Pop', 'pop']
)


# ============================================================
# PARTE E – PREPARAR RISCO CPRM (risco.gdb)
# ============================================================
# Baixa risco.gdb.zip, lê todas as layers, filtra por grau_risco
# ("Alto" e "Muito alto"), reprojecta para EPSG:5880, aplica
# make_valid e salva como risco_preparado.gpkg.
# ============================================================
print("\n" + "="*60)
print("PARTE E – PREPARAR RISCO CPRM (risco.gdb)")
print("="*60)

import io
import shutil

def listar_layers_gdb(gdb_path):
    """Lista layers de um GDB sem depender de fiona diretamente."""
    gdb_str = str(gdb_path)
    # 1) pyogrio (engine padrão do geopandas moderno)
    try:
        import pyogrio
        return [r[0] for r in pyogrio.list_layers(gdb_str)]
    except Exception:
        pass
    # 2) fiona (engine legado)
    try:
        import fiona
        return fiona.listlayers(gdb_str)
    except Exception:
        pass
    # 3) gpd.list_layers (geopandas >= 0.14)
    try:
        layers_df = gpd.list_layers(gdb_str)
        return layers_df['name'].tolist()
    except Exception:
        pass
    # 4) Sem listar: retorna None → lê direto sem especificar layer
    return None

URL_RISCO = "https://geoportal.sgb.gov.br/downloads/risco.gdb.zip"
RISCO_DIR = BASE_DIR / "risco"
RISCO_DIR.mkdir(parents=True, exist_ok=True)
out_risco = OUT_DIR / "risco_preparado.gpkg"

if out_risco.exists():
    print(f"\n  Já existe: {out_risco} — pulando download.")
else:
    # ── E1: Download ─────────────────────────────────────────
    risco_zip = RISCO_DIR / "risco.gdb.zip"
    ok = download_zip(URL_RISCO, risco_zip, timeout=600)

    if not ok:
        print("  ✗ Download do risco.gdb falhou. Pulando PARTE E.")
    else:
        # ── E2: Extrair ──────────────────────────────────────
        print(f"  Extraindo {risco_zip.name} …")
        unzip_safe(risco_zip, RISCO_DIR)

        # Localizar a pasta .gdb extraída
        gdb_candidates = list(RISCO_DIR.rglob("*.gdb"))
        if not gdb_candidates:
            # conteúdo pode ter sido extraído sem subpasta .gdb
            gdbtable_files = list(RISCO_DIR.rglob("*.gdbtable"))
            if gdbtable_files:
                risco_gdb_path = RISCO_DIR / "risco.gdb"
                risco_gdb_path.mkdir(exist_ok=True)
                for f in gdbtable_files:
                    shutil.move(str(f), str(risco_gdb_path / f.name))
                print(f"  Conteúdo movido para {risco_gdb_path}")
            else:
                print("  ✗ Pasta .gdb não encontrada após extração.")
                risco_gdb_path = None
        else:
            risco_gdb_path = gdb_candidates[0]
            print(f"  Encontrado: {risco_gdb_path}")

        if risco_gdb_path and risco_gdb_path.exists():
            # ── E3: Ler layers ───────────────────────────────
            layers = listar_layers_gdb(risco_gdb_path)
            print(f"  Layers disponíveis: {layers}")

            gdfs_risco = []
            if layers is None:
                # Não foi possível listar: lê direto (geopandas escolhe a layer)
                try:
                    gdf = gpd.read_file(str(risco_gdb_path))
                    if len(gdf) > 0:
                        gdfs_risco.append(gdf)
                        print(f"    (layer única): {len(gdf):,} registros")
                except Exception as e:
                    print(f"    ⚠ Erro ao ler GDB: {e}")
            else:
                for layer in layers:
                    try:
                        gdf = gpd.read_file(str(risco_gdb_path), layer=layer)
                        if len(gdf) > 0:
                            gdf['layer_origem'] = layer
                            gdfs_risco.append(gdf)
                            print(f"    {layer}: {len(gdf):,} registros")
                    except Exception as e:
                        print(f"    ⚠ Erro ao ler layer {layer}: {e}")

            if gdfs_risco:
                risco = gpd.GeoDataFrame(
                    pd.concat(gdfs_risco, ignore_index=True)
                )
                print(f"\n  Total de polígonos: {len(risco):,}")
                print(f"  Colunas: {risco.columns.tolist()}")

                # ── E4: Detectar coluna município ────────────
                col_mun_risco = next(
                    (c for c in ['cd_geocmu', 'cd_geocmun', 'CD_GEOCMU',
                                 'CD_GEOCMUN', 'CD_MUN', 'cod_mun']
                     if c in risco.columns),
                    None
                )
                if col_mun_risco is None:
                    print("  ✗ Coluna de município não encontrada. Pulando.")
                else:
                    print(f"  Coluna município: {col_mun_risco!r}")

                    # ── E5: Detectar coluna grau_risco ───────
                    col_grau = next(
                        (c for c in ['grau_risco', 'GRAU_RISCO', 'grau', 'GRAU']
                         if c in risco.columns),
                        None
                    )
                    if col_grau is None:
                        print("  ✗ Coluna grau_risco não encontrada. Pulando.")
                    else:
                        print(f"  Coluna grau: {col_grau!r}")
                        print(f"  Valores únicos: {risco[col_grau].unique().tolist()}")

                        # Filtrar para Alto e Muito alto
                        risco = risco[
                            risco[col_grau].isin(['Alto', 'Muito alto'])
                        ].copy()
                        print(f"  Polígonos Alto + Muito alto: {len(risco):,}")

                        # ── E6: Normalizar + reprojetar ──────
                        risco = risco.rename(columns={
                            col_mun_risco: 'cd_geocmun',
                            col_grau:      'grau_risco',
                        })
                        risco['cd_geocmun'] = (
                            risco['cd_geocmun']
                            .astype(str)
                            .str.replace(r'\D', '', regex=True)
                            .str[:7]
                            .str.zfill(7)
                        )

                        if risco.crs is None:
                            risco = risco.set_crs("EPSG:4674")
                        risco = risco.to_crs(CRS_PROJ)

                        # make_valid
                        if 'fid' in risco.columns:
                            risco = risco.rename(columns={'fid': 'fid_orig'})
                        risco['geometry'] = risco.geometry.make_valid()
                        risco['geometry'] = risco.geometry.buffer(0)
                        risco['geometry'] = risco.geometry.make_valid()
                        risco = risco[
                            ~risco.geometry.is_empty & risco.geometry.is_valid
                        ].copy()

                        print(f"\n  Municípios com risco: "
                              f"{risco['cd_geocmun'].nunique():,}")
                        print(f"  Por grau:")
                        print(risco['grau_risco'].value_counts().to_string())

                        # ── E7: Salvar ───────────────────────
                        risco.to_file(out_risco, driver="GPKG")
                        print(f"\n  ✓ Salvo: {out_risco}  "
                              f"({out_risco.stat().st_size/1024**2:.1f} MB)")
            else:
                print("  ✗ Nenhum dado encontrado nas layers do risco.gdb")


# ============================================================
# RESUMO FINAL
# ============================================================
print("\n" + "="*60)
print("RESUMO FINAL")
print("="*60)
print(f"\nMalha municipal:    {out_malha}")
print(f"AGSN preparada:     {out_agsn}")
print(f"Grade 2010:         {OUT_DIR / 'grade_2010_BR.gpkg'}")
print(f"Grade 2010 pontos:  {OUT_DIR / 'grade_2010_pontos_BR.parquet'}")
print(f"Grade 2022:         {OUT_DIR / 'grade_2022_BR.gpkg'}")
print(f"Grade 2022 pontos:  {OUT_DIR / 'grade_2022_pontos_BR.parquet'}")
print(f"Risco preparado:    {out_risco}")
print("\nPróximos passos:")
print("  python 02_population_in_hazard_zones/02_prepare_high_susceptibility_layer.py")
print("  python 02_population_in_hazard_zones/03_cross_grid_high_susceptibility.py")
print("  python 02_population_in_hazard_zones/04_cross_grid_cprm_risk.py")
print("\n✓ Download e preparação concluídos!")
