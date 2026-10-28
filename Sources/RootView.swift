import SwiftUI

// Le cinque schede. Al primo avvio, il benvenuto con le quattro domande.

struct RootView: View {
    @EnvironmentObject private var store: Store
    @EnvironmentObject private var acquisto: Acquisto
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
        }
        // Il timbro e la vibrazione quando segni un incasso
        .overlay {
            if store.ultimoIncasso > 0 {
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
        .blocco(store.profilo?.faceID ?? false)
        // «Apri con NettoLR» da Mail, File, WhatsApp: le fatture finiscono in Incassi
        .onOpenURL { url in
            guard url.isFileURL else { return }
            store.importa(url)
            scheda = .incassi
        }
        // Le notifiche dei pagamenti si riprogrammano quando cambia qualcosa
        .task(id: store.chiavePromemoria) {
            await Promemoria.aggiorna(store.pagamentiDaFare, attivi: store.profilo?.promemoria ?? false)
        }
    }

    @State private var timbroVisibile = true
}
