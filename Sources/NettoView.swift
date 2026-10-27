import SwiftUI

// La prima scheda: quanto ti resta, dove vanno i soldi, cosa mettere da parte. Niente altro.

struct NettoView: View {
    @EnvironmentObject private var store: Store
    let vaiA: (RootView.Scheda) -> Void
    @State private var calcolo = false
    @State private var capire = false

    var body: some View {
        NavigationStack {
            ScrollView {
                if let p = store.profilo, let res = store.risultato {
                    VStack(spacing: 18) {
                        HStack {
                            NomeApp()
                            Spacer()
                            Button { vaiA(.tu) } label: {
                                Text(String(p.nome.prefix(1)).uppercased().isEmpty ? "Tu" : String(p.nome.prefix(1)).uppercased())
                                    .font(.app(17, .bold)).foregroundStyle(Theme.prugna)
                                    .frame(width: 44, height: 44)
                                    .background(Theme.prugnaSoft, in: Circle())
                            }
                            .accessibilityLabel("Il tuo profilo")
                        }

                        anello(res)

                        ForEach(Calcolo.avvisi(p, ricaviAnno: res.ricavi), id: \.self) { Avviso(testo: $0) }
                        if let a = Calcolo.avvisoFineStartup(p) { Avviso(testo: a) }

                        daMettereDaParte(res)

                        Button { capire = true } label: {
                            riga(icona: "sparkles", testo: "Capire in 1 minuto")
                        }
                        .buttonStyle(.plain)
                        Button { calcolo = true } label: {
                            riga(icona: "questionmark.circle", testo: "Come lo calcolo?")
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("netto.calcolo")
                    }
                    .padding(.horizontal, 20).padding(.vertical, 12)
                }
            }
            .background(Theme.ground)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $calcolo) { ComeLoCalcoloView() }
            .fullScreenCover(isPresented: $capire) { CapireView() }
        }
    }

    private func anello(_ res: RisultatoForfettario) -> some View {
        VStack(spacing: 10) {
            ZStack {
                Anello(parti: [
                    .init(valore: max(res.netto, 0), colore: Theme.prugna),
                    .init(valore: res.contributi, colore: Theme.pensione),
                    .init(valore: res.imposta + res.bolli, colore: Theme.tasse),
                ])
                VStack(spacing: 2) {
                    Text("sono tuoi").font(.app(15)).foregroundStyle(Theme.muted)
                    NumeroCheConta(valore: res.netto, dimensione: 38)
                    Text("nel \(String(store.anno))").font(.app(15)).foregroundStyle(Theme.muted)
                }
                .padding(.horizontal, 40)
            }
            .frame(width: 250, height: 250)
            .accessibilityElement(children: .combine)

            HStack(spacing: 8) {
                Pillola(colore: Theme.prugna, testo: "Tuoi")
                Pillola(colore: Theme.pensione, testo: "Pensione \(Formato.euroTondo(res.contributi))")
                Pillola(colore: Theme.tasse, testo: "Tasse \(Formato.euroTondo(res.imposta + res.bolli))")
            }
            .minimumScaleFactor(0.8)
            if res.ricavi == 0 {
                Text("Aggiungi il primo incasso per vedere il tuo anno.").font(.app(15)).foregroundStyle(Theme.muted)
            }
        }
    }

    @ViewBuilder
    private func daMettereDaParte(_ res: RisultatoForfettario) -> some View {
        Button { vaiA(.pagamenti) } label: {
            HStack(spacing: 16) {
                Image(systemName: "banknote")
                    .font(.system(size: 24, weight: .semibold))
                    .frame(width: 52, height: 52)
                    .background(Theme.prugna, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .foregroundStyle(.white)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Metti da parte").font(.app(14, .semibold)).foregroundStyle(Theme.rosaChiaro)
                    if let prossimo = store.prossimoPagamento {
                        Text(Formato.euroTondo(prossimo.importo)).font(.cifra(26))
                        Text("entro il \(prossimo.data.formatted(.dateTime.day().month(.wide).locale(Formato.it)))")
                            .font(.app(14)).foregroundStyle(Theme.suNotte.opacity(0.8))
                    } else {
                        Text(Formato.euroTondo(res.contributi + res.imposta)).font(.cifra(26))
                        Text("per tasse e pensione di quest'anno").font(.app(14)).foregroundStyle(Theme.suNotte.opacity(0.8))
                    }
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(Theme.suNotte.opacity(0.6))
            }
            .riquadroNotte()
        }
        .buttonStyle(.plain)
    }

    private func riga(icona: String, testo: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icona).font(.app(20)).foregroundStyle(Theme.prugna)
            Text(testo).font(.app(16, .semibold))
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(Theme.muted)
        }
        .scheda(padding: 16)
    }
}

/// I dettagli per chi li vuole: il calcolo riga per riga, con le fonti ufficiali
struct ComeLoCalcoloView: View {
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var chiudi

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let res = store.risultato {
                        VStack(alignment: .leading, spacing: 14) {
                            ForEach(res.righe) { r in
                                let ultima = r.id == res.righe.last?.id
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack {
                                        Text(r.etichetta).font(.app(ultima ? 18 : 16, ultima ? .bold : .regular))
                                        Spacer()
                                        Text(Formato.euro(r.importo)).font(.app(ultima ? 18 : 16, ultima ? .bold : .regular)).monospacedDigit()
                                            .foregroundStyle(r.importo < 0 ? Theme.muted : Theme.ink)
                                    }
                                    Text(r.formula).font(.app(13)).foregroundStyle(Theme.muted)
                                    if let f = r.fonte, let url = URL(string: f.url) {
                                        Link((f.verificata ? "Fonte: " : "Da verificare: ") + f.titolo, destination: url)
                                            .font(.app(13)).foregroundStyle(f.verificata ? Theme.prugna : Theme.tasseTesto)
                                    }
                                }
                                if ultima == false { Divider() }
                            }
                        }
                        .scheda()
                        if res.contributiStimati {
                            Text("I contributi tolti sono una stima. In «Pagamenti» puoi inserire quelli che hai davvero versato.")
                                .font(.app(14)).foregroundStyle(Theme.muted)
                        }
                    }
                    Text("Regole aggiornate al \(Giorno.da(Regole.attuali.aggiornatoAl).formatted(.dateTime.day().month(.wide).year().locale(Formato.it))). È un calcolo, non una consulenza fiscale.")
                        .font(.app(13)).foregroundStyle(Theme.muted)
                }
                .padding(20)
            }
            .background(Theme.ground)
            .navigationTitle("Come lo calcolo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fatto") { chiudi() } } }
        }
    }
}
