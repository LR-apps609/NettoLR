import Foundation

// Il calendario dei pagamenti dell'anno: tasse (imposta sostitutiva) e pensione (INPS).
// I titoli sono in parole semplici; codici tributo e causali restano nei dettagli, per l'F24.

struct Pagamento: Identifiable, Equatable {
    enum Tipo { case tasse, pensione, bollo }
    /// Il titolo in italiano tiene fermo l'id (pagati, ricevute) anche se cambia la lingua dell'app
    var id: String { "\(chiave.isEmpty ? titolo : chiave)-\(data.timeIntervalSince1970)" }
    var data: Date
    var tipo: Tipo
    /// Per tutti: «Tasse: saldo e anticipo»
    var titolo: String
    /// Per l'F24: codice tributo o causale
    var codice: String
    var spiegazione: String
    var importo: Double
    var fonte: Fonte
    var chiave = ""
}

enum Pagamenti {
    /// I pagamenti dell'anno delle regole `r` (date e importi del 2025, del 2026…)
    static func anno2026(_ p: Profilo, precedente prec: DatiAnnoPrecedente, fatture: [Fattura] = [], r: Regole = .attuali) -> [Pagamento] {
        anno(p, precedente: prec, fatture: fatture, r: r)
    }

    static func anno(_ p: Profilo, precedente prec: DatiAnnoPrecedente, fatture: [Fattura] = [], r: Regole) -> [Pagamento] {
        let v = r.versamenti
        var out: [Pagamento] = []

        // Tasse: saldo dell'anno precedente + acconti sull'anno in corso (100% dell'imposta precedente)
        let saldo = arrotonda(max(0, prec.imposta - prec.accontiVersati))
        var primo = 0.0
        var secondo = 0.0
        if prec.imposta > v.sogliaNessunAcconto.valore {
            primo = arrotonda(prec.imposta * v.quotaPrimoAcconto.valore)
            secondo = arrotonda(prec.imposta - primo)
            if primo <= v.sogliaPrimaRata.valore {
                secondo = arrotonda(prec.imposta)
                primo = 0
            }
        }
        if saldo + primo > 0 {
            out.append(Pagamento(
                data: Giorno.da(v.saldoPrimoAcconto.valore), tipo: .tasse, titolo: "Tasse: il conto dell'anno scorso e un anticipo".tradotto,
                codice: String(localized: "1792 saldo \(Formato.euro(saldo)) · 1790 primo acconto \(Formato.euro(primo))"),
                spiegazione: String(localized: "Si può pagare fino al \(Giorno.da(v.saldoPrimoAccontoMaggiorato.valore).formatted(.dateTime.day().month(.wide).locale(Formato.lingua))) con lo \(Formato.pct(v.maggiorazioneDifferito.valore)) in più."),
                importo: arrotonda(saldo + primo), fonte: r.fonte(v.saldoPrimoAcconto), chiave: "Tasse: il conto dell'anno scorso e un anticipo"))
        }
        if secondo > 0 {
            out.append(Pagamento(
                data: Giorno.da(v.secondoAcconto.valore), tipo: .tasse, titolo: "Tasse: secondo anticipo".tradotto,
                codice: "1791 secondo acconto".tradotto, spiegazione: "L'anticipo sulle tasse di quest'anno.".tradotto,
                importo: secondo, fonte: r.fonte(v.secondoAcconto), chiave: "Tasse: secondo anticipo"))
        }

        switch p.gestione {
        case .separata:
            if let dovuti = prec.contributiGS {
                let gs = r.gestioneSeparata
                let saldoGS = arrotonda(max(0, dovuti - (prec.accontiGSVersati ?? 0)))
                let acconto = arrotonda(dovuti * gs.accontoPercentuale.valore / 2)
                out.append(Pagamento(
                    data: Giorno.da(v.saldoPrimoAcconto.valore), tipo: .pensione, titolo: "Pensione: il conto dell'anno scorso e un anticipo".tradotto,
                    codice: String(localized: "causale PXX · saldo \(Formato.euro(saldoGS)) + acconto \(Formato.euro(acconto))"),
                    spiegazione: "Contributi INPS della Gestione Separata.".tradotto,
                    importo: arrotonda(saldoGS + acconto), fonte: r.fonte(gs.aliquota), chiave: "Pensione: il conto dell'anno scorso e un anticipo"))
                out.append(Pagamento(
                    data: Giorno.da(v.secondoAcconto.valore), tipo: .pensione, titolo: "Pensione: secondo anticipo".tradotto,
                    codice: "causale PXX · acconto 40%".tradotto, spiegazione: "Contributi INPS della Gestione Separata.".tradotto,
                    importo: acconto, fonte: r.fonte(gs.aliquota), chiave: "Pensione: secondo anticipo"))
            }
        case .artigiani, .commercianti:
            let ac = r.artigianiCommercianti
            let tab = p.gestione == .artigiani ? ac.artigiani : ac.commercianti
            let riduzione = p.riduzione35 ? 1 - ac.riduzioneForfettari.valore : 1
            let rata = arrotonda(tab.fissoAnnuo.valore * riduzione / 4)
            for (i, data) in ac.scadenzeRateFisse.valore.enumerated() {
                out.append(Pagamento(
                    data: Giorno.da(data), tipo: .pensione, titolo: String(localized: "Pensione: rata fissa \(i + 1) di 4"),
                    codice: "modello F24 precompilato nel Cassetto previdenziale INPS".tradotto,
                    spiegazione: "La quota fissa che si paga anche senza guadagni.".tradotto,
                    importo: rata, fonte: r.fonte(ac.scadenzeRateFisse), chiave: "Pensione: rata fissa \(i + 1) di 4"))
            }
        case .cassa:
            break
        }
        out += bollo(fatture, anno: r.anno, r: r)
        return out.sorted { $0.data < $1.data }
    }

    /// Il bollo virtuale delle fatture: 2 € per ogni fattura sopra 77,47 €, pagato a trimestri.
    /// Se un trimestre (con quelli rinviati) resta sotto 5.000 € si paga con il successivo; il terzo e il quarto mai rinviati.
    static func bollo(_ fatture: [Fattura], anno: Int, r: Regole = .attuali) -> [Pagamento] {
        let b = r.bollo
        var perTrimestre = [Double](repeating: 0, count: 4)
        for f in fatture where Giorno.anno(f.data) == anno && f.importo > b.sogliaFattura.valore {
            let mese = Giorno.calendario.component(.month, from: f.data)
            perTrimestre[(mese - 1) / 3] += b.importo.valore
        }
        var out: [Pagamento] = []
        var rinviato = 0.0
        var trimestriRinviati: [Int] = []
        for (i, data) in b.scadenze.valore.enumerated() where i < 4 {
            let totale = rinviato + perTrimestre[i]
            trimestriRinviati.append(i + 1)
            if i < 2 && totale < b.sogliaRinvio.valore {
                rinviato = totale
                continue
            }
            if totale > 0 {
                let codici = trimestriRinviati.map { "\(2520 + $0)" }.joined(separator: " + ")
                let quali = trimestriRinviati.map { "\($0)°" }.joined(separator: ", ")
                out.append(Pagamento(
                    data: Giorno.da(data), tipo: .bollo, titolo: String(localized: "Bollo delle fatture (\(quali) trimestre)"),
                    codice: String(localized: "codice tributo \(codici) · anno \(String(anno))"),
                    spiegazione: "2 € per ogni fattura sopra 77,47 €. L'importo esatto lo trovi anche nel portale Fatture e Corrispettivi.".tradotto,
                    importo: arrotonda(totale), fonte: r.fonte(b.scadenze), chiave: "Bollo delle fatture (\(quali) trimestre)"))
            }
            rinviato = 0
            trimestriRinviati = []
        }
        return out
    }
}
