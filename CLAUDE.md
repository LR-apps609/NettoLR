# NettoLR — istruzioni per Claude

## Documento della verità (prima di tutto)
Unica fonte di verità su stato, decisioni, link e cronologia:
**[NettoLR · Documento della verità](https://claude.ai/artifact/9GegX7WW72My4D4j89pW8L)** (Claude Docs, con le schede).
- Se un altro file o pagina dice altro, vale il documento. Se il codice dice altro, verifica e correggi uno dei due.
- All'inizio di ogni lavoro: leggi «Inizia qui» e «Diario», confronta il Diario con gli ultimi commit e aggiungi quello che manca.
- Aggiorna il documento: quando inizi un lavoro (voce 🔄), a ogni versione, rilascio o unione di rami, quando ti blocchi
  o aspetti l'utente, quando l'utente decide qualcosa e quando finisci (con tempi e difficoltà). Mai dire «fatto» senza averlo aggiornato.
- Niente nuovi documenti di appunti, piani o resoconti: va tutto nel documento. Restano fuori solo i file che servono
  all'app, alla compilazione, agli store o al sito. NOVITA.txt è per gli utenti, il Diario per noi: si aggiornano insieme.
- Oltre 30 voci nel Diario, le più vecchie vanno in «Archivio» con un riassunto.
- Niente password, chiavi o codici segreti nel documento.

App della famiglia LR (GateLR, OrbitLR, IsoLR, WebcamLR): quanto resta davvero a una partita IVA in regime forfettario.

## Regole
- Lingua: tutto in italiano (interfaccia, nomi di tipi e variabili, commenti, commit).
- Per chi non conosce la burocrazia: una cosa per schermata, numeri grandi, parole semplici. Niente sigle in vista
  («pensione» invece di INPS, «tasse» invece di imposta sostitutiva); i dettagli tecnici stanno in «Come lo calcolo?».
- Ogni numero normativo sta in `Resources/Rules/regole-AAAA.json` con la sua fonte e lo stato
  («verificato» / «da-verificare»). Mai aliquote scritte nel codice.
- Dati solo sul telefono: niente server, niente analisi, niente pubblicità.
- Colore dell'app: prugna (#A23E6E, scuro #D88BB2). L'ottone (#A97E3F / #D6AA62) è il filo della famiglia: solo dettagli.
- Logo: marca da bollo dentellata con la N (`Marca` in Components.swift, icona da `Tools/make_icon.py`).
- Progetto Xcode generato da XcodeGen (`project.yml`): non aggiungere `.xcodeproj`.
- Ogni modifica: il workflow «Compila NettoLR» compila, esegue i test e pubblica le foto nel ramo `screenshots`.
- È un calcolo, non una consulenza fiscale: dirlo sempre dove serve.
