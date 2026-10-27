import Foundation
import SwiftUI

// Lo stato dell'app. Tutto resta sul telefono, in un file JSON nella cartella dell'app:
// nessun account, nessun server.

@MainActor
final class Store: ObservableObject {
    static let shared = Store()

    @Published var profilo: Profilo? { didSet { salva() } }
    @Published var fatture: [Fattura] = [] { didSet { salva() } }
    @Published var annoPrecedente = DatiAnnoPrecedente() { didSet { salva() } }
    /// Contributi versati nell'anno in corso; nil = il calcolo usa una stima
    @Published var contributiVersati: Double? { didSet { salva() } }
    /// I pagamenti segnati come fatti, con il giorno
    @Published var pagati: [String: Date] = [:] { didSet { salva() } }
    /// Cambia a ogni incasso segnato: fa partire timbro e vibrazione
    @Published var ultimoIncasso = 0

    /// L'anno dei calcoli
    let anno = Regole.attuali.anno
    private var caricato = false

    private struct Salvataggio: Codable {
        var profilo: Profilo?
        var fatture: [Fattura]
        var annoPrecedente: DatiAnnoPrecedente
        var contributiVersati: Double?
        var pagati: [String: Date]?
    }

    private static var file: URL {
        URL.applicationSupportDirectory.appending(path: "nettolr.json")
    }

    init() {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-uitestVuoto") {
            // Primo avvio, per le foto automatiche del benvenuto
        } else if args.contains("-uitest") {
            caricaEsempio()
        } else {
            carica()
        }
        caricato = true
    }

    // MARK: - Calcoli pronti per le schermate

    var riepilogo: Calcolo.Riepilogo { Calcolo.riepilogo(fatture, anno: anno) }

    var risultato: RisultatoForfettario? {
        guard let profilo else { return nil }
        let r = riepilogo
        return Calcolo.forfettario(profilo, anno: anno, ricavi: r.ricavi, contributiVersati: contributiVersati,
                                   fattureConBollo: r.fattureConBollo)
    }

    /// Incassato in ogni mese dell'anno (1…12)
    var incassiPerMese: [(mese: Int, totale: Double)] {
        (1...12).map { m in
            let tot = fatture.filter { f in
                guard f.incassata else { return false }
                let d = f.dataIncasso ?? f.data
                return Giorno.anno(d) == anno && Giorno.calendario.component(.month, from: d) == m
            }.reduce(0) { $0 + $1.importo }
            return (m, arrotonda(tot))
        }
    }

    var pagamenti: [Pagamento] {
        guard let profilo else { return [] }
        return Pagamenti.anno2026(profilo, precedente: annoPrecedente, fatture: fatture)
    }

    var prossimoPagamento: (data: Date, importo: Double, voci: [Pagamento])? {
        let oggi = Calendar.current.startOfDay(for: Date())
        let futuri = pagamenti.filter { $0.data >= oggi && pagati[$0.id] == nil }
        guard let primo = futuri.first?.data else { return nil }
        let stessoGiorno = futuri.filter { Calendar.current.isDate($0.data, inSameDayAs: primo) }
        return (primo, arrotonda(stessoGiorno.reduce(0) { $0 + $1.importo }), stessoGiorno)
    }

    // MARK: - Azioni

    func aggiungi(_ f: Fattura) {
        fatture.insert(f, at: 0)
        if f.incassata { ultimoIncasso += 1 }
    }

    func aggiungi(_ nuove: [Fattura]) {
        fatture.insert(contentsOf: nuove, at: 0)
    }

    func segnaIncassata(_ id: Fattura.ID, il giorno: Date = Date()) {
        guard let i = fatture.firstIndex(where: { $0.id == id }) else { return }
        fatture[i].incassata = true
        fatture[i].dataIncasso = giorno
        ultimoIncasso += 1
    }

    func annullaIncasso(_ id: Fattura.ID) {
        guard let i = fatture.firstIndex(where: { $0.id == id }) else { return }
        fatture[i].incassata = false
        fatture[i].dataIncasso = nil
    }

    func elimina(_ id: Fattura.ID) {
        fatture.removeAll { $0.id == id }
    }

    func segnaPagato(_ p: Pagamento, _ fatto: Bool) {
        pagati[p.id] = fatto ? Date() : nil
    }

    func cancellaTutto() {
        pagati = [:]
        profilo = nil
        fatture = []
        annoPrecedente = DatiAnnoPrecedente()
        contributiVersati = nil
    }

    // MARK: - Salvataggio

    private func salva() {
        guard caricato, !ProcessInfo.processInfo.arguments.contains("-uitest") else { return }
        let dati = Salvataggio(profilo: profilo, fatture: fatture, annoPrecedente: annoPrecedente, contributiVersati: contributiVersati, pagati: pagati)
        do {
            try FileManager.default.createDirectory(at: URL.applicationSupportDirectory, withIntermediateDirectories: true)
            try JSONEncoder().encode(dati).write(to: Self.file, options: [.atomic, .completeFileProtection])
        } catch {
            print("NettoLR: salvataggio non riuscito: \(error)")
        }
    }

    private func carica() {
        guard let dati = try? Data(contentsOf: Self.file),
              let s = try? JSONDecoder().decode(Salvataggio.self, from: dati) else { return }
        profilo = s.profilo
        fatture = s.fatture
        annoPrecedente = s.annoPrecedente
        contributiVersati = s.contributiVersati
        pagati = s.pagati ?? [:]
    }

    /// Dati di esempio per le foto automatiche (e per le prove): una web designer in Gestione Separata
    private func caricaEsempio() {
        profilo = Profilo(nome: "Giulia", partitaIVA: "", ateco: "74.10.21", annoApertura: 2024, requisitiStartup: true,
                          gestione: .separata, riduzione35: false)
        let d = { (m: Int, g: Int) in Giorno.data(2026, m, g) }
        fatture = [
            Fattura(numero: "14", data: d(10, 20), cliente: "Fondazione Arte Viva", importo: 3_800, incassata: false, origine: .manuale),
            Fattura(numero: "13", data: d(10, 8), cliente: "Studio Bianchi", importo: 2_500, incassata: true, dataIncasso: d(10, 12), origine: .manuale),
            Fattura(numero: "12", data: d(10, 1), cliente: "Rossi & Figli", importo: 1_200, incassata: true, dataIncasso: d(10, 3), origine: .xml),
            Fattura(numero: "11", data: d(9, 26), cliente: "Caffè Duomo", importo: 450, incassata: true, dataIncasso: d(9, 28), origine: .manuale),
            Fattura(numero: "1-10", data: d(9, 1), cliente: "Incassi gennaio–settembre", importo: 24_250, incassata: true, dataIncasso: d(9, 1), origine: .manuale),
        ]
        annoPrecedente = DatiAnnoPrecedente(imposta: 1_240, accontiVersati: 900, contributiGS: 4_800, accontiGSVersati: 3_600)
    }
}
