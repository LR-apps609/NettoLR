# NettoLR — istruzioni per Claude

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
