# NettoLR

**Quanto ti resta, davvero.** Per le partite IVA in regime forfettario: quanto è tuo, quanto va alla pensione e alle tasse,
quanto mettere da parte e quando pagare. In parole semplici, con la fonte ufficiale di ogni numero. App per iPhone
(SwiftUI, iOS 17 o successivo), della famiglia LR.

> ⚠️ Versione 0.1: le regole 2026 sono prese da circolari INPS e pagine dell'Agenzia delle Entrate, ma alcune voci sono
> ancora **da verificare** e le formule vanno rilette da un commercialista. L'app lo scrive in chiaro.

## Installare sul tuo iPhone

Serve un Mac con **Xcode** (gratis dal Mac App Store), il tuo **Apple ID** e il cavo dell'iPhone.
Apri il Terminale, incolla questa riga e premi Invio:

```
curl -fsSL https://raw.githubusercontent.com/LR-apps609/NettoLR/main/installa.sh | zsh
```

Scarica NettoLR in `~/NettoLR`, prepara il progetto e apre Xcode; poi scegli il tuo Apple ID in *Signing & Capabilities*
e premi ▶︎. Per aggiornare, rilancia la stessa riga. In alternativa: scarica lo ZIP del repository e fai doppio clic su
`Installa su iPhone.command`.

## Come è fatto

| File | Cosa fa |
|---|---|
| `Resources/Rules/regole-2026.json` | Aliquote, soglie, scadenze 2026, ognuna con la sua fonte |
| `Sources/Regole.swift` | Legge il file delle regole |
| `Sources/Calcolo.swift` | Forfettario riga per riga, confronto con il regime normale, simulazioni, dipendente |
| `Sources/Ateco.swift` | Coefficienti di redditività e ricerca del lavoro |
| `Sources/Pagamenti.swift` | Calendario di tasse e pensione |
| `Sources/FatturaXML.swift` | Lettura delle fatture elettroniche XML, sul telefono |
| `Sources/Store.swift` | Stato dell'app; i dati restano salvati sul telefono |
| `Sources/BenvenutoView.swift` | Benvenuto e le quattro domande |
| `Sources/NettoView.swift` | Scheda **Netto** e «Come lo calcolo?» |
| `Sources/IncassiView.swift` | Scheda **Incassi** e nuovo incasso |
| `Sources/ProvaView.swift` | Scheda **Prova**: cursore e le tre domande |
| `Sources/PagamentiView.swift` | Scheda **Pagamenti**: conto alla rovescia e F24 |
| `Sources/TuView.swift` | Scheda **Tu**: profilo, partita IVA, preferenze |
| `Sources/CapireView.swift` | «Capire in 1 minuto» |
| `Sources/Theme.swift`, `Components.swift` | Colori, marca da bollo, anello, numeri che contano |
| `Tests/CalcoloTests.swift` | Test del motore di calcolo |
| `UITests/ScreenshotTests.swift` | Giro dell'app con le foto di ogni schermata |
| `Tools/make_icon.py` | Ridisegna l'icona (Pillow) |
| `installa.sh` | Scarica, prepara il progetto e apre Xcode sul Mac |

## Compilazione e prove

- **Ogni modifica** → workflow «Compila NettoLR» sul Mac di GitHub: genera il progetto con XcodeGen, compila, esegue i
  test e fa il giro delle schermate; le foto finiscono nel ramo `screenshots`.
- **Sul tuo iPhone**: doppio clic su `Installa su iPhone.command`; poi in Xcode scegli il tuo Apple ID in
  *Signing & Capabilities* e premi ▶︎ con l'iPhone collegato.

È un calcolo, non una consulenza fiscale.
