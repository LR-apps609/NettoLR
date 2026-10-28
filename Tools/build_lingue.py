#!/usr/bin/env python3
"""Costruisce Resources/Localizable.xcstrings (italiano → inglese).

Le frasi vengono da tre parti:
  1. l'elenco estratto dal compilatore (ramo «lingue», en.xliff): testi delle viste e String(localized:);
  2. i testi semplici scritti nel codice e mostrati con `.tradotto` (cercati qui nei sorgenti);
  3. i nomi dei gruppi ATECO nelle regole dell'anno.
Le traduzioni stanno in Resources/Lingue/en.json ({"testo italiano": "English text"}).

Uso: python3 Tools/build_lingue.py [percorso/en.xliff]
Stampa le frasi ancora senza traduzione.
"""
import json
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

RADICE = Path(__file__).resolve().parent.parent
TRADUZIONI = RADICE / "Resources/Lingue/en.json"
CATALOGO = RADICE / "Resources/Localizable.xcstrings"


def dal_compilatore(percorso: Path) -> set[str]:
    ns = {"x": "urn:oasis:names:tc:xliff:document:1.2"}
    albero = ET.parse(percorso)
    chiavi = set()
    for f in albero.getroot().findall("x:file", ns):
        if not f.get("original", "").endswith("Localizable.xcstrings"):
            continue
        for u in f.iter("{urn:oasis:names:tc:xliff:document:1.2}trans-unit"):
            chiavi.add(u.get("id"))
    return chiavi


LETTERALE = re.compile(r'"((?:[^"\\\n]|\\.)*)"')


def dai_sorgenti() -> set[str]:
    """Le frasi tra virgolette senza interpolazione, che sembrano testo per le persone."""
    chiavi = set()
    for f in sorted((RADICE / "Sources").glob("*.swift")):
        for riga in f.read_text().splitlines():
            if riga.strip().startswith("//"):
                continue
            codice = riga
            for m in LETTERALE.finditer(codice):
                t = m.group(1)
                if "\\(" in t or not re.search(r"[A-Za-zÀ-ú]", t):
                    continue
                prima = codice[:m.start()]
                if re.search(r"(systemName:|accessibilityIdentifier\(|forResource:|withExtension:|subdirectory:|identifier:|forKey:|URL\(string:|hasPrefix\(|contains\(|arguments)\s*$", prima):
                    continue
                if re.fullmatch(r"[\w.\-/]+", t) and " " not in t and not t[:1].isupper():
                    continue  # chiavi, nomi di file, codici
                chiavi.add(t.replace('\\"', '"').replace("\\n", "\n"))
    return chiavi


def dalle_regole() -> set[str]:
    chiavi = set()
    for f in (RADICE / "Resources/Rules").glob("regole-*.json"):
        d = json.loads(f.read_text())
        for c in d["forfettario"]["coefficienti"]["valore"]:
            chiavi.add(c["nome"])
    return chiavi


def principale():
    traduzioni = json.loads(TRADUZIONI.read_text()) if TRADUZIONI.exists() else {}
    chiavi = dai_sorgenti() | dalle_regole()
    if len(sys.argv) > 1:
        chiavi |= dal_compilatore(Path(sys.argv[1]))
    stringhe = {}
    mancanti = []
    for k in sorted(chiavi):
        en = traduzioni.get(k)
        if en is None:
            mancanti.append(k)
            continue
        stringhe[k] = {"extractionState": "manual",
                       "localizations": {"en": {"stringUnit": {"state": "translated", "value": en}}}}
    CATALOGO.write_text(json.dumps({"sourceLanguage": "it", "strings": stringhe, "version": "1.0"},
                                   ensure_ascii=False, indent=2, sort_keys=True) + "\n")
    print(f"Catalogo: {len(stringhe)} frasi tradotte, {len(mancanti)} senza traduzione")
    for k in mancanti:
        print("  ·", json.dumps(k, ensure_ascii=False))


if __name__ == "__main__":
    principale()
