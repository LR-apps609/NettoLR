import SwiftUI
import UIKit

// «Pagamenti»: il conto alla rovescia al prossimo pagamento, la linea del tempo, i dati per l'F24.

struct PagamentiView: View {
    @EnvironmentObject private var store: Store
    @State private var datiAnnoScorso = false
    @State private var dettaglio: Pagamento?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Titolo(testo: "Pagamenti")
                    if let prossimo = store.prossimoPagamento {
                        contoAllaRovescia(prossimo.data, prossimo.importo)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Nessun pagamento in vista").font(.app(20, .bold))
                            Text("Dicci quanto hai pagato l'anno scorso: calcoliamo date e importi di quest'anno.")
                                .font(.app(15)).foregroundStyle(Theme.muted)
                        }
                        .scheda()
                    }

                    VStack(spacing: 0) {
                        ForEach(Array(store.pagamenti.enumerated()), id: \.element.id) { i, p in
                            Button { dettaglio = p } label: { riga(p) }.buttonStyle(Molla()).entrata(i + 1)
                        }
                    }

                    Button("I dati dell'anno scorso") { datiAnnoScorso = true }
                        .buttonStyle(PulsanteBordo())
                        .accessibilityIdentifier("pagamenti.annoScorso")
                    Text("NettoLR prepara importi e codici da copiare nell'F24 del tuo home banking. Non fa pagamenti.")
                        .font(.app(13)).foregroundStyle(Theme.muted)
                }
                .padding(.horizontal, 20).padding(.vertical, 12)
            }
            .background(Theme.ground)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $datiAnnoScorso) { AnnoScorsoView() }
            .sheet(item: $dettaglio) { DettaglioPagamentoView(pagamento: $0) }
        }
    }

    private func contoAllaRovescia(_ data: Date, _ importo: Double) -> some View {
        let giorni = max(0, Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: Calendar.current.startOfDay(for: data)).day ?? 0)
        return VStack(spacing: 14) {
            ZStack {
                Circle().stroke(Theme.notteRialzo, lineWidth: 12)
                ArcoGiorni(frazione: 1 - min(Double(giorni), 120) / 120)
                VStack(spacing: 0) {
                    Text("\(giorni)").font(.cifra(56))
                    Text(giorni == 1 ? "giorno" : "giorni").font(.app(15)).foregroundStyle(Theme.suNotte.opacity(0.8))
                }
            }
            .frame(width: 160, height: 160)
            Text(Formato.euroTondo(importo)).font(.cifra(34))
            Text("da pagare entro il \(data.formatted(.dateTime.day().month(.wide).locale(Formato.it)))")
                .font(.app(17)).foregroundStyle(Theme.suNotte)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .foregroundStyle(.white)
        .background { Aurora(colori: [Color(hex: 0xF2A07B), Theme.rosaChiaro, Color(hex: 0x7EA4DD)]) }
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func riga(_ p: Pagamento) -> some View {
        let fatto = store.pagati[p.id] != nil
        let passato = fatto || p.data < Calendar.current.startOfDay(for: Date())
        return HStack(spacing: 14) {
            if fatto {
                Image(systemName: "checkmark.circle.fill").font(.app(18)).foregroundStyle(Theme.menta)
                    .frame(width: 18)
            } else {
                Circle()
                    .fill(passato ? Color.clear : (p.tipo == .tasse ? Theme.tasse : p.tipo == .bollo ? Theme.lilla : Theme.pensione))
                    .overlay(Circle().stroke(passato ? Theme.muted : .clear, lineWidth: 2))
                    .frame(width: 14, height: 14)
                    .frame(width: 18)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(p.data.formatted(.dateTime.day().month(.wide).locale(Formato.it))).font(.app(16, .semibold))
                Text(p.titolo).font(.app(14)).foregroundStyle(Theme.muted)
            }
            Spacer()
            Text(Formato.euroTondo(p.importo)).font(.app(16, .bold)).monospacedDigit()
        }
        .padding(.vertical, 10).padding(.horizontal, 4)
        .opacity(passato && !fatto ? 0.5 : 1)
        .contentShape(Rectangle())
    }
}

/// L'arco dei giorni che mancano, che si riempie all'apertura
struct ArcoGiorni: View {
    let frazione: Double
    @State private var mostrata = 0.0
    var body: some View {
        Circle()
            .trim(from: 0, to: mostrata)
            .stroke(Theme.rosaChiaro, style: StrokeStyle(lineWidth: 12, lineCap: .round))
            .rotationEffect(.degrees(-90))
            .onAppear { withAnimation(.easeOut(duration: 1.1)) { mostrata = frazione } }
    }
}

/// I dettagli di un pagamento, con i dati per l'F24 da copiare
struct DettaglioPagamentoView: View {
    let pagamento: Pagamento
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var chiudi
    @State private var copiato = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text(Formato.euro(pagamento.importo)).font(.cifra(40))
                Text(pagamento.titolo).font(.app(18, .semibold))
                Text(pagamento.spiegazione).font(.app(16)).foregroundStyle(Theme.muted)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Per l'F24").font(.app(13, .semibold)).foregroundStyle(Theme.muted)
                    Text(pagamento.codice).font(.system(size: 15, design: .monospaced)).textSelection(.enabled)
                }
                .scheda(padding: 14)
                Button(copiato ? "Copiato" : "Copia i dati") {
                    UIPasteboard.general.string = "\(pagamento.titolo)\n\(pagamento.codice)\nImporto: \(Formato.euro(pagamento.importo))"
                    copiato = true
                }
                .buttonStyle(PulsantePieno())
                .sensoryFeedback(.success, trigger: copiato)
                let fatto = store.pagati[pagamento.id]
                Button {
                    withAnimation(.spring) { store.segnaPagato(pagamento, fatto == nil) }
                } label: {
                    Label(fatto == nil ? "Ho pagato" : "Pagato il \(fatto!.formatted(.dateTime.day().month(.wide).locale(Formato.it)))",
                          systemImage: fatto == nil ? "checkmark.circle" : "checkmark.circle.fill")
                }
                .buttonStyle(PulsantePieno(colore: Theme.menta, testo: .white))
                .sensoryFeedback(.success, trigger: fatto)
                .accessibilityIdentifier("pagamento.fatto")
                if let url = URL(string: pagamento.fonte.url) {
                    Link((pagamento.fonte.verificata ? "Fonte: " : "Da verificare: ") + pagamento.fonte.titolo, destination: url)
                        .font(.app(13))
                }
                Spacer()
            }
            .padding(20)
            .background(Theme.ground)
            .navigationTitle(pagamento.data.formatted(.dateTime.day().month(.wide).year().locale(Formato.it)))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fatto") { chiudi() } } }
        }
        .presentationDetents([.medium, .large])
    }
}

/// I dati dell'anno scorso, per calcolare saldo e anticipi
struct AnnoScorsoView: View {
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var chiudi
    @State private var imposta = ""
    @State private var acconti = ""
    @State private var pensione = ""
    @State private var accontiPensione = ""
    @State private var versati = ""

    var body: some View {
        FoglioProva(titolo: "L'anno scorso") {
            Text("Li trovi nella dichiarazione dei redditi o li chiedi al commercialista. Lascia vuoto quello che non sai.")
                .font(.app(15)).foregroundStyle(Theme.muted)
            CampoEuro(etichetta: "Tasse dovute per il \(String(store.anno - 1))", testo: $imposta)
            CampoEuro(etichetta: "Anticipi di tasse già pagati per il \(String(store.anno - 1))", testo: $acconti)
            if store.profilo?.gestione == .separata {
                CampoEuro(etichetta: "Pensione (INPS) dovuta per il \(String(store.anno - 1))", testo: $pensione)
                CampoEuro(etichetta: "Anticipi di pensione già pagati", testo: $accontiPensione)
            }
            CampoEuro(etichetta: "Pensione (INPS) pagata quest'anno", testo: $versati)
            Button("Salva") {
                store.annoPrecedente = DatiAnnoPrecedente(
                    imposta: Formato.leggiEuro(imposta), accontiVersati: Formato.leggiEuro(acconti),
                    contributiGS: pensione.isEmpty ? nil : Formato.leggiEuro(pensione),
                    accontiGSVersati: accontiPensione.isEmpty ? nil : Formato.leggiEuro(accontiPensione))
                store.contributiVersati = versati.isEmpty ? nil : Formato.leggiEuro(versati)
                chiudi()
            }
            .buttonStyle(PulsantePieno())
        }
        .onAppear {
            let a = store.annoPrecedente
            imposta = Formato.campo(a.imposta)
            acconti = Formato.campo(a.accontiVersati)
            pensione = Formato.campo(a.contributiGS)
            accontiPensione = Formato.campo(a.accontiGSVersati)
            versati = Formato.campo(store.contributiVersati)
        }
    }
}
