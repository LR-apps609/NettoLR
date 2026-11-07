import XCTest

// Sequenze di prova per trovare bug: tocchi ripetuti, fogli aperti e chiusi, valori limite, schede cambiate in fretta.
// Girano su più iPhone (piccolo, medio, grande) con il workflow «Prova su più iPhone».
// Ogni prova controlla che l'app sia ancora viva e al suo posto; in caso di errore allega la foto dello schermo.
final class SequenzeTests: XCTestCase {
    private let app = XCUIApplication()

    override func setUp() {
        continueAfterFailure = false
    }

    override func tearDown() {
        if let run = testRun, run.failureCount > 0 {
            let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            a.name = "errore-\(name)"
            a.lifetime = .keepAlways
            add(a)
        }
    }

    private func avvia(_ extra: [String] = [], lingua: String = "it") {
        app.launchArguments = ["-uitest", "-AppleLanguages", "(\(lingua))", "-AppleLocale", lingua == "it" ? "it_IT" : "en_GB"] + extra
        app.launch()
        XCTAssertTrue(app.tabBars.buttons.element(boundBy: 0).waitForExistence(timeout: 20), "L'app non si è aperta")
    }

    private func scheda(_ i: Int) { app.tabBars.buttons.element(boundBy: i).tap() }

    private func viva(_ dove: String) {
        XCTAssertEqual(app.state, .runningForeground, "L'app si è chiusa: \(dove)")
        XCTAssertTrue(app.tabBars.firstMatch.exists || app.sheets.count > 0 || app.otherElements.count > 0, dove)
    }

    @discardableResult
    private func tocca(_ id: String, timeout: TimeInterval = 4) -> Bool {
        let e = app.buttons[id].firstMatch
        guard e.waitForExistence(timeout: timeout), e.isHittable else { return false }
        e.tap()
        return true
    }

    private func chiudi() {
        for nome in ["Fatto", "Done", "Chiudi", "Close", "Annulla", "Cancel"] {
            let b = app.navigationBars.buttons[nome].firstMatch
            if b.exists && b.isHittable { b.tap(); return }
            let c = app.buttons[nome].firstMatch
            if c.exists && c.isHittable { c.tap(); return }
        }
        // Foglio senza pulsante: si chiude trascinando
        app.swipeDown(velocity: .fast)
    }

    /// Le cinque schede cambiate in fretta, tre giri, anche in modo scuro e in inglese
    func testSchedeInFretta() {
        avvia()
        for giro in 0..<3 {
            for i in [0, 4, 1, 3, 2, 0] { scheda(i) }
            viva("giro \(giro)")
        }
    }

    func testSchedeInFrettaScuroInglese() {
        XCUIDevice.shared.appearance = .dark
        avvia(["-uiDark"], lingua: "en")
        for i in [0, 1, 2, 3, 4, 0] { scheda(i); viva("scheda \(i)") }
        XCUIDevice.shared.appearance = .light
    }

    /// Nuovo incasso: aperto e annullato cinque volte, poi uno salvato e uno con cifre strane
    func testNuovoIncassoAnnullaESalva() {
        avvia()
        scheda(1)
        for _ in 0..<5 {
            XCTAssertTrue(tocca("incassi.aggiungi"))
            let importo = app.textFields["nuovo.importo"]
            XCTAssertTrue(importo.waitForExistence(timeout: 4))
            importo.typeText("12,5")
            app.buttons["Annulla"].firstMatch.tap()
            viva("annulla")
        }
        for cifra in ["1500", "0", "99999999999999", "abc", "1.234,56"] {
            XCTAssertTrue(tocca("incassi.aggiungi"))
            let importo = app.textFields["nuovo.importo"]
            XCTAssertTrue(importo.waitForExistence(timeout: 4))
            importo.typeText(cifra)
            let salva = app.buttons["Salva"].firstMatch
            if salva.isEnabled { salva.tap() } else { app.buttons["Annulla"].firstMatch.tap() }
            viva("cifra \(cifra)")
        }
        scheda(0)
        viva("netto dopo gli incassi")
    }

    /// I fogli di Netto aperti e chiusi più volte, anche andando in secondo piano con un foglio aperto
    func testFogliDiNetto() {
        avvia()
        for id in ["netto.calcolo", "netto.guide", "netto.calcolo"] {
            if tocca(id) { chiudi() }
            viva(id)
        }
        if tocca("netto.calcolo") {
            XCUIDevice.shared.press(.home)
            sleep(2)
            app.activate()
            viva("ritorno con il foglio aperto")
            chiudi()
        }
        XCTAssertTrue(app.staticTexts["netto.avvertenza"].waitForExistence(timeout: 4), "Manca «È un calcolo, non una consulenza fiscale»")
    }

    /// Il cambio d'anno in Netto e poi le altre schede: nessun numero deve far chiudere l'app
    func testCambioAnno() {
        avvia()
        guard tocca("netto.anno") else { return }
        for voce in app.buttons.allElementsBoundByIndex.prefix(8) where voce.label.contains("20") && voce.isHittable {
            voce.tap()
            viva("anno \(voce.label)")
            for i in [1, 2, 3, 0] { scheda(i) }
            if !tocca("netto.anno") { break }
        }
        chiudi()
        viva("fine cambio anno")
    }

    /// Il cursore di Prova agli estremi e i fogli delle domande
    func testProvaEstremi() {
        avvia()
        scheda(2)
        let cursore = app.sliders["prova.cursore"]
        if cursore.waitForExistence(timeout: 4) {
            for v in [0.0, 1.0, 0.5, 0.0, 1.0] { cursore.adjust(toNormalizedSliderPosition: v); viva("cursore \(v)") }
        }
        for id in ["prova.conviene", "prova.obiettivo", "prova.dipendente"] {
            if tocca(id) { chiudi() }
            viva(id)
        }
    }

    /// Tu: partita IVA sbagliata, giusta, vuota; documenti ed esporta aperti e chiusi
    func testTuPartitaIVAEFogli() {
        avvia()
        scheda(4)
        let piva = app.textFields["tu.piva"]
        if piva.waitForExistence(timeout: 4) {
            for valore in ["06363391002", "12345678903", "", "abcdefghijk"] {
                piva.tap()
                if let v = piva.value as? String, !v.isEmpty, v != piva.placeholderValue {
                    piva.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: v.count))
                }
                piva.typeText(valore)
                if tocca("tu.conferma", timeout: 2) {}
                viva("partita IVA \(valore)")
            }
        }
        for id in ["tu.documenti", "tu.esporta", "tu.completo"] {
            app.swipeUp()
            if tocca(id) { chiudi() }
            viva(id)
        }
        XCTAssertTrue(app.links["Privacy completa"].exists || app.buttons["tu.privacy.link"].exists || app.otherElements["tu.privacy.link"].exists,
                      "Manca il link alla privacy in Tu")
    }

    /// Primo avvio completo con il testo più grande: il benvenuto si deve poter finire
    func testBenvenutoTestoGrande() {
        app.launchArguments = ["-uitestVuoto", "-AppleLanguages", "(it)", "-AppleLocale", "it_IT",
                               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(tocca("benvenuto.inizia", timeout: 10), "«Iniziamo» non si raggiunge col testo grande")
        let cerca = app.textFields["profilo.cerca"]
        XCTAssertTrue(cerca.waitForExistence(timeout: 5))
        cerca.tap()
        cerca.typeText("parrucchiera")
        sleep(1)
        viva("ricerca del lavoro")
    }
}
