import SwiftUI
import UIKit

// «Tu»: chi sei, la partita IVA, il lavoro, la pensione, le preferenze. Tutto resta su questo iPhone.

struct TuView: View {
    @EnvironmentObject private var store: Store
    @State private var modifica = false
    @State private var documenti = false
    @State private var esporta = false
    @State private var attivita = false
    @State private var backup = false
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
                                interruttore("plus.forwardslash.minus", "4% INPS in fattura", acceso: Binding(
                                    get: { store.profilo?.rivalsa4 ?? false },
                                    set: { store.profilo?.rivalsa4 = $0 }))
                            }
                            Divider().padding(.leading, 66)
                            interruttore("bell", "Promemoria", acceso: Binding(
                                get: { store.profilo?.promemoria ?? true },
                                set: { store.profilo?.promemoria = $0 }))
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
                            interruttore("faceid", "Blocca con Face ID", acceso: Binding(
                                get: { store.profilo?.faceID ?? false },
                                set: { store.profilo?.faceID = $0 }))
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
            .sheet(isPresented: $documenti) { DocumentiView() }
            .sheet(isPresented: $esporta) { EsportaView() }
            .sheet(isPresented: $attivita) { AltreAttivitaView() }
            .sheet(isPresented: $backup) { BackupView() }
            .sheet(isPresented: $modifica) {
                DomandeProfilo(iniziale: store.profilo) { nuovo in
                    store.profilo = nuovo
                    modifica = false
                }
            }
            .confirmationDialog("Cancellare profilo e incassi da questo iPhone?", isPresented: $chiediCancella, titleVisibility: .visible) {
                Button("Cancella tutto", role: .destructive) { store.cancellaTutto() }
            }
            .onAppear { piva = store.profilo?.partitaIVA ?? "" }
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
                    Text(p.nome.isEmpty ? "Ciao" : p.nome).font(.app(20, .bold))
                    Text("\(lavoro(p)) · dal \(String(p.annoApertura))").font(.app(15)).foregroundStyle(Theme.suNotte.opacity(0.8))
                }
            }
            VStack(alignment: .leading, spacing: 10) {
                Text("Partita IVA").font(.app(13)).foregroundStyle(Theme.suNotte.opacity(0.8))
                HStack(spacing: 10) {
                    TextField("", text: $piva, prompt: Text("11 cifre").foregroundStyle(Theme.suNotte.opacity(0.4)))
                        .keyboardType(.numberPad)
                        .font(.system(size: 20, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white)
                        .focused($focusPiva)
                        .accessibilityIdentifier("tu.piva")
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
                        Text(ok ? "Il codice P.IVA è corretto" : "Il codice P.IVA è sbagliato: controlla le cifre")
                            .font(.app(15, .bold))
                    }
                    .foregroundStyle(ok ? Color(hex: 0x7CD3B0) : Color(hex: 0xF09A85))
                    .transition(.move(edge: .top).combined(with: .opacity))
                    if ok {
                        Text("Controllo la cifra finale: non vuol dire che la partita IVA sia attiva.")
                            .font(.app(12)).foregroundStyle(Theme.suNotte.opacity(0.6))
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
                    Text(riga).font(.app(15)).fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
            }
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
            Text(titolo).font(.app(16, .semibold))
            Spacer()
            Text(valore).font(.app(15)).foregroundStyle(Theme.muted).lineLimit(1)
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
            Toggle(titolo, isOn: acceso).font(.app(16, .semibold)).tint(Theme.prugna)
        }
        .padding(.horizontal, 16).padding(.vertical, 8)
    }

    private func lavoro(_ p: Profilo) -> String {
        Ateco.nomeLavoro(p.ateco)
    }

    private func nomePensione(_ p: Profilo) -> String {
        switch p.gestione {
        case .separata: "INPS"
        case .artigiani: "INPS artigiani"
        case .commercianti: "INPS commercianti"
        case .cassa: "La tua cassa"
        }
    }

    private func tasse(_ p: Profilo) -> String {
        if let ultimo = Calcolo.ultimoAnnoStartup(p), ultimo >= store.anno { return "5% fino al \(ultimo)" }
        return "15%"
    }
}

enum PartitaIVA {
    /// Controlla la cifra finale di una partita IVA italiana (11 cifre)
    static func valida(_ s: String) -> Bool {
        let c = s.compactMap(\.wholeNumberValue)
        guard c.count == 11 else { return false }
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
                                    Text(i == 0 ? "Principale · ATECO \(codice)" : "ATECO \(codice)").font(.app(13)).foregroundStyle(Theme.muted)
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

    private func togli(_ codice: String) {
        withAnimation(.spring) { store.profilo?.altreAttivita?.removeAll { $0 == codice } }
    }
}
