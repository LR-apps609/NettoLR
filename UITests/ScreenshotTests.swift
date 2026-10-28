import XCTest

// Un giro dell'app nel simulatore, con una foto per ogni schermata.
// Le foto finiscono nella cartella indicata da SCREENSHOT_DIR (la imposta il workflow su GitHub)
// e negli allegati del risultato del test.
final class ScreenshotTests: XCTestCase {
    private let app = XCUIApplication()

    override func setUp() {
        continueAfterFailure = true
    }

    private func scheda(_ i: Int) -> XCUIElement { app.tabBars.buttons.element(boundBy: i) }

    func test1Benvenuto() {
        XCUIDevice.shared.appearance = .light
        app.launchArguments = ["-uitestVuoto", "-AppleLanguages", "(it)", "-AppleLocale", "it_IT"]
        app.launch()
        sleep(2)
        foto("00-benvenuto")
        let inizia = app.buttons["benvenuto.inizia"]
        if inizia.waitForExistence(timeout: 5) {
            inizia.tap()
            sleep(1)
            let cerca = app.textFields["profilo.cerca"]
            if cerca.waitForExistence(timeout: 3) {
                cerca.tap()
                cerca.typeText("parrucchiera")
                sleep(1)
            }
            foto("01-domanda-lavoro")
        }
    }

    func test2Giro() {
        XCUIDevice.shared.appearance = .light
        app.launchArguments = ["-uitest", "-AppleLanguages", "(it)", "-AppleLocale", "it_IT"]
        app.launch()
        XCTAssertTrue(scheda(0).waitForExistence(timeout: 15))
        sleep(2)
        foto("02-netto")

        let calcolo = app.buttons["netto.calcolo"]
        if calcolo.waitForExistence(timeout: 3) {
            calcolo.tap()
            sleep(1)
            foto("03-come-lo-calcolo")
            app.buttons["Fatto"].firstMatch.tap()
            sleep(1)
        }

        let guide = app.buttons["netto.guide"]
        if guide.waitForExistence(timeout: 3) {
            guide.tap()
            sleep(1)
            foto("03b-guide")
            let video = app.buttons["guide.video"]
            if video.waitForExistence(timeout: 3) {
                video.tap()
                sleep(3)
                foto("03c-video")
                app.buttons["Chiudi"].firstMatch.tap()
                sleep(1)
            }
            app.buttons["Fatto"].firstMatch.tap()
            sleep(1)
        }

        scheda(1).tap(); sleep(2)
        foto("04-incassi")
        let aggiungi = app.buttons["incassi.aggiungi"]
        if aggiungi.waitForExistence(timeout: 3) {
            aggiungi.tap()
            sleep(1)
            app.textFields["nuovo.importo"].typeText("1500")
            sleep(1)
            foto("05-nuovo-incasso")
            app.buttons["Annulla"].firstMatch.tap()
            sleep(1)
        }

        scheda(2).tap(); sleep(2)
        foto("06-prova")
        let conviene = app.buttons["prova.conviene"]
        if conviene.waitForExistence(timeout: 3) {
            conviene.tap()
            sleep(1)
            foto("07-mi-conviene")
            app.buttons["Fatto"].firstMatch.tap()
            sleep(1)
        }

        scheda(3).tap(); sleep(2)
        foto("08-pagamenti")

        scheda(4).tap(); sleep(1)
        foto("09-tu")
        let piva = app.textFields["tu.piva"]
        if piva.waitForExistence(timeout: 3) {
            piva.tap()
            piva.typeText("06363391002")
            app.buttons["tu.conferma"].tap()
            sleep(1)
            foto("09b-piva-sbagliata")
        }
    }

    func test3Scuro() {
        XCUIDevice.shared.appearance = .dark
        app.launchArguments = ["-uitest", "-uiDark", "-AppleLanguages", "(it)", "-AppleLocale", "it_IT"]
        app.launch()
        XCTAssertTrue(scheda(0).waitForExistence(timeout: 15))
        sleep(2)
        foto("10-netto-scuro")
        scheda(3).tap(); sleep(2)
        foto("11-pagamenti-scuro")
    }

    /// La versione inglese: le stesse schermate con l'iPhone in inglese
    func test4Inglese() {
        XCUIDevice.shared.appearance = .light
        app.launchArguments = ["-uitest", "-uiProva", "-AppleLanguages", "(en)", "-AppleLocale", "en_GB"]
        app.launch()
        XCTAssertTrue(scheda(0).waitForExistence(timeout: 15))
        sleep(2)
        foto("12-en-netto")
        if tocca("netto.calcolo") { foto("13-en-come-lo-calcolo"); chiudi() }
        if tocca("netto.guide") {
            foto("13b-en-guide")
            if tocca("guide.video") { sleep(2); foto("13c-en-video"); chiudi() }
            if tocca("guide.test") { foto("13d-en-test"); chiudi() }
            chiudi()
        }
        scheda(1).tap(); sleep(2)
        foto("14-en-incassi")
        if tocca("incassi.aggiungi") { foto("14b-en-nuovo-incasso"); chiudi() }
        scheda(2).tap(); sleep(2)
        foto("14c-en-prova")
        if tocca("prova.conviene") { foto("14d-en-mi-conviene"); chiudi() }
        scheda(3).tap(); sleep(2)
        foto("14e-en-pagamenti")
        scheda(4).tap(); sleep(1)
        foto("15-en-tu")
        if tocca("tu.completo") { sleep(1); foto("15b-en-completo"); chiudi() }
        app.swipeUp(); sleep(1)
        foto("15c-en-tu-sotto")
    }

    /// Il benvenuto in inglese
    func test5BenvenutoInglese() {
        XCUIDevice.shared.appearance = .light
        app.launchArguments = ["-uitestVuoto", "-AppleLanguages", "(en)", "-AppleLocale", "en_GB"]
        app.launch()
        sleep(2)
        foto("16-en-benvenuto")
        if tocca("benvenuto.inizia") {
            let cerca = app.textFields["profilo.cerca"]
            if cerca.waitForExistence(timeout: 3) {
                cerca.tap()
                cerca.typeText("hairdresser")
                sleep(1)
            }
            foto("17-en-domanda-lavoro")
        }
    }

    /// Testo molto grande (accessibilità) e la schermata dell'abbonamento in italiano
    func test6TestoGrande() {
        XCUIDevice.shared.appearance = .light
        app.launchArguments = ["-uitest", "-uiProva", "-AppleLanguages", "(it)", "-AppleLocale", "it_IT",
                               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityL"]
        app.launch()
        XCTAssertTrue(scheda(0).waitForExistence(timeout: 15))
        sleep(2)
        foto("18-grande-netto")
        scheda(1).tap(); sleep(2)
        foto("19-grande-incassi")
        scheda(3).tap(); sleep(2)
        foto("20-grande-pagamenti")
        scheda(4).tap(); sleep(1)
        foto("21-grande-tu")
        if tocca("tu.completo") { sleep(1); foto("22-grande-completo"); chiudi() }
    }

    /// Tocca un elemento se c'è (pulsante con quell'identificativo)

    @discardableResult
    private func tocca(_ id: String) -> Bool {
        let e = app.buttons[id]
        guard e.waitForExistence(timeout: 3) else { return false }
        e.tap()
        sleep(1)
        return true
    }

    /// Chiude il foglio aperto, in italiano o in inglese
    private func chiudi() {
        for nome in ["Done", "Fatto", "Close", "Chiudi", "Cancel", "Annulla"] {
            let b = app.buttons[nome].firstMatch
            if b.exists && b.isHittable { b.tap(); sleep(1); return }
        }
    }

    private func foto(_ nome: String) {

        let immagine = XCUIScreen.main.screenshot()
        let allegato = XCTAttachment(screenshot: immagine)
        allegato.name = nome
        allegato.lifetime = .keepAlways
        add(allegato)
        if let cartella = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"] {
            try? FileManager.default.createDirectory(atPath: cartella, withIntermediateDirectories: true)
            try? immagine.pngRepresentation.write(to: URL(fileURLWithPath: cartella).appendingPathComponent("\(nome).png"))
        }
    }
}
