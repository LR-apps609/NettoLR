import Foundation
import SwiftUI
import UIKit

// Lo stato dell'app. Tutto resta sul telefono, in un file JSON nella cartella dell'app:
// nessun account, nessun server.

@MainActor
final class Store: ObservableObject {
    static let shared = Store()

    @Published var profilo: Profilo? { didSet { salva() } }
    @Published var fatture: [Fattura] = [] { didSet { riepilogoPronto = nil; salva() } }
    @Published var annoPrecedente = DatiAnnoPrecedente() { didSet { salva() } }
    /// Contributi versati nell'anno in corso; nil = il calcolo usa una stima
    @Published var contributiVersati: Double? { didSet { salva() } }
    /// L'anno dei contributi versati: l'anno dopo non valgono più
    @Published var contributiVersatiAnno: Int? { didSet { salva() } }
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
    @Published var anno = Regole.attuali.anno { didSet { riepilogoPronto = nil } }
    var regole: Regole { Regole.per(anno: anno) }
    /// I dati dell'anno precedente valgono per l'anno in corso; per gli anni passati restano solo bollo e rate fisse
    private var annoCorrente: Bool { anno == Regole.attuali.anno }
    private var caricato = false
    /// Il file c'è ma non si è potuto leggere: niente salvataggi, per non sovrascriverlo
    private var nonSalvare = false

    struct Salvataggio: Codable {
        var profilo: Profilo?
        var fatture: [Fattura]
        var annoPrecedente: DatiAnnoPrecedente
        var contributiVersati: Double?
        var pagati: [String: Date]?
        var ricevute: [String: String]?
        var contributiVersatiAnno: Int?
        /// Le fatture che non si sono potute leggere (il file resta copiato da parte)
        var fattureScartate = 0

        enum CodingKeys: String, CodingKey {
            case profilo, fatture, annoPrecedente, contributiVersati, pagati, ricevute, contributiVersatiAnno
        }

        init(profilo: Profilo?, fatture: [Fattura], annoPrecedente: DatiAnnoPrecedente, contributiVersati: Double?,
             pagati: [String: Date]?, ricevute: [String: String]?, contributiVersatiAnno: Int?) {
            self.profilo = profilo; self.fatture = fatture; self.annoPrecedente = annoPrecedente
            self.contributiVersati = contributiVersati; self.pagati = pagati; self.ricevute = ricevute
            self.contributiVersatiAnno = contributiVersatiAnno
        }

        /// Ogni parte si legge da sola: un campo nuovo o una fattura rovinata non fanno perdere il resto
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            profilo = try c.decodeIfPresent(Profilo.self, forKey: .profilo)
            let elenco = (try? c.decodeIfPresent([Tollerante<Fattura>].self, forKey: .fatture)) ?? []
            fatture = elenco.compactMap(\.valore)
            fattureScartate = elenco.count - fatture.count
            annoPrecedente = (try? c.decodeIfPresent(DatiAnnoPrecedente.self, forKey: .annoPrecedente)) ?? DatiAnnoPrecedente()
            contributiVersati = try? c.decodeIfPresent(Double.self, forKey: .contributiVersati)
            pagati = try? c.decodeIfPresent([String: Date].self, forKey: .pagati)
            ricevute = try? c.decodeIfPresent([String: String].self, forKey: .ricevute)
            contributiVersatiAnno = try? c.decodeIfPresent(Int.self, forKey: .contributiVersatiAnno)
        }
    }

    /// Il salvataggio non si è letto del tutto: la copia del file è da parte e l'utente lo deve sapere
    @Published var avvisoSalvataggio: String?

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
        // I dati vecchi appena timbrati con il loro anno si riscrivono subito
        salva()
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

    /// Il riepilogo delle fatture, calcolato una volta e riusato finché non cambiano fatture o anno
    /// (il cursore di «Prova» lo chiede a ogni passo: con 1000 fatture erano 31 ms a passo)
    private var riepilogoPronto: Calcolo.Riepilogo?

    var riepilogo: Calcolo.Riepilogo {
        if let r = riepilogoPronto { return r }
        let r = Calcolo.riepilogo(fatture, anno: anno, r: regole)
        riepilogoPronto = r
        return r
    }

    /// I dati dell'anno precedente, solo se sono davvero dell'anno prima di quello in corso
    var annoPrecedenteValido: DatiAnnoPrecedente {
        (annoPrecedente.anno ?? Regole.attuali.anno - 1) == Regole.attuali.anno - 1 ? annoPrecedente : DatiAnnoPrecedente()
    }

    /// I contributi versati, solo se inseriti per l'anno in corso
    var contributiVersatiValidi: Double? {
        (contributiVersatiAnno ?? Regole.attuali.anno) == Regole.attuali.anno ? contributiVersati : nil
    }

    /// I contributi versati da usare nei calcoli dell'anno guardato (solo per l'anno in corso)
    var contributiPerCalcolo: Double? { annoCorrente ? contributiVersatiValidi : nil }
    /// Gli incassi per attività, se ce n'è più di una
    var perAttivitaPerCalcolo: [String: Double]? { riepilogo.perAttivita.isEmpty ? nil : riepilogo.perAttivita }

    var risultato: RisultatoForfettario? {
        guard let profilo else { return nil }
        let r = riepilogo
        return Calcolo.forfettario(profilo, anno: anno, ricavi: r.ricavi, contributiVersati: annoCorrente ? contributiVersatiValidi : nil,
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

    var pagamenti: [Pagamento] { pagamenti(anno: anno) }

    /// I pagamenti che cadono in un anno: quelli del suo calendario, più quelli dell'anno prima che scadono
    /// a inizio anno (quarta rata fissa INPS, bollo del quarto trimestre)
    func pagamenti(anno: Int) -> [Pagamento] {
        guard let profilo else { return [] }
        let r = Regole.per(anno: anno)
        let corrente = anno == Regole.attuali.anno
        // I dati dell'anno prima valgono per l'anno giusto (anche guardando un anno passato)
        let giusto = annoPrecedente.anno.map { $0 == anno - 1 } ?? corrente
        let precedente = giusto ? annoPrecedente : DatiAnnoPrecedente()
        var out = Pagamenti.anno(profilo, precedente: precedente, fatture: fatture, r: r)
        if Regole.anniDisponibili.contains(anno - 1) {
            out += Pagamenti.anno(profilo, precedente: DatiAnnoPrecedente(), fatture: fatture, r: Regole.per(anno: anno - 1))
                .filter { Giorno.anno($0.data) == anno }
        }
        return out.sorted { $0.data < $1.data }
    }

    /// I pagamenti futuri non ancora segnati come fatti, dell'anno che si sta guardando
    var pagamentiDaFare: [Pagamento] {
        let oggi = Calendar.current.startOfDay(for: Date())
        return pagamenti.filter { $0.data >= oggi && pagati[$0.id] == nil }
    }

    /// I promemoria valgono sempre per l'anno in corso, qualunque anno si stia guardando in Netto
    var pagamentiPromemoria: [Pagamento] {
        let oggi = Calendar.current.startOfDay(for: Date())
        return pagamenti(anno: Regole.attuali.anno).filter { $0.data >= oggi && pagati[$0.id] == nil }
    }

    /// Cambia quando cambiano i promemoria da programmare
    var chiavePromemoria: String {
        "\(profilo?.promemoria ?? false)|" + pagamentiPromemoria.map { "\($0.id)=\($0.importo)" }.joined(separator: ",")
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

    /// Aggiunge solo le fatture che non ci sono già (stesso numero, data e cliente): importare due volte lo stesso file non raddoppia gli incassi
    @discardableResult
    func aggiungiNuove(_ lette: [Fattura]) -> [Fattura] {
        struct Chiave: Hashable { let numero: String, data: Date, cliente: String }
        var viste = Set(fatture.map { Chiave(numero: $0.numero, data: $0.data, cliente: $0.cliente) })
        var nuove: [Fattura] = []
        for n in lette where viste.insert(Chiave(numero: n.numero, data: n.data, cliente: n.cliente)).inserted {
            nuove.append(n)
        }
        aggiungi(nuove)
        return nuove
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
        let letto = LettoreFatturaPA.leggi(dati, partitaIVA: profilo?.partitaIVA)
        let nuove = aggiungiNuove(letto.fatture)
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
                          contributiVersati: contributiVersati, pagati: pagati, ricevute: ricevute, contributiVersatiAnno: contributiVersatiAnno), foto: foto)
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
        if annoPrecedente.anno == nil, annoPrecedente != DatiAnnoPrecedente() { annoPrecedente.anno = Giorno.anno(copia.creata) - 1 }
        contributiVersati = copia.dati.contributiVersati
        contributiVersatiAnno = copia.dati.contributiVersatiAnno ?? (copia.dati.contributiVersati == nil ? nil : Giorno.anno(copia.creata))
        pagati = Self.migra(copia.dati.pagati ?? [:])
        ricevute = Self.migra(copia.dati.ricevute ?? [:])
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
        contributiVersatiAnno = nil
    }

    // MARK: - Salvataggio

    /// C'è un salvataggio già in programma: più modifiche nella stessa azione diventano una scrittura sola
    private var salvataggioInProgramma = false

    /// Ogni modifica chiede un salvataggio; il file si scrive una volta sola, appena finita l'azione
    /// (un «Sì» su una fattura cambia due campi; 200 fatture XML lette sono 200 aggiunte)
    private func salva() {
        guard caricato, !nonSalvare, !salvataggioInProgramma else { return }
        salvataggioInProgramma = true
        Task { @MainActor [weak self] in self?.salvaSubito() }
    }

    /// Scrive adesso le modifiche in attesa (anche quando l'app va in secondo piano)
    func salvaSubito() {
        guard salvataggioInProgramma else { return }
        salvataggioInProgramma = false
        guard caricato, !nonSalvare, !ProcessInfo.processInfo.arguments.contains(where: { $0.hasPrefix("-uitest") }) else { return }
        let dati = Salvataggio(profilo: profilo, fatture: fatture, annoPrecedente: annoPrecedente, contributiVersati: contributiVersati,
                               pagati: pagati, ricevute: ricevute, contributiVersatiAnno: contributiVersatiAnno)
        do {
            try FileManager.default.createDirectory(at: URL.applicationSupportDirectory, withIntermediateDirectories: true)
            try JSONEncoder().encode(dati).write(to: Self.file, options: [.atomic, .completeFileProtection])
        } catch {
            print("NettoLR: salvataggio non riuscito: \(error)")
        }
    }

    private func carica() {
        guard FileManager.default.fileExists(atPath: Self.file.path) else { return }
        guard let dati = try? Data(contentsOf: Self.file) else {
            // Per esempio a telefono bloccato (file protetto): meglio non toccare niente
            nonSalvare = true
            return
        }
        // Un file che non si legge (o si legge solo in parte) non si perde: resta da parte, accanto, con la data
        func copiaDaParte() {
            let copia = URL.applicationSupportDirectory.appending(path: "nettolr-non-letto-\(Int(Date().timeIntervalSince1970)).json")
            try? FileManager.default.copyItem(at: Self.file, to: copia)
            print("NettoLR: salvataggio non leggibile del tutto, copiato in \(copia.lastPathComponent)")
        }
        guard let s = try? JSONDecoder().decode(Salvataggio.self, from: dati) else {
            copiaDaParte()
            avvisoSalvataggio = String(localized: "Non sono riuscito a leggere i dati salvati: ne ho tenuto una copia sul telefono, non è andato perso niente. Scrivici dal sito e ti aiutiamo a recuperarli.")
            return
        }
        if s.fattureScartate > 0 {
            copiaDaParte()
            avvisoSalvataggio = String(localized: "\(s.fattureScartate) fatture salvate non si sono potute leggere. Le altre ci sono tutte; il file completo è da parte.")
        }
        profilo = s.profilo
        fatture = s.fatture
        annoPrecedente = s.annoPrecedente
        // I dati vecchi senza anno sono quelli dell'anno appena passato
        if annoPrecedente.anno == nil, annoPrecedente != DatiAnnoPrecedente() { annoPrecedente.anno = Regole.attuali.anno - 1 }
        contributiVersati = s.contributiVersati
        contributiVersatiAnno = s.contributiVersatiAnno ?? (s.contributiVersati == nil ? nil : Regole.attuali.anno)
        pagati = Self.migra(s.pagati ?? [:])
        ricevute = Self.migra(s.ricevute ?? [:])
    }

    /// I pagamenti segnati con il vecchio codice («titolo-data in secondi») passano al nuovo («titolo-anno»),
    /// che non cambia se una scadenza viene corretta di qualche giorno
    nonisolated static func migra<V>(_ d: [String: V]) -> [String: V] {
        var out: [String: V] = [:]
        for (k, v) in d {
            if let trattino = k.lastIndex(of: "-"), let secondi = Double(k[k.index(after: trattino)...]), k[trattino...].contains(".") {
                out["\(k[..<trattino])-\(Giorno.anno(Date(timeIntervalSince1970: secondi)))"] = v
            } else {
                out[k] = v
            }
        }
        return out
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
