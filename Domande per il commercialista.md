# NettoLR — domande per il commercialista

NettoLR calcola quanto resta a una partita IVA in regime forfettario. Il calcolo è fatto sul telefono, con i
numeri del file `Resources/Rules/regole-2026.json`. Ogni numero ha una fonte e uno stato: «verificato» o «da
verificare». Qui sotto ci sono le domande ancora aperte per il **2026**. Per ognuna è scritto cosa fa oggi l'app.
Basta un sì, oppure il numero giusto con la fonte.

> È un calcolo, non una consulenza fiscale. L'app lo dice in ogni schermata dove serve.

## 1. Pensione di artigiani e commercianti: anticipi sulla parte sopra il minimo

**Cosa fa oggi l'app**
- Prende i contributi dell'anno scorso sul reddito oltre il minimale (18.808 €).
- Calcola gli anticipi dell'anno come **100% di quella cifra**, divisi in **due rate da 50%**:
  - la prima a luglio, insieme al saldo;
  - la seconda il 30 novembre.
- Toglie gli anticipi già pagati.
- Causale **AP** per gli artigiani e **CP** per i commercianti.

**Cosa abbiamo trovato**
- Le circolari INPS 14/2026 e 62/2026 confermano le scadenze.
- La percentuale non la scrivono.
- Alcuni siti parlano di 80% (40% + 40%), ma sembra la regola della Gestione Separata.

**Domanda**
- Per artigiani e commercianti forfettari è giusto 50% + 50%?
- Vale anche per chi ha la riduzione del 35%?

## 2. Proroga al 20 luglio 2026 (D.L. 89/2026, art. 6): vale anche per la pensione?

**Cosa fa oggi l'app**
- Saldo 2025 e primo anticipo 2026 entro il **20 luglio 2026**.
- Oppure entro il **20 agosto** con lo **0,80%** in più.
- Usa le stesse date per tasse, pensione sopra il minimo (artigiani e commercianti) e Gestione Separata.

**Cosa abbiamo trovato**
- Diversi studi e associazioni dicono che la proroga vale anche per i contributi INPS.
- La circolare INPS 62/2026 è del 27 maggio, uscita prima del decreto. Riporta ancora 30 giugno / 30 luglio
  con lo 0,40%.
- Non abbiamo trovato un messaggio INPS successivo che confermi.

**Domande**
1. La proroga al 20 luglio vale anche per i contributi INPS?
2. Il differimento al 20 agosto per i contributi costa 0,80% o 0,40%?

## 3. Soglia della prima rata di anticipo delle tasse (103 €)

**Cosa fa oggi l'app**
- Sotto 51,65 € di anticipo totale non si paga niente.
- Se la prima rata sarebbe sotto 103 €, tutto l'anticipo va pagato a novembre.

**Cosa abbiamo trovato**
- Le fonti non sono d'accordo.

**Domanda**
- È giusto per i forfettari con anticipi al 50% + 50%?

## 4. Bollo sulle fatture elettroniche

**Cosa fa oggi l'app**
- Usa queste scadenze per il 2026:
  - 1° giugno 2026;
  - 30 settembre 2026;
  - 30 novembre 2026;
  - 1° marzo 2027.
- Se il bollo del primo o del secondo trimestre, sommato a quelli rinviati prima, è sotto i **5.000 €**, lo
  sposta alla scadenza dopo.

**Domanda**
- Date e soglia sono giuste per il 2026?

## 5. Coefficienti di redditività e codici ATECO

**Cosa fa oggi l'app**
- Usa i coefficienti della L. 190/2014, allegato 4.
- Li collega ai **codici ATECO 2007**.
- Chiede all'utente il codice ATECO 2007, quello del quadro LM, rigo LM22, anche se dal 1° aprile 2025 è in
  vigore ATECO 2025.
- Con più attività, ogni incasso usa il coefficiente del suo codice.

**Domanda**
- Per il 2026 il coefficiente si sceglie ancora dal codice ATECO 2007?
- Oppure c'è una tabella ufficiale di raccordo con ATECO 2025 da usare?

## 6. Formula del reddito e delle tasse

**Cosa fa oggi l'app**
- Reddito = incassi × coefficiente.
- Imponibile = reddito − contributi INPS **pagati nell'anno**.
- Tasse = imponibile × **15%**, oppure **5%** per i primi 5 anni se si hanno i requisiti.
- Artigiani e commercianti:
  - pagano 4 rate fisse sul minimale e una parte sopra il minimo;
  - con la riduzione del 35% su entrambe.

**Domanda**
- C'è qualcosa che va trattato in modo diverso (per esempio contributi pagati per anni precedenti, o rimborsi)?

## 7. Confronto con il regime ordinario (solo indicativo)

**Cosa fa oggi l'app**
- Usa gli scaglioni IRPEF 2026: 23% fino a 28.000 €, 33% fino a 50.000 €, 43% oltre.
- Aggiunge una stima media delle addizionali del **2%**.
- Serve solo per mostrare la differenza con il forfettario.

**Domanda**
- Va bene come stima, o è meglio usare un'altra percentuale per le addizionali?

---

## Già verificato sulle fonti ufficiali

| Cosa | Fonte |
|---|---|
| Rate fisse artigiani e commercianti 2026: 18 maggio, 20 agosto, 16 novembre 2026, 16 febbraio 2027 | INPS, circolare 14/2026, par. 9 |
| Pensione sopra il minimo pagata alle date delle tasse: saldo + primo anticipo, secondo anticipo il 30 novembre | INPS, circolari 14/2026 e 62/2026 |
| Gestione Separata: aliquota 26,07%, anticipi all'80% (40% + 40%), causale PXX | INPS, circolari 8/2026 e 62/2026 |
| Anticipi delle tasse per i forfettari: 50% + 50% | Agenzia delle Entrate, risoluzione 93/E del 2019 |
