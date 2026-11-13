import SwiftUI
import UserNotifications
import LocalAuthentication
import UIKit

// «Tu»: chi sei, la partita IVA, il lavoro, la pensione, le preferenze. Tutto resta su questo iPhone.

struct TuView: View {
    /// Face ID o Touch ID, secondo l'iPhone (l'SE ha Touch ID)
    static let biometria: LABiometryType = {
        let c = LAContext()
        _ = c.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
        return c.biometryType
    }()
    @EnvironmentObject private var store: Store
    @State private var senzaCodice = false
    @State private var notificheNegate = false
    @Environment(\.scenePhase) private var fase
    @State private var modifica = false
    @State private var documenti = false
    @State private var esporta = false
    @State private var attivita = false
    @State private var backup = false
    @State private var completo = false
    @EnvironmentObject private var acquisto: Acquisto
    @State private var piva = ""
    @State private var chiediCancella = false
    @State private var esitoPiva: Bool?
    @State private var scossa: CGFloat = 0
    @FocusState private var focusPiva: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                if let p = store.profilo {
                    VStack(alignment: .leading, spacing: 16) {
                        Titolo(testo: "Tu")
                        intestazione(p)
                        Button { completo = true } label: {
                            riga("seal", Theme.brass, "NettoLR completo",
                                 valore: acquisto.completo ? (acquisto.piano ?? "Attivo") : String(localized: "Prova: \(acquisto.giorniRimasti) giorni"), freccia: true)
                                .foregroundStyle(Theme.ink)
                                .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.raggio, style: .continuous))
                        }
                        .buttonStyle(Molla())
                        .accessibilityIdentifier("tu.completo")
                        Button { documenti = true } label: { documentiCard }
                            .buttonStyle(Molla())
                            .accessibilityIdentifier("tu.documenti")
                        VStack(spacing: 0) {
                            Button { modifica = true } label: {
                                riga("house", Theme.prugna, "Il tuo lavoro", valore: lavoro(p), freccia: true)
                            }
                            .buttonStyle(.plain)
                            Divider().padding(.leading, 66)
                            Button { attivita = true } label: {
                                riga("square.stack.3d.up", Theme.lilla, "Altre attività", valore: p.attivita.count > 1 ? "\(p.attivita.count - 1)" : "Nessuna", freccia: true)
                            }
                            .buttonStyle(.plain)
                            Divider().padding(.leading, 66)
                            riga("person.2", Theme.pensione, "Pensione", valore: nomePensione(p))
                            Divider().padding(.leading, 66)
                            riga("percent", Theme.tasseTesto, "Tasse", valore: tasse(p))
                            if p.gestione == .separata {
                                Divider().padding(.leading, 66)
                                interruttore("plus.forwardslash.minus", "4% di pensione in fattura", acceso: Binding(
                                    get: { store.profilo?.rivalsa4 ?? false },
                                    set: { store.profilo?.rivalsa4 = $0 }))
                            }
                            Divider().padding(.leading, 66)
                            interruttore("bell", "Promemoria", acceso: Binding(
                                get: { store.profilo?.promemoria ?? true },
                                set: { store.profilo?.promemoria = $0 }))
                            if notificheNegate && (store.profilo?.promemoria ?? true) {
                                // Acceso qui ma negato in Impostazioni: i promemoria non arriverebbero
                                Button { Fotocamera.apriImpostazioni() } label: {
                                    Text("Le notifiche sono spente nelle Impostazioni: i promemoria non arrivano. Tocca per accenderle.")
                                        .font(.app(13, .semibold)).foregroundStyle(Theme.avviso).multilineTextAlignment(.leading)
                                        .padding(.horizontal, 16).padding(.bottom, 10)
                                }
                                .buttonStyle(.plain)
                            }
                            Divider().padding(.leading, 66)
                            Button { esporta = true } label: {
                                riga("square.and.arrow.up", Theme.menta, "Manda al commercialista", valore: "PDF ed Excel", freccia: true)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("tu.esporta")
                            Divider().padding(.leading, 66)
                            Button { backup = true } label: {
                                riga("icloud", Theme.pensione, "Copia di sicurezza", valore: "iCloud Drive", freccia: true)
                            }
                            .buttonStyle(.plain)
                            Divider().padding(.leading, 66)
                            interruttore(Self.biometria == .touchID ? "touchid" : "faceid",
                                         Self.biometria == .touchID ? "Blocca con Touch ID" : "Blocca con Face ID", acceso: Binding(
                                get: { store.profilo?.faceID ?? false },
                                set: { nuovo in
                                    // Senza codice dell'iPhone il blocco non può funzionare: meglio dirlo che lasciarlo acceso finto
                                    if nuovo && !LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) {
                                        senzaCodice = true
                                    } else {
                                        store.profilo?.faceID = nuovo
                                    }
                                }))
                        }
                        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.raggio, style: .continuous))

                        privacy


                        Button("Cancella tutti i dati", role: .destructive) { chiediCancella = true }
                            .font(.app(15))
                            .frame(maxWidth: .infinity)
                        Text("NettoLR \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "") · regole \(String(Regole.attuali.anno)) · È un calcolo, non una consulenza fiscale.")
                            .font(.app(12)).foregroundStyle(Theme.muted)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 20).padding(.vertical, 12)
                }
            }
            .background(Theme.ground)
            .toolbar(.hidden, for: .navigationBar)
            // Senza barra di navigazione il contenuto scorreva sotto l'ora e la batteria (tester T17, T19)
            .safeAreaInset(edge: .top, spacing: 0) { Color.clear.frame(height: 0).background(Theme.ground) }
            .alert("Prima imposta il codice dell'iPhone", isPresented: $senzaCodice) {
                Button("Ho capito", role: .cancel) {}
            } message: {
                Text("Il blocco usa Face ID, Touch ID o il codice: senza un codice impostato sull'iPhone non può proteggere i tuoi numeri.")
            }
            .sheet(isPresented: $documenti) { DocumentiView() }
            .sheet(isPresented: $esporta) { EsportaView() }
            .sheet(isPresented: $attivita) { AltreAttivitaView() }
            .sheet(isPresented: $backup) { BackupView() }
            .fullScreenCover(isPresented: $completo) { CompletoView().environmentObject(acquisto) }
            .sheet(isPresented: $modifica) {
                DomandeProfilo(iniziale: store.profilo) { nuovo in
                    store.profilo = nuovo
                    modifica = false
                }
            }
            .confirmationDialog("Cancellare profilo e incassi da questo iPhone?", isPresented: $chiediCancella, titleVisibility: .visible) {
                Button("Cancella tutto", role: .destructive) { store.cancellaTutto() }
                Button("Annulla", role: .cancel) {}
            } message: {
                Text("Non si può annullare. Le copie in iCloud Drive e i file già mandati al commercialista restano: quelli vanno cancellati a mano.")
            }
            .onAppear { piva = store.profilo?.partitaIVA ?? "" }
            .task(id: fase) {
                notificheNegate = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus == .denied
            }
        }
    }

    private func intestazione(_ p: Profilo) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                Text(p.nome.isEmpty ? "?" : String(p.nome.prefix(1)).uppercased())
                    .font(.app(24, .heavy)).foregroundStyle(Theme.notte)
                    .frame(width: 56, height: 56)
                    .background(Theme.rosaChiaro, in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(p.nome.isEmpty ? "Ciao".tradotto : p.nome).font(.app(20, .bold))
                    Text("\(lavoro(p)) · dal \(String(p.annoApertura))").font(.app(15)).foregroundStyle(Theme.suNotte.opacity(0.95))
                }
            }
            VStack(alignment: .leading, spacing: 10) {
                Text("Partita IVA").font(.app(13)).foregroundStyle(Theme.suNotte.opacity(0.95))
                HStack(spacing: 10) {
                    TextField("", text: $piva, prompt: Text("11 cifre").foregroundStyle(Theme.suNotte.opacity(0.4)))
                        .keyboardType(.numberPad)
                        .font(.system(size: 20, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white)
                        .focused($focusPiva)
                        .accessibilityIdentifier("tu.piva")
                        .accessibilityLabel("Partita IVA")
                        .onChange(of: piva) { _, nuova in
                            let cifre = String(nuova.filter(\.isNumber).prefix(11))
                            if cifre != nuova { piva = cifre }
                            if esitoPiva != nil { withAnimation { esitoPiva = nil } }
                        }
                    Button("Conferma") { confermaPiva() }
                        .font(.app(15, .bold))
                        .padding(.horizontal, 14).frame(height: 40)
                        .foregroundStyle(Theme.notte)
                        .background(Theme.rosaChiaro, in: Capsule())
                        .buttonStyle(Molla())
                        .disabled(piva.isEmpty)
                        .opacity(piva.isEmpty ? 0.5 : 1)
                        .accessibilityIdentifier("tu.conferma")
                }
                .modifier(Scuoti(volte: scossa))
                if let ok = esitoPiva {
                    HStack(spacing: 8) {
                        Image(systemName: ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .font(.app(20))
                            .symbolEffect(.bounce, value: ok)
                        Text((ok ? "Il codice P.IVA è corretto" : "Il codice P.IVA è sbagliato: controlla le cifre").tradotto)
                            .font(.app(15, .bold))
                    }
                    .foregroundStyle(ok ? Color(hex: 0x7CD3B0) : Color(hex: 0xF09A85))
                    .transition(.move(edge: .top).combined(with: .opacity))
                    if ok {
                        Text("Controllo la cifra finale: non vuol dire che la partita IVA sia attiva.")
                            .font(.app(12)).foregroundStyle(Theme.suNotte.opacity(0.95))
                    }
                }
            }
            .padding(14)
            .background(Theme.notteRialzo, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .riquadroNotte()
    }

    private func confermaPiva() {
        focusPiva = false
        let ok = PartitaIVA.valida(piva)
        withAnimation(.spring(duration: 0.4, bounce: 0.4)) { esitoPiva = ok }
        AccessibilityNotification.Announcement((ok ? "Il codice P.IVA è corretto" : "Il codice P.IVA è sbagliato: controlla le cifre").tradotto).post()
        if ok {
            store.profilo?.partitaIVA = piva
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } else {
            withAnimation(.linear(duration: 0.4)) { scossa += 1 }
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    /// La privacy in tre righe
    private var privacy: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("La tua privacy, in tre righe", systemImage: "lock.shield.fill")
                .font(.app(16, .bold)).foregroundStyle(Theme.menta)
            ForEach(Array([
                "I tuoi dati restano su questo iPhone: niente account, niente server.",
                "Nessuna pubblicità, nessuna statistica, nessun tracciamento.",
                "La foto del certificato si legge sul telefono e non si salva; le ricevute che aggiungi restano solo qui.",
            ].enumerated()), id: \.offset) { i, riga in
                HStack(alignment: .top, spacing: 10) {
                    Text("\(i + 1)").font(.app(13, .heavy)).foregroundStyle(Theme.menta)
                        .frame(width: 22, height: 22).background(Theme.card, in: Circle())
                    Text(riga.tradotto).font(.app(15)).fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
            }
            HStack(spacing: 16) {
                Link("Privacy completa", destination: Sito.privacy)
                Link("Condizioni d'uso", destination: Sito.condizioni)
            }
            .font(.app(14, .semibold))
            .accessibilityIdentifier("tu.privacy.link")
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.mentaSoft, in: RoundedRectangle(cornerRadius: Theme.raggio, style: .continuous))
    }

    private var documentiCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "folder.fill").font(.system(size: 24)).foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .background(Theme.lilla, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text("Documenti").font(.app(17, .bold)).foregroundStyle(Theme.ink)
                Text("Le fonti ufficiali dei calcoli, il certificato, le ricevute").font(.app(14)).foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.leading)
            }
            Spacer()
            if !store.novitaNuove.isEmpty {
                Text("\(store.novitaNuove.count)").font(.app(13, .heavy)).foregroundStyle(.white)
                    .frame(minWidth: 24, minHeight: 24)
                    .background(Theme.tasse, in: Capsule())
                    .accessibilityLabel(String(localized: "Regole cambiate: \(store.novitaNuove.count) novità"))
            }
            Image(systemName: "chevron.right").foregroundStyle(Theme.lilla)
        }
        .padding(16)
        .background(Theme.lillaSoft, in: RoundedRectangle(cornerRadius: Theme.raggio, style: .continuous))

    }

    private func riga(_ icona: String, _ colore: Color, _ titolo: String, valore: String, freccia: Bool = false) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icona).font(.system(size: 17, weight: .semibold)).foregroundStyle(colore)
                .frame(width: 36, height: 36)
                .background(colore.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            Text(titolo.tradotto).font(.app(16, .semibold))
            Spacer()
            Text(valore.tradotto).font(.app(15)).foregroundStyle(Theme.muted).lineLimit(1).minimumScaleFactor(0.7)

            if freccia { Image(systemName: "chevron.right").font(.app(13)).foregroundStyle(Theme.muted) }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    private func interruttore(_ icona: String, _ titolo: String, acceso: Binding<Bool>) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icona).font(.system(size: 17, weight: .semibold)).foregroundStyle(Theme.prugna)
                .frame(width: 36, height: 36)
                .background(Theme.prugnaSoft, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            Toggle(titolo.tradotto, isOn: acceso).font(.app(16, .semibold)).tint(Theme.prugna)
        }
        .padding(.horizontal, 16).padding(.vertical, 8)
    }

    private func lavoro(_ p: Profilo) -> String {
        Ateco.nomeLavoro(p.ateco)
    }

    private func nomePensione(_ p: Profilo) -> String {
        switch p.gestione {
        case .separata: "Liberi professionisti"
        case .artigiani: "Artigiani"
        case .commercianti: "Commercianti"
        case .cassa: "La tua cassa"
        }
    }

    private func tasse(_ p: Profilo) -> String {
        let f = store.regole.forfettario
        if let ultimo = Calcolo.ultimoAnnoStartup(p), ultimo >= store.anno {
            return String(localized: "\(Formato.pct(f.aliquotaStartup.valore)) fino al \(String(ultimo))")
        }
        return Formato.pct(f.aliquotaOrdinaria.valore)
    }
}

enum PartitaIVA {
    /// Controlla la cifra finale di una partita IVA italiana (11 cifre)
    static func valida(_ s: String) -> Bool {
        let c = s.compactMap(\.wholeNumberValue)
        guard c.count == 11 else { return false }
        // Le prime 7 cifre sono il numero del contribuente: tutte zero non esiste (tester T04)
        guard c.prefix(7).contains(where: { $0 != 0 }) else { return false }
        var somma = 0
        for i in 0..<10 {
            if i % 2 == 0 {
                somma += c[i]
            } else {
                let d = c[i] * 2
                somma += d > 9 ? d - 9 : d
            }
        }
        return (10 - somma % 10) % 10 == c[10]
    }
}

/// Le altre attività oltre alla principale: si cercano tra tutti i codici ATECO
struct AltreAttivitaView: View {
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var chiudi
    @State private var ricerca = ""
    @State private var daScegliere: TrovatoAteco?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Se fai più lavori, ognuno ha la sua percentuale. Quando aggiungi un incasso scegli a quale appartiene.")
                        .font(.app(16)).foregroundStyle(Theme.muted)
                    if let p = store.profilo {
                        ForEach(Array(p.attivita.enumerated()), id: \.element) { i, codice in
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(Ateco.nomeLavoro(codice)).font(.app(16, .semibold))
                                    Text(i == 0 ? String(localized: "Principale · ATECO \(codice)") : "ATECO \(codice)").font(.app(13)).foregroundStyle(Theme.muted)

                                }
                                Spacer()
                                Text("\(Int((Ateco.gruppo(ateco2007: codice)?.coefficiente ?? 0) * 100))%").font(.app(15, .heavy)).foregroundStyle(Theme.prugna)
                                if i > 0 {
                                    Button { togli(codice) } label: { Image(systemName: "minus.circle.fill").font(.app(20)).foregroundStyle(Theme.avviso) }
                                        .accessibilityLabel("Togli \(Ateco.nomeLavoro(codice))")
                                }
                            }
                            .scheda(padding: 14)
                        }
                    }
                    Text("Aggiungi un'attività").font(.app(17, .bold)).padding(.top, 6)
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass").foregroundStyle(Theme.muted)
                        TextField("Lavoro o codice ATECO", text: $ricerca).font(.app(17))
                    }
                    .padding(.horizontal, 14).frame(height: 50)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    if let amb = daScegliere {
                        Text("Il codice \(amb.codice) del 2025 corrisponde a più attività di prima. Quale fai?").font(.app(15, .bold))
                        ForEach(amb.codici2007, id: \.self) { c in
                            Button { aggiungi(c) } label: {
                                HStack {
                                    Text(Ateco.titolo2007(c) ?? c).font(.app(15)).multilineTextAlignment(.leading)
                                    Spacer()
                                    Text("\(Int((Ateco.gruppo(ateco2007: c)?.coefficiente ?? 0) * 100))%").font(.app(14, .heavy)).foregroundStyle(Theme.prugna)
                                }
                                .scheda(padding: 12)
                            }
                            .buttonStyle(Molla())
                        }
                    } else {
                        ForEach(Ateco.cerca(ricerca, max: 8)) { t in
                            Button {
                                if t.ambiguo { daScegliere = t } else if let c = t.codici2007.first { aggiungi(c) }
                            } label: {
                                HStack(alignment: .top) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(t.nomeComune ?? t.titolo).font(.app(15, .semibold)).multilineTextAlignment(.leading)
                                        Text("\(t.versione.rawValue) \(t.codice)").font(.app(12)).foregroundStyle(Theme.muted)
                                    }
                                    Spacer()
                                    Image(systemName: "plus.circle.fill").font(.app(20)).foregroundStyle(Theme.prugna)
                                }
                                .scheda(padding: 12)
                            }
                            .buttonStyle(Molla())
                        }
                    }
                }
                .padding(20)
            }
            .background(Theme.ground)
            .navigationTitle("Le tue attività")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fatto") { chiudi() } } }
        }
    }

    private func aggiungi(_ codice: String) {
        guard var p = store.profilo, !p.attivita.contains(codice) else { daScegliere = nil; ricerca = ""; return }
        p.altreAttivita = (p.altreAttivita ?? []) + [codice]
        withAnimation(.spring) { store.profilo = p }
        daScegliere = nil
        ricerca = ""
    }

    /// Togliendo un'attività i suoi incassi passano alla principale: non devono restare con la vecchia percentuale
    private func togli(_ codice: String) {
        withAnimation(.spring) {
            store.profilo?.altreAttivita?.removeAll { $0 == codice }
            if store.fatture.contains(where: { $0.ateco == codice }) {
                store.fatture = store.fatture.map { f in
                    var f = f
                    if f.ateco == codice { f.ateco = nil }
                    return f
                }
            }
        }
    }
}
