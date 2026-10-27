# Costruisce Resources/Rules/ateco.json: TUTTI i codici ATECO, dai file ufficiali ISTAT.
#  - ATECO 2007 aggiornamento 2022 (quello che decide il coefficiente del forfettario nel 2026)
#  - ATECO 2025 (quello sui certificati dal 1° aprile 2025), con i codici 2007/2022 corrispondenti
# I file si scaricano con il workflow «Scarica i codici ATECO dall'ISTAT» nel ramo dati-istat.
# Uso:
#   git fetch origin dati-istat
#   mkdir -p /tmp/istat && for f in Struttura-ATECO-2007-aggiornamento-2022.xlsx StrutturaATECO-2025-IT-EN-1.xlsx \
#     Aggiornamento-2026-Tavola-raccordo-bidirezionale-ATECO-2025-ATECO-2022-italiano.xlsx; do
#     git show "origin/dati-istat:$f" > "/tmp/istat/$f"; done
#   python3 Tools/build_ateco.py /tmp/istat          (richiede openpyxl)
import json
import re
import sys
from pathlib import Path

import openpyxl

cartella = Path(sys.argv[1] if len(sys.argv) > 1 else "/tmp/istat")
SOTTOCATEGORIA = re.compile(r"^\d{2}\.\d{2}\.\d{2}$")


def righe(file, foglio=None):
    wb = openpyxl.load_workbook(cartella / file, read_only=True)
    ws = wb[foglio] if foglio else wb.worksheets[0]
    return list(ws.iter_rows(values_only=True))


def pulisci(t):
    return re.sub(r"\s+", " ", str(t or "")).strip()


# ATECO 2007 aggiornamento 2022: codice, titolo
a2007 = []
for r in righe("Struttura-ATECO-2007-aggiornamento-2022.xlsx")[1:]:
    codice = pulisci(r[0])
    if SOTTOCATEGORIA.match(codice):
        a2007.append([codice, pulisci(r[1])])

# ATECO 2025: codice, titolo
titoli2025 = {}
for r in righe("StrutturaATECO-2025-IT-EN-1.xlsx", "ATECO 2025 Struttura")[1:]:
    codice = pulisci(r[1])
    if SOTTOCATEGORIA.match(codice):
        titoli2025[codice] = pulisci(r[2])

# Raccordo 2025 → 2022 (= ATECO 2007 aggiornamento 2022), solo tra sottocategorie
raccordo = {}
for r in righe("Aggiornamento-2026-Tavola-raccordo-bidirezionale-ATECO-2025-ATECO-2022-italiano.xlsx", "ATECO 2025 vs ATECO 2022")[1:]:
    c25, c22 = pulisci(r[1]), pulisci(r[5])
    if SOTTOCATEGORIA.match(c25) and SOTTOCATEGORIA.match(c22):
        raccordo.setdefault(c25, [])
        if c22 not in raccordo[c25]:
            raccordo[c25].append(c22)

a2025 = [[c, t, raccordo.get(c, [])] for c, t in titoli2025.items()]

uscita = {
    "fonte": "ISTAT – Struttura ATECO 2007 aggiornamento 2022, Struttura ATECO 2025, "
             "Tavola di raccordo bidirezionale ATECO 2025 – ATECO 2022 (aggiornamento 2026)",
    "url": "https://www.istat.it/classificazione/documenti-ateco/",
    "a2007": a2007,
    "a2025": a2025,
}
dest = Path("Resources/Rules/ateco.json")
dest.write_text(json.dumps(uscita, ensure_ascii=False, separators=(",", ":")))
senza = sum(1 for x in a2025 if not x[2])
print(f"ATECO 2007: {len(a2007)} codici · ATECO 2025: {len(a2025)} codici ({senza} senza raccordo) · {dest.stat().st_size // 1024} KB")
