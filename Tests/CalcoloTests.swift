import XCTest

// I test del motore di calcolo: gli stessi casi controllati a mano nella prima bozza.

final class CalcoloTests: XCTestCase {
    let sviluppatore = Profilo(ateco: "62.01.00", annoApertura: 2020, requisitiStartup: false, gestione: .separata, riduzione35: false)
    let parrucchiera = Profilo(ateco: "96.02.01", annoApertura: 2024, requisitiStartup: true, gestione: .artigiani, riduzione35: true)

    func testRegoleCaricate() {
        let r = Regole.attuali
        XCTAssertEqual(r.anno, 2026)
        XCTAssertEqual(r.gestioneSeparata.aliquota.valore, 0.2607)
        XCTAssertEqual(r.fonte(r.gestioneSeparata.aliquota).verificata, true)
        XCTAssertNotEqual(r.fonte(r.irpef.scaglioni).titolo, Fonte.sconosciuta.titolo)
    }

    func testCoefficienti() {
        let casi: [(String, Double)] = [
            ("62.01.00", 0.67), ("74.10.21", 0.78), ("47.82.01", 0.54), ("47.81.01", 0.40), ("46.19.01", 0.62),
            ("45.20.10", 0.40), ("43.21.01", 0.86), ("68.31.00", 0.86), ("56.10.11", 0.40), ("86.90.30", 0.78),
        ]
        for (codice, atteso) in casi {
            XCTAssertEqual(Ateco.gruppo(ateco2007: codice)?.coefficiente, atteso, codice)
        }
        XCTAssertNil(Ateco.gruppo(ateco2007: "6"))
    }

    func testGestioneSeparata30000() {
        let r = Calcolo.forfettario(sviluppatore, anno: 2026, ricavi: 30_000)
        XCTAssertEqual(r.redditoLordo, 20_100)
        XCTAssertEqual(r.contributi, 5_240.07)
        XCTAssertEqual(r.imponibile, 14_859.93)
        XCTAssertEqual(r.imposta, 2_228.99)
        XCTAssertEqual(r.netto, 22_530.94)
    }

    func testArtigianaConRiduzione() {
        let c = Calcolo.contributi(parrucchiera, reddito: 26_800, forfettario: true)
        XCTAssertEqual(c.fissi, 2_938.88)
        XCTAssertEqual(c.variabili, 1_246.75)
        XCTAssertEqual(c.totale, 4_185.63)
        let r = Calcolo.forfettario(parrucchiera, anno: 2026, ricavi: 40_000)
        XCTAssertEqual(r.aliquota, 0.05)
        XCTAssertEqual(r.imposta, arrotonda((26_800 - 4_185.63) * 0.05))
    }

    func testFineStartup() {
        XCTAssertEqual(Calcolo.forfettario(parrucchiera, anno: 2028, ricavi: 1).aliquota, 0.05)
        XCTAssertEqual(Calcolo.forfettario(parrucchiera, anno: 2029, ricavi: 1).aliquota, 0.15)
        XCTAssertNotNil(Calcolo.avvisoFineStartup(parrucchiera, oggi: Giorno.data(2028, 3, 1)))
        XCTAssertNil(Calcolo.avvisoFineStartup(parrucchiera, oggi: Giorno.data(2026, 3, 1)))
    }

    func testContributiVersati() {
        let r = Calcolo.forfettario(sviluppatore, anno: 2026, ricavi: 30_000, contributiVersati: 3_000)
        XCTAssertFalse(r.contributiStimati)
        XCTAssertEqual(r.imponibile, 17_100)
    }

    func testDoveVannoISoldi() {
        let d = Calcolo.doveVannoISoldi(Calcolo.forfettario(sviluppatore, anno: 2026, ricavi: 30_000))
        XCTAssertEqual(arrotonda(d.stato + d.inps + d.te), 100)
    }

    func testCalcoloInverso() {
        let lordo = Calcolo.incassoPerNetto(sviluppatore, anno: 2026, netto: 20_000)
        XCTAssertGreaterThanOrEqual(Calcolo.forfettario(sviluppatore, anno: 2026, ricavi: lordo).netto, 20_000)
        XCTAssertLessThan(Calcolo.forfettario(sviluppatore, anno: 2026, ricavi: lordo - 2).netto, 20_000)
    }

    func testMettereDaParte() {
        let messo = Calcolo.daMettereDaParte(sviluppatore, anno: 2026, ricaviAttuali: 30_000, incasso: 1_000)
        // 1.000 × 67% = 670; INPS 26,07% = 174,67; tasse 15% di 495,33 = 74,30
        XCTAssertEqual(messo, 248.97, accuracy: 0.02)
    }

    func testOrdinario() {
        XCTAssertEqual(Calcolo.irpefLorda(40_000), 10_400)
        XCTAssertEqual(Calcolo.detrazioneLavoroAutonomo(20_000), 772)
        let r = Calcolo.ordinario(sviluppatore, ricavi: 30_000, costi: 3_000)
        XCTAssertEqual(r.netto, arrotonda(30_000 - 3_000 - r.contributi - r.irpef - r.addizionali))
    }

    func testDipendente() {
        let netto = Calcolo.nettoDipendente(ral: 30_000)
        XCTAssertGreaterThan(netto, 20_000)
        XCTAssertLessThan(netto, 24_000)
        let ral = Calcolo.ralEquivalente(netto: netto)
        XCTAssertEqual(ral, 30_000, accuracy: 100)
    }

    func testRiepilogoPrincipioDiCassa() {
        let fatture = [
            Fattura(numero: "1", data: Giorno.data(2025, 12, 20), cliente: "A", importo: 1_000, incassata: true, dataIncasso: Giorno.data(2026, 1, 10), origine: .manuale),
            Fattura(numero: "2", data: Giorno.data(2026, 3, 1), cliente: "B", importo: 500, incassata: false, origine: .manuale),
            Fattura(numero: "3", data: Giorno.data(2026, 4, 1), cliente: "C", importo: 50, incassata: true, dataIncasso: Giorno.data(2026, 4, 2), origine: .manuale),
        ]
        let r = Calcolo.riepilogo(fatture, anno: 2026)
        XCTAssertEqual(r.ricavi, 1_050)
        XCTAssertEqual(r.daIncassare, 500)
        XCTAssertEqual(r.fattureConBollo, 1)
    }

    func testPagamenti() {
        let p = Pagamenti.anno2026(sviluppatore, precedente: DatiAnnoPrecedente(imposta: 1_000, accontiVersati: 800))
        XCTAssertEqual(p.first { $0.data == Giorno.da("2026-07-20") }?.importo, 700)
        XCTAssertEqual(p.first { $0.data == Giorno.da("2026-11-30") }?.importo, 500)
        let piccolo = Pagamenti.anno2026(sviluppatore, precedente: DatiAnnoPrecedente(imposta: 150, accontiVersati: 150))
        XCTAssertEqual(piccolo.count, 1)
        XCTAssertEqual(piccolo.first?.importo, 150)
        let rate = Pagamenti.anno2026(parrucchiera, precedente: DatiAnnoPrecedente())
        XCTAssertEqual(rate.filter { $0.tipo == .pensione }.count, 4)
        XCTAssertEqual(rate.first?.importo, 734.72)
    }

    func testFatturaXML() {
        let xml = """
        <?xml version="1.0"?><p:FatturaElettronica xmlns:p="http://ivaservizi.agenziaentrate.gov.it/docs/xsd/fatture/v1.2"><FatturaElettronicaHeader>
        <CessionarioCommittente><DatiAnagrafici><Anagrafica><Denominazione>Rossi &amp; Figli Srl</Denominazione></Anagrafica></DatiAnagrafici></CessionarioCommittente>
        </FatturaElettronicaHeader><FatturaElettronicaBody><DatiGenerali><DatiGeneraliDocumento><TipoDocumento>TD01</TipoDocumento>
        <Data>2026-03-15</Data><Numero>12/2026</Numero><DatiBollo><BolloVirtuale>SI</BolloVirtuale><ImportoBollo>2.00</ImportoBollo></DatiBollo>
        <ImportoTotaleDocumento>1202.00</ImportoTotaleDocumento></DatiGeneraliDocumento></DatiGenerali></FatturaElettronicaBody></p:FatturaElettronica>
        """
        let esito = LettoreFatturaPA.leggi(Data(xml.utf8))
        XCTAssertEqual(esito.errori, [])
        XCTAssertEqual(esito.fatture.first?.numero, "12/2026")
        XCTAssertEqual(esito.fatture.first?.cliente, "Rossi & Figli Srl")
        XCTAssertEqual(esito.fatture.first?.importo, 1_200)
        XCTAssertEqual(esito.fatture.first.map { Giorno.anno($0.data) }, 2026)
        XCTAssertFalse(LettoreFatturaPA.leggi(Data("non è xml".utf8)).errori.isEmpty)
    }

    func testRicerca() {
        XCTAssertGreaterThan(Ateco.numeroCodici, 2_400)
        XCTAssertEqual(Ateco.cerca("parrucchiera").first?.codice, "96.02.01")
        // Anche in inglese
        XCTAssertEqual(Ateco.cerca("hairdresser").first?.codice, "96.02.01")
        XCTAssertEqual(Ateco.cerca("I'm a plumber").first?.codice, "43.22.01")
        XCTAssertEqual(Ateco.cerca("62.01").first?.codice, "62.01.00")
        XCTAssertEqual(Ateco.cerca("faccio il web designer").first?.codice, "74.10.21")
        // Un codice ATECO 2025 con un solo corrispondente 2007
        let grafica = Ateco.cerca("74.12.01").first
        XCTAssertEqual(grafica?.versione, .v2025)
        XCTAssertEqual(grafica?.codici2007, ["74.10.21"])
        XCTAssertEqual(grafica?.percentuale, "78%")
        // Un codice 2025 che corrisponde a più codici 2007 con percentuali diverse
        let ambiguo = Ateco.cerca("47.91.10").first { $0.versione == .v2025 }
        XCTAssertEqual(ambiguo?.ambiguo, true)
        // Un codice qualunque, fuori dai lavori più comuni
        XCTAssertEqual(Ateco.cerca("01.11.10").first?.percentuale, "67%")
        XCTAssertEqual(Ateco.titolo2007("62.01.00"), "Produzione di software non connesso all'edizione")
    }

    func testPartitaIVA() {
        // Partita IVA dell'Agenzia delle Entrate, pubblica
        XCTAssertTrue(PartitaIVA.valida("06363391001"))
        XCTAssertFalse(PartitaIVA.valida("06363391002"))
        XCTAssertFalse(PartitaIVA.valida("123"))
    }

    func testLeggiEuro() {
        XCTAssertEqual(Formato.leggiEuro("1.234,56"), 1_234.56)
        XCTAssertEqual(Formato.leggiEuro("1234.56"), 1_234.56)
        XCTAssertEqual(Formato.leggiEuro("1.234"), 1_234)
        XCTAssertEqual(Formato.leggiEuro("2.000 €"), 2_000)
    }

    func testGiorniInAttesa() {
        let f = Fattura(numero: "1", data: Giorno.data(2026, 9, 1), cliente: "A", importo: 100, incassata: false, origine: .manuale)
        XCTAssertEqual(Calcolo.giorniInAttesa(f, oggi: Giorno.data(2026, 10, 15)), 44)
        var pagata = f
        pagata.incassata = true
        XCTAssertEqual(Calcolo.giorniInAttesa(pagata, oggi: Giorno.data(2026, 10, 15)), 0)
    }

    func testBolloTrimestrale() {
        // 3 fatture nel 1° trimestre, 2 nel 3°, 1 nel 4°, una sotto soglia
        let d = { (m: Int) in Giorno.data(2026, m, 10) }
        let fatture = [d(1), d(2), d(3), d(8), d(9), d(11)].map {
            Fattura(numero: "x", data: $0, cliente: "A", importo: 500, incassata: true, origine: .manuale)
        } + [Fattura(numero: "y", data: d(2), cliente: "B", importo: 50, incassata: true, origine: .manuale)]
        let b = Pagamenti.bollo(fatture, anno: 2026)
        // 1° e 2° sotto 5.000 €: pagati con il 3° il 30 novembre (6+0+4 = 10 €); il 4° a febbraio (2 €)
        XCTAssertEqual(b.count, 2)
        XCTAssertEqual(b.first?.importo, 10)
        XCTAssertEqual(b.first?.data, Giorno.da("2026-11-30"))
        XCTAssertEqual(b.last?.importo, 2)
        XCTAssertTrue(b.first?.codice.contains("2521 + 2522 + 2523") ?? false)
    }

    func testFormatoEuro() {
        XCTAssertEqual(Formato.euroTondo(2_544.4), "2.544 €")
        XCTAssertEqual(Formato.euro(1_234_567.891), "1.234.567,89 €")
        XCTAssertEqual(Formato.euro(-5_775.03), "-5.775,03 €")
        XCTAssertEqual(Formato.euro(10), "10,00 €")
        XCTAssertEqual(Formato.euroTondo(0), "0 €")
    }

    func testLetturaCertificato() {
        let testo = """
        AGENZIA DELLE ENTRATE
        Attribuzione del numero di partita IVA 06363391001
        Data inizio attività 01/03/2024
        Codice attività 74.12.01 - Grafica di pagine web
        Altro numero 27.10.2026
        """
        let t = LettoreCertificato.cerca(in: testo)
        XCTAssertEqual(t.partitaIVA, "06363391001")
        XCTAssertEqual(t.codici.first?.codice, "74.12.01")
        XCTAssertEqual(t.codici.first?.codici2007, ["74.10.21"])
        XCTAssertEqual(t.codici.count, 1)
    }

    func testCSV() {
        let f = Fattura(numero: "3", data: Giorno.data(2026, 3, 5), cliente: "Rossi \"Il Bello\"", importo: 1_234.5,
                        incassata: true, dataIncasso: Giorno.data(2026, 3, 20), origine: .manuale)
        let csv = Esporta.csv([f])
        XCTAssertTrue(csv.hasPrefix("\u{FEFF}Numero;Data fattura"))
        XCTAssertTrue(csv.contains("3;05/03/2026;\"Rossi \"\"Il Bello\"\"\";1234,50;sì;20/03/2026"))
    }

    func testPiuAttivita() {
        // Web designer (78%) e vendita online (40%): 20.000 + 10.000
        var p = Profilo(ateco: "74.10.21", annoApertura: 2020, requisitiStartup: false, gestione: .separata, riduzione35: false)
        p.altreAttivita = ["47.91.10"]
        XCTAssertEqual(p.attivita, ["74.10.21", "47.91.10"])
        let fatture = [
            Fattura(numero: "1", data: Giorno.data(2026, 2, 1), cliente: "A", importo: 20_000, incassata: true, dataIncasso: Giorno.data(2026, 2, 1), origine: .manuale),
            Fattura(numero: "2", data: Giorno.data(2026, 3, 1), cliente: "B", importo: 10_000, incassata: true, dataIncasso: Giorno.data(2026, 3, 1), origine: .manuale, ateco: "47.91.10"),
        ]
        let riep = Calcolo.riepilogo(fatture, anno: 2026)
        XCTAssertEqual(riep.perAttivita, ["47.91.10": 10_000])
        let r = Calcolo.forfettario(p, anno: 2026, ricavi: riep.ricavi, perAttivita: riep.perAttivita)
        XCTAssertEqual(r.redditoLordo, 20_000 * 0.78 + 10_000 * 0.40)
        // Senza assegnazioni resta tutto alla principale
        XCTAssertEqual(Calcolo.forfettario(p, anno: 2026, ricavi: 30_000).redditoLordo, 23_400)
    }

    func testRegole2025() {
        let r = Regole.per(anno: 2025)
        XCTAssertEqual(r.anno, 2025)
        XCTAssertEqual(r.artigianiCommercianti.artigiani.fissoAnnuo.valore, 4_460.64)
        XCTAssertEqual(r.irpef.scaglioni.valore[1].aliquota, 0.35)
        XCTAssertEqual(Regole.per(anno: 2031).anno, 2026)
        // Il calcolo del 2025 usa le regole 2025 (minimale 18.555 €)
        let c25 = Calcolo.forfettario(parrucchiera, anno: 2025, ricavi: 0).contributi
        XCTAssertEqual(c25, arrotonda(4_460.64 * 0.65))
        // Pagamenti 2025 con le date 2025
        let pag = Pagamenti.anno(sviluppatore, precedente: DatiAnnoPrecedente(imposta: 1_000, accontiVersati: 800), r: r)
        XCTAssertEqual(pag.first?.data, Giorno.da("2025-07-21"))
        XCTAssertEqual(Calcolo.irpefLorda(40_000, r: r), 6_440 + 12_000 * 0.35)
    }

    @MainActor
    func testCopiaDiSicurezza() throws {
        let store = Store.shared
        let prima = store.fatture
        let primoProfilo = store.profilo
        store.profilo = sviluppatore
        store.fatture = [Fattura(numero: "1", data: Giorno.data(2026, 1, 2), cliente: "A", importo: 10, incassata: true, origine: .manuale)]
        let copia = try store.copiaDiSicurezza()
        store.fatture = []
        try store.ripristina(copia)
        XCTAssertEqual(store.fatture.count, 1)
        XCTAssertEqual(store.profilo?.ateco, "62.01.00")
        XCTAssertThrowsError(try store.ripristina(Data("{}".utf8)))
        store.fatture = prima
        store.profilo = primoProfilo
    }

    func testLetturaFatturaDaFoto() {
        let testo = """
        Giulia Verdi - Web designer
        P.IVA 06363391001
        FATTURA N. 14/2026
        Data 20/10/2026
        Spett.le
        Fondazione Arte Viva
        Via Roma 1, 20100 Milano
        Realizzazione sito web 3.800,00
        Marca da bollo 2,00
        Totale documento
        € 3.802,00
        """
        let p = LettoreFatturaFoto.analizza(testo)
        XCTAssertEqual(p.importo, 3802)
        XCTAssertEqual(p.numero, "14/2026")
        XCTAssertEqual(p.cliente, "Fondazione Arte Viva")
        XCTAssertEqual(p.data, Giorno.data(2026, 10, 20))
        // Anni, CAP, partite IVA e telefoni non sono importi
        XCTAssertEqual(LettoreFatturaFoto.importi(in: "CAP 20100 · P.IVA 06363391001 · tel 3331234567 · 2026"), [])
        XCTAssertEqual(LettoreFatturaFoto.importi(in: "Cliente: Rossi Srl  450.00"), [450])
        XCTAssertEqual(LettoreFatturaFoto.analizza("Cliente: Rossi & Figli Srl\nTotale 1.200,00").cliente, "Rossi & Figli Srl")
        XCTAssertTrue(LettoreFatturaFoto.analizza("niente di utile qui").vuota)
    }
}
