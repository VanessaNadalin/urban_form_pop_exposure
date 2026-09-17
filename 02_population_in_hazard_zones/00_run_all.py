"""
00_run_all.py
-------------
Executa o pipeline 02_population_in_hazard_zones em sequência.

Execute na raiz do projeto:
    python 02_population_in_hazard_zones/00_run_all.py

Pré-condições:
    - Arquivos em data/raw_data/02_hazard_zones/:
        suscet_massa_br.gpkg
        suscet_inundacao_br.gpkg
    - risco.gdb é baixado automaticamente pelo script 01

Estimated runtime (high susceptibility only): script 01 ~1-3h; script 03
(full crossing) ~18-24h -- see PIPELINE.md. Roughly 20-28h for the stage.
"""

import subprocess
import sys
import time
from pathlib import Path

SCRIPTS = [
    "02_population_in_hazard_zones/01_download_prepare_ibge_grid.py",
    "02_population_in_hazard_zones/02_prepare_high_susceptibility_layer.py",
    "02_population_in_hazard_zones/03_cross_grid_high_susceptibility.py",
]

def fmt_tempo(segundos):
    h, r = divmod(int(segundos), 3600)
    m, s = divmod(r, 60)
    if h:
        return f"{h}h{m:02d}m{s:02d}s"
    if m:
        return f"{m}m{s:02d}s"
    return f"{s}s"

print("=" * 60)
print("PIPELINE RISK_EXPOSURE")
print("=" * 60)

inicio_total = time.time()

for i, script in enumerate(SCRIPTS, 1):
    print(f"\n[{i}/{len(SCRIPTS)}] {script}")
    print("-" * 60)

    if not Path(script).exists():
        print(f"  ✗ Arquivo não encontrado: {script}")
        sys.exit(1)

    inicio = time.time()
    resultado = subprocess.run([sys.executable, script])
    duracao = time.time() - inicio

    if resultado.returncode != 0:
        print(f"\n{'='*60}")
        print(f"  ✗ ERRO em {script} (código {resultado.returncode})")
        print(f"  Pipeline interrompido após {fmt_tempo(time.time() - inicio_total)}")
        print(f"{'='*60}")
        sys.exit(resultado.returncode)

    print(f"\n  ✓ Concluído em {fmt_tempo(duracao)}")

print(f"\n{'='*60}")
print(f"PIPELINE CONCLUÍDO em {fmt_tempo(time.time() - inicio_total)}")
print("="*60)
