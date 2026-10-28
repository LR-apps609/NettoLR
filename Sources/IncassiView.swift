import SwiftUI
import UniformTypeIdentifiers

// Gli incassi: il totale, «Aggiungi un incasso», le fatture in attesa con «Ti hanno pagato?».

struct IncassiView: View {
    @EnvironmentObject private var store: Store
    @State private var nuovo = false
    @State private var importa = false
    @State private var messaggio: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Titolo(testo: "Incassi")
                    VStack(alignment: .leading, spacing: 2) {
                        NumeroCheConta(valore: store.riepilogo.ricavi, dimensione: 44)
                        Text("ricevuti nel \(String(store.anno))").font(.app(16)).foregroundStyle(Theme.muted)
                    }

                    Button { nuovo = true } label: {
                        Label("Aggiungi un incasso", systemImage: "plus.circle.fill")
                            .symbolEffect(.bounce, value: store.fatture.count)
                    }
                        .buttonStyle(PulsantePieno())
                        .accessibilityIdentifier("incassi.aggiungi")

                    if let messaggio { Avviso(testo: messaggio) }
                    if let esito = store.esitoImport {
                        HStack(alignment: .top) {
                            Label(esito.tradotto, systemImage: "tray.and.arrow.down.fill").font(.app(15)).foregroundStyle(Theme.menta)
                            Spacer()
                            Button { store.esitoImport = nil } label: { Image(systemName: "xmark").foregroundStyle(Theme.muted) }
                                .accessibilityLabel("Chiudi")
                        }
                        .padding(14)
                        .background(Theme.mentaSoft, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }

                    ForEach(store.fatture.filter { !$0.incassata }) { f in
                        inAttesa(f).transition(.asymmetric(insertion: .scale.combined(with: .opacity), removal: .move(edge: .trailing).combined(with: .opacity)))
                    }

                    let pagate = store.fatture.filter(\.incassata)
                    if pagate.isEmpty && store.fatture.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "tray").font(.system(size: 40)).foregroundStyle(Theme.prugna)
                            Text("Ancora nessun incasso").font(.app(18, .bold))
                            Text("Ogni volta che ti pagano, aggiungilo qui: ti diciamo subito quanto è tuo.")
                                .font(.app(15)).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 30)
                    }
                    VStack(spacing: 4) {
                        ForEach(Array(pagate.enumerated()), id: \.element.id) { i, f in pagata(f).entrata(min(i, 8)) }
                    }

                    Button("Importa dalle fatture elettroniche") { importa = true }
                        .font(.app(15, .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.top, 4)
                }
                .padding(.horizontal, 20).padding(.vertical, 12)
            }
            .background(Theme.ground)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $nuovo) { NuovoIncassoView() }
            .fileImporter(isPresented: $importa, allowedContentTypes: [.xml], allowsMultipleSelection: true) { esito in
                leggi(esito)
            }
        }
    }

    private func inAttesa(_ f: Fattura) -> some View {
        HStack(spacing: 14) {
            iniziale(f.cliente, piena: true)
            VStack(alignment: .leading, spacing: 2) {
                Text(f.cliente).font(.app(16, .bold)).lineLimit(1)
                Text("\(Formato.euroTondo(f.importo)) · ti hanno pagato?").font(.app(14)).foregroundStyle(Theme.muted)
                let giorni = Calcolo.giorniInAttesa(f)
                if giorni > 30 {
                    Label("Aspetti da \(giorni) giorni", systemImage: "hourglass")
                        .font(.app(12, .bold)).foregroundStyle(Theme.tasseTesto)
                }
            }
            Spacer()
            Button("Sì") { withAnimation(.spring) { store.segnaIncassata(f.id) } }
                .font(.app(15, .bold))
                .padding(.horizontal, 18).frame(height: 40)
                .foregroundStyle(Theme.suPrugna)
                .background(Theme.prugna, in: Capsule())
                .accessibilityLabel("Sì, \(f.cliente) mi ha pagato")
        }
        .padding(16)
        .background(Theme.prugnaSoft, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .contextMenu { Button("Elimina", systemImage: "trash", role: .destructive) { store.elimina(f.id) } }
    }

    private func pagata(_ f: Fattura) -> some View {
        HStack(spacing: 14) {
            iniziale(f.cliente, piena: false)
            VStack(alignment: .leading, spacing: 2) {
                Text(f.cliente).font(.app(16, .semibold)).lineLimit(1)
                Text((f.dataIncasso ?? f.data).formatted(.dateTime.day().month(.wide).locale(Formato.lingua)))
                    .font(.app(14)).foregroundStyle(Theme.muted)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(Formato.euroTondo(f.importo)).font(.app(17, .bold)).monospacedDigit()
                Label("pagata", systemImage: "checkmark").font(.app(11, .bold)).foregroundStyle(Theme.menta)
            }
        }
        .padding(.vertical, 10).padding(.horizontal, 4)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(f.cliente), \(Formato.euroTondo(f.importo)), pagata il \((f.dataIncasso ?? f.data).formatted(.dateTime.day().month(.wide).locale(Formato.lingua)))")
        .contextMenu {
            Button("Non ancora pagata", systemImage: "arrow.uturn.backward") { store.annullaIncasso(f.id) }
            Button("Elimina", systemImage: "trash", role: .destructive) { store.elimina(f.id) }
        }
    }

    private func iniziale(_ nome: String, piena: Bool) -> some View {
        let (colore, fondo) = Theme.colori(per: nome)
        return Text(String(nome.prefix(1)).uppercased())
            .font(.app(18, .heavy))
            .foregroundStyle(piena ? Color.white : colore)
            .frame(width: 44, height: 44)
            .background(piena ? colore : fondo, in: Circle())
    }

    private func leggi(_ esito: Result<[URL], Error>) {
        guard case .success(let urls) = esito else { return }
        var n = 0
        var errori: [String] = []
        for url in urls {
            let accesso = url.startAccessingSecurityScopedResource()
            defer { if accesso { url.stopAccessingSecurityScopedResource() } }
            guard let dati = try? Data(contentsOf: url) else { errori.append(String(localized: "\(url.lastPathComponent): non riesco ad aprirlo.")); continue }
            let letto = LettoreFatturaPA.leggi(dati)
            n += store.aggiungiNuove(letto.fatture).count
            errori += letto.errori.map { "\(url.lastPathComponent): \($0)" }
        }
        messaggio = ([String(localized: "Aggiunte \(n) fatture. Tocca «Sì» quando te le pagano.")] + errori).joined(separator: "\n")
    }
}

/// Aggiungere un incasso: importo, chi, quando. Mostra subito quanto è tuo e quanto mettere da parte.
struct NuovoIncassoView: View {
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var chiudi
    @State private var importo = ""
    @State private var cliente = ""
    @State private var giorno = Date()
    @State private var pagata = true
    @State private var attivita = ""
    @State private var numeroLetto: String?
    @FocusState private var focusImporto: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    LeggiFattura { p in
                        withAnimation(.spring) {
                            if let v = p.importo { importo = Formato.campo(v) }
                            if let c = p.cliente { cliente = c }
                            if let d = p.data { giorno = d }
                            numeroLetto = p.numero
                        }
                        focusImporto = false
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Quanto?").font(.app(15)).foregroundStyle(Theme.muted)
                        HStack(alignment: .firstTextBaseline) {
                            TextField("0", text: $importo)
                                .keyboardType(.decimalPad)
                                .font(.cifra(48))
                                .focused($focusImporto)
                                .accessibilityIdentifier("nuovo.importo")
                            Text("€").font(.cifra(36)).foregroundStyle(Theme.muted)
                        }
                    }
                    if let p = store.profilo, valore > 0 {
                        let messo = Calcolo.daMettereDaParte(p, anno: store.anno, ricaviAttuali: store.riepilogo.ricavi, incasso: valore)
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Tuoi").font(.app(13, .semibold)).foregroundStyle(Theme.prugna)
                                Text(Formato.euroTondo(valore - messo)).font(.cifra(24))
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("Da mettere da parte").font(.app(13, .semibold)).foregroundStyle(Theme.muted)
                                Text(Formato.euroTondo(messo)).font(.cifra(24)).foregroundStyle(Theme.muted)
                            }
                        }
                        .scheda(padding: 16)
                        .animation(.easeOut, value: valore)
                        if p.rivalsa4 && p.gestione == .separata {
                            Text("Con il 4% INPS in fattura il cliente paga \(Formato.euro(Calcolo.conRivalsa(valore))): inserisci quella cifra se è già compresa.")
                                .font(.app(14)).foregroundStyle(Theme.muted)
                        }
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Chi ti paga?").font(.app(15)).foregroundStyle(Theme.muted)
                        TextField("Nome del cliente", text: $cliente)
                            .font(.app(18))
                            .padding(.horizontal, 14).frame(height: 52)
                            .background(Theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    if let p = store.profilo, p.attivita.count > 1 {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Per quale lavoro?").font(.app(15)).foregroundStyle(Theme.muted)
                            Picker("Per quale lavoro?", selection: $attivita) {
                                ForEach(p.attivita, id: \.self) { c in Text(Ateco.nomeLavoro(c)).tag(c) }
                            }
                            .pickerStyle(.menu)
                            .tint(Theme.prugna)
                        }
                    }
                    Toggle("Mi hanno già pagato", isOn: $pagata).font(.app(17, .semibold)).tint(Theme.prugna)
                    DatePicker((pagata ? "Il giorno" : "Data della fattura").tradotto, selection:
 $giorno, displayedComponents: .date)
                        .font(.app(17))
                        .environment(\.locale, Formato.lingua)
                }
                .padding(20)
            }
            .background(Theme.ground)
            .navigationTitle("Nuovo incasso")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annulla") { chiudi() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") { salva() }.bold().disabled(valore <= 0)
                }
            }
            .onAppear {
                focusImporto = true
                attivita = store.profilo?.ateco ?? ""
            }
        }
    }

    private var valore: Double { Formato.leggiEuro(importo) }

    private func salva() {
        let numero = numeroLetto ?? String(store.fatture.count + 1)
        store.aggiungi(Fattura(numero: numero, data: giorno, cliente: cliente.isEmpty ? "Cliente".tradotto : cliente,
                               importo: valore, incassata: pagata, dataIncasso: pagata ? giorno : nil, origine: numeroLetto == nil ? .manuale : .foto,

                               ateco: attivita.isEmpty || attivita == store.profilo?.ateco ? nil : attivita))
        chiudi()
    }
}
