import Foundation

// Il motore di calcolo: forfettario riga per riga, confronto con l'ordinario, simulazioni.
// Niente SwiftUI qui: lo provano i test (Tests/CalcoloTests.swift) e le stesse formule servono al sito.

func arrotonda(_ n: Double) -> Double { (n * 100).rounded() / 100 }

struct RisultatoForfettario {
    var ricavi: Double
    var coefficiente: Double
    var nomeGruppo: String
    var redditoLordo: Double
    var contributi: Double
    var contributiDedotti: Double
    var contributiStimati: Bool
    var imponibile: Double
    var aliquota: Double
    var imposta: Double
    var bolli: Double
    var netto: Double
    var righe: [Riga]
}

struct ContributiDovuti {
    var totale: Double
    var fissi: Double
    var variabili: Double
}

enum Calcolo {
    /// L'aliquota al 5% vale per l'anno di apertura e i 4 successivi, se ci sono i requisiti
    static func aliquotaImposta(_ p: Profilo, anno: Int, r: Regole = .attuali) -> Double {
        let f = r.forfettario
        let inStartup = p.requisitiStartup && anno - p.annoApertura < f.anniStartup.valore
        return inStartup ? f.aliquotaStartup.valore : f.aliquotaOrdinaria.valore
    }

    /// Ultimo anno con aliquota al 5% (nil se non applicabile)
    static func ultimoAnnoStartup(_ p: Profilo, r: Regole = .attuali) -> Int? {
        p.requisitiStartup ? p.annoApertura + r.forfettario.anniStartup.valore - 1 : nil
    }

    /// Contributi previdenziali dovuti su un reddito, per la gestione del profilo
    static func contributi(_ p: Profilo, reddito: Double, forfettario: Bool, r: Regole = .attuali) -> ContributiDovuti {
        switch p.gestione {
        case .separata:
            let gs = r.gestioneSeparata
            let t = arrotonda(min(reddito, gs.massimale.valore) * gs.aliquota.valore)
            return .init(totale: t, fissi: 0, variabili: t)
        case .cassa:
            let variabili = arrotonda(reddito * (p.cassaAliquota ?? 0))
            let fissi = p.cassaFisso ?? 0
            return .init(totale: arrotonda(max(variabili, fissi)), fissi: fissi, variabili: variabili)
        case .artigiani, .commercianti:
            let ac = r.artigianiCommercianti
            let tab = p.gestione == .artigiani ? ac.artigiani : ac.commercianti
            let riduzione = forfettario && p.riduzione35 ? 1 - ac.riduzioneForfettari.valore : 1
            let base = min(reddito, ac.massimale.valore)
            let minimale = ac.minimale.valore
            let soglia = ac.sogliaAliquotaMaggiorata.valore
            let eccedenza = max(0, min(base, soglia) - minimale) * tab.aliquota.valore
                + max(0, base - soglia) * tab.aliquotaMaggiorata.valore
            let fissi = arrotonda(tab.fissoAnnuo.valore * riduzione)
            let variabili = arrotonda(eccedenza * riduzione)
            return .init(totale: arrotonda(fissi + variabili), fissi: fissi, variabili: variabili)
        }
    }

    /// - Parameters:
    ///   - contributiVersati: contributi effettivamente versati nell'anno (deducibili); nil = stima pari ai dovuti
    ///   - fattureConBollo: fatture sopra la soglia del bollo, per il costo delle marche
    static func forfettario(_ p: Profilo, anno: Int, ricavi ricaviIn: Double, contributiVersati: Double? = nil,
                            fattureConBollo: Int = 0, r: Regole = .attuali) -> RisultatoForfettario {
        let gruppo = Ateco.gruppo(ateco2007: p.ateco) ?? Ateco.gruppo("altre")
        let coefficiente = gruppo.coefficiente
        let ricavi = arrotonda(ricaviIn)
        let redditoLordo = arrotonda(ricavi * coefficiente)
        let contributi = contributi(p, reddito: redditoLordo, forfettario: true, r: r).totale
        let stimati = contributiVersati == nil
        let dedotti = arrotonda(min(redditoLordo, contributiVersati ?? contributi))
        let imponibile = arrotonda(max(0, redditoLordo - dedotti))
        let aliquota = aliquotaImposta(p, anno: anno, r: r)
        let imposta = arrotonda(imponibile * aliquota)
        let bolli = arrotonda(Double(fattureConBollo) * r.bollo.importo.valore)
        let netto = arrotonda(ricavi - contributi - imposta - bolli)

        let fonteInps: Fonte? = switch p.gestione {
        case .separata: r.fonte(r.gestioneSeparata.aliquota)
        case .artigiani, .commercianti: r.fonte(r.artigianiCommercianti.minimale)
        case .cassa: nil
        }
        let nomeGestione = switch p.gestione {
        case .separata: "Gestione Separata \(Formato.pct(r.gestioneSeparata.aliquota.valore))"
        case .artigiani: "Artigiani" + (p.riduzione35 ? ", riduzione 35%" : "")
        case .commercianti: "Commercianti" + (p.riduzione35 ? ", riduzione 35%" : "")
        case .cassa: "Cassa professionale \(Formato.pct(p.cassaAliquota ?? 0)) (dato inserito da te)"
        }

        var righe: [Riga] = [
            Riga(etichetta: "Incassato", formula: "Somma delle fatture incassate nell'anno", importo: ricavi),
            Riga(etichetta: "Reddito lordo",
                 formula: "\(Formato.euro(ricavi)) × coefficiente \(Formato.pct(coefficiente)) (\(gruppo.nome))",
                 importo: redditoLordo, fonte: r.fonte(r.forfettario.aliquotaOrdinaria)),
            Riga(etichetta: "Contributi INPS", formula: nomeGestione, importo: -contributi, fonte: fonteInps),
            Riga(etichetta: "Contributi dedotti",
                 formula: stimati ? "Stima: contributi dell'anno, come se fossero versati nell'anno"
                                  : "Contributi effettivamente versati nell'anno",
                 importo: dedotti),
            Riga(etichetta: "Reddito imponibile", formula: "\(Formato.euro(redditoLordo)) − \(Formato.euro(dedotti))", importo: imponibile),
            Riga(etichetta: "Imposta sostitutiva \(Formato.pct(aliquota))",
                 formula: "\(Formato.euro(imponibile)) × \(Formato.pct(aliquota))",
                 importo: -imposta, fonte: r.fonte(r.forfettario.aliquotaOrdinaria)),
        ]
        if bolli > 0 {
            righe.append(Riga(etichetta: "Marche da bollo",
                              formula: "\(fattureConBollo) fatture sopra \(Formato.euro(r.bollo.sogliaFattura.valore)) × \(Formato.euro(r.bollo.importo.valore))",
                              importo: -bolli, fonte: r.fonte(r.bollo.importo)))
        }
        righe.append(Riga(etichetta: "Ti resta", formula: "Incassato − contributi − imposta − bolli", importo: netto))

        return RisultatoForfettario(ricavi: ricavi, coefficiente: coefficiente, nomeGruppo: gruppo.nome,
                                    redditoLordo: redditoLordo, contributi: contributi, contributiDedotti: dedotti,
                                    contributiStimati: stimati, imponibile: imponibile, aliquota: aliquota,
                                    imposta: imposta, bolli: bolli, netto: netto, righe: righe)
    }

    /// «Su 100 € incassati: X allo Stato, Y all'INPS, Z a te»
    static func doveVannoISoldi(_ res: RisultatoForfettario) -> (stato: Double, inps: Double, te: Double) {
        guard res.ricavi > 0 else { return (0, 0, 100) }
        let stato = arrotonda((res.imposta + res.bolli) / res.ricavi * 100)
        let inps = arrotonda(res.contributi / res.ricavi * 100)
        return (stato, inps, arrotonda(100 - stato - inps))
    }

    // MARK: - Regime ordinario (stima semplificata, solo per il confronto)

    static func irpefLorda(_ imponibile: Double, r: Regole = .attuali) -> Double {
        var resto = imponibile
        var precedente = 0.0
        var imposta = 0.0
        for s in r.irpef.scaglioni.valore {
            let fino = s.fino ?? .infinity
            let quota = max(0, min(resto, fino - precedente))
            imposta += quota * s.aliquota
            resto -= quota
            precedente = fino
            if resto <= 0 { break }
        }
        return arrotonda(imposta)
    }

    /// Detrazione per redditi di lavoro autonomo (art. 13 c. 5 TUIR)
    static func detrazioneLavoroAutonomo(_ reddito: Double) -> Double {
        if reddito <= 5_500 { return 1_265 }
        if reddito <= 28_000 { return arrotonda(500 + 765 * (28_000 - reddito) / 22_500) }
        if reddito <= 50_000 { return arrotonda(500 * (50_000 - reddito) / 22_000) }
        return 0
    }

    struct RisultatoOrdinario {
        var ricavi, costi, reddito, contributi, imponibile, irpef, addizionali, netto: Double
        var righe: [Riga]
    }

    static func ordinario(_ p: Profilo, ricavi ricaviIn: Double, costi costiIn: Double, addizionali: Double? = nil,
                          r: Regole = .attuali) -> RisultatoOrdinario {
        let ricavi = arrotonda(ricaviIn)
        let costi = arrotonda(costiIn)
        let reddito = arrotonda(max(0, ricavi - costi))
        let contributi = contributi(p, reddito: reddito, forfettario: false, r: r).totale
        let imponibile = arrotonda(max(0, reddito - contributi))
        let irpef = arrotonda(max(0, irpefLorda(imponibile, r: r) - detrazioneLavoroAutonomo(imponibile)))
        let aliqAdd = addizionali ?? r.irpef.addizionaliDefault.valore
        let add = arrotonda(imponibile * aliqAdd)
        let netto = arrotonda(ricavi - costi - contributi - irpef - add)
        return RisultatoOrdinario(
            ricavi: ricavi, costi: costi, reddito: reddito, contributi: contributi, imponibile: imponibile,
            irpef: irpef, addizionali: add, netto: netto,
            righe: [
                Riga(etichetta: "Incassato", formula: "IVA esclusa (in ordinario l'IVA si incassa e si versa)", importo: ricavi),
                Riga(etichetta: "Costi reali", formula: "Spese documentate inserite da te", importo: -costi),
                Riga(etichetta: "Contributi INPS", formula: "Senza riduzione 35%", importo: -contributi),
                Riga(etichetta: "IRPEF netta", formula: "Scaglioni 23% / 33% / 43% meno detrazione lavoro autonomo",
                     importo: -irpef, fonte: r.fonte(r.irpef.scaglioni)),
                Riga(etichetta: "Addizionali", formula: "\(Formato.pct(aliqAdd)) stimato (dipende da Regione e Comune)",
                     importo: -add, fonte: r.fonte(r.irpef.addizionaliDefault)),
                Riga(etichetta: "Ti resta", formula: "Incassato − costi − contributi − imposte", importo: netto),
            ])
    }

    // MARK: - Fatture → anno

    struct Riepilogo {
        var ricavi: Double
        var daIncassare: Double
        var nIncassate: Int
        var nDaIncassare: Int
        var fattureConBollo: Int
    }

    static func riepilogo(_ fatture: [Fattura], anno: Int, r: Regole = .attuali) -> Riepilogo {
        let incassate = fatture.filter { $0.incassata && Giorno.anno($0.dataIncasso ?? $0.data) == anno }
        let daIncassare = fatture.filter { !$0.incassata }
        let conBollo = fatture.filter { Giorno.anno($0.data) == anno && $0.importo > r.bollo.sogliaFattura.valore }.count
        return Riepilogo(ricavi: arrotonda(incassate.reduce(0) { $0 + $1.importo }),
                         daIncassare: arrotonda(daIncassare.reduce(0) { $0 + $1.importo }),
                         nIncassate: incassate.count, nDaIncassare: daIncassare.count, fattureConBollo: conBollo)
    }

    // MARK: - Simulazioni

    struct SeFatturo {
        var nettoExtra: Double
        var percentualeTrattenuta: Double
        var superaSoglia: Bool
        var superaUscitaImmediata: Bool
        var margineSoglia: Double
    }

    /// Quanto resta di un incasso in più, al margine (differenza tra due calcoli)
    static func seFatturoAncora(_ p: Profilo, anno: Int, ricaviAttuali: Double, extra: Double, r: Regole = .attuali) -> SeFatturo {
        let prima = forfettario(p, anno: anno, ricavi: ricaviAttuali, r: r)
        let dopo = forfettario(p, anno: anno, ricavi: ricaviAttuali + extra, r: r)
        let nettoExtra = arrotonda(dopo.netto - prima.netto)
        let soglia = r.forfettario.sogliaRicavi.valore
        return SeFatturo(nettoExtra: nettoExtra,
                         percentualeTrattenuta: extra > 0 ? arrotonda(nettoExtra / extra * 100) : 0,
                         superaSoglia: ricaviAttuali + extra > soglia,
                         superaUscitaImmediata: ricaviAttuali + extra > r.forfettario.sogliaUscitaImmediata.valore,
                         margineSoglia: arrotonda(soglia - ricaviAttuali - extra))
    }

    /// Calcolo inverso: quanto incassare in un anno per avere un certo netto
    static func incassoPerNetto(_ p: Profilo, anno: Int, netto obiettivo: Double, r: Regole = .attuali) -> Double {
        var basso = 0.0
        var alto = obiettivo * 4 + 10_000
        for _ in 0..<60 {
            let medio = (basso + alto) / 2
            if forfettario(p, anno: anno, ricavi: medio, r: r).netto < obiettivo { basso = medio } else { alto = medio }
        }
        return alto.rounded(.up)
    }

    static func avvisi(_ p: Profilo, ricaviAnno: Double, r: Regole = .attuali) -> [String] {
        var out: [String] = []
        let f = r.forfettario
        if ricaviAnno > f.sogliaUscitaImmediata.valore {
            out.append("Hai superato \(Formato.euro(f.sogliaUscitaImmediata.valore)): esci dal forfettario già da quest'anno, con l'IVA dalla fattura che supera la soglia. Senti subito un commercialista.")
        } else if ricaviAnno > f.sogliaRicavi.valore {
            out.append("Hai superato \(Formato.euro(f.sogliaRicavi.valore)): dal prossimo anno passi al regime ordinario.")
        } else if ricaviAnno > f.sogliaRicavi.valore * 0.85 {
            out.append("Sei vicino alla soglia: mancano \(Formato.euro(f.sogliaRicavi.valore - ricaviAnno)) a \(Formato.euro(f.sogliaRicavi.valore)).")
        }
        if (p.redditoDipendente ?? 0) > f.limiteRedditoDipendente.valore {
            out.append("Il reddito da dipendente supera \(Formato.euro(f.limiteRedditoDipendente.valore)): potresti non avere i requisiti per il forfettario. Verifica con un commercialista.")
        }
        if p.gestione == .cassa && (p.cassaAliquota ?? 0) == 0 {
            out.append("Inserisci l'aliquota della tua cassa professionale per un calcolo dei contributi corretto.")
        }
        return out
    }
}
