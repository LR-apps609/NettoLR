import SwiftUI

// Le cinque schede. Al primo avvio, il benvenuto con le quattro domande.

struct RootView: View {
    @EnvironmentObject private var store: Store
    @EnvironmentObject private var acquisto: Acquisto
    @Environment(\.scenePhase) private var fase
    @State private var scheda = Scheda.netto

    enum Scheda: Hashable { case netto, incassi, prova, pagamenti, tu }

    var body: some View {
        TabView(selection: $scheda) {
            NettoView(vaiA: { scheda = $0 })
                .tabItem { Label("Netto", systemImage: "eurosign.circle") }
                .tag(Scheda.netto)
            IncassiView()
                .tabItem { Label("Incassi", systemImage: "list.bullet.rectangle.portrait") }
                .tag(Scheda.incassi)
            ProvaView()
                .tabItem { Label("Prova", systemImage: "slider.horizontal.3") }
                .tag(Scheda.prova)
            PagamentiView()
                .tabItem { Label("Pagamenti", systemImage: "calendar") }
                .tag(Scheda.pagamenti)
            TuView()
                .tabItem { Label("Tu", systemImage: "person.crop.circle") }
                .tag(Scheda.tu)
        }
        .fullScreenCover(isPresented: Binding(get: { store.profilo == nil }, set: { _ in })) {
            BenvenutoView()
                .environmentObject(store)
                .modifier(AvvisoSalvataggio(store: store, attivo: true))
        }
        .modifier(AvvisoSalvataggio(store: store, attivo: store.profilo != nil))
        // Il timbro e la vibrazione quando segni un incasso
        .overlay {
            if store.ultimoIncasso > 0 && timbroVisibile {

                ZStack {
                    Coriandoli().ignoresSafeArea()
                    TimbroAnimato()
                }
                    .id(store.ultimoIncasso)
                    .transition(.opacity)
                    .task(id: store.ultimoIncasso) {
                        try? await Task.sleep(for: .seconds(1.5))
                        withAnimation(.easeOut(duration: 0.3)) { timbroVisibile = false }
                    }
                    .opacity(timbroVisibile ? 1 : 0)
            }
        }
        .onChange(of: store.ultimoIncasso) { _, _ in timbroVisibile = true }
        .sensoryFeedback(.success, trigger: store.ultimoIncasso)
        // A prova finita, senza acquisto: la schermata per sbloccare (i dati restano)
        .overlay {
            if acquisto.bloccato && store.profilo != nil {
                CompletoView(bloccato: true).transition(.opacity)
            }
        }
        .task { await acquisto.aggiorna() }
        // L'abbonamento si ricontrolla ogni volta che si torna nell'app (scadenze, rinnovi)
        .onChange(of: fase) { _, nuova in
            if nuova == .active { Task { await acquisto.aggiorna() } }
            // Le modifiche appena fatte si scrivono prima che iOS sospenda l'app
            if nuova == .background { store.salvaSubito() }
        }
        .blocco(store.profilo?.faceID ?? false)
        // «Apri con NettoLR» da Mail, File, WhatsApp: le fatture finiscono in Incassi
        .onOpenURL { url in
            guard url.isFileURL else { return }
            store.importa(url)
            scheda = .incassi
        }
        // Le notifiche dei pagamenti si riprogrammano quando cambia qualcosa
        .task(id: store.chiavePromemoria) {
            await Promemoria.aggiorna(store.pagamentiPromemoria, attivi: store.profilo?.promemoria ?? false)
        }
    }

    @State private var timbroVisibile = true
}

/// Se il salvataggio non si è letto del tutto lo diciamo, una volta, senza nascondere niente
private struct AvvisoSalvataggio: ViewModifier {
    @ObservedObject var store: Store
    let attivo: Bool

    func body(content: Content) -> some View {
        content.alert("I tuoi dati", isPresented: Binding(get: { attivo && store.avvisoSalvataggio != nil },
                                                         set: { if !$0 { store.avvisoSalvataggio = nil } })) {
            Button("Ho capito", role: .cancel) { store.avvisoSalvataggio = nil }
        } message: {
            Text(store.avvisoSalvataggio ?? "")
        }
    }
}
