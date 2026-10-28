#!/usr/bin/env python3
"""Costruisce il sito di NettoLR in sito/ (italiano) e sito/en/ (inglese): la pagina principale,
una pagina per ogni lavoro, la privacy e le condizioni d'uso.

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
INGLESE = {c: re.findall(r'"([^"]+)"', v) for c, v in re.findall(r'^\s+"(\d\d\.\d\d\.\d\d)": \[([^\]]*)\],$', swift, re.M)}

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



MESI = {"it": ["gennaio", "febbraio", "marzo", "aprile", "maggio", "giugno", "luglio", "agosto", "settembre", "ottobre", "novembre", "dicembre"],
        "en": ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]}

# I testi del sito nelle due lingue
T = {
    "it": {
        "su_esempio": "Su {e} incassati in un anno te ne restano circa",
        "a_te": "A te", "pensione": "Pensione", "tasse": "Tasse",
        "startup": "Nei primi cinque anni, se è la tua prima attività, le tasse scendono a {e}.",
        "incassato": "Incassato", "reddito": "Reddito", "tasse_di": "Tasse: {p} di {e}", "ti_resta": "Ti resta",
        "esempio": "Esempio semplice: pensione pagata nello stesso anno, senza riduzioni e senza marche da bollo.",
        "cassa_100": "Di ogni 100 € che incassi, lo Stato considera tuo reddito",
        "cassa_nota": "La pensione la paghi alla cassa del tuo albo: la percentuale la scegli in NettoLR.",
        "da_sapere": "Le cose da sapere",
        "percentuale": "<b>La tua percentuale è il {p}.</b> Nel forfettario non conti le spese: su 100 € incassati, {n} € sono il reddito su cui paghi.",
        "paghi_pensione": "<b>Pensione:</b> paghi {g}.",
        "tasse_testo": "<b>Tasse:</b> un'unica tassa del {p}, o del {s} per i primi {a} anni.",
        "soglia": "<b>Fino a {e}</b> di incassi all'anno puoi restare nel forfettario.",
        "come": "Come lo calcolo?", "fonti": "Fonti", "da_verificare": "da verificare",
        "veri": "Con i tuoi incassi veri",
        "veri_testo": "NettoLR fa questo conto sui soldi che ti arrivano davvero, ti dice quanto mettere da parte e ti avvisa quando pagare. Tutto resta sul tuo telefono.",
        "presto": "Presto su App Store",
        "titolo_lavoro": "{n} in partita IVA: quanto ti resta",
        "altri_nomi": "Altri nomi",
        "meta_titolo": "{n} in partita IVA forfettaria: quanto ti resta nel {a} | NettoLR",
        "meta_desc": "{n} nel regime forfettario {a}: percentuale {p}, pensione e tasse spiegate in parole semplici.",
        "h1": "Quanto ti resta davvero, con la partita IVA",
        "intro": "Cerca il tuo lavoro: ti dico la percentuale, la pensione e quanto resta su {e} incassati, con le regole del {a}.",
        "cerca": "Il tuo lavoro: fotografo, idraulico, psicologo…", "cerca_label": "Cerca il tuo lavoro",
        "non_trovi": "Non trovi il tuo lavoro? NettoLR contiene tutti i codici ATECO dell'ISTAT.",
        "home_titolo": "NettoLR – quanto ti resta con la partita IVA forfettaria ({a})",
        "home_desc": "Il netto della partita IVA forfettaria in parole semplici, lavoro per lavoro.",
        "piede1": "È un calcolo, non una consulenza fiscale: per i casi particolari senti un commercialista.",
        "piede2": "Regole {a} aggiornate al {d}. Nessun cookie, nessuna statistica, nessuna pubblicità.",
        "privacy": "Privacy", "condizioni": "Condizioni d'uso", "altra_lingua": "English",
        "pensioni": {
            "separata": "la Gestione separata, per chi non ha una cassa del suo albo",
            "artigiani": "la gestione Artigiani (una quota fissa, più una parte sopra il minimo)",
            "commercianti": "la gestione Commercianti (una quota fissa, più una parte sopra il minimo)",
            "cassa": "la cassa del tuo albo",
        },
    },
    "en": {
        "su_esempio": "Bring in {e} in a year and you keep about",
        "a_te": "Yours", "pensione": "Pension", "tasse": "Taxes",
        "startup": "For the first five years, if it's your first business, taxes drop to {e}.",
        "incassato": "Received", "reddito": "Income", "tasse_di": "Tax: {p} of {e}", "ti_resta": "You keep",
        "esempio": "Simple example: pension paid in the same year, no reductions and no revenue stamps.",
        "cassa_100": "Of every €100 you bring in, the State counts as your income",
        "cassa_nota": "You pay your pension to your professional body's fund: you set the rate in NettoLR.",
        "da_sapere": "What to know",
        "percentuale": "<b>Your percentage is {p}.</b> On the flat-rate scheme (forfettario) you don't count expenses: of every €100 you bring in, €{n} is the income you pay on.",
        "paghi_pensione": "<b>Pension:</b> you pay into {g}.",
        "tasse_testo": "<b>Taxes:</b> a single tax of {p}, or {s} for the first {a} years.",
        "soglia": "<b>Up to {e}</b> of income a year you can stay on the flat-rate scheme.",
        "come": "How do I work it out?", "fonti": "Sources", "da_verificare": "to be checked",
        "veri": "With your real income",
        "veri_testo": "NettoLR does this sum on the money you actually receive, tells you how much to set aside and reminds you when to pay. Everything stays on your phone.",
        "presto": "Coming soon to the App Store",
        "titolo_lavoro": "{n} with an Italian VAT number: what you keep",
        "altri_nomi": "Also known as",
        "meta_titolo": "{n} on Italy's flat-rate scheme: what you keep in {a} | NettoLR",
        "meta_desc": "{n} on the Italian flat-rate scheme (forfettario) in {a}: {p} rate, pension and taxes in plain words.",
        "h1": "What you really keep with an Italian VAT number",
        "intro": "Find your job: I'll show the percentage, the pension and what you keep from {e} received, with the {a} rules.",
        "cerca": "Your job: photographer, plumber, psychologist…", "cerca_label": "Search for your job",
        "non_trovi": "Can't find your job? NettoLR includes every official ISTAT ATECO code.",
        "home_titolo": "NettoLR – what you keep on Italy's flat-rate scheme ({a})",
        "home_desc": "Take-home pay on the Italian flat-rate scheme (forfettario) in plain words, job by job.",
        "piede1": "It's a calculation, not tax advice: for special cases, talk to an accountant.",
        "piede2": "{a} rules updated {d}. No cookies, no analytics, no ads.",
        "privacy": "Privacy", "condizioni": "Terms of use", "altra_lingua": "Italiano",
        "pensioni": {
            "separata": "the INPS Gestione Separata, for those without a professional fund",
            "artigiani": "the INPS Artisans scheme (a fixed amount, plus a share above the minimum)",
            "commercianti": "the INPS Traders scheme (a fixed amount, plus a share above the minimum)",
            "cassa": "your professional body's fund",
        },
    },
}


def euro(x: float, lingua: str = "it") -> str:
    if lingua == "en":
        return f"€{x:,.0f}"
    return f"{x:,.0f}".replace(",", ".") + " €"


def pct(x: float, lingua: str = "it") -> str:
    v = x * 100
    if abs(v - round(v)) < 0.001:
        return f"{v:.0f}%"
    return (f"{v:.2f}" if lingua == "en" else f"{v:.2f}".replace(".", ",")) + "%"


def data(iso: str, lingua: str = "it") -> str:
    a, m, g = iso.split("-")
    return f"{int(g)} {MESI[lingua][int(m) - 1]} {a}"


def slug(testo: str) -> str:
    t = testo.lower()
    for a, b in {"à": "a", "è": "e", "é": "e", "ì": "i", "ò": "o", "ù": "u", "&": "e"}.items():
        t = t.replace(a, b)
    return re.sub(r"[^a-z0-9]+", "-", t).strip("-")


def fonte(chiave: str, lingua: str) -> str:
    f = regole["fonti"][chiave]
    stato = "" if f["stato"] == "verificato" else f' ({T[lingua]["da_verificare"]})'
    return f'<a href="{html.escape(f["url"])}" rel="noopener">{html.escape(f["titolo"])}</a>{stato}'


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
footer{margin-top:40px;font-size:14px;color:var(--muted)}footer a{color:var(--muted)}
header .lingua{margin-left:auto;font-size:15px;font-weight:700;color:var(--prugna)}
.testo h2{font-size:20px}.testo p,.testo li{color:var(--ink)}"""


def pagina(titolo: str, descrizione: str, corpo: str, lingua: str, profondita: int, altra: str) -> str:
    """profondita: quante cartelle sopra c'è sito/; altra: il percorso della stessa pagina nell'altra lingua"""
    su = "../" * profondita
    casa = su + ("en/" if lingua == "en" else "")
    t = T[lingua]
    return f"""<!doctype html>
<html lang="{lingua}"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>{html.escape(titolo)}</title><meta name="description" content="{html.escape(descrizione)}">
<link rel="stylesheet" href="{su}stile.css"></head>
<body><main>
<header>{MARCA}<a href="{casa}index.html">Netto<b>LR</b></a><a class="lingua" href="{su}{altra}" hreflang="{'it' if lingua == 'en' else 'en'}">{t["altra_lingua"]}</a></header>
{corpo}
<footer><p>{t["piede1"]}</p>
<p>{t["piede2"].format(a=ANNO, d=data(regole["aggiornatoAl"], lingua))}</p>
<p><a href="{casa}privacy.html">{t["privacy"]}</a> · <a href="{casa}condizioni.html">{t["condizioni"]}</a></p></footer>
</main></body></html>
"""


def nome_lavoro(l: dict, lingua: str) -> str:
    if lingua == "en" and INGLESE.get(l["codice"]):
        n = INGLESE[l["codice"]][0]
    else:
        n = l["sinonimi"][0] if l["sinonimi"] else l["descrizione"]
    return n[:1].upper() + n[1:]


def pagina_lavoro(l: dict, lingua: str) -> tuple[str, str]:
    t = T[lingua]
    e = lambda x: euro(x, lingua)
    p_ = lambda x: pct(x, lingua)
    nome = nome_lavoro(l, lingua)
    g = gruppo(l["codice"])
    reddito = round(ESEMPIO * g["valore"], 2)
    inps = contributi(l["gestione"], reddito)
    f = regole["forfettario"]
    altri = INGLESE.get(l["codice"], []) if lingua == "en" else l["sinonimi"]
    corpo = [f'<span class="pillola">ATECO {html.escape(l["codice"])}</span>',
             f'<h1>{html.escape(t["titolo_lavoro"].format(n=nome))}</h1>',
             f'<p class="muted">{html.escape(l["descrizione"])}. {t["altri_nomi"]}: {html.escape(", ".join(altri))}.</p>']
    if inps is not None:
        imponibile = max(0, reddito - inps)
        tasse = round(imponibile * f["aliquotaOrdinaria"]["valore"], 2)
        tasse5 = round(imponibile * f["aliquotaStartup"]["valore"], 2)
        netto = ESEMPIO - inps - tasse
        w = lambda x: f"{x / ESEMPIO * 100:.1f}%"
        corpo.append(f"""<section class="scheda notte">
<p class="muted">{t["su_esempio"].format(e=e(ESEMPIO))}</p>
<p class="grande">{e(netto)}</p>
<div class="barra"><span style="width:{w(netto)};background:var(--marca)"></span><span style="width:{w(inps)};background:#7EA4DD"></span><span style="width:{w(tasse)};background:#F2A07B"></span></div>
<div class="legenda"><span><i style="background:var(--marca)"></i>{t["a_te"]} {e(netto)}</span><span><i style="background:#7EA4DD"></i>{t["pensione"]} {e(inps)}</span><span><i style="background:#F2A07B"></i>{t["tasse"]} {e(tasse)}</span></div>
<p class="muted">{t["startup"].format(e=e(tasse5))}</p>
</section>""")
        dettaglio = f"""<table class="righe">
<tr><td>{t["incassato"]}</td><td>{e(ESEMPIO)}</td></tr>
<tr><td>{t["reddito"]}: {e(ESEMPIO)} × {p_(g["valore"])}</td><td>{e(reddito)}</td></tr>
<tr><td>{t["pensione"]}</td><td>− {e(inps)}</td></tr>
<tr><td>{t["tasse_di"].format(p=p_(f["aliquotaOrdinaria"]["valore"]), e=e(imponibile))}</td><td>− {e(tasse)}</td></tr>
<tr><td>{t["ti_resta"]}</td><td>{e(netto)}</td></tr></table>
<p class="muted">{t["esempio"]}</p>"""
    else:
        corpo.append(f"""<section class="scheda notte"><p class="muted">{t["cassa_100"]}</p>
<p class="grande">{e(100 * g["valore"])}</p><p class="muted">{t["cassa_nota"]}</p></section>""")
        dettaglio = ""
    fonte_pensione = regole["gestioneSeparata"]["aliquota"]["fonte"] if l["gestione"] == "separata" else regole["artigianiCommercianti"]["minimale"]["fonte"]
    corpo.append(f"""<section class="scheda"><h2 style="margin-top:0">{t["da_sapere"]}</h2>
<p>{t["percentuale"].format(p=p_(g["valore"]), n=round(g["valore"] * 100))}</p>
<p>{t["paghi_pensione"].format(g=t["pensioni"][l["gestione"]])}</p>
<p>{t["tasse_testo"].format(p=p_(f["aliquotaOrdinaria"]["valore"]), s=p_(f["aliquotaStartup"]["valore"]), a=f["anniStartup"]["valore"])}</p>
<p>{t["soglia"].format(e=e(f["sogliaRicavi"]["valore"]))}</p>
<details><summary>{t["come"]}</summary>{dettaglio}
<p class="muted">{t["fonti"]}: {fonte(f["aliquotaOrdinaria"]["fonte"], lingua)}; {fonte(fonte_pensione, lingua)}.</p></details>
</section>
<section class="scheda"><h2 style="margin-top:0">{t["veri"]}</h2>
<p>{t["veri_testo"]}</p>
<p class="pillola">{t["presto"]}</p></section>""")
    titolo = t["meta_titolo"].format(n=nome, a=ANNO)
    desc = t["meta_desc"].format(n=nome, a=ANNO, p=p_(g["valore"]))
    return slug(nome_lavoro(l, "it")), "\n".join(corpo), titolo, desc


# La privacy e le condizioni d'uso: cosa fa davvero l'app (dati solo sul telefono), da far rileggere prima del lancio
LEGALE = {
    "it": {
        "privacy": ("Privacy", """<p class="muted">In vigore dal 28 ottobre 2026.</p>
<h2>In breve</h2>
<p>I tuoi dati restano sul tuo iPhone. NettoLR non ha account, non ha server, non usa pubblicità, statistiche o tracciamento.</p>
<h2>Cosa resta sul telefono</h2>
<ul><li>Il profilo (nome facoltativo, lavoro, codice ATECO, partita IVA se la scrivi), gli incassi, i pagamenti e le ricevute F24 che aggiungi: si salvano nella memoria dell'app, protetti dal codice dell'iPhone.</li>
<li>Le foto del certificato e delle fatture si leggono sul telefono, senza internet, e non si salvano. Le foto delle ricevute F24 si salvano solo se le aggiungi tu.</li>
<li>I promemoria sono notifiche programmate sul telefono.</li>
<li>Face ID lo gestisce iOS: NettoLR riceve solo «sbloccato» o «non sbloccato».</li></ul>
<h2>Copia di sicurezza</h2>
<p>Se fai una copia di sicurezza, scegli tu dove salvarla (per esempio iCloud Drive). Da lì la custodisce chi gestisce quel servizio, secondo le sue regole.</p>
<h2>Abbonamento</h2>
<p>Gli acquisti passano dall'App Store di Apple. NettoLR non vede i tuoi dati di pagamento: sa solo se l'abbonamento è attivo.</p>
<h2>Questo sito</h2>
<p>Niente cookie, niente statistiche, niente pubblicità. I caratteri e lo stile sono nei file del sito.</p>
<h2>Cancellare tutto</h2>
<p>In «Tu» c'è «Cancella tutti i dati». Anche eliminare l'app cancella tutto ciò che contiene.</p>
<h2>Chi siamo</h2>
<p>NettoLR fa parte delle app LR. Per domande sulla privacy: <b>[indirizzo email da inserire]</b>.</p>"""),
        "condizioni": ("Condizioni d'uso", """<p class="muted">In vigore dal 28 ottobre 2026.</p>
<h2>Cos'è NettoLR</h2>
<p>NettoLR fa un calcolo: stima quanto ti resta in regime forfettario, con le regole ufficiali e le fonti indicate nell'app. <b>Non è una consulenza fiscale</b>: per decisioni importanti e casi particolari senti un commercialista.</p>
<h2>Prova e abbonamento</h2>
<ul><li>Hai 14 giorni di prova gratuita, senza carta.</li>
<li>Poi puoi abbonarti a NettoLR completo, mensile o annuale, al prezzo che vedi nell'app.</li>
<li>L'abbonamento si rinnova da solo. Puoi disdirlo quando vuoi da Impostazioni › il tuo nome › Abbonamenti, almeno 24 ore prima del rinnovo.</li>
<li>I pagamenti e i rimborsi li gestisce Apple, secondo le sue condizioni.</li></ul>
<h2>Responsabilità</h2>
<p>Facciamo il possibile perché i numeri siano giusti e aggiornati, ma possono esserci errori o cambi di legge non ancora inseriti. Controlla sempre gli importi prima di pagare.</p>
<h2>Licenza</h2>
<p>Valgono anche le condizioni standard di Apple per le app (<a href="https://www.apple.com/legal/internet-services/itunes/dev/stdeula/" rel="noopener">EULA</a>).</p>"""),
    },
    "en": {
        "privacy": ("Privacy", """<p class="muted">Effective 28 October 2026.</p>
<h2>In short</h2>
<p>Your data stays on your iPhone. NettoLR has no accounts, no servers, no ads, no analytics and no tracking.</p>
<h2>What stays on your phone</h2>
<ul><li>Your profile (optional name, job, ATECO code, VAT number if you enter it), income, payments and the F24 receipts you add: saved in the app's storage, protected by your iPhone passcode.</li>
<li>Photos of your certificate and invoices are read on the phone, without internet, and not saved. Photos of F24 receipts are saved only if you add them.</li>
<li>Reminders are notifications scheduled on the phone.</li>
<li>Face ID is handled by iOS: NettoLR only learns “unlocked” or “not unlocked”.</li></ul>
<h2>Backups</h2>
<p>If you make a backup, you choose where to save it (for example iCloud Drive). From there it's kept by that service, under its own rules.</p>
<h2>Subscription</h2>
<p>Purchases go through Apple's App Store. NettoLR never sees your payment details: it only knows whether your subscription is active.</p>
<h2>This website</h2>
<p>No cookies, no analytics, no ads. Fonts and styles are part of the site's own files.</p>
<h2>Deleting everything</h2>
<p>In “You” there's “Delete all data”. Deleting the app also removes everything in it.</p>
<h2>Who we are</h2>
<p>NettoLR is one of the LR apps. Privacy questions: <b>[email address to be added]</b>.</p>"""),
        "condizioni": ("Terms of use", """<p class="muted">Effective 28 October 2026.</p>
<h2>What NettoLR is</h2>
<p>NettoLR does a calculation: it estimates what you keep on the Italian flat-rate scheme, using the official rules and the sources shown in the app. <b>It is not tax advice</b>: for important decisions and special cases, talk to an accountant.</p>
<h2>Trial and subscription</h2>
<ul><li>You get a 14-day free trial, no card needed.</li>
<li>Then you can subscribe to NettoLR Complete, monthly or yearly, at the price shown in the app.</li>
<li>The subscription renews automatically. Cancel anytime in Settings › your name › Subscriptions, at least 24 hours before renewal.</li>
<li>Payments and refunds are handled by Apple, under its terms.</li></ul>
<h2>Liability</h2>
<p>We do our best to keep the numbers right and up to date, but there may be mistakes or law changes not yet included. Always check amounts before paying.</p>
<h2>Licence</h2>
<p>Apple's standard licence terms for apps also apply (<a href="https://www.apple.com/legal/internet-services/itunes/dev/stdeula/" rel="noopener">EULA</a>).</p>"""),
    },
}


def principale():
    radice = RADICE / "sito"
    radice.mkdir(exist_ok=True)
    (radice / "stile.css").write_text(CSS + "\n")
    for lingua in ("it", "en"):
        t = T[lingua]
        out = radice / ("en" if lingua == "en" else "")
        prof = 1 if lingua == "en" else 0
        pref_altra = "" if lingua == "en" else "en/"
        (out / "lavori").mkdir(parents=True, exist_ok=True)
        voci = []
        for l in sorted(LAVORI, key=lambda l: nome_lavoro(l, lingua).lower()):
            s, corpo, titolo, desc = pagina_lavoro(l, lingua)
            (out / "lavori" / f"{s}.html").write_text(pagina(titolo, desc, corpo, lingua, prof + 1, f"{pref_altra}lavori/{s}.html"))
            nome = nome_lavoro(l, lingua)
            parole = [nome, l["descrizione"], l["codice"], *l["sinonimi"], *INGLESE.get(l["codice"], [])]
            cerca = html.escape(" ".join(parole).lower())
            voci.append(f'<li data-cerca="{cerca}"><a href="lavori/{s}.html">{html.escape(nome)}<small>{pct(gruppo(l["codice"])["valore"], lingua)} · {html.escape(l["codice"])}</small></a></li>')
        corpo = f"""<h1>{t["h1"]}</h1>
<p class="muted">{t["intro"].format(e=euro(ESEMPIO, lingua), a=ANNO)}</p>
<input id="cerca" type="search" placeholder="{t["cerca"]}" aria-label="{t["cerca_label"]}">
<ul class="lavori" id="lavori">
{chr(10).join(voci)}
</ul>
<p class="muted">{t["non_trovi"]}</p>
<script>
const c=document.getElementById('cerca'),v=[...document.querySelectorAll('#lavori li')];
c.addEventListener('input',()=>{{const q=c.value.trim().toLowerCase();v.forEach(li=>li.hidden=q&&!li.dataset.cerca.includes(q))}});
</script>"""
        (out / "index.html").write_text(pagina(t["home_titolo"].format(a=ANNO), t["home_desc"], corpo, lingua, prof, f"{pref_altra}index.html"))
        for nome_file, (titolo, testo) in LEGALE[lingua].items():
            (out / f"{nome_file}.html").write_text(pagina(f"{titolo} | NettoLR", titolo, f'<div class="testo"><h1>{titolo}</h1>\n{testo}</div>',
                                                          lingua, prof, f"{pref_altra}{nome_file}.html"))
        print(f"Sito ({lingua}): {len(voci)} lavori in {out}")


if __name__ == "__main__":
    principale()
