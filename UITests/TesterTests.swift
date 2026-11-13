import XCTest

// I 20 tester del giro «founder-skill» (metodo del gruppo di acquirenti, ridotto a 20 profili).
// Ogni prova è un tester: usa l'app vera nel simulatore, fa una foto a ogni passo e scrive un diario
// (tempi, pulsanti trovati o no, stato dei pulsanti). Le foto e i diari finiscono in SCREENSHOT_DIR:
// gli agenti-tester li guardano e scrivono le segnalazioni. Le prove non si fermano al primo errore:
// quello che manca va nel diario, così il tester vede tutto il percorso.
final class TesterTests: XCTestCase {
    private let app = XCUIApplication()
    private var codice = "T00"
    private var passo = 0
    private var diario: [String] = []

    override func setUp() {
        continueAfterFailure = true
        diario = []
        passo = 0
        XCUIDevice.shared.orientation = .portrait
    }

    override func tearDown() {
        nota("fine · errori registrati da XCTest: \(testRun?.failureCount ?? 0)")
        let testo = diario.joined(separator: "\n")
        scrivi("\(codice)-diario.txt", testo)
        let a = XCTAttachment(string: testo)
        a.name = "\(codice)-diario"
        a.lifetime = .keepAlways
        add(a)
        XCUIDevice.shared.orientation = .portrait
        XCUIDevice.shared.appearance = .light
    }

    // MARK: - Attrezzi

    private var cartella: URL? {
        ProcessInfo.processInfo.environment["SCREENSHOT_DIR"].map { URL(fileURLWithPath: $0) }
    }

    private func scrivi(_ nome: String, _ testo: String) {
        guard let c = cartella else { return }
        try? FileManager.default.createDirectory(at: c, withIntermediateDirectories: true)
        try? testo.write(to: c.appendingPathComponent(nome), atomically: true, encoding: .utf8)
    }

    private func nota(_ s: String) {
        diario.append(String(format: "[%02d] ", passo) + s)
    }

    /// Foto dello schermo; con `albero` salva anche l'elenco degli elementi (etichette, pulsanti, stato)
    private func foto(_ descrizione: String, albero: Bool = false) {
        passo += 1
        let nome = "\(codice)-" + String(format: "%02d", passo) + "-\(descrizione)"
        let immagine = XCUIScreen.main.screenshot()
        let a = XCTAttachment(screenshot: immagine)
        a.name = nome
        a.lifetime = .keepAlways
        add(a)
        if let c = cartella {
            try? FileManager.default.createDirectory(at: c, withIntermediateDirectories: true)
            try? immagine.pngRepresentation.write(to: c.appendingPathComponent(nome + ".png"))
        }
        if albero { scrivi(nome + ".txt", app.debugDescription) }
        nota("foto \(nome)" + (app.state == .runningForeground ? "" : " · APP NON IN PRIMO PIANO (\(app.state.rawValue))"))
    }

    private func avvia(_ codice: String, vuoto: Bool = false, lingua: String = "it", scuro: Bool = false, extra: [String] = []) {
        self.codice = codice
        XCUIDevice.shared.appearance = scuro ? .dark : .light
        var argomenti = [vuoto ? "-uitestVuoto" : "-uitest", "-AppleLanguages", "(\(lingua))",
                         "-AppleLocale", lingua == "it" ? "it_IT" : "en_GB"]
        if scuro { argomenti.append("-uiDark") }
        app.launchArguments = argomenti + extra
        let t0 = Date()
        app.launch()
        let pronto = vuoto ? app.buttons["benvenuto.inizia"].waitForExistence(timeout: 25)
                           : app.tabBars.buttons.element(boundBy: 0).waitForExistence(timeout: 25)
        nota(String(format: "avvio %@ in %.1f s · argomenti %@", pronto ? "riuscito" : "NON RIUSCITO",
                    Date().timeIntervalSince(t0), argomenti.joined(separator: " ")))
        if !pronto { XCTFail("\(codice): l'app non si è aperta") }
    }

    private func scheda(_ i: Int) {
        let b = app.tabBars.buttons.element(boundBy: i)
        if b.waitForExistence(timeout: 5) {
            b.tap()
            nota("scheda \(i) («\(b.label)»)")
        } else {
            nota("scheda \(i) NON TROVATA")
        }
    }

    /// Tocca il pulsante con quell'identificativo; scrive nel diario se manca, è disattivato o fuori schermo
    @discardableResult
    private func tocca(_ id: String, attesa: TimeInterval = 4) -> Bool {
        let e = app.buttons[id].firstMatch
        guard e.waitForExistence(timeout: attesa) else { nota("pulsante «\(id)» NON TROVATO"); return false }
        if !e.isEnabled { nota("pulsante «\(id)» DISATTIVATO") ; return false }
        if !e.isHittable {
            app.swipeUp()
            if !e.isHittable { nota("pulsante «\(id)» FUORI SCHERMO"); return false }
        }
        e.tap()
        nota("toccato «\(id)»")
        return true
    }

    /// Tocca il primo pulsante la cui etichetta contiene il testo (maiuscole ignorate)
    @discardableResult
    private func toccaTesto(_ testo: String, attesa: TimeInterval = 4, scorri: Bool = true) -> Bool {
        let e = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", testo)).firstMatch
        if !e.waitForExistence(timeout: attesa) && scorri {
            for _ in 0..<4 where !e.exists { app.swipeUp() }
        }
        guard e.exists else { nota("pulsante con «\(testo)» NON TROVATO"); return false }
        if !e.isHittable { app.swipeUp() }
        guard e.exists, e.isHittable else { nota("pulsante con «\(testo)» FUORI SCHERMO o sparito"); return false }
        let etichetta = e.label
        e.tap()
        nota("toccato «\(etichetta)»")
        return true
    }

    /// Chiude il foglio aperto, in italiano o in inglese; se non c'è un pulsante lo trascina giù
    private func chiudi() {
        for nome in ["Fatto", "Done", "Chiudi", "Close", "Annulla", "Cancel"] {
            let b = app.buttons[nome].firstMatch
            if b.exists && b.isHittable { b.tap(); nota("chiuso con «\(nome)»"); sleep(1); return }
        }
        app.swipeDown(velocity: .fast)
        nota("chiuso trascinando (nessun pulsante)")
        sleep(1)
    }

    private func campo(_ id: String) -> XCUIElement { app.textFields[id].firstMatch }

    /// Svuota un campo e ci scrive il testo
    private func riscrivi(_ e: XCUIElement, _ testo: String) {
        guard e.waitForExistence(timeout: 4) else { nota("campo NON TROVATO"); return }
        e.tap()
        let attuale = (e.value as? String) ?? ""
        if !attuale.isEmpty {
            e.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: attuale.count + 2))
        }
        e.typeText(testo)
        nota("scritto «\(testo)» · nel campo ora c'è «\((e.value as? String) ?? "")»")
    }

    /// Stato del pulsante Salva del nuovo incasso
    private func statoSalva() -> String {
        let s = app.buttons["Salva"].firstMatch
        return s.exists ? (s.isEnabled ? "Salva ATTIVO" : "Salva disattivato") : "Salva assente"
    }

    private func misura(_ cosa: String, _ blocco: () -> Void) {
        let t0 = Date()
        blocco()
        nota(String(format: "%@: %.2f s", cosa, Date().timeIntervalSince(t0)))
    }

    /// Percorso del benvenuto: cerca il lavoro, sceglie il primo risultato che contiene `scelta`, poi Avanti fino alle schede
    private func benvenuto(cerca: String, scelta: String, fretta: Bool = false, fotoOgniPasso: Bool = true) {
        foto("benvenuto")
        guard tocca("benvenuto.inizia") else { return }
        sleep(1)
        foto("domanda-lavoro-vuota")
        // Avanti senza aver scelto
        let avanti = app.buttons["profilo.avanti"].firstMatch
        nota("Avanti senza lavoro scelto: \(avanti.exists ? (avanti.isEnabled ? "ATTIVO" : "disattivato") : "assente")")
        riscrivi(campo("profilo.cerca"), cerca)
        sleep(1)
        foto("ricerca-\(cerca.replacingOccurrences(of: " ", with: "_"))", albero: true)
        if !toccaTesto(scelta, scorri: true) {
            // Prende il primo risultato qualunque sotto il campo
            if toccaTesto("Non trovo") { sleep(1); foto("gruppi") }
        }
        sleep(1)
        if fotoOgniPasso { foto("lavoro-scelto") }
        for i in 0..<6 {
            if app.tabBars.buttons.element(boundBy: 0).exists { break }
            if !fretta { sleep(1) }
            if fotoOgniPasso { foto("domanda-\(i + 2)") }
            let b = app.buttons["profilo.avanti"].firstMatch
            if b.exists && !b.isEnabled {
                nota("Avanti disattivato alla domanda \(i + 2): rispondo «No» se c'è")
                if app.buttons["No"].exists { app.buttons["No"].firstMatch.tap() }
            }
            if !tocca("profilo.avanti", attesa: 3) { break }
        }
        let dentro = app.tabBars.buttons.element(boundBy: 0).waitForExistence(timeout: 6)
        nota("fine del benvenuto: \(dentro ? "schede visibili" : "SCHEDE NON VISIBILI")")
        foto("dopo-benvenuto", albero: true)
    }

    private func nuovoIncasso(_ importo: String, salva: Bool = true) {
        guard tocca("incassi.aggiungi") else { return }
        let e = campo("nuovo.importo")
        guard e.waitForExistence(timeout: 4) else { nota("campo importo NON TROVATO"); return }
        e.typeText(importo)
        nota("importo «\(importo)» · \(statoSalva())")
        if salva, app.buttons["Salva"].firstMatch.isEnabled {
            app.buttons["Salva"].firstMatch.tap()
            nota("salvato")
        } else {
            chiudi()
        }
        sleep(1)
    }

    // MARK: - I 20 tester

    /// T01 · Giulia, 26, grafica alle prime armi · primo avvio · ha fretta · iPhone piccolo
    func test01_Giulia() {
        avvia("T01", vuoto: true)
        benvenuto(cerca: "grafica", scelta: "grafic", fretta: true)
        scheda(0); foto("netto-vuoto", albero: true)
        scheda(1); foto("incassi-vuoto")
        nuovoIncasso("1200")
        foto("incassi-dopo-primo")
        scheda(0); sleep(1); foto("netto-dopo-primo", albero: true)
    }

    /// T02 · Marco, 41, sviluppatore esperto · torna con un anno di dati · esplora tutto · iPhone grande
    func test02_Marco() {
        avvia("T02")
        for i in 0..<5 {
            misura("apertura scheda \(i)") { scheda(i) }
            sleep(1); foto("scheda-\(i)", albero: i == 0)
        }
        scheda(0)
        if tocca("netto.calcolo") {
            sleep(1); foto("come-lo-calcolo", albero: true)
            app.swipeUp(); foto("come-lo-calcolo-sotto")
            app.swipeUp(); foto("come-lo-calcolo-fondo")
            chiudi()
        }
        scheda(2)
        let cursore = app.sliders["prova.cursore"].firstMatch
        if cursore.waitForExistence(timeout: 4) {
            misura("cursore a 0") { cursore.adjust(toNormalizedSliderPosition: 0) }
            foto("prova-cursore-zero", albero: true)
            misura("cursore a 1") { cursore.adjust(toNormalizedSliderPosition: 1) }
            foto("prova-cursore-massimo", albero: true)
        } else { nota("cursore «prova.cursore» NON TROVATO") }
        scheda(4)
        if tocca("tu.esporta") { sleep(2); foto("esporta", albero: true); chiudi() }
        if toccaTesto("Manda al commercialista") { sleep(2); foto("esporta-2", albero: true); chiudi() }
    }

    /// T03 · Anna, 58, insegnante di yoga · prime armi · testo grandissimo
    func test03_Anna() {
        avvia("T03", vuoto: true, extra: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        benvenuto(cerca: "insegnante di yoga", scelta: "yoga")
        for i in 0..<5 { scheda(i); sleep(1); foto("scheda-\(i)-testo-grande", albero: i == 0) }
    }

    /// T04 · Luca, 33, consulente esperto · input sbagliati
    func test04_Luca() {
        avvia("T04")
        scheda(1)
        guard tocca("incassi.aggiungi") else { return }
        let e = campo("nuovo.importo")
        for valore in ["-500", "abc", "0", "0,00", "99999999999", "1.234,56", "1,234.56", "12,,5", "1e5", "  300 "] {
            riscrivi(e, valore)
            nota("→ \(statoSalva())")
            foto("importo-\(valore.replacingOccurrences(of: " ", with: "_"))")
        }
        riscrivi(e, "1.234,56")
        if app.buttons["Salva"].firstMatch.isEnabled { app.buttons["Salva"].firstMatch.tap(); nota("salvato 1.234,56") } else { chiudi() }
        sleep(1); foto("incassi-dopo-1234", albero: true)
        scheda(2)
        if toccaTesto("ore", attesa: 2, scorri: true) { foto("prova-ore") }
        scheda(4)
        let piva = campo("tu.piva")
        for v in ["123", "00000000000", "abcdefghijk", "123456789012"] {
            riscrivi(piva, v)
            tocca("tu.conferma")
            sleep(1)
            foto("piva-\(v)")
        }
    }

    /// T05 · Sara, 29, fotografa · primo avvio in inglese
    func test05_Sara() {
        avvia("T05", vuoto: true, lingua: "en")
        benvenuto(cerca: "photographer", scelta: "photo")
        for i in 0..<5 { scheda(i); sleep(1); foto("en-scheda-\(i)", albero: true) }
        scheda(1)
        if tocca("incassi.aggiungi") { foto("en-nuovo-incasso", albero: true); chiudi() }
        scheda(4)
        if tocca("tu.completo") { sleep(1); foto("en-completo"); chiudi() }
    }

    /// T06 · Davide, 37, idraulico · torna · iPad (l'app è per iPhone: gira in modalità compatibile)
    func test06_Davide() {
        avvia("T06")
        scheda(3); sleep(1); foto("pagamenti", albero: true)
        let righe = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "€"))
        nota("righe con € nei pagamenti: \(righe.count)")
        if righe.count > 0 {
            righe.element(boundBy: 0).tap()
            sleep(1); foto("pagamento-dettaglio", albero: true)
            if toccaTesto("Copia i dati", attesa: 2) { sleep(1); foto("copiato") }
            if tocca("pagamento.fatto") { sleep(1); foto("ho-pagato", albero: true) }
            chiudi()
            foto("pagamenti-dopo")
        }
        if tocca("pagamenti.annoScorso") { sleep(1); foto("anno-scorso", albero: true); chiudi() }
        scheda(0); foto("netto-ipad")
    }

    /// T07 · Elena, 45, ex impiegata di uno studio · esperta · controlla i numeri
    func test07_Elena() {
        avvia("T07")
        foto("netto", albero: true)
        if tocca("netto.calcolo") {
            for i in 0..<4 { foto("calcolo-\(i)", albero: true); app.swipeUp() }
            chiudi()
        }
        if tocca("netto.avvertenza", attesa: 2) { foto("avvertenza"); chiudi() }
        scheda(1)
        nuovoIncasso("90000")
        scheda(0); sleep(1); foto("netto-oltre-85mila", albero: true)
        scheda(1)
        nuovoIncasso("40000")
        scheda(0); sleep(1); foto("netto-oltre-100mila", albero: true)
        scheda(3); sleep(1); foto("pagamenti-oltre-100mila", albero: true)
        scheda(4)
        if tocca("tu.documenti") {
            sleep(1); foto("documenti", albero: true)
            if tocca("documenti.novita", attesa: 2) { foto("novita"); chiudi() }
            chiudi()
        }
    }

    /// T08 · Paolo, 52 · prime armi · salta tutto · stati vuoti
    func test08_Paolo() {
        avvia("T08", vuoto: true)
        foto("benvenuto")
        app.swipeDown(velocity: .fast); app.swipeLeft()
        foto("dopo-gesti-sul-benvenuto")
        guard tocca("benvenuto.inizia") else { return }
        riscrivi(campo("profilo.cerca"), "boh")
        sleep(1); foto("ricerca-boh", albero: true)
        riscrivi(campo("profilo.cerca"), "xyzxyz")
        sleep(1); foto("ricerca-senza-risultati", albero: true)
        if toccaTesto("Non trovo") { sleep(1); foto("gruppi", albero: true) }
        // Il primo gruppo che si può toccare
        let gruppi = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "%"))
        nota("gruppi con percentuale: \(gruppi.count)")
        if gruppi.count > 0 { gruppi.element(boundBy: 0).tap(); sleep(1); foto("gruppo-scelto") }
        for i in 0..<6 {
            if app.tabBars.buttons.element(boundBy: 0).exists { break }
            if app.buttons["No"].exists { app.buttons["No"].firstMatch.tap() }
            if !tocca("profilo.avanti", attesa: 3) { foto("bloccato-\(i)", albero: true); break }
        }
        for i in 0..<5 { scheda(i); sleep(1); foto("vuoto-scheda-\(i)", albero: true) }
    }

    /// T09 · Chiara, 31 · modo scuro, di notte · ha fretta · iPhone piccolo
    func test09_Chiara() {
        avvia("T09", scuro: true)
        misura("15 cambi di scheda") { for i in [0, 4, 1, 3, 2, 0, 1, 4, 2, 3, 0, 2, 4, 1, 0] { scheda(i) } }
        foto("netto-scuro", albero: true)
        scheda(1)
        for v in ["300", "450", "75,50"] { nuovoIncasso(v) }
        foto("incassi-scuro-dopo-3")
        // Cancella il primo incasso con lo scorrimento
        let cella = app.cells.firstMatch
        if cella.waitForExistence(timeout: 3) {
            cella.swipeLeft()
            sleep(1); foto("scorrimento-sinistra", albero: true)
            if app.buttons["Elimina"].firstMatch.exists { app.buttons["Elimina"].firstMatch.tap(); nota("eliminato con lo scorrimento") }
            else { nota("nessun «Elimina» dopo lo scorrimento") }
        } else {
            nota("nessuna cella nella lista degli incassi: provo il tocco lungo")
            let primo = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "€")).firstMatch
            if primo.exists { primo.press(forDuration: 1.2); sleep(1); foto("tocco-lungo", albero: true); chiudi() }
        }
        sleep(1); foto("incassi-scuro-fine")
        for i in 2...4 { scheda(i); sleep(1); foto("scuro-scheda-\(i)") }
    }

    /// T10 · Roberto, 64, pensionato con P.IVA · usa le funzioni di accessibilità
    func test10_Roberto() {
        avvia("T10")
        for i in 0..<5 {
            scheda(i); sleep(1)
            foto("audit-scheda-\(i)")
            controllaAccessibilita("scheda \(i)")
        }
        scheda(1)
        if tocca("incassi.aggiungi") { sleep(1); controllaAccessibilita("nuovo incasso"); foto("audit-nuovo"); chiudi() }
        scheda(0)
        if tocca("netto.calcolo") { sleep(1); controllaAccessibilita("come lo calcolo"); chiudi() }
        // Anche il primo avvio
        app.terminate()
        avvia("T10", vuoto: true)
        controllaAccessibilita("benvenuto")
        if tocca("benvenuto.inizia") { sleep(1); controllaAccessibilita("domanda lavoro"); foto("audit-domanda") }
    }

    private func controllaAccessibilita(_ dove: String) {
        if #available(iOS 17.0, *) {
            var n = 0
            do {
                try app.performAccessibilityAudit { problema in
                    n += 1
                    let el = problema.element.map { "«\($0.label)» (\($0.elementType.rawValue))" } ?? "elemento sconosciuto"
                    self.nota("ACCESSIBILITÀ \(dove): \(problema.compactDescription) · \(el)")
                    return true
                }
            } catch {
                nota("controllo accessibilità \(dove) non riuscito: \(error.localizedDescription)")
            }
            nota("controllo accessibilità \(dove): \(n) problemi")
        }
    }

    /// T11 · Francesca, 27 · senza rete (nel simulatore: niente iCloud e App Store non raggiungibile)
    func test11_Francesca() {
        avvia("T11", extra: ["-uiProva"])
        scheda(4)
        if tocca("tu.completo") {
            sleep(4); foto("completo-senza-store", albero: true)
            if tocca("completo.compra", attesa: 3) { sleep(4); foto("compra-senza-store", albero: true) }
            if toccaTesto("Ripristina", attesa: 2) { sleep(4); foto("ripristina-senza-store", albero: true) }
            chiudi()
        }
        if toccaTesto("Copia di sicurezza") { sleep(3); foto("backup-senza-icloud", albero: true); chiudi() }
        if tocca("tu.privacy.link", attesa: 3) {
            sleep(3); foto("privacy-link")
            app.activate(); sleep(1)
            foto("tornata-nell-app")
        }
    }

    /// T12 · Andrea, 35 · torna dopo mesi · anno precedente e novità delle regole
    func test12_Andrea() {
        avvia("T12")
        foto("netto-anno-corrente", albero: true)
        if tocca("netto.anno") {
            sleep(1); foto("menu-anno", albero: true)
            let anni = app.buttons.matching(NSPredicate(format: "label MATCHES %@", "Il [0-9]{4}"))
            nota("anni nel menu: \(anni.count) · \(anni.allElementsBoundByIndex.map(\.label).joined(separator: ", "))")
            let ultimo = anni.allElementsBoundByIndex.last { $0.isHittable }
            if anni.count > 1, let ultimo { ultimo.tap(); sleep(1); foto("netto-altro-anno", albero: true) }
            else { app.tap(); sleep(1) }
        }
        scheda(1); foto("incassi-altro-anno")
        scheda(3); foto("pagamenti-altro-anno", albero: true)
        scheda(4)
        if tocca("tu.documenti") { sleep(1); foto("documenti"); if tocca("documenti.novita", attesa: 2) { foto("novita", albero: true); chiudi() }; chiudi() }
    }

    /// T13 · Martina, 23 · ha appena aperto la P.IVA · guide, test e video
    func test13_Martina() {
        avvia("T13")
        guard tocca("netto.guide") else { return }
        sleep(1); foto("guide", albero: true)
        if tocca("guide.test") {
            for i in 0..<10 {
                sleep(1); foto("test-domanda-\(i + 1)", albero: i == 0)
                if app.buttons["Ho capito"].exists { foto("test-esito", albero: true); app.buttons["Ho capito"].firstMatch.tap(); break }
                let risposta = i % 3 == 2 ? "No" : "Sì"
                if app.buttons[risposta].exists { app.buttons[risposta].firstMatch.tap(); nota("risposto \(risposta)") } else { nota("nessun pulsante Sì/No"); break }
            }
        }
        if tocca("guide.video") { sleep(2); foto("video-inizio", albero: true); sleep(6); foto("video-dopo-8s"); chiudi() }
        app.swipeUp(); foto("guide-sotto", albero: true)
        if toccaTesto("aprire", attesa: 2) { sleep(1); foto("guida-aprire", albero: true); app.swipeUp(); foto("guida-aprire-sotto"); chiudi() }
        if toccaTesto("chiudere", attesa: 2) { sleep(1); foto("guida-chiudere"); chiudi() }
        chiudi()
    }

    /// T14 · Stefano, 48 · più attività · ricerca con errori di battitura
    func test14_Stefano() {
        avvia("T14", vuoto: true)
        guard tocca("benvenuto.inizia") else { return }
        for testo in ["parucchiera", "idraulco", "sviluppatore software", "62.01.00", "62.01", "ATECO 74.10", "Avvocato", "ingegnere"] {
            misura("ricerca «\(testo)»") { riscrivi(campo("profilo.cerca"), testo) }
            sleep(1); foto("ricerca-\(testo.replacingOccurrences(of: " ", with: "_"))", albero: true)
        }
        riscrivi(campo("profilo.cerca"), "sviluppatore software")
        sleep(1)
        _ = toccaTesto("software") || toccaTesto("informatic")
        for _ in 0..<6 {
            if app.tabBars.buttons.element(boundBy: 0).exists { break }
            if app.buttons["No"].exists { app.buttons["No"].firstMatch.tap() }
            if !tocca("profilo.avanti", attesa: 3) { break }
        }
        scheda(4)
        if toccaTesto("Altre attività") {
            sleep(1); foto("altre-attivita", albero: true)
            let f = app.textFields.firstMatch
            if f.exists { riscrivi(f, "fotografo"); sleep(1); foto("aggiungi-fotografo", albero: true); _ = toccaTesto("fotograf", scorri: true); sleep(1); foto("dopo-aggiunta", albero: true) }
            chiudi()
        }
        scheda(1)
        if tocca("incassi.aggiungi") { sleep(1); foto("nuovo-con-due-lavori", albero: true); chiudi() }
    }

    /// T15 · Valentina, 39 · esperta · fatture elettroniche e fatture lette da foto o PDF
    func test15_Valentina() {
        avvia("T15")
        scheda(1)
        foto("incassi", albero: true)
        if toccaTesto("Importa", attesa: 2) { sleep(2); foto("importa-xml", albero: true); chiudi() }
        if tocca("incassi.aggiungi") {
            sleep(1)
            if tocca("nuovo.leggi", attesa: 2) { sleep(2); foto("leggi-fattura", albero: true); chiudi(); sleep(1) }
            foto("nuovo-incasso-completo", albero: true)
            riscrivi(campo("nuovo.importo"), "2500")
            let cliente = app.textFields["Nome del cliente"].firstMatch
            if cliente.exists { riscrivi(cliente, "Studio Rossi & Figli S.r.l. con un nome molto lungo davvero") }
            let t = app.switches.matching(NSPredicate(format: "label CONTAINS[c] %@", "4%")).firstMatch
            if t.exists { t.tap(); nota("interruttore 4% toccato") }
            let pagata = app.switches.matching(NSPredicate(format: "label CONTAINS[c] %@", "pagato")).firstMatch
            if pagata.exists { pagata.tap(); nota("interruttore «già pagato» toccato") }
            foto("nuovo-compilato", albero: true)
            if app.buttons["Salva"].firstMatch.isEnabled { app.buttons["Salva"].firstMatch.tap() } else { chiudi() }
            sleep(1); foto("incassi-dopo", albero: true)
        }
    }

    /// T16 · Giorgio, 55 · la prova di 14 giorni è finita
    func test16_Giorgio() {
        avvia("T16", extra: ["-uiProvaFinita"])
        sleep(3); foto("apertura-prova-finita", albero: true)
        scheda(1); foto("incassi-prova-finita")
        if tocca("completo.compra", attesa: 3) { sleep(4); foto("compra", albero: true) }
        if toccaTesto("Ripristina", attesa: 2) { sleep(4); foto("ripristina", albero: true) }
        if toccaTesto("codice regalo", attesa: 2) { sleep(2); foto("codice-regalo", albero: true); chiudi() }
    }

    /// T17 · Ilaria, 30 · gira il telefono in orizzontale (gira su iPhone piccolo e grande)
    func test17_Ilaria() {
        avvia("T17")
        XCUIDevice.shared.orientation = .landscapeLeft
        sleep(2)
        for i in 0..<5 { scheda(i); sleep(1); foto("orizzontale-scheda-\(i)", albero: i == 0) }
        scheda(1)
        if tocca("incassi.aggiungi") { sleep(1); foto("orizzontale-nuovo", albero: true); chiudi() }
        scheda(0)
        if tocca("netto.calcolo") { sleep(1); foto("orizzontale-calcolo"); chiudi() }
        XCUIDevice.shared.orientation = .portrait
        sleep(1); foto("di-nuovo-verticale")
    }

    /// T18 · Simone, 43 · impaziente: doppi tocchi, fogli aperti e chiusi, app in background
    func test18_Simone() {
        avvia("T18")
        scheda(1)
        let righePrima = app.cells.count
        let aggiungi = app.buttons["incassi.aggiungi"].firstMatch
        if aggiungi.waitForExistence(timeout: 4) {
            aggiungi.doubleTap()
            sleep(1); foto("doppio-tocco-aggiungi", albero: true)
            chiudi()
            misura("5 aperture e chiusure del nuovo incasso") {
                for _ in 0..<5 { aggiungi.tap(); _ = campo("nuovo.importo").waitForExistence(timeout: 3); chiudi() }
            }
            aggiungi.tap()
            if campo("nuovo.importo").waitForExistence(timeout: 3) {
                campo("nuovo.importo").typeText("777")
                app.buttons["Salva"].firstMatch.doubleTap()
                nota("doppio tocco su Salva")
                sleep(1)
                if campo("nuovo.importo").exists { chiudi() }
            }
            sleep(1)
            let doppi = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "777")).count
                + app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "777")).count
            nota("righe prima \(righePrima), dopo \(app.cells.count) · elementi con 777: \(doppi)")
            foto("dopo-doppio-salva", albero: true)
        }
        // L'app va in background e torna
        scheda(0)
        if tocca("netto.calcolo") {
            XCUIDevice.shared.press(.home)
            sleep(3)
            app.activate()
            sleep(2)
            foto("ritorno-dal-background", albero: true)
            chiudi()
        }
        // Tocchi rapidi su Prova
        scheda(2)
        let cursore = app.sliders["prova.cursore"].firstMatch
        if cursore.waitForExistence(timeout: 3) {
            misura("10 spostamenti del cursore") { for p in [0.1, 0.9, 0.3, 0.7, 0.0, 1.0, 0.5, 0.2, 0.8, 0.4] { cursore.adjust(toNormalizedSliderPosition: CGFloat(p)) } }
            foto("prova-dopo-cursore", albero: true)
        }
    }

    /// T19 · Laura, 50 · attenta alla privacy: blocco, esporta, condivide, cancella tutto
    func test19_Laura() {
        avvia("T19")
        scheda(0)
        if toccaTesto("30 secondi") { sleep(3); foto("anno-in-30-secondi", albero: true); sleep(5); foto("anno-in-30-secondi-dopo"); chiudi() }
        scheda(4)
        foto("tu", albero: true)
        let blocco = app.switches.matching(NSPredicate(format: "label CONTAINS[c] %@", "Face ID")).firstMatch
        if !blocco.waitForExistence(timeout: 2) { app.swipeUp() }
        if blocco.exists {
            blocco.tap(); sleep(2); foto("blocco-acceso", albero: true)
            for nome in ["Ho capito", "OK", "Annulla"] where app.buttons[nome].exists { app.buttons[nome].firstMatch.tap(); break }
        } else { nota("interruttore Face ID NON TROVATO") }
        if tocca("tu.esporta") { sleep(2); foto("esporta", albero: true); chiudi() }
        if toccaTesto("Cancella tutti i dati") {
            sleep(1); foto("conferma-cancella", albero: true)
            if app.buttons["Cancella tutto"].exists { app.buttons["Cancella tutto"].firstMatch.tap(); nota("cancellato tutto") }
            sleep(2); foto("dopo-cancella", albero: true)
        }
    }

    /// T20 · Nicola, 34 · ha aperto la P.IVA a metà anno · promemoria e notifiche negate
    func test20_Nicola() {
        addUIInterruptionMonitor(withDescription: "Notifiche") { avviso in
            for nome in ["Non consentire", "Don’t Allow", "Don't Allow"] where avviso.buttons[nome].exists {
                avviso.buttons[nome].tap(); return true
            }
            return false
        }
        avvia("T20", vuoto: true)
        guard tocca("benvenuto.inizia") else { return }
        riscrivi(campo("profilo.cerca"), "consulente")
        sleep(1)
        _ = toccaTesto("consulen")
        tocca("profilo.avanti")
        sleep(1); foto("domanda-apertura", albero: true)
        let mese = app.buttons["profilo.mese"].firstMatch
        if mese.waitForExistence(timeout: 3) {
            mese.tap(); sleep(1); foto("menu-mesi", albero: true)
            if app.buttons["luglio"].exists { app.buttons["luglio"].firstMatch.tap(); nota("scelto luglio") } else { chiudi() }
            foto("luglio-scelto")
        } else { nota("scelta del mese «profilo.mese» NON TROVATA (forse serve prima l'anno)") }
        for _ in 0..<5 {
            if app.tabBars.buttons.element(boundBy: 0).exists { break }
            if app.buttons["No"].exists { app.buttons["No"].firstMatch.tap() }
            if !tocca("profilo.avanti", attesa: 3) { break }
        }
        scheda(3); sleep(1); foto("pagamenti-meta-anno", albero: true)
        scheda(0); foto("netto-meta-anno", albero: true)
        scheda(4)
        let promemoria = app.switches.matching(NSPredicate(format: "label CONTAINS[c] %@", "Promemoria")).firstMatch
        if promemoria.waitForExistence(timeout: 3) {
            promemoria.tap(); sleep(2); app.tap(); sleep(1)
            foto("promemoria-notifiche-negate", albero: true)
        } else { nota("interruttore Promemoria NON TROVATO") }
        riscrivi(campo("tu.piva"), "12345678901")
        tocca("tu.conferma"); sleep(1); foto("piva-cifra-sbagliata")
    }
}
