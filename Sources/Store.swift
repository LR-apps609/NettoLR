import Foundation
import SwiftUI
import UIKit

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
    /// Le ricevute F24 fotografate: pagamento → nome del file in Application Support/Ricevute
    @Published var ricevute: [String: String] = [:] { didSet { salva() } }
    /// Cambia a ogni incasso segnato: fa partire timbro e vibrazione
    @Published var ultimoIncasso = 0
    /// La data dell'ultima novità delle regole già vista in Documenti
    @Published var regoleViste = UserDefaults.standard.string(forKey: "regoleViste") ?? "" {
        didSet { UserDefaults.standard.set(regoleViste, forKey: "regoleViste") }
    }

    /// L'anno che si sta guardando (si cambia in Netto)
    @Published var anno = Regole.attuali.anno
    var regole: Regole { Regole.per(anno: anno) }
    /// I dati dell'anno precedente valgono per l'anno in corso; per gli anni passati restano solo bollo e rate fisse
    private var annoCorrente: Bool { anno == Regole.attuali.anno }
    private var caricato = false

    struct Salvataggio: Codable {
        var profilo: Profilo?
        var fatture: [Fattura]
        var annoPrecedente: DatiAnnoPrecedente
        var contributiVersati: Double?
        var pagati: [String: Date]?
        var ricevute: [String: String]?
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
        // Al primo avvio non c'è niente di «nuovo»: le novità contano da qui in avanti
        if regoleViste.isEmpty { segnaNovitaViste() }
    }

    /// Le novità delle regole dell'anno in corso non ancora viste
    var novitaNuove: [Regole.Novita] {
        (Regole.attuali.novita ?? []).filter { $0.data > regoleViste }
    }

    func segnaNovitaViste() {
        guard let ultima = (Regole.attuali.novita ?? []).map(\.data).max(), ultima > regoleViste else { return }
        regoleViste = ultima
        // Anche durante init (dove didSet non scatta)
        UserDefaults.standard.set(ultima, forKey: "regoleViste")

    }


    // MARK: - Calcoli pronti per le schermate

    var riepilogo: Calcolo.Riepilogo { Calcolo.riepilogo(fatture, anno: anno, r: regole) }

    var risultato: RisultatoForfettario? {
        guard let profilo else { return nil }
        let r = riepilogo
        return Calcolo.forfettario(profilo, anno: anno, ricavi: r.ricavi, contributiVersati: annoCorrente ? contributiVersati : nil,
                                   fattureConBollo: r.fattureConBollo, perAttivita: r.perAttivita.isEmpty ? nil : r.perAttivita)
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
        return Pagamenti.anno(profilo, precedente: annoCorrente ? annoPrecedente : DatiAnnoPrecedente(), fatture: fatture, r: regole)
    }

    /// I pagamenti futuri non ancora segnati come fatti
    var pagamentiDaFare: [Pagamento] {
        let oggi = Calendar.current.startOfDay(for: Date())
        return pagamenti.filter { $0.data >= oggi && pagati[$0.id] == nil }
    }

    /// Cambia quando cambiano i promemoria da programmare
    var chiavePromemoria: String {
        "\(profilo?.promemoria ?? false)|" + pagamentiDaFare.map { "\($0.id)=\($0.importo)" }.joined(separator: ",")
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

    /// Fatture arrivate da «Apri con NettoLR»: l'esito da mostrare in Incassi
    @Published var esitoImport: String?

    /// Legge un file XML aperto da un'altra app e aggiunge le fatture
    func importa(_ url: URL) {
        let accesso = url.startAccessingSecurityScopedResource()
        defer { if accesso { url.stopAccessingSecurityScopedResource() } }
        guard let dati = try? Data(contentsOf: url) else {
            esitoImport = String(localized: "Non riesco ad aprire \(url.lastPathComponent).")
            return
        }
        let letto = LettoreFatturaPA.leggi(dati)
        let nuove = letto.fatture.filter { n in !fatture.contains { $0.numero == n.numero && $0.data == n.data && $0.cliente == n.cliente } }
        aggiungi(nuove)
        var righe = [nuove.isEmpty ? String(localized: "Nessuna fattura nuova in \(url.lastPathComponent).") : String(localized: "Aggiunte \(nuove.count) fatture da \(url.lastPathComponent). Tocca «Sì» quando te le pagano.")]

        righe += letto.errori
        esitoImport = righe.joined(separator: "\n")
    }

    func elimina(_ id: Fattura.ID) {
        fatture.removeAll { $0.id == id }
    }

    func segnaPagato(_ p: Pagamento, _ fatto: Bool) {
        pagati[p.id] = fatto ? Date() : nil
    }

    static var cartellaRicevute: URL { URL.applicationSupportDirectory.appending(path: "Ricevute") }

    /// Salva la foto della ricevuta di un pagamento (JPEG, protetta dal codice dell'iPhone)
    func salvaRicevuta(_ immagine: UIImage, per p: Pagamento) {
        guard let dati = immagine.jpegData(compressionQuality: 0.7) else { return }
        let nome = "ricevuta-\(Int(p.data.timeIntervalSince1970))-\(abs(p.titolo.hashValue)).jpg"
        do {
            try FileManager.default.createDirectory(at: Self.cartellaRicevute, withIntermediateDirectories: true)
            try dati.write(to: Self.cartellaRicevute.appending(path: nome), options: [.atomic, .completeFileProtection])
            ricevute[p.id] = nome
            if pagati[p.id] == nil { pagati[p.id] = Date() }
        } catch {
            print("NettoLR: ricevuta non salvata: \(error)")
        }
    }

    func immagineRicevuta(_ id: String) -> UIImage? {
        guard let nome = ricevute[id] else { return nil }
        return UIImage(contentsOfFile: Self.cartellaRicevute.appending(path: nome).path)
    }

    // MARK: - Copia di sicurezza (file .nettolr da salvare in iCloud Drive o in File)

    /// Tutti i dati in un file, ricevute comprese
    func copiaDiSicurezza() throws -> Data {
        var foto: [String: Data] = [:]
        for (_, nome) in ricevute {
            if let d = try? Data(contentsOf: Self.cartellaRicevute.appending(path: nome)) { foto[nome] = d }
        }
        let copia = Copia(versione: 1, creata: Date(), dati: Salvataggio(profilo: profilo, fatture: fatture, annoPrecedente: annoPrecedente,
                          contributiVersati: contributiVersati, pagati: pagati, ricevute: ricevute), foto: foto)
        return try JSONEncoder().encode(copia)
    }

    /// Rimette i dati da una copia: sostituisce quelli attuali
    func ripristina(_ dati: Data) throws {
        let copia = try JSONDecoder().decode(Copia.self, from: dati)
        try FileManager.default.createDirectory(at: Self.cartellaRicevute, withIntermediateDirectories: true)
        for (nome, d) in copia.foto where !nome.contains("/") {
            try d.write(to: Self.cartellaRicevute.appending(path: nome), options: [.atomic, .completeFileProtection])
        }
        profilo = copia.dati.profilo
        fatture = copia.dati.fatture
        annoPrecedente = copia.dati.annoPrecedente
        contributiVersati = copia.dati.contributiVersati
        pagati = copia.dati.pagati ?? [:]
        ricevute = copia.dati.ricevute ?? [:]
    }

    struct Copia: Codable {
        var versione: Int
        var creata: Date
        var dati: Salvataggio
        var foto: [String: Data]
    }

    func cancellaTutto() {
        try? FileManager.default.removeItem(at: Self.cartellaRicevute)
        ricevute = [:]
        pagati = [:]
        profilo = nil
        fatture = []
        annoPrecedente = DatiAnnoPrecedente()
        contributiVersati = nil
    }

    // MARK: - Salvataggio

    private func salva() {
        guard caricato, !ProcessInfo.processInfo.arguments.contains("-uitest") else { return }
        let dati = Salvataggio(profilo: profilo, fatture: fatture, annoPrecedente: annoPrecedente, contributiVersati: contributiVersati, pagati: pagati, ricevute: ricevute)
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
        ricevute = s.ricevute ?? [:]
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
