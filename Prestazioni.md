# NettoLR · prestazioni

Passata del 3 novembre 2026 con le «30 regole di velocità» delle web app, applicate solo dove servono.

**Regola d'oro:** mai un numero provvisorio spacciato per vero.
- **Azioni** (aggiungere un incasso, «Sì», «Ho pagato»): si vedono subito.
- **Netto, tasse e scadenze:** si mostrano solo quando sono calcolati.

## Come si misura

- **Dove:** `Tests/PrestazioniTests.swift`, sul Mac di GitHub, nel simulatore iPhone.
- **Dove si leggono le misure:** nel registro della compilazione, alle righe «MISURA».
- **Dati di prova:** 1000 fatture e 200 fatture elettroniche XML.
- **Impronta dei risultati:**
  - **cosa contiene:** netto, tasse, pensione e pagamenti di 4 profili per 3 anni, più ricerca ATECO e lettura XML;
  - **valore:** prima `220f0a89b6205a54`, dopo `220f0a89b6205a54`. **Identica.**
  - **controllo:** il test fallisce se cambia anche un solo numero.
- **Attenzione al confronto:** i due giri sono stati fatti su Mac diversi di GitHub. Anche le voci che non ho toccato cambiano fino a ×1,5 (per esempio la lettura da foto). Sono reali solo i guadagni molto più grandi di così.

## Misure prima / dopo

| Cosa | Prima | Dopo | Guadagno |
|---|---|---|---|
| Cursore di «Prova», un passo (1000 fatture) | 31,3 ms | 0,2 ms | **×145**: ora sta ampiamente sotto i 16 ms di un fotogramma |
| 200 fatture XML lette e aggiunte (1000 fatture già presenti) | 5,17 s | 0,21 s | **×25** |
| «Sì, mi hanno pagato» su una fattura (con il salvataggio su disco) | 67 ms | 6 ms | **×11** |
| Netto: risultato, pagamenti, prossimo pagamento | 18 ms | 4,5 ms | ×4 |
| Ricerca ATECO, «faccio siti web» lettera per lettera (15 ricerche) | 179 ms | 101 ms | ×1,8: 6,7 ms per lettera |
| Ricerca ATECO, 15 ricerche diverse | 159 ms | 122 ms | ×1,3 |
| Avvio: regole 2025-2027 lette | 1,3 ms | 1,4 ms | non serviva |
| Copia di sicurezza (1200 fatture) | 7,8 ms | 5,6 ms | non serviva |
| CSV per il commercialista | 25 ms | 14 ms | non serviva (Mac diverso) |
| Lettura di una fattura da foto (Vision) | 5,3 s | 3,6 s | già fuori dal thread principale; nel simulatore è lenta, su iPhone è molto più veloce |

### Sito (rete 3G simulata: 750 kbit/s, 100 ms di latenza)

| Pagina | Peso | Caricamento |
|---|---|---|
| Pagina principale | 16 KB | 0,30 s |
| Pagina di un lavoro | 8 KB | 0,25 s |

Misurato su un server locale senza compressione: GitHub Pages comprime, quindi online pesa ancora meno.

## Modifiche fatte (basso rischio)

- [x] **Un salvataggio per azione:**
  - **prima:** ogni modifica riscriveva subito tutto il file, quindi «Sì» lo scriveva 2 volte e 200 XML lo scrivevano 200 volte;
  - **ora:** una scrittura sola, appena finita l'azione;
  - **in secondo piano:** se l'app va in secondo piano scrive subito (`Store.salva`, `salvaSubito`).
- [x] **Doppioni delle fatture importate:**
  - **prima:** ogni fattura nuova veniva confrontata con tutte le altre;
  - **ora:** un solo passaggio con un insieme (`aggiungiNuove`);
  - **risultato:** stesse fatture aggiunte, nello stesso ordine.
- [x] **Riepilogo delle fatture:**
  - **ora:** si calcola una volta e si riusa finché non cambiano fatture o anno;
  - **prima:** il cursore di «Prova» lo ricalcolava 3 volte a ogni passo.
- [x] **Ricerca ATECO:** i sinonimi italiani e inglesi sono normalizzati una volta sola, non a ogni lettera.
- [x] **Lista incassi pigra (`LazyVStack`):**
  - **cosa fa:** costruisce solo le righe visibili;
  - **animazione:** l'entrata animata resta per le prime 12 righe; quelle che arrivano scorrendo compaiono subito.
- [x] **Sito:** impronta nel nome del foglio di stile (`stile.css?v=…`). Il browser lo tiene in memoria e lo riscarica solo quando cambia.

## Le 30 voci

Il messaggio non conteneva l'elenco, quindi ho usato le 30 regole classiche: comprendono tutte quelle indicate.

| # | Regola | Si applica? | Dove | Stato | Guadagno | Sforzo | Rischio |
|---|---|---|---|---|---|---|---|
| 1 | Misura prima e dopo | Sì | `PrestazioniTests` | ✅ fatto | — | basso | nessuno |
| 2 | Interfaccia aggiornata prima della risposta | Solo per le azioni | Incassi, Pagamenti | ✅ già così: tutto è locale, nessuna attesa | — | — | — |
| 3 | Debounce sugli input | Ricerca ATECO | Benvenuto, Tu | ⏸ non serve: 6,7 ms per lettera | piccolo | basso | basso |
| 4 | Throttle degli eventi continui | Cursore di «Prova» | `ProvaView` | ⏸ non serve: 0,2 ms per passo | — | — | — |
| 5 | Caricamento quando serve | Voci, regole | `Video`, `Regole` | ✅ già così: voci lette scena per scena, regole in 1,4 ms | — | — | — |
| 6 | Liste virtualizzate | Incassi | `IncassiView` | ✅ fatto | grande con centinaia di incassi | basso | basso |
| 7 | Memorizzare i calcoli costosi | Riepilogo fatture | `Store.riepilogo` | ✅ fatto | ×145 sul cursore | basso | basso |
| 8 | Meno ridisegni (stato diviso) | Store unico | tutte le schede | ❓ da confermare | medio | alto | medio |
| 9 | Lavori lenti fuori dal thread principale | XML, foto, backup | Incassi, Certificato | ✅ foto già fuori · ❓ XML (0,2 s ora) | piccolo | medio | medio |
| 10 | Avanzamento e «Annulla» | Lettura di molte XML | Incassi | ❓ da confermare | piccolo ora | medio | basso |
| 11 | Scritture raggruppate | Salvataggio | `Store.salva` | ✅ fatto | ×25 sulle XML | basso | basso |
| 12 | Indice pronto per la ricerca | ATECO | `Ateco.cerca` | ✅ fatto: elenco caricato una volta, sinonimi pronti | ×1,8 | basso | nessuno |
| 13 | Paginazione | — | — | ➖ coperta dalla lista pigra | — | — | — |
| 14 | Pacchetto piccolo / divisione del codice | App 1,5 MB di voci | — | ➖ non serve | — | — | — |
| 15 | Dipendenze inutili | — | `project.yml` | ✅ già così: zero dipendenze esterne | — | — | — |
| 16 | Compressione | Sito | GitHub Pages | ✅ già così: gzip automatico | — | — | — |
| 17 | Immagini WebP e caricate quando servono | Sito | `sito/` | ➖ il sito non ha immagini | — | — | — |
| 18 | Font ospitati in casa, solo i pesi usati | Sito | `stile.css` | ✅ già così: font di sistema, zero download | — | — | — |
| 19 | Script di terze parti dopo | Sito | `sito/` | ✅ già così: nessuno script esterno, solo 3 righe in pagina | — | — | — |
| 20 | Nomi con impronta per la cache | Sito | `build_sito.py` | ✅ fatto | piccolo | basso | nessuno |
| 21 | Precaricare le risorse critiche | Sito | — | ➖ un solo CSS da 2,7 KB | — | — | — |
| 22 | Scheletri invece di rotelline | — | — | ➖ i numeri arrivano subito; la foto mostra già «Leggo…» | — | — | — |
| 23 | Timeout sulle chiamate esterne | Acquisti StoreKit | `Acquisto` | ❓ da confermare | piccolo | basso | basso |
| 24 | Ritenta con attesa crescente | StoreKit | `Acquisto` | ➖ StoreKit ritenta da solo; si ricontrolla a ogni ritorno nell'app | — | — | — |
| 25 | CDN | Sito | — | 🚫 no: GitHub Pages | — | — | — |
| 26 | Generazione lato server (SSR) | Sito | — | 🚫 no: il sito è già generato | — | — | — |
| 27 | Server, database, Redis | — | — | 🚫 no: dati solo sul telefono | — | — | — |
| 28 | Load balancing | — | — | 🚫 no | — | — | — |
| 29 | Monitoraggio esterno (OpenTelemetry, RUM) | — | — | 🚫 no: niente analisi, per scelta | — | — | — |
| 30 | Risposte AI in streaming | — | — | 🚫 no | — | — | — |

Legenda: ✅ fatto o già così · ⏸ misurato, non serve · ❓ da confermare · ➖ non pertinente · 🚫 escluso

## Decisioni da confermare

- [ ] **Stato diviso (voce 8):**
  - **oggi:** tutte le schede leggono lo stesso `Store`, quindi una modifica le ridisegna tutte;
  - **perché aspettare:** con le misure di adesso non si vede un problema, e dividerlo tocca tutta l'app;
  - **consiglio:** aspettare la prova su iPhone vecchio.
- [ ] **Lettura XML in sottofondo con avanzamento e «Annulla» (voci 9 e 10):**
  - **oggi:** 200 file richiedono 0,2 s;
  - **consiglio:** serve solo per chi importa migliaia di file, quindi non ora.
- [ ] **Timeout sugli acquisti (voce 23):**
  - **senza rete:** i prezzi restano «…», ma l'app non si blocca;
  - **proposta:** dopo 10 secondi mostrare «Controlla la connessione». Sforzo piccolo.

## Prove che servono da te

- [ ] **iPhone vecchio** (per esempio iPhone XR, SE 2ª gen. o 11) con **risparmio energetico attivo**:
  - [ ] **avvio:** fino alla schermata Netto
  - [ ] **«Prova»:** cursore mosso veloce avanti e indietro (deve restare fluido)
  - [ ] **ricerca ATECO:** «faccio siti web» scritto veloce
  - [ ] **Incassi:** scorrere una lista lunga
  - [ ] **lettura di una fattura da foto:** quanto ci mette
  - [ ] **importazione di molte XML insieme**
