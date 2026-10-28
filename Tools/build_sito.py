#!/usr/bin/env python3
"""Costruisce il sito di NettoLR in sito/: la pagina principale e una pagina per ogni lavoro.

I numeri vengono dalle regole dell'anno (Resources/Rules/regole-AAAA.json), i lavori dall'elenco
di Sources/Ateco.swift: il sito dice le stesse cose dell'app. Uso: python3 Tools/build_sito.py [anno]
"""
import html
import json
import re
import sys
from pathlib import Path

RADICE = Path(__file__).resolve().parent.parent
ANNO = int(sys.argv[1]) if len(sys.argv) > 1 else 2026
ESEMPIO = 30_000  # incassi dell'esempio su ogni pagina

regole = json.loads((RADICE / f"Resources/Rules/regole-{ANNO}.json").read_text())
swift = (RADICE / "Sources/Ateco.swift").read_text()

LAVORI = [
    {"codice": c, "descrizione": d, "sinonimi": re.findall(r'"([^"]+)"', s), "gestione": g}
    for c, d, s, g in re.findall(
        r'Attivita\(ateco2007: "([^"]+)", descrizione: "([^"]+)", sinonimi: \[([^\]]*)\], gestioneTipica: \.(\w+)\)', swift)
]
assert len(LAVORI) > 30, "Elenco dei lavori non trovato in Ateco.swift"

COEFF = {c["id"]: c for c in regole["forfettario"]["coefficienti"]["valore"]}


def gruppo(codice: str) -> dict:
    """Stessa logica di Ateco.gruppo(ateco2007:) nell'app."""
    c = re.sub(r"\D", "", codice)
    n = lambda k: int(c[:k]) if len(c) >= k else -1
    div, g3, c4 = n(2), n(3), n(4)
    if div in (10, 11): return COEFF["alimentari"]
    if c4 == 4781: return COEFF["ambulante-alimentari"]
    if 4782 <= c4 <= 4789: return COEFF["ambulante-altri"]
    if g3 == 461: return COEFF["intermediari"]
    if div == 45 or 462 <= g3 <= 469 or 471 <= g3 <= 477 or g3 == 479: return COEFF["commercio"]
    if 41 <= div <= 43 or div == 68: return COEFF["costruzioni"]
    if div in (55, 56): return COEFF["alloggio"]
    if 64 <= div <= 66 or 69 <= div <= 75 or 85 <= div <= 88: return COEFF["professionali"]
    return COEFF["altre"]


def contributi(gestione: str, reddito: float) -> float | None:
    """Stessa logica di Calcolo.contributi nell'app (senza riduzione del 35%)."""
    if gestione == "separata":
        gs = regole["gestioneSeparata"]
        return round(min(reddito, gs["massimale"]["valore"]) * gs["aliquota"]["valore"], 2)
    if gestione in ("artigiani", "commercianti"):
        ac = regole["artigianiCommercianti"]
        tab = ac[gestione]
        base = min(reddito, ac["massimale"]["valore"])
        minimale, soglia = ac["minimale"]["valore"], ac["sogliaAliquotaMaggiorata"]["valore"]
        ecc = max(0, min(base, soglia) - minimale) * tab["aliquota"]["valore"] + max(0, base - soglia) * tab["aliquotaMaggiorata"]["valore"]
        return round(tab["fissoAnnuo"]["valore"] + ecc, 2)
    return None  # cassa professionale: dipende dalla cassa


def euro(x: float) -> str:
    return f"{x:,.0f}".replace(",", ".") + " €"


def pct(x: float) -> str:
    v = x * 100
    return (f"{v:.0f}" if abs(v - round(v)) < 0.001 else f"{v:.2f}".replace(".", ",")) + "%"


MESI = ["gennaio", "febbraio", "marzo", "aprile", "maggio", "giugno", "luglio", "agosto", "settembre", "ottobre", "novembre", "dicembre"]


def data(iso: str) -> str:
    a, m, g = iso.split("-")
    return f"{int(g)} {MESI[int(m) - 1]} {a}"


def slug(testo: str) -> str:
    t = testo.lower()
    for a, b in {"à": "a", "è": "e", "é": "e", "ì": "i", "ò": "o", "ù": "u", "&": "e"}.items():
        t = t.replace(a, b)
    return re.sub(r"[^a-z0-9]+", "-", t).strip("-")


def fonte(chiave: str) -> str:
    f = regole["fonti"][chiave]
    stato = "" if f["stato"] == "verificato" else " (da verificare)"
    return f'<a href="{html.escape(f["url"])}" rel="noopener">{html.escape(f["titolo"])}</a>{stato}'


NOMI_PENSIONE = {
    "separata": "la Gestione separata, per chi non ha una cassa del suo albo",
    "artigiani": "la gestione Artigiani (una quota fissa, più una parte sopra il minimo)",
    "commercianti": "la gestione Commercianti (una quota fissa, più una parte sopra il minimo)",
    "cassa": "la cassa del tuo albo",
}

MARCA = """<svg class="marca" viewBox="0 0 60 60" aria-hidden="true"><defs><mask id="d"><rect width="60" height="60" fill="#fff"/>
""" + "".join(f'<circle cx="{x}" cy="{y}" r="3" fill="#000"/>' for i in range(7) for x, y in
               [(i * 10, 0), (i * 10, 60), (0, i * 10), (60, i * 10)]) + """</mask></defs>
<rect width="60" height="60" fill="var(--marca)" mask="url(#d)"/><rect x="9" y="9" width="42" height="42" rx="3" fill="none" stroke="var(--notte)" stroke-width="2" stroke-dasharray="3 3"/>
<text x="30" y="41" text-anchor="middle" font-size="30" font-weight="900" fill="var(--notte)" font-family="ui-rounded, system-ui">N</text></svg>"""

CSS = """:root{--fondo:#F7F5F6;--card:#fff;--ink:#1E1520;--muted:#685E69;--line:#E4DDE2;--prugna:#A23E6E;--prugna-soft:#F6ECF1;
--pensione:#3A64A0;--tasse:#E07A52;--ottone:#A97E3F;--notte:#21131B;--marca:#D88BB2;color-scheme:light dark}
@media (prefers-color-scheme:dark){:root{--fondo:#141013;--card:#1F181E;--ink:#F0E9EE;--muted:#AA9DA8;--line:#352A33;--prugna:#D88BB2;
--prugna-soft:#3A1C2A;--pensione:#7EA4DD;--tasse:#F2A07B;--ottone:#D6AA62}}
*{box-sizing:border-box}body{margin:0;background:var(--fondo);color:var(--ink);font:17px/1.5 ui-rounded,-apple-system,system-ui,sans-serif}
main{max-width:720px;margin:0 auto;padding:24px 16px 64px}a{color:var(--prugna)}
header{display:flex;align-items:center;gap:12px;margin-bottom:28px}header a{text-decoration:none;color:var(--ink);font-weight:900;font-size:22px}
header b{color:var(--prugna)}.marca{width:44px;height:44px;transform:rotate(-6deg)}
h1{font-size:clamp(30px,7vw,46px);line-height:1.08;margin:0 0 12px;letter-spacing:-.02em}h2{font-size:22px;margin:32px 0 10px}
.scheda{background:var(--card);border-radius:22px;padding:20px;margin:16px 0;border:1px solid var(--line)}
.notte{background:var(--notte);color:#fff;border:0}
@media (prefers-color-scheme:dark){.notte{border:1px solid #4A2D3D;box-shadow:0 0 60px #A23E6E33}}.notte .muted{color:#E9DFE6}
.grande{font-size:clamp(44px,12vw,72px);font-weight:900;line-height:1;margin:8px 0;color:var(--marca)}
.muted{color:var(--muted)}.barra{display:flex;height:18px;border-radius:9px;overflow:hidden;margin:16px 0 10px}
.barra span{display:block}.legenda{display:flex;flex-wrap:wrap;gap:14px;font-size:15px}.legenda i{display:inline-block;width:10px;height:10px;border-radius:5px;margin-right:6px}
.righe{width:100%;border-collapse:collapse}.righe td{padding:8px 0;border-bottom:1px solid var(--line)}.righe td:last-child{text-align:right;font-weight:700}
details{margin-top:12px}summary{cursor:pointer;font-weight:700;color:var(--prugna)}
input{width:100%;font:inherit;padding:14px 16px;border-radius:16px;border:1px solid var(--line);background:var(--card);color:var(--ink)}
ul.lavori{list-style:none;padding:0;display:grid;grid-template-columns:repeat(auto-fill,minmax(200px,1fr));gap:10px}
ul.lavori a{display:block;padding:14px 16px;background:var(--card);border:1px solid var(--line);border-radius:16px;text-decoration:none;color:var(--ink)}
ul.lavori small{display:block;color:var(--muted)}.pillola{display:inline-block;background:var(--prugna-soft);color:var(--prugna);border-radius:99px;padding:3px 12px;font-weight:700;font-size:15px}
footer{margin-top:40px;font-size:14px;color:var(--muted)}"""


def pagina(titolo: str, descrizione: str, corpo: str, profondita: int) -> str:
    su = "../" * profondita
    return f"""<!doctype html>
<html lang="it"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>{html.escape(titolo)}</title><meta name="description" content="{html.escape(descrizione)}">
<link rel="stylesheet" href="{su}stile.css"></head>
<body><main>
<header>{MARCA}<a href="{su}index.html">Netto<b>LR</b></a></header>
{corpo}
<footer><p>È un calcolo, non una consulenza fiscale: per i casi particolari senti un commercialista.</p>
<p>Regole {ANNO} aggiornate al {data(regole["aggiornatoAl"])}. Nessun cookie, nessuna statistica, nessuna pubblicità.</p></footer>
</main></body></html>
"""


def pagina_lavoro(l: dict) -> tuple[str, str]:
    nome = l["sinonimi"][0].capitalize() if l["sinonimi"] else l["descrizione"]
    g = gruppo(l["codice"])
    reddito = round(ESEMPIO * g["valore"], 2)
    inps = contributi(l["gestione"], reddito)
    f = regole["forfettario"]
    corpo = [f'<span class="pillola">{html.escape(l["codice"])}</span>',
             f"<h1>{html.escape(nome)} in partita IVA: quanto ti resta</h1>",
             f'<p class="muted">{html.escape(l["descrizione"])}. Altri nomi: {html.escape(", ".join(l["sinonimi"]))}.</p>']
    if inps is not None:
        imponibile = max(0, reddito - inps)
        tasse = round(imponibile * f["aliquotaOrdinaria"]["valore"], 2)
        tasse5 = round(imponibile * f["aliquotaStartup"]["valore"], 2)
        netto = ESEMPIO - inps - tasse
        w = lambda x: f"{x / ESEMPIO * 100:.1f}%"
        corpo.append(f"""<section class="scheda notte">
<p class="muted">Su {euro(ESEMPIO)} incassati in un anno te ne restano circa</p>
<p class="grande">{euro(netto)}</p>
<div class="barra"><span style="width:{w(netto)};background:var(--marca)"></span><span style="width:{w(inps)};background:#7EA4DD"></span><span style="width:{w(tasse)};background:#F2A07B"></span></div>
<div class="legenda"><span><i style="background:var(--marca)"></i>A te {euro(netto)}</span><span><i style="background:#7EA4DD"></i>Pensione {euro(inps)}</span><span><i style="background:#F2A07B"></i>Tasse {euro(tasse)}</span></div>
<p class="muted">Nei primi cinque anni, se è la tua prima attività, le tasse scendono a {euro(tasse5)}.</p>
</section>""")
        dettaglio = f"""<table class="righe">
<tr><td>Incassato</td><td>{euro(ESEMPIO)}</td></tr>
<tr><td>Reddito: {euro(ESEMPIO)} × {pct(g["valore"])}</td><td>{euro(reddito)}</td></tr>
<tr><td>Pensione</td><td>− {euro(inps)}</td></tr>
<tr><td>Tasse: {pct(f["aliquotaOrdinaria"]["valore"])} di {euro(imponibile)}</td><td>− {euro(tasse)}</td></tr>
<tr><td>Ti resta</td><td>{euro(netto)}</td></tr></table>
<p class="muted">Esempio semplice: pensione pagata nello stesso anno, senza riduzioni e senza marche da bollo.</p>"""
    else:
        corpo.append(f"""<section class="scheda notte"><p class="muted">Di ogni 100 € che incassi, lo Stato considera tuo reddito</p>
<p class="grande">{round(g["valore"] * 100)} €</p><p class="muted">La pensione la paghi alla cassa del tuo albo: la percentuale la scegli in NettoLR.</p></section>""")
        dettaglio = ""
    corpo.append(f"""<section class="scheda"><h2 style="margin-top:0">Le cose da sapere</h2>
<p><b>La tua percentuale è il {pct(g["valore"])}.</b> Nel forfettario non conti le spese: su 100 € incassati, {round(g["valore"] * 100)} € sono il reddito su cui paghi.</p>
<p><b>Pensione:</b> paghi {NOMI_PENSIONE[l["gestione"]]}.</p>
<p><b>Tasse:</b> un'unica tassa del {pct(f["aliquotaOrdinaria"]["valore"])}, o del {pct(f["aliquotaStartup"]["valore"])} per i primi {f["anniStartup"]["valore"]} anni.</p>
<p><b>Fino a {euro(f["sogliaRicavi"]["valore"])}</b> di incassi all'anno puoi restare nel forfettario.</p>
<details><summary>Come lo calcolo?</summary>{dettaglio}
<p class="muted">Fonti: {fonte(f["aliquotaOrdinaria"]["fonte"])}; {fonte(regole["gestioneSeparata"]["aliquota"]["fonte"] if l["gestione"] == "separata" else regole["artigianiCommercianti"]["minimale"]["fonte"])}.</p></details>
</section>
<section class="scheda"><h2 style="margin-top:0">Con i tuoi incassi veri</h2>
<p>NettoLR fa questo conto sui soldi che ti arrivano davvero, ti dice quanto mettere da parte e ti avvisa quando pagare. Tutto resta sul tuo telefono.</p>
<p class="pillola">Presto su App Store</p></section>""")
    titolo = f"{nome} in partita IVA forfettaria: quanto ti resta nel {ANNO} | NettoLR"
    desc = f"{nome} nel regime forfettario {ANNO}: percentuale {pct(g['valore'])}, pensione e tasse spiegate in parole semplici."
    return slug(nome), pagina(titolo, desc, "\n".join(corpo), 1)


def principale():
    out = RADICE / "sito"
    (out / "lavori").mkdir(parents=True, exist_ok=True)
    (out / "stile.css").write_text(CSS + "\n")
    voci = []
    for l in sorted(LAVORI, key=lambda l: l["sinonimi"][0] if l["sinonimi"] else l["descrizione"]):
        s, testo = pagina_lavoro(l)
        (out / "lavori" / f"{s}.html").write_text(testo)
        nome = l["sinonimi"][0].capitalize() if l["sinonimi"] else l["descrizione"]
        cerca = html.escape(" ".join([nome, l["descrizione"], l["codice"], *l["sinonimi"]]).lower())
        voci.append(f'<li data-cerca="{cerca}"><a href="lavori/{s}.html">{html.escape(nome)}<small>{pct(gruppo(l["codice"])["valore"])} · {html.escape(l["codice"])}</small></a></li>')
    corpo = f"""<h1>Quanto ti resta davvero, con la partita IVA</h1>
<p class="muted">Cerca il tuo lavoro: ti dico la percentuale, la pensione e quanto resta su {euro(ESEMPIO)} incassati, con le regole del {ANNO}.</p>
<input id="cerca" type="search" placeholder="Il tuo lavoro: fotografo, idraulico, psicologo…" aria-label="Cerca il tuo lavoro">
<ul class="lavori" id="lavori">
{chr(10).join(voci)}
</ul>
<p class="muted">Non trovi il tuo lavoro? NettoLR contiene tutti i codici ATECO dell'ISTAT.</p>
<script>
const c=document.getElementById('cerca'),v=[...document.querySelectorAll('#lavori li')];
c.addEventListener('input',()=>{{const q=c.value.trim().toLowerCase();v.forEach(li=>li.hidden=q&&!li.dataset.cerca.includes(q))}});
</script>"""
    (out / "index.html").write_text(pagina(f"NettoLR – quanto ti resta con la partita IVA forfettaria ({ANNO})",
                                           "Il netto della partita IVA forfettaria in parole semplici, lavoro per lavoro.", corpo, 0))
    print(f"Sito: {len(voci)} lavori in {out}")


if __name__ == "__main__":
    principale()
