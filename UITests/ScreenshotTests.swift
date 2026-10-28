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
        app.launchArguments = ["-uitestVuoto"]
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
        app.launchArguments = ["-uitest"]
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
        app.launchArguments = ["-uitest", "-uiDark"]
        app.launch()
        XCTAssertTrue(scheda(0).waitForExistence(timeout: 15))
        sleep(2)
        foto("10-netto-scuro")
        scheda(3).tap(); sleep(2)
        foto("11-pagamenti-scuro")
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
