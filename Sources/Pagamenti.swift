import Foundation

// Il calendario dei pagamenti dell'anno: tasse (imposta sostitutiva) e pensione (INPS).
// I titoli sono in parole semplici; codici tributo e causali restano nei dettagli, per l'F24.

struct Pagamento: Identifiable, Equatable {
    enum Tipo { case tasse, pensione, bollo }
    var id: String { "\(titolo)-\(data.timeIntervalSince1970)" }
    var data: Date
    var tipo: Tipo
    /// Per tutti: «Tasse: saldo e anticipo»
    var titolo: String
    /// Per l'F24: codice tributo o causale
    var codice: String
    var spiegazione: String
    var importo: Double
    var fonte: Fonte
}

enum Pagamenti {
    static func anno2026(_ p: Profilo, precedente prec: DatiAnnoPrecedente, fatture: [Fattura] = [], r: Regole = .attuali) -> [Pagamento] {
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
                data: Giorno.da(v.saldoPrimoAcconto.valore), tipo: .tasse, titolo: "Tasse: il conto dell'anno scorso e un anticipo",
                codice: "1792 saldo \(Formato.euro(saldo)) · 1790 primo acconto \(Formato.euro(primo))",
                spiegazione: "Si può pagare fino al 20 agosto con lo 0,80% in più.",
                importo: arrotonda(saldo + primo), fonte: r.fonte(v.saldoPrimoAcconto)))
        }
        if secondo > 0 {
            out.append(Pagamento(
                data: Giorno.da(v.secondoAcconto.valore), tipo: .tasse, titolo: "Tasse: secondo anticipo",
                codice: "1791 secondo acconto", spiegazione: "L'anticipo sulle tasse di quest'anno.",
                importo: secondo, fonte: r.fonte(v.secondoAcconto)))
        }

        switch p.gestione {
        case .separata:
            if let dovuti = prec.contributiGS {
                let gs = r.gestioneSeparata
                let saldoGS = arrotonda(max(0, dovuti - (prec.accontiGSVersati ?? 0)))
                let acconto = arrotonda(dovuti * gs.accontoPercentuale.valore / 2)
                out.append(Pagamento(
                    data: Giorno.da(v.saldoPrimoAcconto.valore), tipo: .pensione, titolo: "Pensione: il conto dell'anno scorso e un anticipo",
                    codice: "causale PXX · saldo \(Formato.euro(saldoGS)) + acconto \(Formato.euro(acconto))",
                    spiegazione: "Contributi INPS della Gestione Separata.",
                    importo: arrotonda(saldoGS + acconto), fonte: r.fonte(gs.aliquota)))
                out.append(Pagamento(
                    data: Giorno.da(v.secondoAcconto.valore), tipo: .pensione, titolo: "Pensione: secondo anticipo",
                    codice: "causale PXX · acconto 40%", spiegazione: "Contributi INPS della Gestione Separata.",
                    importo: acconto, fonte: r.fonte(gs.aliquota)))
            }
        case .artigiani, .commercianti:
            let ac = r.artigianiCommercianti
            let tab = p.gestione == .artigiani ? ac.artigiani : ac.commercianti
            let riduzione = p.riduzione35 ? 1 - ac.riduzioneForfettari.valore : 1
            let rata = arrotonda(tab.fissoAnnuo.valore * riduzione / 4)
            for (i, data) in ac.scadenzeRateFisse.valore.enumerated() {
                out.append(Pagamento(
                    data: Giorno.da(data), tipo: .pensione, titolo: "Pensione: rata fissa \(i + 1) di 4",
                    codice: "modello F24 precompilato nel Cassetto previdenziale INPS",
                    spiegazione: "La quota fissa che si paga anche senza guadagni.",
                    importo: rata, fonte: r.fonte(ac.scadenzeRateFisse)))
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
                    data: Giorno.da(data), tipo: .bollo, titolo: "Bollo delle fatture (\(quali) trimestre)",
                    codice: "codice tributo \(codici) · anno \(anno)",
                    spiegazione: "2 € per ogni fattura sopra 77,47 €. L'importo esatto lo trovi anche nel portale Fatture e Corrispettivi.",
                    importo: arrotonda(totale), fonte: r.fonte(b.scadenze)))
            }
            rinviato = 0
            trimestriRinviati = []
        }
        return out
    }
}
