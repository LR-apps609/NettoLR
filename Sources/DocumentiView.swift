import SwiftUI

// «Documenti»: da dove vengono i numeri (tutte le fonti ufficiali, verificate e da verificare)
// e, più avanti, il certificato della partita IVA e le ricevute F24 fotografate.

struct DocumentiView: View {
    @Environment(\.dismiss) private var chiudi
    @EnvironmentObject private var store: Store
    @State private var certificato = false
    @State private var nuove: [Regole.Novita] = []

    private var regole: Regole { store.regole }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    riepilogo.entrata(0)

                    if let novita = regole.novita, !novita.isEmpty {
                        sezione("Cosa è cambiato")
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(novita, id: \.self) { n in
                                let nuova = nuove.contains(n)
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: nuova ? "sparkles" : "checkmark.circle")
                                        .font(.app(16, .bold)).foregroundStyle(nuova ? Theme.tasseTesto : Theme.muted)
                                        .frame(width: 24)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(Giorno.da(n.data).formatted(.dateTime.day().month(.wide).year().locale(Formato.lingua)))
                                            .font(.app(12, .bold)).foregroundStyle(nuova ? Theme.tasseTesto : Theme.muted)
                                        Text(n.testo.tradotto).font(.app(15)).fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                        }
                        .scheda(padding: 16)
                        .entrata(1)

                        .accessibilityIdentifier("documenti.novita")
                    }

                    sezione("Le fonti dei calcoli")
                    VStack(spacing: 0) {
                        ForEach(Array(fonti.enumerated()), id: \.element.titolo) { i, f in
                            if i > 0 { Divider().padding(.leading, 52) }
                            fonte(f)
                        }
                    }
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.raggio, style: .continuous))
                    .entrata(1)

                    sezione("Codici ATECO")
                    HStack(spacing: 12) {
                        Image(systemName: "list.number").font(.app(18, .bold)).foregroundStyle(Theme.pensione)
                            .frame(width: 40, height: 40)
                            .background(Theme.pensioneSoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(Ateco.numeroCodici) codici ufficiali ISTAT").font(.app(16, .semibold))
                            Text("ATECO 2007 (aggiornamento 2022), ATECO 2025 e la tavola di raccordo tra i due")
                                .font(.app(13)).foregroundStyle(Theme.muted)
                        }
                    }
                    .scheda(padding: 14)
                    .entrata(2)

                    sezione("I tuoi documenti")
                    VStack(spacing: 10) {
                        Button { certificato = true } label: {
                            voce("doc.viewfinder", "Certificato della partita IVA", "Lo fotografi e leggo io il codice ATECO")
                        }
                        .buttonStyle(Molla())
                        if store.ricevute.isEmpty {
                            voce("doc.text.image", "Ricevute F24", "Aggiungile da «Pagamenti» quando segni «Ho pagato»")
                        } else {
                            ricevuteF24
                        }
                    }
                    .entrata(3)

                    Text("NettoLR fa un calcolo, non una consulenza fiscale. Le voci «da verificare» saranno controllate da un commercialista prima del lancio.")
                        .font(.app(13)).foregroundStyle(Theme.muted)
                }
                .padding(20)
            }
            .background(Theme.ground)
            .navigationTitle("Documenti")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fatto") { chiudi() } } }
            .sheet(isPresented: $certificato) { CertificatoView() }
            // Le novità restano evidenziate finché la schermata è aperta, poi contano come viste
            .onAppear { nuove = store.novitaNuove }
            .onDisappear { store.segnaNovitaViste() }
        }
    }

    private var ricevuteF24: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Ricevute F24").font(.app(16, .semibold))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(store.pagamenti.filter { store.ricevute[$0.id] != nil }) { p in
                        VStack(alignment: .leading, spacing: 4) {
                            if let img = store.immagineRicevuta(p.id) {
                                Image(uiImage: img).resizable().scaledToFill()
                                    .frame(width: 110, height: 140).clipped()
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                            Text(p.data.formatted(.dateTime.day().month(.abbreviated).locale(Formato.lingua))).font(.app(12, .bold))
                            Text(Formato.euroTondo(p.importo)).font(.app(12)).foregroundStyle(Theme.muted)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
        .scheda(padding: 14)
    }

    private func voce(_ icona: String, _ titolo: String, _ sotto: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icona).font(.app(20)).foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(Theme.prugna, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(titolo.tradotto).font(.app(16, .semibold)).foregroundStyle(Theme.ink)
                Text(sotto.tradotto).font(.app(13)).foregroundStyle(Theme.muted)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(Theme.prugna)
        }
        .scheda(padding: 14)
    }

    /// Le fonti in ordine: prima quelle verificate
    private var fonti: [Fonte] {
        regole.fonti.values.sorted { a, b in
            if a.verificata != b.verificata { return a.verificata }
            return a.titolo < b.titolo
        }
    }

    private var riepilogo: some View {
        let verificate = regole.fonti.values.filter(\.verificata).count
        let totale = regole.fonti.count
        return HStack(spacing: 16) {
            ZStack {
                Circle().stroke(Color.white.opacity(0.15), lineWidth: 8)
                Circle().trim(from: 0, to: CGFloat(verificate) / CGFloat(max(totale, 1)))
                    .stroke(Color(hex: 0x7CD3B0), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(verificate)/\(totale)").font(.app(15, .heavy))
            }
            .frame(width: 66, height: 66)
            VStack(alignment: .leading, spacing: 4) {
                Text("Regole \(String(regole.anno))").font(.app(20, .bold))
                Text("\(verificate) fonti verificate, \(totale - verificate) da verificare · aggiornate al \(Giorno.da(regole.aggiornatoAl).formatted(.dateTime.day().month(.wide).locale(Formato.lingua)))")
                    .font(.app(14)).foregroundStyle(Theme.suNotte.opacity(0.85))
            }
        }
        .riquadroNotte()
    }

    private func sezione(_ t: String) -> some View {
        Text(t.tradotto.uppercased()).font(.app(12, .bold)).tracking(0.6).foregroundStyle(Theme.muted).padding(.top, 4)
    }

    @ViewBuilder
    private func fonte(_ f: Fonte) -> some View {
        let riga = HStack(alignment: .top, spacing: 12) {
            Image(systemName: f.verificata ? "checkmark.seal.fill" : "questionmark.circle.fill")
                .font(.app(20)).foregroundStyle(f.verificata ? Theme.menta : Theme.tasse)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text(f.titolo).font(.app(15, .semibold)).foregroundStyle(Theme.ink).multilineTextAlignment(.leading)
                Text((f.verificata ? "Verificata" : "Da verificare").tradotto).font(.app(12, .bold))

                    .foregroundStyle(f.verificata ? Theme.menta : Theme.tasseTesto)
            }
            Spacer(minLength: 0)
            Image(systemName: "arrow.up.right").font(.app(12, .bold)).foregroundStyle(Theme.muted)
        }
        .padding(14)
        if let url = URL(string: f.url) {
            Link(destination: url) { riga }
        } else {
            riga
        }
    }

    private func inArrivo(_ icona: String, _ titolo: String, _ sotto: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icona).font(.app(20)).foregroundStyle(Theme.lilla)
                .frame(width: 40, height: 40)
                .background(Theme.lillaSoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(titolo.tradotto).font(.app(16, .semibold))
                Text(sotto.tradotto).font(.app(13)).foregroundStyle(Theme.muted)
            }
            Spacer()
            Text("in arrivo").font(.app(11, .bold)).foregroundStyle(Theme.lilla)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Theme.lillaSoft, in: Capsule())
        }
        .scheda(padding: 14)
    }
}
