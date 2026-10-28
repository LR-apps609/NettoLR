import Foundation

// I dati dell'utente. Restano sul telefono (vedi Store.swift): nessun account, nessun server.

enum Gestione: String, Codable, CaseIterable, Identifiable {
    case separata, artigiani, commercianti, cassa
    var id: String { rawValue }

    var nome: String {
        switch self {
        case .separata: "Gestione Separata".tradotto
        case .artigiani: "Artigiani".tradotto
        case .commercianti: "Commercianti".tradotto
        case .cassa: "Cassa professionale".tradotto
        }
    }
}

struct Profilo: Codable, Equatable {
    /// Solo per salutare: facoltativo
    var nome: String = ""
    /// Facoltativa; controllata con la cifra di controllo, mai inviata
    var partitaIVA: String = ""
    /// Codice ATECO 2007, es. "62.01.00": per il 2026 il coefficiente si determina ancora da questo
    var ateco: String
    var annoApertura: Int
    /// L'utente dichiara di avere i requisiti per l'aliquota al 5% (nuova attività)
    var requisitiStartup: Bool
    var gestione: Gestione
    /// Riduzione contributiva del 35% per artigiani e commercianti forfettari
    var riduzione35: Bool
    /// Solo cassa professionale: aliquota indicata dall'utente (es. 0,145)
    var cassaAliquota: Double?
    /// Solo cassa professionale: contributo minimo annuo indicato dall'utente
    var cassaFisso: Double?
    /// Reddito da lavoro dipendente o pensione dell'anno precedente
    var redditoDipendente: Double?
    /// Solo Gestione Separata: aggiunge il 4% INPS in fattura (rivalsa), pagato dal cliente
    var rivalsa4: Bool = false
    var promemoria: Bool = true
    /// Blocco con Face ID all'apertura (facoltativo: assente nei salvataggi vecchi)
    var faceID: Bool?
    /// Altre attività (codici ATECO 2007) oltre a quella principale, ognuna con la sua percentuale
    var altreAttivita: [String]?

    /// Tutte le attività: la principale per prima
    var attivita: [String] { [ateco] + (altreAttivita ?? []).filter { $0 != ateco } }
}

struct Fattura: Codable, Identifiable, Equatable {
    enum Origine: String, Codable { case manuale, xml, foto }


    var id = UUID()
    var numero: String
    /// Data di emissione
    var data: Date
    var cliente: String
    /// Importo incassato o da incassare, senza bollo
    var importo: Double
    var incassata: Bool
    /// Nel forfettario conta il giorno dell'incasso, non quello della fattura
    var dataIncasso: Date?
    var origine: Origine
    /// L'attività (codice ATECO 2007) a cui appartiene; nil = quella principale
    var ateco: String?
}

/// Dati dell'anno precedente, per saldo e acconti
struct DatiAnnoPrecedente: Codable, Equatable {
    /// Imposta sostitutiva dovuta per l'anno precedente (rigo LM42)
    var imposta: Double = 0
    /// Acconti d'imposta già versati per l'anno precedente
    var accontiVersati: Double = 0
    /// Solo Gestione Separata: contributi dovuti per l'anno precedente
    var contributiGS: Double?
    var accontiGSVersati: Double?
}

/// Un numero normativo con la sua fonte: ogni cifra mostrata deve averne una
struct Fonte: Codable, Equatable {
    var titolo: String
    var url: String
    /// Data di pubblicazione o di consultazione (AAAA-MM-GG)
    var data: String
    /// "verificato" = letto sulla fonte ufficiale; "da-verificare" = da confermare prima del lancio
    var stato: String

    var verificata: Bool { stato == "verificato" }
    static let sconosciuta = Fonte(titolo: "Fonte non trovata", url: "https://www.agenziaentrate.gov.it", data: "", stato: "da-verificare")
}

/// Una riga del calcolo «riga per riga»
struct Riga: Identifiable, Equatable {
    var id: String { etichetta }
    var etichetta: String
    var formula: String
    var importo: Double
    var fonte: Fonte?
}

// MARK: - Date

enum Giorno {
    static let calendario: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Rome")!
        return c
    }()

    /// "2026-07-20" → data (mezzogiorno, per non cambiare giorno con il fuso)
    static func da(_ testo: String) -> Date {
        let p = testo.split(separator: "-").compactMap { Int($0) }
        guard p.count == 3 else { return .distantPast }
        return calendario.date(from: DateComponents(year: p[0], month: p[1], day: p[2], hour: 12)) ?? .distantPast
    }

    static func anno(_ d: Date) -> Int { calendario.component(.year, from: d) }

    static func data(_ anno: Int, _ mese: Int, _ giorno: Int) -> Date {
        calendario.date(from: DateComponents(year: anno, month: mese, day: giorno, hour: 12)) ?? .distantPast
    }
}

// MARK: - Traduzioni

extension String {
    /// La traduzione di un testo italiano dal catalogo Localizable (versione inglese), o il testo stesso
    var tradotto: String { Bundle.main.localizedString(forKey: self, value: self, table: nil) }
}

// MARK: - Formati italiani


enum Formato {
    static let it = Locale(identifier: "it_IT")

    /// «2.544,00 €»: sempre con il punto delle migliaia (il formato di Apple lo toglie sotto 10.000)
    static func euro(_ n: Double) -> String { importo(n, decimali: 2) }
    /// «2.544 €»
    static func euroTondo(_ n: Double) -> String { importo(n, decimali: 0) }

    static func importo(_ n: Double, decimali: Int) -> String {
        let fattore = decimali == 2 ? 100.0 : 1.0
        let centesimi = Int64((abs(n) * fattore).rounded())
        let intero = centesimi / Int64(fattore)
        var cifre = String(intero)
        var gruppi: [String] = []
        while cifre.count > 3 {
            gruppi.insert(String(cifre.suffix(3)), at: 0)
            cifre.removeLast(3)
        }
        gruppi.insert(cifre, at: 0)
        var testo = gruppi.joined(separator: ".")
        if decimali == 2 {
            let resto = centesimi % 100
            testo += "," + (resto < 10 ? "0" : "") + String(resto)
        }
        return (n < 0 && centesimi > 0 ? "-" : "") + testo + " €"
    }
    static func pct(_ n: Double) -> String {
        (n * 100).formatted(.number.locale(it).precision(.fractionLength(0...2))) + "%"
    }
    static func data(_ d: Date) -> String {
        d.formatted(.dateTime.day().month(.wide).year().locale(lingua))
    }
    /// La lingua dell'app per i nomi di mesi e giorni (gli importi restano sempre all'italiana)
    static var lingua: Locale { inglese ? Locale(identifier: "en_GB") : it }
    /// L'app è in inglese (iPhone in inglese)
    static var inglese: Bool { Bundle.main.preferredLocalizations.first == "en" }
    static func dataCorta(_ d: Date) -> String {
        d.formatted(.dateTime.day(.twoDigits).month(.twoDigits).year().locale(it))
    }

    /// "1.234,56" → 1234.56; "1234.56" → 1234.56; "1.234" → 1234
    static func leggiEuro(_ s: String) -> Double {
        let pulito = s.replacingOccurrences(of: "€", with: "").filter { !$0.isWhitespace }
        if pulito.contains(",") {
            return Double(pulito.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")) ?? 0
        }
        if pulito.range(of: #"^\d+\.\d{1,2}$"#, options: .regularExpression) != nil {
            return Double(pulito) ?? 0
        }
        return Double(pulito.replacingOccurrences(of: ".", with: "")) ?? 0
    }

    /// 1234.5 → "1234,5" per i campi da modificare
    static func campo(_ n: Double?) -> String {
        guard let n, n != 0 else { return "" }
        return n.formatted(.number.locale(it).grouping(.never).precision(.fractionLength(0...2)))
    }
}
