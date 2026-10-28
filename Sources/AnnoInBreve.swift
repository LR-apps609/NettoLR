import SwiftUI

// «Il tuo anno in 30 secondi»: quattro schermate che vanno avanti da sole, come le storie,
// e alla fine una cartolina da condividere (senza importi, se preferisci).

struct AnnoInBreveView: View {
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var chiudi
    @Environment(\.accessibilityReduceMotion) private var menoMovimento
    @State private var passo = 0
    @State private var avanzamento = 0.0
    @State private var conImporti = true
    private let durata = 6.0
    private let passi = 4

    var body: some View {
        ZStack {
            Aurora(colori: colori).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 4) {
                    ForEach(0..<passi, id: \.self) { i in
                        GeometryReader { geo in
                            Capsule().fill(Color.white.opacity(0.25))
                                .overlay(alignment: .leading) {
                                    Capsule().fill(Color.white)
                                        .frame(width: geo.size.width * (i < passo ? 1 : i == passo ? avanzamento : 0))
                                }
                        }
                        .frame(height: 4)
                    }
                    Button { chiudi() } label: {
                        Image(systemName: "xmark").font(.app(15, .bold)).foregroundStyle(.white).frame(width: 40, height: 40)
                    }
                    .accessibilityLabel("Chiudi")
                }
                Spacer()
                contenuto
                    .id(passo)
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
                Spacer()
                if passo == passi - 1 {
                    Toggle("Mostra gli importi", isOn: $conImporti).font(.app(15, .semibold)).tint(Theme.rosaChiaro)
                    ShareLink(item: cartolina, preview: SharePreview("Il mio \(String(store.anno)) con NettoLR", image: cartolina)) {
                        Label("Condividi", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(PulsantePieno(colore: Theme.rosaChiaro, testo: Theme.notte))
                }
            }
            .foregroundStyle(.white)
            .padding(20)
        }
        .contentShape(Rectangle())
        .onTapGesture { avanti() }
        .task(id: passo) {
            avanzamento = 0
            guard passo < passi - 1, !menoMovimento else { avanzamento = 1; return }
            withAnimation(.linear(duration: durata)) { avanzamento = 1 }
            try? await Task.sleep(for: .seconds(durata))
            if !Task.isCancelled { avanti() }
        }
        .sensoryFeedback(.selection, trigger: passo)
    }

    private var colori: [Color] {
        [[Theme.rosaChiaro, Color(hex: 0xF2A07B), Color(hex: 0x7EA4DD)],
         [Color(hex: 0x7EA4DD), Theme.rosaChiaro, Color(hex: 0xB9A0E0)],
         [Color(hex: 0xF2A07B), Color(hex: 0x7CD3B0), Theme.rosaChiaro],
         [Theme.rosaChiaro, Color(hex: 0xB9A0E0), Color(hex: 0xF2A07B)]][passo % 4]
    }

    private func avanti() {
        guard passo < passi - 1 else { return }
        withAnimation(.spring(duration: 0.5)) { passo += 1 }
    }

    // MARK: I numeri dell'anno

    private var mesi: [(mese: Int, totale: Double)] { store.incassiPerMese }
    private var meseMigliore: (mese: Int, totale: Double)? { mesi.max { $0.totale < $1.totale }.flatMap { $0.totale > 0 ? $0 : nil } }
    private var clienti: Int { Set(store.fatture.filter { $0.incassata && Giorno.anno($0.dataIncasso ?? $0.data) == store.anno }.map(\.cliente)).count }
    /// I nomi dei mesi nella lingua dell'app
    private static var nomiMesi: [String] {
        var c = Calendar(identifier: .gregorian)
        c.locale = Formato.lingua
        return c.standaloneMonthSymbols
    }

    @ViewBuilder
    private var contenuto: some View {
        let res = store.risultato
        switch passo {
        case 0:
            grande(String(localized: "Nel \(String(store.anno)) hai incassato"), Formato.euroTondo(res?.ricavi ?? 0), "Tutto con le tue mani.")
        case 1:
            if let m = meseMigliore {
                grande("Il mese migliore è stato", Self.nomiMesi[m.mese - 1].capitalized, String(localized: "con \(Formato.euroTondo(m.totale)) incassati."))
            } else {
                grande("Il tuo anno", "è appena iniziato", "Aggiungi gli incassi e qui vedrai il mese migliore.")
            }
        case 2:
            grande("Di ogni 100 € sono rimasti a te", "\(Int((res.map(Calcolo.doveVannoISoldi)?.te ?? 0).rounded())) €", "Il resto è andato alla pensione e alle tasse.")
        default:
            VStack(alignment: .leading, spacing: 18) {
                Text("Il mio \(String(store.anno))").font(.app(18, .bold)).opacity(0.85)
                cartolinaVista.frame(maxWidth: .infinity)
            }
        }
    }

    private func grande(_ sopra: String, _ numero: String, _ sotto: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(sopra.tradotto).font(.app(22, .semibold)).opacity(0.9)
            Text(numero.tradotto).font(
.system(size: 64, weight: .heavy, design: .rounded)).minimumScaleFactor(0.5).lineLimit(1)
            Text(sotto.tradotto).font(.app(19)).opacity(0.85)
        }
    }

    // MARK: La cartolina da condividere

    private var cartolinaVista: some View {
        CartolinaAnno(anno: store.anno, ricavi: store.risultato?.ricavi ?? 0, netto: store.risultato?.netto ?? 0,
                      clienti: clienti, meseMigliore: meseMigliore.map { Self.nomiMesi[$0.mese - 1] }, conImporti: conImporti)
    }

    private var cartolina: Image {
        let r = ImageRenderer(content: cartolinaVista.frame(width: 360))
        r.scale = 3
        return r.uiImage.map { Image(uiImage: $0) } ?? Image(systemName: "photo")
    }
}

struct CartolinaAnno: View {
    let anno: Int
    let ricavi: Double
    let netto: Double
    let clienti: Int
    let meseMigliore: String?
    let conImporti: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Marca().frame(width: 40, height: 40)
                Spacer()
                Text(String(anno)).font(.system(size: 28, weight: .heavy, design: .rounded)).foregroundStyle(Theme.rosaChiaro)
            }
            if conImporti {
                riga("Incassato", Formato.euroTondo(ricavi))
                riga("Rimasto a me", Formato.euroTondo(netto))
            }
            riga("Clienti", "\(clienti)")
            if let meseMigliore { riga("Mese migliore", meseMigliore.capitalized) }
            (Text("Netto").foregroundStyle(.white) + Text("LR").foregroundStyle(Theme.rosaChiaro))
                .font(.system(size: 16, weight: .heavy, design: .rounded))
                .padding(.top, 4)
        }
        .padding(22)
        .background(Theme.notte, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .foregroundStyle(.white)
    }

    private func riga(_ etichetta: String, _ valore: String) -> some View {
        HStack {
            Text(etichetta.tradotto).font(.system(size: 15, weight: .semibold, design: .rounded)).foregroundStyle(Color(hex: 0xE9DFE6))

            Spacer()
            Text(valore).font(.system(size: 20, weight: .heavy, design: .rounded))
        }
    }
}
