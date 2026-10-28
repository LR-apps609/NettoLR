import Foundation

// Le regole fiscali e contributive dell'anno, lette da Resources/Rules/regole-2026.json.
// Ogni anno si aggiunge un nuovo file (regole-2027.json…) invece di modificare questo:
// così i calcoli degli anni passati restano riproducibili. Lo stesso file servirà al sito.

struct Voce<T: Codable>: Codable {
    let valore: T
    /// Chiave in `Regole.fonti`
    let fonte: String
}

struct Regole: Codable {
    let anno: Int
    let aggiornatoAl: String
    let fonti: [String: Fonte]
    let forfettario: Forfettario
    let gestioneSeparata: GestioneSeparata
    let artigianiCommercianti: ArtigianiCommercianti
    let versamenti: Versamenti
    let bollo: Bollo
    let irpef: Irpef

    struct Forfettario: Codable {
        let sogliaRicavi: Voce<Double>
        let sogliaUscitaImmediata: Voce<Double>
        let limiteRedditoDipendente: Voce<Double>
        let aliquotaOrdinaria: Voce<Double>
        let aliquotaStartup: Voce<Double>
        let anniStartup: Voce<Int>
        /// La percentuale di reddito per gruppo di codici ATECO 2007
        let coefficienti: Voce<[Coefficiente]>
    }

    struct Coefficiente: Codable {
        let id: String
        let nome: String
        let valore: Double
        let divisioni2007: String
    }

    struct GestioneSeparata: Codable {
        let aliquota: Voce<Double>
        let aliquotaAltraCopertura: Voce<Double>
        let massimale: Voce<Double>
        let minimale: Voce<Double>
        /// Acconti contributivi: 40% + 40% del dovuto dell'anno precedente
        let accontoPercentuale: Voce<Double>
    }

    struct Tabella: Codable {
        let fissoAnnuo: Voce<Double>
        let aliquota: Voce<Double>
        let aliquotaMaggiorata: Voce<Double>
    }

    struct ArtigianiCommercianti: Codable {
        let minimale: Voce<Double>
        let sogliaAliquotaMaggiorata: Voce<Double>
        let massimale: Voce<Double>
        let artigiani: Tabella
        let commercianti: Tabella
        let riduzioneForfettari: Voce<Double>
        let scadenzeRateFisse: Voce<[String]>
    }

    struct Versamenti: Codable {
        let saldoPrimoAcconto: Voce<String>
        let saldoPrimoAccontoMaggiorato: Voce<String>
        let maggiorazioneDifferito: Voce<Double>
        let secondoAcconto: Voce<String>
        /// Forfettari: acconti in due rate uguali (50/50)
        let quotaPrimoAcconto: Voce<Double>
        let sogliaNessunAcconto: Voce<Double>
        /// Se il 1° acconto non supera questa cifra si versa tutto a novembre
        let sogliaPrimaRata: Voce<Double>
    }

    struct Bollo: Codable {
        let importo: Voce<Double>
        let sogliaFattura: Voce<Double>
        /// Scadenze dei quattro trimestri (il quarto l'anno dopo)
        let scadenze: Voce<[String]>
        /// Sotto questa cifra il trimestre si può pagare insieme al successivo
        let sogliaRinvio: Voce<Double>
    }

    struct Scaglione: Codable {
        /// nil = senza limite superiore
        let fino: Double?
        let aliquota: Double
    }

    struct Irpef: Codable {
        let scaglioni: Voce<[Scaglione]>
        let addizionaliDefault: Voce<Double>
    }

    func fonte<T: Codable>(_ voce: Voce<T>) -> Fonte { fonti[voce.fonte] ?? .sconosciuta }

    /// Le regole dell'anno in corso dell'app
    static let attuali: Regole = carica(anno: 2026)

    /// Gli anni per cui ci sono le regole (Resources/Rules/regole-AAAA.json)
    static let anniDisponibili = [2025, 2026]

    private static let tutte: [Int: Regole] = Dictionary(uniqueKeysWithValues: anniDisponibili.map { ($0, carica(anno: $0)) })

    /// Le regole di un anno; se mancano, quelle dell'anno più vicino
    static func per(anno: Int) -> Regole {
        if let r = tutte[anno] { return r }
        let vicino = anniDisponibili.min { abs($0 - anno) < abs($1 - anno) } ?? attuali.anno
        return tutte[vicino] ?? attuali
    }

    static func carica(anno: Int) -> Regole {
        let bundle = Bundle(for: SegnaBundle.self)
        // La cartella Resources/Rules entra nel bundle come cartella «Rules»
        guard let url = bundle.url(forResource: "regole-\(anno)", withExtension: "json", subdirectory: "Rules")
                ?? bundle.url(forResource: "regole-\(anno)", withExtension: "json"),
              let dati = try? Data(contentsOf: url) else {
            fatalError("Manca Resources/Rules/regole-\(anno).json")
        }
        do {
            return try JSONDecoder().decode(Regole.self, from: dati)
        } catch {
            fatalError("regole-\(anno).json non valido: \(error)")
        }
    }
}

/// Serve solo a trovare il bundle giusto: l'app o, nei test, il bundle dei test
final class SegnaBundle {}
