import SwiftUI

// Il benvenuto e le quattro domande facili. Le stesse domande servono a «Tu» per cambiare il profilo.

struct BenvenutoView: View {
    @EnvironmentObject private var store: Store
    @State private var iniziato = false
    @State private var timbro = false
    @Environment(\.accessibilityReduceMotion) private var menoMovimento

    var body: some View {
        if iniziato {
            DomandeProfilo(iniziale: nil) { store.profilo = $0 }
        } else {
            VStack(spacing: 0) {
                Marca(colore: Theme.rosaChiaro, inchiostro: Theme.notte)
                    .frame(width: 132, height: 132)
                    .scaleEffect(timbro ? 1 : 1.6)
                    .rotationEffect(.degrees(timbro ? -6 : -14))
                    .opacity(timbro ? 1 : 0)
                    .padding(.top, 70)
                VStack(spacing: 14) {
                    Text("Quanto ti resta,\ndavvero?")
                        .font(.system(size: 40, weight: .heavy, design: .rounded))
                        .multilineTextAlignment(.center)
                    Text("Te lo diciamo con quattro domande facili.")
                        .font(.app(18)).foregroundStyle(Theme.suNotte.opacity(0.85))
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 44)
                VStack(alignment: .leading, spacing: 12) {
                    promessa("Niente account, niente moduli")
                    promessa("I tuoi dati restano sul telefono")
                    promessa("Parole semplici, zero sigle")
                }
                .padding(.top, 40)
                Spacer()
                Button("Iniziamo") { withAnimation(.easeInOut) { iniziato = true } }
                    .buttonStyle(PulsantePieno(colore: Theme.rosaChiaro, testo: Theme.notte))
                    .accessibilityIdentifier("benvenuto.inizia")
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 24).padding(.bottom, 24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Aurora().opacity(0.8).ignoresSafeArea())
            .onAppear {
                if menoMovimento { timbro = true } else { withAnimation(.spring(duration: 0.6, bounce: 0.4).delay(0.2)) { timbro = true } }
            }
            .sensoryFeedback(.impact(weight: .medium), trigger: timbro)
        }
    }

    private func promessa(_ testo: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark").font(.app(16, .bold)).foregroundStyle(Theme.rosaChiaro)
            Text(testo.tradotto).font(.app(17)).foregroundStyle(Theme.suNotte)
        }
    }
}

/// Le quattro domande: lavoro, apertura, pensione, altri redditi
struct DomandeProfilo: View {
    let iniziale: Profilo?
    let salva: (Profilo) -> Void

    @State private var passo = 0
    @State private var ricerca = ""
    @State private var ateco = ""
    @State private var nomeLavoro = ""
    @State private var annoApertura = Regole.attuali.anno
    @State private var primaVolta = true
    @State private var gestione = Gestione.separata
    @State private var riduzione35 = false
    @State private var cassaAliquota = ""
    @State private var cassaFisso = ""
    @State private var haStipendio = false
    @State private var stipendio = ""
    @State private var nome = ""
    @State private var mostraGruppi = false
    @State private var daScegliere: TrovatoAteco?
    @State private var certificato = false
    @State private var pivaLetta: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 6) {
                ForEach(0..<4) { i in
                    Capsule().fill(i <= passo ? Theme.prugna : Theme.line).frame(height: 5)
                }
            }
            .accessibilityLabel("Domanda \(passo + 1) di 4")
            .padding(.top, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    switch passo {
                    case 0: lavoro
                    case 1: apertura
                    case 2: pensione
                    default: altriRedditi
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .animation(.easeInOut, value: passo)
            }
            .scrollDismissesKeyboard(.interactively)

            HStack(spacing: 12) {
                if passo > 0 {
                    Button { withAnimation { passo -= 1 } } label: { Image(systemName: "chevron.left").font(.app(18, .bold)) }
                        .frame(width: 58, height: 58)
                        .background(Theme.raised, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .accessibilityLabel("Indietro")
                }
                Button((passo < 3 ? "Avanti" : "Fatto").tradotto) { avanti() }
                    .buttonStyle(PulsantePieno())
                    .disabled(passo == 0 && ateco.isEmpty)
                    .opacity(passo == 0 && ateco.isEmpty ? 0.4 : 1)
                    .accessibilityIdentifier("profilo.avanti")
            }
        }
        .padding(.horizontal, 20).padding(.bottom, 12)
        .background(Theme.ground.ignoresSafeArea())
        .foregroundStyle(Theme.ink)
        .onAppear(perform: riempi)
        .sheet(isPresented: $certificato) {
            CertificatoView { codice, piva in
                imposta(codice)
                pivaLetta = piva
                certificato = false
            }
        }
    }

    // MARK: Le domande

    private var lavoro: some View {
        VStack(alignment: .leading, spacing: 16) {
            domanda("Che lavoro fai?")
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(Theme.muted)
                TextField("Scrivilo come lo diresti a un amico", text: $ricerca)
                    .font(.app(17))
                    .accessibilityIdentifier("profilo.cerca")
            }
            .padding(.horizontal, 14).frame(height: 52)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            if ricerca.isEmpty {
                Text("Per esempio").font(.app(14, .semibold)).foregroundStyle(Theme.muted)
                FlowChips(voci: Ateco.attivita.filter { Self.popolari.contains($0.ateco2007) }.map(Ateco.nomeComune)) { ricerca = $0 }
            }
            if let scelto = daScegliere {
                sceltaCodice2007(scelto)
            } else {
                VStack(spacing: 8) {
                    ForEach(Ateco.cerca(ricerca)) { t in
                        Button { scegli(t) } label: { voceTrovata(t) }
                            .buttonStyle(Molla())
                    }
                }
            }
            if !ateco.isEmpty, let g = Ateco.gruppo(ateco2007: ateco) {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.seal.fill").font(.app(22)).foregroundStyle(Theme.menta)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(nomeLavoro) · ATECO \(ateco)").font(.app(15, .bold))
                        Text("Conta come reddito il \(Int(g.coefficiente * 100))% di quello che incassi").font(.app(14)).foregroundStyle(Theme.muted)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.mentaSoft, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
            Button { certificato = true } label: {
                Label("Ho il certificato della partita IVA: fotografalo", systemImage: "doc.viewfinder")
                    .font(.app(16, .semibold))
            }
            .accessibilityIdentifier("profilo.certificato")
            Text("Puoi scrivere anche il codice ATECO, vecchio (2007) o nuovo (2025): lo trovi sul certificato della partita IVA o nella dichiarazione.")
                .font(.app(13)).foregroundStyle(Theme.muted)
            Button((mostraGruppi ? "Nascondi" : "Non trovo il mio lavoro").tradotto) { withAnimation { mostraGruppi.toggle() } }
                .font(.app(16, .semibold))
            if mostraGruppi {
                VStack(spacing: 8) {
                    ForEach(Ateco.gruppi) { g in
                        Button {
                            imposta(Self.codiceRappresentativo[g.id] ?? "74.90.99")
                            nomeLavoro = g.nome
                        } label: {
                            Text(g.nome.tradotto).font(.app(15)).multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(14)
                                .background(nomeLavoro == g.nome ? Theme.prugnaSoft : Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var apertura: some View {
        VStack(alignment: .leading, spacing: 16) {
            domanda("Da quando hai la partita IVA?")
            Picker("Anno", selection: $annoApertura) {
                ForEach((1990...Regole.attuali.anno).reversed(), id: \.self) { Text(String($0)).tag($0) }
            }
            .pickerStyle(.wheel)
            .frame(height: 150)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            domanda("È la prima volta che lavori in proprio?", piccola: true)
            sceltaSiNo($primaVolta)
            Text("Se è la prima volta, per cinque anni le tasse sono al 5% invece del 15%.")
                .font(.app(15)).foregroundStyle(Theme.muted)
        }
    }

    private var pensione: some View {
        VStack(alignment: .leading, spacing: 14) {
            domanda("Dove versi la pensione?")
            opzione(.separata, "INPS, Gestione Separata", "La strada della maggior parte dei liberi professionisti")
            opzione(.artigiani, "INPS, Artigiani", "Parrucchieri, idraulici, elettricisti…")
            opzione(.commercianti, "INPS, Commercianti", "Negozi, vendita online, agenti…")
            opzione(.cassa, "Una cassa del mio ordine", "Avvocati, ingegneri, psicologi…")
            if gestione == .artigiani || gestione == .commercianti {
                domanda("Hai chiesto lo sconto del 35% sui contributi?", piccola: true)
                sceltaSiNo($riduzione35)
            }
            if gestione == .cassa {
                CampoEuro(etichetta: "Percentuale della tua cassa (es. 14,5)", testo: $cassaAliquota)
                CampoEuro(etichetta: "Contributo minimo all'anno", testo: $cassaFisso)
            }
            Text("Non sei sicuro? Lo trovi nel cassetto previdenziale INPS o chiedilo al commercialista.")
                .font(.app(14)).foregroundStyle(Theme.muted)
        }
    }

    private var altriRedditi: some View {
        VStack(alignment: .leading, spacing: 16) {
            domanda("Hai anche uno stipendio o una pensione?")
            sceltaSiNo($haStipendio)
            if haStipendio {
                CampoEuro(etichetta: "Quanto, all'anno, lordo", testo: $stipendio)
            }
            domanda("Come ti chiamiamo?", piccola: true)
            TextField("Il tuo nome (facoltativo)", text: $nome)
                .font(.app(17))
                .padding(.horizontal, 14).frame(height: 52)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    // MARK: Pezzi

    private func domanda(_ testo: String, piccola: Bool = false) -> some View {
        Text(testo.tradotto)
            .font(.system(size: piccola ? 22 : 30, weight: .heavy, design: .rounded))
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, piccola ? 8 : 0)
    }

    private func sceltaSiNo(_ valore: Binding<Bool>) -> some View {
        HStack(spacing: 10) {
            ForEach([true, false], id: \.self) { v in
                Button((v ? "Sì" : "No").tradotto) { valore.wrappedValue = v }
                    .font(.app(17, .bold))
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .foregroundStyle(valore.wrappedValue == v ? Theme.suPrugna : Theme.ink)
                    .background(valore.wrappedValue == v ? Theme.prugna : Theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }

    private func opzione(_ g: Gestione, _ titolo: String, _ sotto: String) -> some View {
        Button { gestione = g } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(titolo.tradotto).font(.app(17, .semibold))
                    Text(sotto.tradotto).font(.app(14)).foregroundStyle(Theme.muted)

                }
                Spacer()
                Image(systemName: gestione == g ? "checkmark.circle.fill" : "circle")
                    .font(.app(22)).foregroundStyle(gestione == g ? Theme.prugna : Theme.line)
            }
            .padding(16)
            .background(gestione == g ? Theme.prugnaSoft : Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: Logica

    private func scegli(_ t: TrovatoAteco) {
        if t.ambiguo {
            withAnimation(.spring) { daScegliere = t }
            return
        }
        if let c = t.codici2007.first { imposta(c) }
    }

    private func imposta(_ codice2007: String) {
        withAnimation(.spring(duration: 0.4, bounce: 0.3)) {
            ateco = codice2007
            nomeLavoro = Ateco.nomeLavoro(codice2007)
            daScegliere = nil
        }
        if let a = Ateco.attivita.first(where: { $0.ateco2007 == codice2007 }) { gestione = a.gestioneTipica }
    }

    private func voceTrovata(_ t: TrovatoAteco) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(t.nomeComune ?? t.titolo).font(.app(16, .semibold)).multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Text("\(t.versione.rawValue) \(t.codice)" + (t.nomeComune != nil ? " · \(t.titolo)" : ""))
                    .font(.app(12)).foregroundStyle(Theme.muted).lineLimit(2)
            }
            Spacer(minLength: 4)
            Text(t.percentuale)
                .font(.app(14, .heavy))
                .padding(.horizontal, 10).padding(.vertical, 6)
                .foregroundStyle(t.ambiguo ? Theme.tasseTesto : Theme.prugna)
                .background(t.ambiguo ? Theme.tasseSoft : Theme.prugnaSoft, in: Capsule())
        }
        .padding(14)
        .background(t.codici2007.first == ateco && !t.ambiguo ? Theme.prugnaSoft : Theme.card,
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    /// Un codice 2025 che corrisponde a più codici 2007 con percentuali diverse: si sceglie quale
    private func sceltaCodice2007(_ t: TrovatoAteco) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Il codice \(t.codice) del 2025 corrisponde a più attività di prima. Quale fai?")
                .font(.app(16, .bold)).fixedSize(horizontal: false, vertical: true)
            ForEach(t.codici2007, id: \.self) { c in
                Button { imposta(c) } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(Ateco.titolo2007(c) ?? c).font(.app(15, .semibold)).multilineTextAlignment(.leading)
                            Text("ATECO 2007 \(c)").font(.app(12)).foregroundStyle(Theme.muted)
                        }
                        Spacer()
                        Text("\(Int((Ateco.gruppo(ateco2007: c)?.coefficiente ?? 0) * 100))%").font(.app(14, .heavy)).foregroundStyle(Theme.prugna)
                    }
                    .padding(12)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(Molla())
            }
            Button("Annulla") { withAnimation { daScegliere = nil } }.font(.app(15, .semibold))
        }
        .padding(14)
        .background(Theme.tasseSoft, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func avanti() {
        if passo < 3 {
            withAnimation { passo += 1 }
            return
        }
        salva(Profilo(
            nome: nome.trimmingCharacters(in: .whitespaces),
            partitaIVA: pivaLetta ?? iniziale?.partitaIVA ?? "",
            ateco: ateco,
            annoApertura: annoApertura,
            requisitiStartup: primaVolta,
            gestione: gestione,
            riduzione35: (gestione == .artigiani || gestione == .commercianti) && riduzione35,
            cassaAliquota: gestione == .cassa ? Formato.leggiEuro(cassaAliquota) / 100 : nil,
            cassaFisso: gestione == .cassa ? Formato.leggiEuro(cassaFisso) : nil,
            redditoDipendente: haStipendio ? Formato.leggiEuro(stipendio) : nil,
            rivalsa4: iniziale?.rivalsa4 ?? false,
            promemoria: iniziale?.promemoria ?? true))
    }

    private func riempi() {
        guard let p = iniziale else { return }
        ateco = p.ateco
        nomeLavoro = Ateco.nomeLavoro(p.ateco)
        annoApertura = p.annoApertura
        primaVolta = p.requisitiStartup
        gestione = p.gestione
        riduzione35 = p.riduzione35
        cassaAliquota = Formato.campo(p.cassaAliquota.map { $0 * 100 })
        cassaFisso = Formato.campo(p.cassaFisso)
        haStipendio = (p.redditoDipendente ?? 0) > 0
        stipendio = Formato.campo(p.redditoDipendente)
        nome = p.nome
    }

    static let popolari: Set<String> = ["74.10.21", "62.01.00", "73.11.02", "74.20.19", "85.59.90", "96.02.01", "47.91.10", "86.90.29"]

    /// Un codice per gruppo, quando la persona sceglie il gruppo invece del lavoro
    static let codiceRappresentativo: [String: String] = [
        "alimentari": "10.71.20", "commercio": "47.91.10", "ambulante-alimentari": "47.81.01", "ambulante-altri": "47.82.01",
        "costruzioni": "43.39.01", "intermediari": "46.19.01", "alloggio": "56.10.11", "professionali": "74.90.99", "altre": "82.99.99",
    ]
}

/// Etichette che vanno a capo da sole, toccabili
struct FlowChips: View {
    let voci: [String]
    let tocca: (String) -> Void
    var body: some View {
        ViewThatFits(in: .horizontal) {
            riga(voci)
            VStack(alignment: .leading, spacing: 8) {
                riga(Array(voci.prefix((voci.count + 1) / 2)))
                riga(Array(voci.dropFirst((voci.count + 1) / 2)))
            }
        }
    }
    private func riga(_ v: [String]) -> some View {
        HStack(spacing: 8) {
            ForEach(v, id: \.self) { voce in
                Button(voce) { tocca(voce) }
                    .font(.app(14, .semibold))
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .foregroundStyle(Theme.prugna)
                    .background(Theme.prugnaSoft, in: Capsule())
                    .buttonStyle(Molla())
            }
        }
    }
}
