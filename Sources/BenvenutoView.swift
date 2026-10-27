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
            .background(Theme.notte.ignoresSafeArea())
            .onAppear {
                if menoMovimento { timbro = true } else { withAnimation(.spring(duration: 0.6, bounce: 0.4).delay(0.2)) { timbro = true } }
            }
            .sensoryFeedback(.impact(weight: .medium), trigger: timbro)
        }
    }

    private func promessa(_ testo: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark").font(.app(16, .bold)).foregroundStyle(Theme.rosaChiaro)
            Text(testo).font(.app(17)).foregroundStyle(Theme.suNotte)
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
                Button(passo < 3 ? "Avanti" : "Fatto") { avanti() }
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

            let risultati = ricerca.isEmpty ? Array(Ateco.attivita.filter { Self.popolari.contains($0.ateco2007) }) : Ateco.cerca(ricerca)
            VStack(spacing: 8) {
                ForEach(risultati) { a in
                    Button { scegli(a) } label: {
                        HStack {
                            Text(Self.nomeSemplice(a)).font(.app(17, .semibold)).multilineTextAlignment(.leading)
                            Spacer()
                            if ateco == a.ateco2007 { Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.prugna) }
                        }
                        .padding(16)
                        .background(ateco == a.ateco2007 ? Theme.prugnaSoft : Theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            Button(mostraGruppi ? "Nascondi" : "Non trovo il mio lavoro") { withAnimation { mostraGruppi.toggle() } }
                .font(.app(16, .semibold))
            if mostraGruppi {
                VStack(spacing: 8) {
                    ForEach(Ateco.gruppi) { g in
                        Button {
                            ateco = Self.codiceRappresentativo[g.id] ?? "74.90.99"
                            nomeLavoro = g.nome
                        } label: {
                            Text(g.nome).font(.app(15)).multilineTextAlignment(.leading)
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
        Text(testo)
            .font(.system(size: piccola ? 22 : 30, weight: .heavy, design: .rounded))
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, piccola ? 8 : 0)
    }

    private func sceltaSiNo(_ valore: Binding<Bool>) -> some View {
        HStack(spacing: 10) {
            ForEach([true, false], id: \.self) { v in
                Button(v ? "Sì" : "No") { valore.wrappedValue = v }
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
                    Text(titolo).font(.app(17, .semibold))
                    Text(sotto).font(.app(14)).foregroundStyle(Theme.muted)
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

    private func scegli(_ a: Attivita) {
        ateco = a.ateco2007
        nomeLavoro = Self.nomeSemplice(a)
        gestione = a.gestioneTipica
    }

    private func avanti() {
        if passo < 3 {
            withAnimation { passo += 1 }
            return
        }
        salva(Profilo(
            nome: nome.trimmingCharacters(in: .whitespaces),
            partitaIVA: iniziale?.partitaIVA ?? "",
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
        nomeLavoro = Ateco.attivita.first { $0.ateco2007 == p.ateco }.map(Self.nomeSemplice) ?? ""
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

    /// Il primo sinonimo, con la maiuscola: «Web designer» invece della descrizione ISTAT
    static func nomeSemplice(_ a: Attivita) -> String {
        guard let s = a.sinonimi.first else { return a.descrizione }
        return s.prefix(1).uppercased() + s.dropFirst()
    }

    static let popolari: Set<String> = ["74.10.21", "62.01.00", "73.11.02", "74.20.19", "85.59.90", "96.02.01", "47.91.10", "86.90.29"]

    /// Un codice per gruppo, quando la persona sceglie il gruppo invece del lavoro
    static let codiceRappresentativo: [String: String] = [
        "alimentari": "10.71.20", "commercio": "47.91.10", "ambulante-alimentari": "47.81.01", "ambulante-altri": "47.82.01",
        "costruzioni": "43.39.01", "intermediari": "46.19.01", "alloggio": "56.10.11", "professionali": "74.90.99", "altre": "82.99.99",
    ]
}
