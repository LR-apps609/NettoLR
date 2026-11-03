import UIKit
import XCTest

// Le misure delle prestazioni (stampate come «MISURA …» nel registro della compilazione) e l'impronta
// dei risultati: se una modifica per la velocità cambiasse anche un solo numero, l'impronta cambierebbe.

final class PrestazioniTests: XCTestCase {
    let sviluppatore = Profilo(ateco: "62.01.00", annoApertura: 2020, requisitiStartup: false, gestione: .separata, riduzione35: false)
    let parrucchiera = Profilo(ateco: "96.02.01", annoApertura: 2024, requisitiStartup: true, gestione: .artigiani, riduzione35: true)
    let negozio = Profilo(ateco: "47.78.10", annoApertura: 2019, requisitiStartup: false, gestione: .commercianti, riduzione35: false)
    let avvocato = Profilo(ateco: "69.10.10", annoApertura: 2022, requisitiStartup: true, gestione: .cassa, riduzione35: false,
                           cassaAliquota: 0.145, cassaFisso: 2_000)

    // MARK: - Strumenti

    /// Tempo mediano di un blocco, in millisecondi, stampato nel registro
    @discardableResult
    func misura(_ nome: String, volte: Int = 5, _ blocco: () -> Void) -> Double {
        var tempi: [Double] = []
        for _ in 0..<volte {
            let inizio = CFAbsoluteTimeGetCurrent()
            blocco()
            tempi.append((CFAbsoluteTimeGetCurrent() - inizio) * 1_000)
        }
        tempi.sort()
        let mediana = tempi[tempi.count / 2]
        print("MISURA \(nome): \(String(format: "%.2f", mediana)) ms (mediana di \(volte))")
        return mediana
    }

    /// FNV-1a a 64 bit: uguale a ogni esecuzione (hashValue di Swift cambia a ogni avvio)
    func impronta(_ s: String) -> String {
        var h: UInt64 = 0xcbf29ce484222325
        for b in s.utf8 { h = (h ^ UInt64(b)) &* 0x100000001b3 }
        return String(h, radix: 16)
    }

    func n(_ x: Double) -> String { String(format: "%.4f", x) }

    /// Fatture di prova: tante, su due anni, con clienti ripetuti e alcune in attesa
    func fatture(_ quante: Int) -> [Fattura] {
        (0..<quante).map { i in
            let anno = i % 5 == 0 ? 2025 : 2026
            let d = Giorno.data(anno, 1 + i % 12, 1 + i % 28)
            let incassata = i % 7 != 0
            return Fattura(numero: "\(i + 1)", data: d, cliente: "Cliente \(i % 60)", importo: Double(80 + (i * 37) % 2_400),
                           incassata: incassata, dataIncasso: incassata ? d : nil, origine: i % 3 == 0 ? .xml : .manuale,
                           ateco: i % 11 == 0 ? "74.10.21" : nil)
        }
    }

    /// Una fattura elettronica FatturaPA come arriva dallo SDI
    func xml(_ i: Int) -> Data {
        let mese = String(format: "%02d", 1 + i % 12), giorno = String(format: "%02d", 1 + i % 28)
        let importo = String(format: "%.2f", Double(150 + (i * 53) % 3_000))
        return Data("""
        <?xml version="1.0"?><p:FatturaElettronica xmlns:p="http://ivaservizi.agenziaentrate.gov.it/docs/xsd/fatture/v1.2"><FatturaElettronicaHeader>
        <CessionarioCommittente><DatiAnagrafici><Anagrafica><Denominazione>Azienda \(i % 40) Srl</Denominazione></Anagrafica></DatiAnagrafici></CessionarioCommittente>
        </FatturaElettronicaHeader><FatturaElettronicaBody><DatiGenerali><DatiGeneraliDocumento><TipoDocumento>TD01</TipoDocumento>
        <Data>2026-\(mese)-\(giorno)</Data><Numero>\(i + 1)/2026</Numero>
        <ImportoTotaleDocumento>\(importo)</ImportoTotaleDocumento></DatiGeneraliDocumento></DatiGenerali>
        <DatiBeniServizi><DettaglioLinee><NumeroLinea>1</NumeroLinea><Descrizione>Lavoro \(i)</Descrizione><PrezzoTotale>\(importo)</PrezzoTotale></DettaglioLinee>
        <DatiRiepilogo><ImponibileImporto>\(importo)</ImponibileImporto></DatiRiepilogo></DatiBeniServizi></FatturaElettronicaBody></p:FatturaElettronica>
        """.utf8)
    }

    let ricerche = ["web", "faccio siti web", "parrucchiera", "62.01", "6201", "idraulico", "hairdresser", "commercio al dettaglio",
                    "consulente", "47.91.10", "fotografo matrimoni", "traduttrice", "insegnante di yoga", "elettricista", "74"]

    // MARK: - Impronta dei risultati

    /// Netto, tasse, pensione, pagamenti, ricerca ATECO e lettura XML: tutto in una stringa, poi l'impronta
    func testImprontaDeiRisultati() {
        var s = ""
        let profili = [sviluppatore, parrucchiera, negozio, avvocato]
        let elenco = fatture(400)
        for p in profili {
            for anno in [2025, 2026, 2027] {
                for ricavi in stride(from: 0.0, through: 90_000, by: 2_500) {
                    let r = Calcolo.forfettario(p, anno: anno, ricavi: ricavi)
                    s += "\(p.ateco)|\(anno)|\(n(ricavi))|\(n(r.netto))|\(n(r.imposta))|\(n(r.contributi))|\(n(r.imponibile))|\(n(r.bolli))\n"
                }
                let rie = Calcolo.riepilogo(elenco, anno: anno, r: Regole.per(anno: anno))
                s += "rie|\(anno)|\(n(rie.ricavi))|\(n(rie.daIncassare))|\(rie.nIncassate)|\(rie.nDaIncassare)|\(rie.fattureConBollo)|"
                s += rie.perAttivita.sorted { $0.key < $1.key }.map { "\($0.key)=\(n($0.value))" }.joined(separator: ",") + "\n"
            }
            for extra in stride(from: 0.0, through: 20_000, by: 100) {
                let e = Calcolo.seFatturoAncora(p, anno: 2026, ricaviAttuali: 24_000, extra: extra)
                s += "se|\(n(extra))|\(n(e.nettoExtra))|\(e.superaSoglia)|\(e.superaUscitaImmediata)\n"
            }
            let prec = DatiAnnoPrecedente(imposta: 1_240, accontiVersati: 900, contributiGS: 4_800, accontiGSVersati: 3_600, anno: 2025)
            for pag in Pagamenti.anno(p, precedente: prec, fatture: elenco, r: Regole.per(anno: 2026)) {
                s += "pag|\(pag.id)|\(Int(pag.data.timeIntervalSince1970))|\(n(pag.importo))|\(pag.codice)\n"
            }
        }
        for q in ricerche {
            s += "ateco|\(q)|" + Ateco.cerca(q).map { "\($0.versione.rawValue):\($0.codice)" }.joined(separator: ",") + "\n"
        }
        for i in 0..<20 {
            let e = LettoreFatturaPA.leggi(xml(i))
            s += "xml|" + e.fatture.map { "\($0.numero)|\($0.cliente)|\(n($0.importo))|\(Int($0.data.timeIntervalSince1970))" }.joined(separator: ";")
            s += "|" + e.errori.joined(separator: ";") + "\n"
        }
        print("IMPRONTA risultati: \(impronta(s)) (\(s.count) caratteri)")
        // L'impronta misurata prima delle modifiche per la velocità (3 novembre 2026): i risultati devono restare identici
        XCTAssertEqual(impronta(s), "220f0a89b6205a54")
    }

    // MARK: - Misure

    func testMisure() async throws {
        // Avvio: le regole dei tre anni lette dal file
        misura("avvio · regole 2025-2027 lette") { for a in [2025, 2026, 2027] { _ = Regole.carica(anno: a) } }

        // Ricerca ATECO: ogni lettera scritta rifà la ricerca
        _ = Ateco.cerca("web")
        misura("ricerca ATECO · 15 ricerche") { for q in ricerche { _ = Ateco.cerca(q) } }
        misura("ricerca ATECO · «faccio siti web» lettera per lettera") {
            let frase = "faccio siti web"
            for k in 1...frase.count { _ = Ateco.cerca(String(frase.prefix(k))) }
        }

        // Il cursore di «Prova»: lo stesso lavoro che fa la schermata, a ogni passo da 100 €
        let store = await MainActor.run { Store() }
        let primaFatture = await MainActor.run { store.fatture }
        let primoProfilo = await MainActor.run { store.profilo }
        await MainActor.run {
            store.profilo = sviluppatore
            store.fatture = fatture(1_000)
        }
        await MainActor.run {
            let p = sviluppatore
            let passi = 201
            let totale = misura("Prova · 201 passi del cursore, 1000 fatture") {
                for k in 0..<passi {
                    let extra = Double(k * 100)
                    let s = Calcolo.seFatturoAncora(p, anno: store.anno, ricaviAttuali: store.riepilogo.ricavi, extra: extra)
                    let dopo = Calcolo.forfettario(p, anno: store.anno, ricavi: store.riepilogo.ricavi + extra)
                    let prima = Calcolo.forfettario(p, anno: store.anno, ricavi: store.riepilogo.ricavi)
                    _ = (s, dopo, prima)
                }
            }
            print("MISURA Prova · un passo del cursore: \(String(format: "%.3f", totale / Double(passi))) ms")
            misura("Netto · risultato e pagamenti con 1000 fatture") {
                _ = store.risultato
                _ = store.pagamenti
                _ = store.prossimoPagamento
            }

            // «Ti hanno pagato? Sì»: un'azione = salvataggio su disco
            let attesa = store.fatture.filter { !$0.incassata }.prefix(10).map(\.id)
            var i = 0
            misura("Incassi · «Sì» su una fattura (1000 fatture)", volte: 9) {
                store.segnaIncassata(attesa[i % attesa.count])
                store.salvaSubito()     // anche la scrittura su disco, per un confronto onesto con prima
                i += 1
            }

            // Fatture elettroniche: 200 file letti e aggiunti
            let files = (0..<200).map(xml)
            misura("XML · lettura di 200 fatture (solo lettura)", volte: 3) {
                for d in files { _ = LettoreFatturaPA.leggi(d) }
            }
            misura("XML · 200 file letti e aggiunti a 1000 fatture", volte: 1) {
                for d in files { store.aggiungiNuove(LettoreFatturaPA.leggi(d).fatture) }
                store.salvaSubito()
            }
            misura("Copia di sicurezza · 1200 fatture", volte: 3) { _ = try? store.copiaDiSicurezza() }
            misura("Esportazione · CSV dell'anno", volte: 3) { _ = Esporta.csv(Esporta.fatture(store)) }
        }

        // Fattura da foto: il testo letto con Vision (fuori dal thread principale)
        let immagine = UIGraphicsImageRenderer(size: CGSize(width: 1_000, height: 700)).image { _ in
            UIColor.white.setFill()
            UIRectFill(CGRect(x: 0, y: 0, width: 1_000, height: 700))
            let testo = "FATTURA N. 12/2026 del 15/03/2026\nSpett.le Rossi & Figli Srl\nImponibile 1.200,00\nTotale documento EUR 1.202,00"
            (testo as NSString).draw(in: CGRect(x: 40, y: 40, width: 920, height: 620),
                                      withAttributes: [.font: UIFont.systemFont(ofSize: 40)])
        }
        if let cg = immagine.cgImage {
            let inizio = CFAbsoluteTimeGetCurrent()
            let letto = await LettoreCertificato.testo([cg])
            print("MISURA Foto · testo letto da una fattura: \(String(format: "%.2f", (CFAbsoluteTimeGetCurrent() - inizio) * 1_000)) ms (\(letto.count) caratteri)")
        }

        await MainActor.run {
            store.fatture = primaFatture
            store.profilo = primoProfilo
        }
    }
}
