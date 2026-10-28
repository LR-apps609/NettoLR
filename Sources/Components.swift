import SwiftUI

// I pezzi grafici comuni: la marca da bollo, il nome, le schede, l'anello, i numeri che contano.

/// Il logo: una marca da bollo dentellata con la N
struct Marca: View {
    var colore: Color = Theme.rosaChiaro
    var inchiostro: Color = Theme.notte

    var body: some View {
        Canvas { ctx, size in
            let s = min(size.width, size.height) / 60          // il disegno è su una griglia 60×60
            ctx.fill(Path(CGRect(x: 0, y: 0, width: 60 * s, height: 60 * s)), with: .color(colore))
            // I dentelli: cerchi tolti lungo i bordi
            ctx.blendMode = .destinationOut
            for i in 0...6 {
                let p = CGFloat(i) * 10 * s
                for c in [CGPoint(x: p, y: 0), CGPoint(x: p, y: 60 * s), CGPoint(x: 0, y: p), CGPoint(x: 60 * s, y: p)] {
                    ctx.fill(Path(ellipseIn: CGRect(x: c.x - 3.6 * s, y: c.y - 3.6 * s, width: 7.2 * s, height: 7.2 * s)), with: .color(.black))
                }
            }
            ctx.blendMode = .normal
            ctx.stroke(Path(CGRect(x: 8 * s, y: 8 * s, width: 44 * s, height: 44 * s)), with: .color(inchiostro), lineWidth: 2 * s)
            var n = Path()
            let punti: [(CGFloat, CGFloat)] = [(18, 44), (18, 16), (24, 16), (36, 34), (36, 16), (42, 16), (42, 44), (36, 44), (24, 26), (24, 44)]
            n.move(to: CGPoint(x: punti[0].0 * s, y: punti[0].1 * s))
            for p in punti.dropFirst() { n.addLine(to: CGPoint(x: p.0 * s, y: p.1 * s)) }
            n.closeSubpath()
            ctx.fill(n, with: .color(inchiostro))
        }
        .compositingGroup()
        .aspectRatio(1, contentMode: .fit)
        .accessibilityLabel("Logo di NettoLR")
    }
}

/// «Netto» + «LR» nel colore dell'app, come per tutta la famiglia LR
struct NomeApp: View {
    var dimensione: CGFloat = 22
    var body: some View {
        (Text("Netto").foregroundStyle(Theme.ink) + Text("LR").foregroundStyle(Theme.prugna))
            .font(.system(size: dimensione, weight: .heavy, design: .rounded))
            .accessibilityLabel("NettoLR")
    }
}

extension View {
    /// Una scheda bianca arrotondata
    func scheda(padding: CGFloat = 18) -> some View {
        self.padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.raggio, style: .continuous))
    }
    /// Un riquadro scuro «notte», per la cosa più importante della schermata
    func riquadroNotte(padding: CGFloat = 20) -> some View {
        self.padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.notte, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .foregroundStyle(.white)
    }
}

struct PulsantePieno: ButtonStyle {
    var colore: Color = Theme.prugna
    var testo: Color = Theme.suPrugna
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.app(18, .bold))
            .frame(maxWidth: .infinity, minHeight: 58)
            .foregroundStyle(testo)
            .background(colore, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct PulsanteBordo: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.app(17, .bold))
            .frame(maxWidth: .infinity, minHeight: 56)
            .foregroundStyle(Theme.prugna)
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.prugna, lineWidth: 1.5))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

/// Un anello diviso in parti colorate, che si disegna da solo all'apertura
struct Anello: View {
    struct Parte: Identifiable {
        let id = UUID()
        let valore: Double
        let colore: Color
    }
    let parti: [Parte]
    var spessore: CGFloat = 26
    var fondo: Color = Theme.prugnaSoft
    @State private var avanzamento: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var menoMovimento

    var body: some View {
        let totale = max(parti.reduce(0) { $0 + $1.valore }, 0.0001)
        let spazio = parti.filter { $0.valore > 0 }.count > 1 ? 0.006 : 0
        ZStack {
            Circle().stroke(fondo, lineWidth: spessore)
            ForEach(Array(parti.enumerated()), id: \.element.id) { i, parte in
                let inizio = parti.prefix(i).reduce(0) { $0 + $1.valore } / totale
                let fine = inizio + parte.valore / totale
                Circle()
                    .trim(from: CGFloat(inizio + spazio) * avanzamento, to: max(CGFloat(inizio + spazio), CGFloat(fine - spazio)) * avanzamento)
                    .stroke(parte.colore, style: StrokeStyle(lineWidth: spessore, lineCap: .butt))
            }
        }
        .rotationEffect(.degrees(-90))
        .padding(spessore / 2)
        .onAppear {
            if menoMovimento { avanzamento = 1 } else { withAnimation(.spring(duration: 1.2, bounce: 0.15)) { avanzamento = 1 } }
        }
    }
}

/// Un importo che «conta» fino al valore quando compare o cambia
struct NumeroCheConta: View {
    let valore: Double
    var dimensione: CGFloat = 40
    var colore: Color = Theme.ink
    @State private var mostrato: Double = 0

    var body: some View {
        Text(Formato.euroTondo(mostrato))
            .font(.cifra(dimensione))
            .foregroundStyle(colore)
            .contentTransition(.numericText(value: mostrato))
            .minimumScaleFactor(0.5)
            .lineLimit(1)
            .onAppear { withAnimation(.easeOut(duration: 0.9)) { mostrato = valore } }
            .onChange(of: valore) { _, nuovo in withAnimation(.easeOut(duration: 0.5)) { mostrato = nuovo } }
            .accessibilityLabel(Formato.euroTondo(valore))
    }
}

/// Il timbro che si «stampa» quando segni un incasso
struct TimbroAnimato: View {
    @State private var stampato = false
    var body: some View {
        Marca()
            .frame(width: 120, height: 120)
            .scaleEffect(stampato ? 1 : 1.7)
            .rotationEffect(.degrees(stampato ? -6 : -16))
            .opacity(stampato ? 1 : 0)
            .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
            .onAppear { withAnimation(.spring(duration: 0.45, bounce: 0.35)) { stampato = true } }
            .allowsHitTesting(false)
    }
}

/// Un pallino colorato con un'etichetta, sotto l'anello
struct Pillola: View {
    let colore: Color
    let testo: String
    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(colore).frame(width: 10, height: 10)
            Text(testo.tradotto).font(.app(14, .semibold))
        }
        .padding(.horizontal, 12).padding(.vertical, 7)
        .background(Theme.card, in: Capsule())
    }
}

/// Avviso in evidenza (soglia vicina, requisiti…)
struct Avviso: View {
    let testo: String
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.circle.fill").foregroundStyle(Theme.avviso)
            Text(testo.tradotto).font(.app(15)).foregroundStyle(Theme.avviso)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.avvisoSoft, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

/// Il titolo grande in cima a una scheda
struct Titolo: View {
    let testo: String
    var body: some View {
        Text(testo.tradotto).font(.system(size: 34, weight: .heavy, design: .rounded)).foregroundStyle(Theme.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}

/// Un campo per gli importi in euro
struct CampoEuro: View {
    let etichetta: String
    @Binding var testo: String
    var segnaposto = "0"
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(etichetta.tradotto).font(.app(14)).foregroundStyle(Theme.muted)

            HStack {
                TextField(segnaposto, text: $testo).keyboardType(.decimalPad).font(.app(20, .semibold))
                Text("€").font(.app(20, .semibold)).foregroundStyle(Theme.muted)
            }
            .padding(.horizontal, 14).frame(height: 50)
            .background(Theme.raised, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
}
