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

    /// Gestione Separata: chi ha già un'altra pensione obbligatoria (dipendente o pensionato) paga l'aliquota ridotta
    static func aliquotaSeparata(_ p: Profilo, r: Regole = .attuali) -> Double {
        let gs = r.gestioneSeparata
        return (p.redditoDipendente ?? 0) > 0 ? gs.aliquotaAltraCopertura.valore : gs.aliquota.valore
    }

    /// Contributi deducibili nell'anno quando l'utente non li ha inseriti.
    /// Primo anno: in Gestione Separata (e la parte variabile delle altre) si paga tutto l'anno dopo, quindi
    /// nell'anno si versano solo le quote fisse; negli anni dopo saldo + acconti valgono circa quanto il dovuto dell'anno.
    static func contributiDeducibiliStimati(_ p: Profilo, anno: Int, dovuti: ContributiDovuti) -> Double {
        anno <= p.annoApertura ? dovuti.fissi : dovuti.totale
    }

    /// I mesi di attività in un anno: 12, meno i mesi prima dell'apertura nell'anno di apertura, 0 prima di aprire
    static func mesiAttivi(_ p: Profilo, anno: Int) -> Int {
        if anno < p.annoApertura { return 0 }
        if anno > p.annoApertura { return 12 }
        return 13 - min(12, max(1, p.meseApertura ?? 1))
    }

    /// Contributi previdenziali dovuti su un reddito, per la gestione del profilo.
    /// - Parameter mesi: mesi di attività nell'anno; le quote fisse e il minimale si riducono in proporzione
    static func contributi(_ p: Profilo, reddito: Double, forfettario: Bool, mesi: Int = 12, r: Regole = .attuali) -> ContributiDovuti {
        let quota = Double(min(12, max(0, mesi))) / 12
        guard quota > 0 else { return .init(totale: 0, fissi: 0, variabili: 0) }
        switch p.gestione {
        case .separata:
            let gs = r.gestioneSeparata
            let t = arrotonda(min(reddito, gs.massimale.valore) * aliquotaSeparata(p, r: r))
            return .init(totale: t, fissi: 0, variabili: t)
        case .cassa:
            let variabili = arrotonda(reddito * (p.cassaAliquota ?? 0))
            let fissi = arrotonda((p.cassaFisso ?? 0) * quota)
            return .init(totale: arrotonda(max(variabili, fissi)), fissi: fissi, variabili: variabili)
        case .artigiani, .commercianti:
            let ac = r.artigianiCommercianti
            let tab = p.gestione == .artigiani ? ac.artigiani : ac.commercianti
            let riduzione = forfettario && p.riduzione35 ? 1 - ac.riduzioneForfettari.valore : 1
            let base = min(reddito, ac.massimale.valore)
            let minimale = ac.minimale.valore * quota
            let soglia = ac.sogliaAliquotaMaggiorata.valore
            let eccedenza = max(0, min(base, soglia) - minimale) * tab.aliquota.valore
                + max(0, base - soglia) * tab.aliquotaMaggiorata.valore
            let fissi = arrotonda(tab.fissoAnnuo.valore * riduzione * quota)
            let variabili = arrotonda(eccedenza * riduzione)
            return .init(totale: arrotonda(fissi + variabili), fissi: fissi, variabili: variabili)
        }
    }

    /// - Parameters:
    ///   - contributiVersati: contributi effettivamente versati nell'anno (deducibili); nil = stima pari ai dovuti
    ///   - fattureConBollo: fatture sopra la soglia del bollo, per il costo delle marche
    ///   - perAttivita: con più attività, gli incassi di ognuna (codice ATECO 2007 → euro); ognuna ha la sua percentuale
    static func forfettario(_ p: Profilo, anno: Int, ricavi ricaviIn: Double, contributiVersati: Double? = nil,
                            fattureConBollo: Int = 0, perAttivita: [String: Double]? = nil, r regoleIn: Regole = .attuali) -> RisultatoForfettario {
        // Le regole dell'anno del calcolo (2025, 2026…)
        let r = regoleIn.anno == anno ? regoleIn : Regole.per(anno: anno)
        let ricavi = arrotonda(ricaviIn)
        // Con più attività: reddito = somma di (incassi × percentuale) di ognuna; quel che non è assegnato va alla principale
        let quote: [(codice: String, ricavi: Double)] = {
            guard let perAttivita, perAttivita.count > 1 || perAttivita.keys.first != p.ateco else { return [(p.ateco, ricavi)] }
            let assegnati = perAttivita.values.reduce(0, +)
            var q = perAttivita.map { ($0.key, $0.value) }.sorted { $0.0 < $1.0 }
            if ricavi - assegnati > 0.005 { q.append((p.ateco, ricavi - assegnati)) }
            return q
        }()
        // Con un solo lavoro conta il suo codice (anche se non è la principale, quando tutto è assegnato a un'altra attività)
        let gruppo = Ateco.gruppo(ateco2007: quote.count == 1 ? quote[0].codice : p.ateco, r: r) ?? Ateco.gruppo("altre", r: r)
        let redditoLordo = arrotonda(quote.reduce(0) { $0 + $1.ricavi * (Ateco.gruppo(ateco2007: $1.codice, r: r) ?? Ateco.gruppo("altre", r: r)).coefficiente })
        let coefficiente = ricavi > 0 && quote.count > 1 ? redditoLordo / ricavi : gruppo.coefficiente
        let dovuti = Self.contributi(p, reddito: redditoLordo, forfettario: true, mesi: mesiAttivi(p, anno: anno), r: r)
        let contributi = dovuti.totale
        let stimati = contributiVersati == nil
        let primoAnno = stimati && anno <= p.annoApertura
        let dedotti = arrotonda(min(redditoLordo, contributiVersati ?? contributiDeducibiliStimati(p, anno: anno, dovuti: dovuti)))
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
        case .separata: String(localized: "Gestione Separata \(Formato.pct(aliquotaSeparata(p, r: r)))")
        case .artigiani: (p.riduzione35 ? "Artigiani, riduzione 35%" : "Artigiani").tradotto
        case .commercianti: (p.riduzione35 ? "Commercianti, riduzione 35%" : "Commercianti").tradotto
        case .cassa: String(localized: "Cassa professionale \(Formato.pct(p.cassaAliquota ?? 0)) (dato inserito da te)")
        }

        var righe: [Riga] = [
            Riga(etichetta: "Incassato", formula: "Somma delle fatture incassate nell'anno", importo: ricavi),
            Riga(etichetta: "Reddito lordo",
                 formula: quote.count > 1
                    ? quote.map { "\(Formato.euro($0.ricavi)) × \(Formato.pct((Ateco.gruppo(ateco2007: $0.codice, r: r) ?? Ateco.gruppo("altre", r: r)).coefficiente)) (\($0.codice))" }.joined(separator: " + ")
                    : String(localized: "\(Formato.euro(ricavi)) × coefficiente \(Formato.pct(coefficiente)) (\(gruppo.nome.tradotto))"),
                 importo: redditoLordo, fonte: r.fonte(r.forfettario.aliquotaOrdinaria)),
            Riga(etichetta: "Contributi INPS", formula: nomeGestione, importo: -contributi, fonte: fonteInps),
            Riga(etichetta: "Contributi dedotti",
                 formula: primoAnno ? "Primo anno: la pensione di quest'anno si paga l'anno prossimo, quindi si toglie solo quella già versata"
                          : stimati ? "Stima: contributi dell'anno, come se fossero versati nell'anno"
                                  : "Contributi effettivamente versati nell'anno",
                 importo: dedotti),
            Riga(etichetta: "Reddito imponibile", formula: "\(Formato.euro(redditoLordo)) − \(Formato.euro(dedotti))", importo: imponibile),
            Riga(etichetta: String(localized: "Imposta sostitutiva \(Formato.pct(aliquota))"),
                 formula: "\(Formato.euro(imponibile)) × \(Formato.pct(aliquota))",
                 importo: -imposta, fonte: r.fonte(r.forfettario.aliquotaOrdinaria)),
        ]
        if bolli > 0 {
            righe.append(Riga(etichetta: "Marche da bollo",
                              formula: String(localized: "\(fattureConBollo) fatture sopra \(Formato.euro(r.bollo.sogliaFattura.valore)) × \(Formato.euro(r.bollo.importo.valore))"),
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
        // Ogni parte resta tra 0 e 100: con la pensione fissa sopra gli incassi «a te» va a 0, non sotto
        let inps = min(100, arrotonda(res.contributi / res.ricavi * 100))
        let stato = min(100 - inps, arrotonda((res.imposta + res.bolli) / res.ricavi * 100))
        return (stato, inps, max(0, arrotonda(100 - stato - inps)))
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
    static func detrazioneLavoroAutonomo(_ reddito: Double, r: Regole = .attuali) -> Double {
        detrazione(reddito, tratti: r.irpef.detrazioneLavoroAutonomo.valore)
    }

    /// Una detrazione a tratti (art. 13 TUIR), con i numeri da regole-AAAA.json
    static func detrazione(_ reddito: Double, tratti: [Regole.Tratto]) -> Double {
        var inizio = 0.0
        for (i, t) in tratti.enumerated() {
            if reddito <= t.fino {
                if i == 0 || t.variabile == 0 || t.fino <= inizio { return arrotonda(t.fisso) }
                return arrotonda(t.fisso + t.variabile * (t.fino - reddito) / (t.fino - inizio))
            }
            inizio = t.fino
        }
        return 0
    }

    /// «23% / 33% / 43%»: le aliquote IRPEF dell'anno, prese dalle regole
    static func testoScaglioni(_ r: Regole) -> String {
        r.irpef.scaglioni.valore.map { Formato.pct($0.aliquota) }.joined(separator: " / ")
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
        let contributi = Self.contributi(p, reddito: reddito, forfettario: false, r: r).totale
        let imponibile = arrotonda(max(0, reddito - contributi))
        let irpef = arrotonda(max(0, irpefLorda(imponibile, r: r) - detrazioneLavoroAutonomo(imponibile, r: r)))
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
                Riga(etichetta: "IRPEF netta", formula: String(localized: "Scaglioni \(testoScaglioni(r)) meno detrazione lavoro autonomo"),
                     importo: -irpef, fonte: r.fonte(r.irpef.scaglioni)),
                Riga(etichetta: "Addizionali", formula: String(localized: "\(Formato.pct(aliqAdd)) stimato (dipende da Regione e Comune)"),
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
        /// Incassi per attività (codice ATECO 2007); vuoto se c'è una sola attività
        var perAttivita: [String: Double] = [:]
    }

    static func riepilogo(_ fatture: [Fattura], anno: Int, r: Regole = .attuali) -> Riepilogo {
        let incassate = fatture.filter { $0.incassata && Giorno.anno($0.dataIncasso ?? $0.data) == anno }
        let daIncassare = fatture.filter { !$0.incassata }
        let conBollo = fatture.filter { Giorno.anno($0.data) == anno && $0.importo > r.bollo.sogliaFattura.valore }.count
        var perAttivita: [String: Double] = [:]
        if incassate.contains(where: { $0.ateco != nil }) {
            for f in incassate { if let a = f.ateco { perAttivita[a, default: 0] += f.importo } }
        }
        return Riepilogo(ricavi: arrotonda(incassate.reduce(0) { $0 + $1.importo }),
                         daIncassare: arrotonda(daIncassare.reduce(0) { $0 + $1.importo }),
                         nIncassate: incassate.count, nDaIncassare: daIncassare.count, fattureConBollo: conBollo,
                         perAttivita: perAttivita)
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
    static func seFatturoAncora(_ p: Profilo, anno: Int, ricaviAttuali: Double, extra: Double, contributiVersati: Double? = nil,
                                perAttivita: [String: Double]? = nil, r: Regole = .attuali) -> SeFatturo {
        // L'incasso in più va all'attività principale (quel che non è assegnato va lì)
        let prima = forfettario(p, anno: anno, ricavi: ricaviAttuali, contributiVersati: contributiVersati, perAttivita: perAttivita, r: r)
        let dopo = forfettario(p, anno: anno, ricavi: ricaviAttuali + extra, contributiVersati: contributiVersati, perAttivita: perAttivita, r: r)
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
        // Un anno con tutte le fonti ancora da confermare (per esempio il 2027 prima della legge di bilancio)
        if !r.fonti.isEmpty && r.fonti.values.allSatisfy({ !$0.verificata }) {
            out.append(String(localized: "I numeri del \(String(r.anno)) sono provvisori: le regole di quell'anno non sono ancora tutte uscite. Li aggiorno appena escono."))
        }
        if ricaviAnno > f.sogliaUscitaImmediata.valore {
            out.append(String(localized: "Hai superato \(Formato.euro(f.sogliaUscitaImmediata.valore)): esci dal forfettario già da quest'anno, con l'IVA dalla fattura che supera la soglia. Senti subito un commercialista."))
        } else if ricaviAnno > f.sogliaRicavi.valore {
            out.append(String(localized: "Hai superato \(Formato.euro(f.sogliaRicavi.valore)): dal prossimo anno passi al regime ordinario."))
        } else if ricaviAnno > f.sogliaRicavi.valore * 0.85 {
            out.append(String(localized: "Sei vicino alla soglia: mancano \(Formato.euro(f.sogliaRicavi.valore - ricaviAnno)) a \(Formato.euro(f.sogliaRicavi.valore))."))
        }
        if (p.redditoDipendente ?? 0) > f.limiteRedditoDipendente.valore {
            out.append(String(localized: "Il reddito da dipendente supera \(Formato.euro(f.limiteRedditoDipendente.valore)): potresti non avere i requisiti per il forfettario. Verifica con un commercialista."))
        }
        if p.gestione == .cassa && (p.cassaAliquota ?? 0) == 0 {
            out.append("Inserisci l'aliquota della tua cassa professionale per un calcolo dei contributi corretto.")
        }
        return out
    }

    // MARK: - Funzioni della roadmap (fase 1)

    /// Di un incasso, quanto mettere da parte per tasse e pensione (al margine, con gli incassi già fatti)
    static func daMettereDaParte(_ p: Profilo, anno: Int, ricaviAttuali: Double, incasso: Double, r: Regole = .attuali) -> Double {
        let s = seFatturoAncora(p, anno: anno, ricaviAttuali: ricaviAttuali, extra: incasso, r: r)
        return arrotonda(incasso - s.nettoExtra)
    }

    /// Con la rivalsa INPS del 4% il cliente paga compenso × 1,04: tutto è ricavo
    static func conRivalsa(_ compenso: Double, r: Regole = .attuali) -> Double {
        arrotonda(compenso * (1 + r.gestioneSeparata.rivalsa.valore))
    }

    /// Tariffa oraria minima per avere un netto mensile, con le ore fatturabili in un anno
    static func tariffaOraria(_ p: Profilo, anno: Int, nettoMensile: Double, oreAnno: Double = 1_400, r: Regole = .attuali) -> Double {
        guard oreAnno > 0 else { return 0 }
        return (incassoPerNetto(p, anno: anno, netto: nettoMensile * 12, r: r) / oreAnno).rounded(.up)
    }

    /// Detrazione per lavoro dipendente (art. 13 c. 1 TUIR), anno intero
    static func detrazioneDipendente(_ reddito: Double, r: Regole = .attuali) -> Double {
        detrazione(reddito, tratti: r.irpef.detrazioneDipendente.valore)
    }

    /// Netto annuo di un dipendente con una certa RAL (stima semplificata: contributi dalle regole, IRPEF,
    /// detrazione lavoro dipendente, addizionali medie; senza cuneo fiscale né trattamento integrativo)
    static func nettoDipendente(ral: Double, r: Regole = .attuali) -> Double {
        let contributi = ral * r.irpef.contributiDipendente.valore
        let imponibile = max(0, ral - contributi)
        let irpef = max(0, irpefLorda(imponibile, r: r) - detrazioneDipendente(imponibile, r: r))
        let addizionali = imponibile * r.irpef.addizionaliDefault.valore
        return arrotonda(ral - contributi - irpef - addizionali)
    }

    /// La RAL da dipendente che darebbe lo stesso netto annuo
    static func ralEquivalente(netto: Double, r: Regole = .attuali) -> Double {
        var basso = 0.0
        var alto = netto * 3 + 10_000
        for _ in 0..<60 {
            let medio = (basso + alto) / 2
            if nettoDipendente(ral: medio, r: r) < netto { basso = medio } else { alto = medio }
        }
        return (alto / 100).rounded(.up) * 100
    }

    /// Avviso sull'aliquota al 5%: quanti mesi mancano alla fine (nil se non applicabile o lontana)
    static func avvisoFineStartup(_ p: Profilo, oggi: Date = Date(), r: Regole = .attuali) -> String? {
        guard let ultimo = ultimoAnnoStartup(p, r: r) else { return nil }
        let annoOggi = Giorno.anno(oggi)
        let startup = Formato.pct(r.forfettario.aliquotaStartup.valore)
        let ordinaria = Formato.pct(r.forfettario.aliquotaOrdinaria.valore)
        if ultimo == annoOggi {
            return String(localized: "Quest'anno è l'ultimo con le tasse al \(startup). Dal \(String(ultimo + 1)) passano al \(ordinaria).")
        }
        if ultimo == annoOggi + 1 {
            return String(localized: "Le tasse al \(startup) valgono fino al \(String(ultimo)). Poi passano al \(ordinaria).")
        }
        return nil
    }

    /// Da quanti giorni una fattura aspetta di essere pagata (0 se pagata)
    static func giorniInAttesa(_ f: Fattura, oggi: Date = Date()) -> Int {
        guard !f.incassata else { return 0 }
        let inizio = Giorno.calendario.startOfDay(for: f.data)
        return max(0, Giorno.calendario.dateComponents([.day], from: inizio, to: Giorno.calendario.startOfDay(for: oggi)).day ?? 0)
    }
}
