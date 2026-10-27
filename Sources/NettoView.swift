import Charts
import SwiftUI

// La prima scheda: quanto ti resta (l'anello si tocca), cosa mettere da parte, l'anno mese per mese.

struct NettoView: View {
    @EnvironmentObject private var store: Store
    let vaiA: (RootView.Scheda) -> Void
    @State private var calcolo = false
    @State private var capire = false
    @State private var guide = false

    var body: some View {
        NavigationStack {
            ScrollView {
                if let p = store.profilo, let res = store.risultato {
                    VStack(spacing: 16) {
                        intestazione(p).entrata(0)
                        AnelloNetto(res: res, anno: store.anno).entrata(1).id(store.anno)
                        ForEach(Array((Calcolo.avvisi(p, ricaviAnno: res.ricavi) + [Calcolo.avvisoFineStartup(p)].compactMap { $0 }).enumerated()), id: \.offset) { i, a in
                            Avviso(testo: a).entrata(2 + i)
                        }
                        daMettereDaParte(res).entrata(3)
                        GraficoMesi(mesi: store.incassiPerMese).entrata(4)
                        HStack(spacing: 12) {
                            tessera("Capire in 1 minuto", "sparkles", Theme.lilla, Theme.lillaSoft) { capire = true }
                            tessera("Come lo calcolo?", "function", Theme.pensione, Theme.pensioneSoft) { calcolo = true }
                                .accessibilityIdentifier("netto.calcolo")
                        }
                        .entrata(5)
                        Button { guide = true } label: {
                            HStack(spacing: 14) {
                                Image(systemName: "book.pages.fill").font(.system(size: 22, weight: .bold)).foregroundStyle(.white)
                                    .frame(width: 48, height: 48)
                                    .background(Theme.menta, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Guide").font(.app(17, .bold)).foregroundStyle(Theme.ink)
                                    Text("Aprire, chiudere, capire la partita IVA").font(.app(14)).foregroundStyle(Theme.muted)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").foregroundStyle(Theme.menta)
                            }
                            .padding(14)
                            .background(Theme.mentaSoft, in: RoundedRectangle(cornerRadius: Theme.raggio, style: .continuous))
                        }
                        .buttonStyle(Molla())
                        .entrata(6)
                        .accessibilityIdentifier("netto.guide")
                    }
                    .padding(.horizontal, 20).padding(.vertical, 12)
                }
            }
            .background(Theme.ground)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $calcolo) { ComeLoCalcoloView() }
            .fullScreenCover(isPresented: $capire) { CapireView() }
            .sheet(isPresented: $guide) { GuideView() }
        }
    }

    private func intestazione(_ p: Profilo) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Date().formatted(.dateTime.weekday(.wide).day().month(.wide).locale(Formato.it)).capitalized)
                    .font(.app(14, .semibold)).foregroundStyle(Theme.muted)
                Text(p.nome.isEmpty ? "Ciao!" : "Ciao \(p.nome)!")
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                Menu {
                    Picker("Anno", selection: $store.anno) {
                        ForEach(Regole.anniDisponibili.reversed(), id: \.self) { Text("Il \(String($0))").tag($0) }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text("Il tuo \(String(store.anno))")
                        Image(systemName: "chevron.down").font(.app(11, .bold))
                    }
                    .font(.app(14, .bold)).foregroundStyle(Theme.prugna)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Theme.prugnaSoft, in: Capsule())
                }
                .accessibilityIdentifier("netto.anno")
            }
            Spacer()
            Button { vaiA(.tu) } label: {
                Marca().frame(width: 40, height: 40)
                    .padding(6)
                    .background(Theme.notte, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(Molla())
            .accessibilityLabel("Il tuo profilo")
        }
    }

    private func daMettereDaParte(_ res: RisultatoForfettario) -> some View {
        Button { vaiA(.pagamenti) } label: {
            HStack(spacing: 16) {
                Salvadanaio(riempimento: riempimento)
                    .frame(width: 58, height: 58)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Metti da parte").font(.app(14, .bold)).foregroundStyle(Theme.tasseTesto)
                    if let prossimo = store.prossimoPagamento {
                        Text(Formato.euroTondo(prossimo.importo)).font(.cifra(28)).foregroundStyle(Theme.ink)
                        Text("entro il \(prossimo.data.formatted(.dateTime.day().month(.wide).locale(Formato.it)))")
                            .font(.app(14)).foregroundStyle(Theme.muted)
                    } else {
                        Text(Formato.euroTondo(res.contributi + res.imposta)).font(.cifra(28)).foregroundStyle(Theme.ink)
                        Text("per tasse e pensione di quest'anno").font(.app(14)).foregroundStyle(Theme.muted)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(Theme.tasseTesto)
            }
            .padding(18)
            .background(Theme.tasseSoft, in: RoundedRectangle(cornerRadius: Theme.raggio, style: .continuous))
        }
        .buttonStyle(Molla())
    }

    /// Quanto manca al prossimo pagamento: il salvadanaio si riempie man mano che la data si avvicina
    private var riempimento: Double {
        guard let prossimo = store.prossimoPagamento else { return 0.5 }
        let giorni = Calendar.current.dateComponents([.day], from: Date(), to: prossimo.data).day ?? 0
        return max(0.1, min(1, 1 - Double(giorni) / 120))
    }

    private func tessera(_ testo: String, _ icona: String, _ colore: Color, _ fondo: Color, azione: @escaping () -> Void) -> some View {
        Button(action: azione) {
            VStack(alignment: .leading, spacing: 18) {
                Image(systemName: icona).font(.system(size: 22, weight: .bold)).foregroundStyle(colore)
                Text(testo).font(.app(16, .bold)).foregroundStyle(Theme.ink).multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, minHeight: 104, alignment: .topLeading)
            .padding(16)
            .background(fondo, in: RoundedRectangle(cornerRadius: Theme.raggio, style: .continuous))
        }
        .buttonStyle(Molla())
    }
}

/// L'anello del netto su fondo che si muove. Si tocca: mostra a turno la parte tua, la pensione, le tasse.
struct AnelloNetto: View {
    let res: RisultatoForfettario
    let anno: Int
    @State private var scelta = 0

    var body: some View {
        let parti: [(String, Double, Color)] = [
            ("sono tuoi", max(res.netto, 0), Theme.rosaChiaro),
            ("vanno alla pensione", res.contributi, Color(hex: 0x7EA4DD)),
            ("sono tasse", res.imposta + res.bolli, Color(hex: 0xF2A07B)),
        ]
        let scelto = parti[scelta]
        VStack(spacing: 14) {
            Button {
                withAnimation(.spring(duration: 0.4, bounce: 0.3)) { scelta = (scelta + 1) % parti.count }
            } label: {
                ZStack {
                    Anello(parti: parti.enumerated().map { i, p in
                        .init(valore: p.1, colore: i == scelta ? p.2 : p.2.opacity(0.45))
                    }, spessore: 24, fondo: Color.white.opacity(0.12))
                    VStack(spacing: 2) {
                        Text(scelto.0).font(.app(15, .semibold)).foregroundStyle(scelto.2)
                            .contentTransition(.opacity)
                        NumeroCheConta(valore: scelto.1, dimensione: 36, colore: .white)
                        Text("nel \(String(anno))").font(.app(14)).foregroundStyle(Theme.suNotte.opacity(0.7))
                    }
                    .padding(.horizontal, 40)
                }
                .frame(width: 240, height: 240)
            }
            .buttonStyle(Molla())
            .sensoryFeedback(.selection, trigger: scelta)
            .accessibilityLabel("\(scelto.0): \(Formato.euroTondo(scelto.1)). Tocca per cambiare.")

            HStack(spacing: 8) {
                ForEach(Array(parti.enumerated()), id: \.offset) { i, p in
                    Button {
                        withAnimation(.spring(duration: 0.4, bounce: 0.3)) { scelta = i }
                    } label: {
                        HStack(spacing: 6) {
                            Circle().fill(p.2).frame(width: 9, height: 9)
                            Text(["Tuoi", "Pensione", "Tasse"][i]).font(.app(14, .semibold))
                        }
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .foregroundStyle(i == scelta ? Theme.notte : .white)
                        .background(i == scelta ? p.2 : Color.white.opacity(0.1), in: Capsule())
                    }
                    .buttonStyle(Molla())
                }
            }
            if res.ricavi == 0 {
                Text("Aggiungi il primo incasso per vedere il tuo anno.").font(.app(14)).foregroundStyle(Theme.suNotte.opacity(0.8))
            } else {
                Text("su \(Formato.euroTondo(res.ricavi)) incassati · tocca l'anello").font(.app(13)).foregroundStyle(Theme.suNotte.opacity(0.7))
            }
        }
        .padding(.vertical, 22)
        .frame(maxWidth: .infinity)
        .background { Aurora() }
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
    }
}

/// Il salvadanaio che si riempie
struct Salvadanaio: View {
    let riempimento: Double
    @State private var livello = 0.0

    var body: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.card)
            RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.tasse.opacity(0.85))
                .frame(height: 58 * livello)
            Image(systemName: "eurosign")
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .foregroundStyle(livello > 0.5 ? .white : Theme.tasseTesto)
                .frame(maxHeight: .infinity)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onAppear { withAnimation(.spring(duration: 1.2, bounce: 0.3).delay(0.3)) { livello = riempimento } }
        .accessibilityHidden(true)
    }
}

/// L'anno mese per mese: quanto hai incassato. Tocca un mese per vedere la cifra.
struct GraficoMesi: View {
    let mesi: [(mese: Int, totale: Double)]
    @State private var cresciuto = false
    @State private var selezione: Int?

    var body: some View {
        let massimo = mesi.map(\.totale).max() ?? 0
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Il tuo anno").font(.app(17, .bold))
                Spacer()
                if let m = selezione, let v = mesi.first(where: { $0.mese == m }) {
                    Text("\(Self.nome(m)): \(Formato.euroTondo(v.totale))").font(.app(14, .semibold)).foregroundStyle(Theme.prugna)
                }
            }
            if massimo == 0 {
                Text("Qui vedrai i tuoi incassi, mese per mese.").font(.app(14)).foregroundStyle(Theme.muted)
            } else {
                Chart(mesi, id: \.mese) { m in
                    BarMark(x: .value("Mese", Self.nome(m.mese)), y: .value("Incassato", cresciuto ? m.totale : 0))
                        .foregroundStyle(m.mese == selezione ? Theme.tasse : Theme.prugna)
                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                }
                .chartYAxis(.hidden)
                .chartXAxis {
                    AxisMarks { _ in AxisValueLabel().font(.app(10)).foregroundStyle(Theme.muted) }
                }
                .chartYScale(domain: 0...(massimo * 1.1))
                .chartOverlay { proxy in
                    GeometryReader { _ in
                        Rectangle().fill(.clear).contentShape(Rectangle())
                            .onTapGesture { punto in
                                if let nome: String = proxy.value(atX: punto.x), let i = Self.nomi.firstIndex(of: nome) {
                                    withAnimation(.snappy) { selezione = selezione == i + 1 ? nil : i + 1 }
                                }
                            }
                    }
                }
                .frame(height: 130)
                .sensoryFeedback(.selection, trigger: selezione)
            }
        }
        .scheda()
        .onAppear { withAnimation(.spring(duration: 0.9, bounce: 0.2).delay(0.4)) { cresciuto = true } }
    }

    static let nomi = ["G", "F", "M", "A", "M ", "G ", "L", "A ", "S", "O", "N", "D"]
    static func nome(_ mese: Int) -> String { nomi[max(0, min(11, mese - 1))] }
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
                    Text("Regole \(String(store.anno)) aggiornate al \(Giorno.da(store.regole.aggiornatoAl).formatted(.dateTime.day().month(.wide).year().locale(Formato.it))). È un calcolo, non una consulenza fiscale.")
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
