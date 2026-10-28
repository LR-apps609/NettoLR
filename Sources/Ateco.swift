import Foundation

// Coefficienti di redditività del forfettario (L. 190/2014, all. 4 come sostituito da L. 145/2018): i valori stanno nelle regole dell'anno.
// Per il 2026 il coefficiente si determina ancora dal codice ATECO 2007 (quadro LM, rigo LM22), anche se
// dal 1/4/2025 è in vigore ATECO 2025: in attesa di una tabella ufficiale di raccordo l'app chiede l'ATECO 2007.

struct GruppoCoefficiente: Identifiable, Equatable {
    let id: String
    let nome: String
    let coefficiente: Double
    let divisioni2007: String
}

struct Attivita: Identifiable, Equatable {
    var id: String { ateco2007 }
    let ateco2007: String
    let descrizione: String
    /// Le parole che la gente usa davvero per cercare
    let sinonimi: [String]
    let gestioneTipica: Gestione
}

enum Ateco {
    /// I gruppi con la loro percentuale, da Resources/Rules (uguali nel 2025 e nel 2026)
    static let gruppi: [GruppoCoefficiente] = Regole.attuali.forfettario.coefficienti.valore.map {
        GruppoCoefficiente(id: $0.id, nome: $0.nome, coefficiente: $0.valore, divisioni2007: $0.divisioni2007)
    }

    static func gruppo(_ id: String) -> GruppoCoefficiente {
        gruppi.first { $0.id == id } ?? gruppi[gruppi.count - 1]
    }

    /// Le cifre di un codice ("62.01.00" → "620100")
    static func cifre(_ codice: String) -> String { codice.filter(\.isNumber) }

    /// Il gruppo dal codice ATECO 2007 ("62.01.00", "6201", "47.82"…); nil se il codice è troppo corto
    static func gruppo(ateco2007 codice: String) -> GruppoCoefficiente? {
        let c = cifre(codice)
        guard c.count >= 2 else { return nil }
        func n(_ k: Int) -> Int { Int(c.prefix(k)) ?? -1 }
        let div = n(2)
        let gruppo3 = c.count >= 3 ? n(3) : -1      // es. 461 per 46.1
        let classe4 = c.count >= 4 ? n(4) : -1      // es. 4781 per 47.81
        if div == 10 || div == 11 { return gruppo("alimentari") }
        if classe4 == 4781 { return gruppo("ambulante-alimentari") }
        if (4782...4789).contains(classe4) { return gruppo("ambulante-altri") }
        if gruppo3 == 461 { return gruppo("intermediari") }
        if div == 45 || (462...469).contains(gruppo3) || (471...477).contains(gruppo3) || gruppo3 == 479 { return gruppo("commercio") }
        if (41...43).contains(div) || div == 68 { return gruppo("costruzioni") }
        if div == 55 || div == 56 { return gruppo("alloggio") }
        if (64...66).contains(div) || (69...75).contains(div) || (85...88).contains(div) { return gruppo("professionali") }
        return gruppo("altre")
    }

    // Elenco iniziale delle attività più comuni tra i forfettari.
    // Da sostituire con la struttura completa ISTAT più la tabella di raccordo 2025 ↔ 2007.
    static let attivita: [Attivita] = [
        Attivita(ateco2007: "62.01.00", descrizione: "Produzione di software non connesso all’edizione", sinonimi: ["sviluppatore", "programmatore", "app", "software", "developer"], gestioneTipica: .separata),
        Attivita(ateco2007: "62.02.00", descrizione: "Consulenza nel settore delle tecnologie dell’informatica", sinonimi: ["consulente it", "informatico", "sistemista"], gestioneTipica: .separata),
        Attivita(ateco2007: "62.09.09", descrizione: "Altre attività dei servizi connessi alle tecnologie dell’informatica", sinonimi: ["assistenza informatica", "tecnico pc"], gestioneTipica: .separata),
        Attivita(ateco2007: "63.12.00", descrizione: "Portali web", sinonimi: ["sito web", "blog", "portale"], gestioneTipica: .separata),
        Attivita(ateco2007: "73.11.02", descrizione: "Conduzione di campagne di marketing e altri servizi pubblicitari", sinonimi: ["social media manager", "marketing", "ads", "pubblicità"], gestioneTipica: .separata),
        Attivita(ateco2007: "74.10.21", descrizione: "Attività dei disegnatori grafici di pagine web", sinonimi: ["web designer", "grafico web", "ux", "ui"], gestioneTipica: .separata),
        Attivita(ateco2007: "74.10.29", descrizione: "Altre attività dei disegnatori grafici", sinonimi: ["grafico", "graphic designer", "illustratore"], gestioneTipica: .separata),
        Attivita(ateco2007: "74.20.19", descrizione: "Altre attività di riprese fotografiche", sinonimi: ["fotografo", "foto", "videomaker"], gestioneTipica: .separata),
        Attivita(ateco2007: "74.30.00", descrizione: "Traduzione e interpretariato", sinonimi: ["traduttore", "interprete"], gestioneTipica: .separata),
        Attivita(ateco2007: "70.22.09", descrizione: "Altre attività di consulenza imprenditoriale e di gestione aziendale", sinonimi: ["consulente", "business coach", "consulenza aziendale"], gestioneTipica: .separata),
        Attivita(ateco2007: "74.90.99", descrizione: "Altre attività professionali nca", sinonimi: ["libero professionista", "freelance"], gestioneTipica: .separata),
        Attivita(ateco2007: "69.10.10", descrizione: "Attività degli studi legali", sinonimi: ["avvocato", "legale"], gestioneTipica: .cassa),
        Attivita(ateco2007: "69.20.11", descrizione: "Servizi forniti da dottori commercialisti", sinonimi: ["commercialista"], gestioneTipica: .cassa),
        Attivita(ateco2007: "71.11.00", descrizione: "Attività degli studi di architettura", sinonimi: ["architetto"], gestioneTipica: .cassa),
        Attivita(ateco2007: "71.12.10", descrizione: "Attività degli studi di ingegneria", sinonimi: ["ingegnere"], gestioneTipica: .cassa),
        Attivita(ateco2007: "71.12.20", descrizione: "Servizi di progettazione di ingegneria integrata", sinonimi: ["geometra", "progettista"], gestioneTipica: .cassa),
        Attivita(ateco2007: "86.90.30", descrizione: "Attività svolta da psicologi", sinonimi: ["psicologo", "psicoterapeuta"], gestioneTipica: .cassa),
        Attivita(ateco2007: "86.90.21", descrizione: "Fisioterapia", sinonimi: ["fisioterapista"], gestioneTipica: .separata),
        Attivita(ateco2007: "86.90.29", descrizione: "Altre attività paramediche indipendenti nca", sinonimi: ["nutrizionista", "osteopata", "infermiere"], gestioneTipica: .separata),
        Attivita(ateco2007: "85.59.30", descrizione: "Scuole e corsi di lingua", sinonimi: ["insegnante di lingue", "ripetizioni inglese"], gestioneTipica: .separata),
        Attivita(ateco2007: "85.59.90", descrizione: "Altri servizi di istruzione nca", sinonimi: ["formatore", "docente", "tutor", "ripetizioni"], gestioneTipica: .separata),
        Attivita(ateco2007: "85.51.00", descrizione: "Corsi sportivi e ricreativi", sinonimi: ["personal trainer", "istruttore", "yoga", "pilates"], gestioneTipica: .separata),
        Attivita(ateco2007: "90.03.09", descrizione: "Altre creazioni artistiche e letterarie", sinonimi: ["scrittore", "copywriter", "artista", "content creator"], gestioneTipica: .separata),
        Attivita(ateco2007: "59.11.00", descrizione: "Attività di produzione cinematografica, di video e di programmi televisivi", sinonimi: ["video", "youtuber", "montatore"], gestioneTipica: .separata),
        Attivita(ateco2007: "82.99.99", descrizione: "Altri servizi di supporto alle imprese nca", sinonimi: ["assistente virtuale", "segreteria"], gestioneTipica: .separata),
        Attivita(ateco2007: "96.02.01", descrizione: "Servizi dei saloni di barbiere e parrucchiere", sinonimi: ["parrucchiere", "barbiere", "parrucchiera"], gestioneTipica: .artigiani),
        Attivita(ateco2007: "96.02.02", descrizione: "Servizi degli istituti di bellezza", sinonimi: ["estetista", "nail", "unghie"], gestioneTipica: .artigiani),
        Attivita(ateco2007: "43.21.01", descrizione: "Installazione di impianti elettrici in edifici o in altre opere di costruzione", sinonimi: ["elettricista"], gestioneTipica: .artigiani),
        Attivita(ateco2007: "43.22.01", descrizione: "Installazione di impianti idraulici, di riscaldamento e di condizionamento dell’aria", sinonimi: ["idraulico", "termoidraulico"], gestioneTipica: .artigiani),
        Attivita(ateco2007: "43.34.00", descrizione: "Tinteggiatura e posa in opera di vetri", sinonimi: ["imbianchino", "pittore edile"], gestioneTipica: .artigiani),
        Attivita(ateco2007: "43.39.01", descrizione: "Attività non specializzate di lavori edili (muratori)", sinonimi: ["muratore", "edile", "ristrutturazioni"], gestioneTipica: .artigiani),
        Attivita(ateco2007: "81.21.00", descrizione: "Pulizia generale (non specializzata) di edifici", sinonimi: ["pulizie", "impresa di pulizie"], gestioneTipica: .artigiani),
        Attivita(ateco2007: "95.11.00", descrizione: "Riparazione e manutenzione di computer e periferiche", sinonimi: ["riparazione pc", "tecnico computer"], gestioneTipica: .artigiani),
        Attivita(ateco2007: "68.31.00", descrizione: "Attività di mediazione immobiliare", sinonimi: ["agente immobiliare", "mediatore"], gestioneTipica: .commercianti),
        Attivita(ateco2007: "47.91.10", descrizione: "Commercio al dettaglio di qualsiasi tipo di prodotto effettuato via internet", sinonimi: ["ecommerce", "shop online", "vendita online", "dropshipping"], gestioneTipica: .commercianti),
        Attivita(ateco2007: "47.81.01", descrizione: "Commercio al dettaglio ambulante di prodotti ortofrutticoli", sinonimi: ["ambulante frutta", "mercato"], gestioneTipica: .commercianti),
        Attivita(ateco2007: "47.82.01", descrizione: "Commercio al dettaglio ambulante di tessuti, articoli tessili per la casa, articoli di abbigliamento", sinonimi: ["ambulante abbigliamento", "bancarella"], gestioneTipica: .commercianti),
        Attivita(ateco2007: "46.19.01", descrizione: "Agenti e rappresentanti di vari prodotti senza prevalenza di alcuno", sinonimi: ["agente di commercio", "rappresentante"], gestioneTipica: .commercianti),
        Attivita(ateco2007: "56.10.11", descrizione: "Ristorazione con somministrazione", sinonimi: ["ristorante", "trattoria", "pizzeria"], gestioneTipica: .commercianti),
        Attivita(ateco2007: "56.10.30", descrizione: "Gelaterie e pasticcerie", sinonimi: ["gelateria", "pasticceria"], gestioneTipica: .commercianti),
        Attivita(ateco2007: "55.20.51", descrizione: "Affittacamere per brevi soggiorni, case ed appartamenti per vacanze, B&B, residence", sinonimi: ["b&b", "bed and breakfast", "affittacamere", "casa vacanze"], gestioneTipica: .commercianti),
        Attivita(ateco2007: "49.32.10", descrizione: "Trasporto con taxi", sinonimi: ["tassista", "taxi", "ncc"], gestioneTipica: .artigiani),
    ]

    /// I nomi in inglese dei lavori più comuni (il primo si mostra, tutti servono alla ricerca)
    static let inglese: [String: [String]] = [
        "62.01.00": ["software developer", "programmer", "app developer", "coder"],
        "62.02.00": ["IT consultant", "systems administrator"],
        "62.09.09": ["IT support", "computer technician"],
        "63.12.00": ["website owner", "blogger", "web portal"],
        "73.11.02": ["social media manager", "digital marketer", "advertising"],
        "74.10.21": ["web designer", "UX designer", "UI designer"],
        "74.10.29": ["graphic designer", "illustrator"],
        "74.20.19": ["photographer", "videographer"],
        "74.30.00": ["translator", "interpreter"],
        "70.22.09": ["business consultant", "management consultant", "business coach"],
        "74.90.99": ["freelancer", "self-employed professional"],
        "69.10.10": ["lawyer", "attorney"],
        "69.20.11": ["accountant", "chartered accountant"],
        "71.11.00": ["architect"],
        "71.12.10": ["engineer"],
        "71.12.20": ["surveyor", "design engineer"],
        "86.90.30": ["psychologist", "psychotherapist", "therapist"],
        "86.90.21": ["physiotherapist", "physical therapist"],
        "86.90.29": ["nutritionist", "osteopath", "nurse"],
        "85.59.30": ["language teacher", "English teacher", "language tutor"],
        "85.59.90": ["trainer", "teacher", "tutor"],
        "85.51.00": ["personal trainer", "fitness instructor", "yoga teacher", "pilates instructor"],
        "90.03.09": ["writer", "copywriter", "artist", "content creator"],
        "59.11.00": ["video producer", "YouTuber", "video editor"],
        "82.99.99": ["virtual assistant", "admin support"],
        "96.02.01": ["hairdresser", "barber", "hair stylist"],
        "96.02.02": ["beautician", "nail technician", "beauty therapist"],
        "43.21.01": ["electrician"],
        "43.22.01": ["plumber", "heating engineer"],
        "43.34.00": ["painter and decorator", "house painter"],
        "43.39.01": ["builder", "bricklayer", "renovations"],
        "81.21.00": ["cleaner", "cleaning company"],
        "95.11.00": ["computer repair", "PC repair"],
        "68.31.00": ["estate agent", "real estate agent"],
        "47.91.10": ["online shop", "ecommerce", "online seller", "dropshipping"],
        "47.81.01": ["market trader (fruit and veg)", "market stall"],
        "47.82.01": ["market trader (clothing)", "stallholder"],
        "46.19.01": ["sales agent", "sales representative"],
        "56.10.11": ["restaurant", "pizzeria"],
        "56.10.30": ["ice cream shop", "pastry shop", "bakery"],
        "55.20.51": ["B&B", "bed and breakfast", "holiday rental", "guest house"],
        "49.32.10": ["taxi driver", "private hire driver"],
    ]

    static func normalizza(_ s: String) -> String {
        s.lowercased().folding(options: [.diacriticInsensitive], locale: Formato.it)
            .replacingOccurrences(of: "’", with: " ")
            .replacingOccurrences(of: "'", with: " ")
    }

    // MARK: - Tutti i codici ISTAT (Resources/Rules/ateco.json, costruito da Tools/build_ateco.py)

    private struct Riga2025: Decodable {
        let codice: String, titolo: String, codici2007: [String]
        init(from decoder: Decoder) throws {
            var c = try decoder.unkeyedContainer()
            codice = try c.decode(String.self)
            titolo = try c.decode(String.self)
            codici2007 = try c.decode([String].self)
        }
    }

    private struct File: Decodable {
        let a2007: [[String]]
        let a2025: [Riga2025]
    }

    /// Ogni voce con il suo testo già pronto per la ricerca
    private static let elenco: [(voce: TrovatoAteco, testo: String)] = {
        let bundle = Bundle(for: SegnaBundle.self)
        guard let url = bundle.url(forResource: "ateco", withExtension: "json", subdirectory: "Rules")
                ?? bundle.url(forResource: "ateco", withExtension: "json"),
              let dati = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(File.self, from: dati) else { return [] }
        let comuni = Dictionary(Ateco.attivita.map { ($0.ateco2007, $0) }, uniquingKeysWith: { a, _ in a })
        var out: [(TrovatoAteco, String)] = []
        for r in file.a2007 where r.count >= 2 {
            let a = comuni[r[0]]
            let voce = TrovatoAteco(codice: r[0], titolo: r[1], versione: .v2007, codici2007: [r[0]],
                                    nomeComune: a.map(Ateco.nomeComune))
            out.append((voce, Ateco.normalizza(([r[1]] + (a?.sinonimi ?? []) + (inglese[r[0]] ?? [])).joined(separator: " "))))
        }
        for r in file.a2025 {
            let voce = TrovatoAteco(codice: r.codice, titolo: r.titolo, versione: .v2025, codici2007: r.codici2007, nomeComune: nil)
            out.append((voce, Ateco.normalizza(r.titolo)))
        }
        return out
    }()

    static var numeroCodici: Int { elenco.count }

    /// Il titolo ISTAT di un codice ATECO 2007
    static func titolo2007(_ codice: String) -> String? {
        elenco.first { $0.voce.versione == .v2007 && $0.voce.codice == codice }?.voce.titolo
    }

    /// Il nome che usa la gente («Web designer») se c'è, altrimenti il titolo ISTAT
    static func nomeLavoro(_ codice2007: String) -> String {
        if let a = attivita.first(where: { $0.ateco2007 == codice2007 }) { return nomeComune(a) }
        return titolo2007(codice2007) ?? codice2007
    }

    static func nomeComune(_ a: Attivita) -> String {
        guard let s = (Formato.inglese ? inglese[a.ateco2007]?.first : nil) ?? a.sinonimi.first else { return a.descrizione }
        return s.prefix(1).uppercased() + s.dropFirst()
    }

    /// Cerca tra tutti i codici ATECO 2007 e 2025: per codice («62.01», «6201») o per parole («faccio siti web»)
    static func cerca(_ testo: String, max: Int = 12) -> [TrovatoAteco] {
        let q = normalizza(testo.trimmingCharacters(in: .whitespaces))
        guard !q.isEmpty else { return [] }
        let numeri = cifre(q)
        if numeri.count >= 2, q.allSatisfy({ $0.isNumber || $0 == "." || $0 == " " }) {
            let trovati = elenco.filter { cifre($0.voce.codice).hasPrefix(numeri) }.map(\.voce)
            // Prima i codici esatti, poi il 2007 (decide la percentuale), poi il 2025
            return Array(trovati.sorted { a, b in
                let ea = cifre(a.codice) == numeri, eb = cifre(b.codice) == numeri
                if ea != eb { return ea }
                if a.versione != b.versione { return a.versione == .v2007 }
                return a.codice < b.codice
            }.prefix(max))
        }
        let parole = q.split(separator: " ").map(String.init).filter { $0.count > 2 }
        guard !parole.isEmpty else { return [] }
        let punteggi: [(TrovatoAteco, Int)] = elenco.compactMap { e in
            let colpite = parole.filter { e.testo.contains($0) }.count
            guard colpite > 0 else { return nil }
            var punti = colpite * 10
            if colpite == parole.count { punti += 20 }
            if e.voce.nomeComune != nil { punti += 5 }
            if let comune = attivita.first(where: { $0.ateco2007 == e.voce.codice }),
               (comune.sinonimi + (inglese[comune.ateco2007] ?? [])).contains(where: { q.contains(normalizza($0)) }) { punti += 40 }
            if e.voce.versione == .v2007 { punti += 1 }
            return (e.voce, punti)
        }
        return Array(punteggi.sorted { $0.1 > $1.1 }.prefix(max).map(\.0))
    }
}

/// Un codice ATECO trovato nella ricerca, 2007 o 2025
struct TrovatoAteco: Identifiable, Equatable {
    enum Versione: String { case v2007 = "ATECO 2007", v2025 = "ATECO 2025" }
    var id: String { versione.rawValue + codice }
    let codice: String
    let titolo: String
    let versione: Versione
    /// I codici 2007 corrispondenti (per un codice 2007: sé stesso)
    let codici2007: [String]
    /// Il nome che usa la gente, se è tra i lavori più comuni
    let nomeComune: String?

    /// I gruppi di coefficiente toccati: più di uno = bisogna scegliere il codice 2007
    var gruppi: [GruppoCoefficiente] {
        var visti: [GruppoCoefficiente] = []
        for c in codici2007 {
            if let g = Ateco.gruppo(ateco2007: c), !visti.contains(g) { visti.append(g) }
        }
        return visti
    }

    var ambiguo: Bool { gruppi.count > 1 }

    var percentuale: String {
        let valori = gruppi.map { Int(($0.coefficiente * 100).rounded()) }
        guard let minimo = valori.min(), let massimo = valori.max() else { return "?" }
        return minimo == massimo ? "\(minimo)%" : "\(minimo)–\(massimo)%"
    }
}
