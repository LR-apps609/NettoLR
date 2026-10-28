import SwiftUI

// Movimento e carattere: lo sfondo che si muove piano, le schede che entrano, i pulsanti che rispondono
// al dito, i coriandoli, il «no» che scuote. Tutto si ferma con «Riduci movimento» dell'iPhone.

/// Macchie di colore sfocate che si muovono lentamente dietro a un riquadro scuro
struct Aurora: View {
    var colori: [Color] = [Theme.rosaChiaro, Color(hex: 0xF2A07B), Color(hex: 0x7EA4DD)]
    @Environment(\.accessibilityReduceMotion) private var menoMovimento

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: menoMovimento)) { tempo in
            let t = menoMovimento ? 0 : tempo.date.timeIntervalSinceReferenceDate
            GeometryReader { geo in
                let w = geo.size.width, h = geo.size.height
                ZStack {
                    ForEach(Array(colori.enumerated()), id: \.offset) { i, colore in
                        let fase = Double(i) * 2.1
                        Circle()
                            .fill(colore)
                            .frame(width: w * 0.75, height: w * 0.75)
                            .offset(x: w * 0.32 * cos(t * 0.23 + fase), y: h * 0.28 * sin(t * 0.31 + fase))
                            .opacity(0.55)
                    }
                }
                .frame(width: w, height: h)
                .blur(radius: 60)
            }
        }
        .background(Theme.notte)
        .clipped()
        .allowsHitTesting(false)
    }
}

extension View {
    /// La scheda entra dal basso, una dopo l'altra (`ordine` = posizione nella pagina)
    func entrata(_ ordine: Int) -> some View { modifier(Entrata(ordine: ordine)) }
}

struct Entrata: ViewModifier {
    let ordine: Int
    @State private var visibile = false
    @Environment(\.accessibilityReduceMotion) private var menoMovimento

    func body(content: Content) -> some View {
        content
            .opacity(visibile || menoMovimento ? 1 : 0)
            .offset(y: visibile || menoMovimento ? 0 : 24)
            .onAppear {
                withAnimation(.spring(duration: 0.55, bounce: 0.25).delay(Double(ordine) * 0.07)) { visibile = true }
            }
    }
}

/// Pulsante che si abbassa sotto il dito
struct Molla: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .brightness(configuration.isPressed ? -0.03 : 0)
            .animation(.spring(duration: 0.25, bounce: 0.4), value: configuration.isPressed)
    }
}

/// Scuote orizzontalmente: per i «no» (partita IVA sbagliata…)
struct Scuoti: GeometryEffect {
    var volte: CGFloat
    var animatableData: CGFloat {
        get { volte }
        set { volte = newValue }
    }
    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 9 * sin(volte * .pi * 4), y: 0))
    }
}

/// Coriandoli nei colori dell'app, per un secondo e mezzo
struct Coriandoli: View {
    private struct Pezzo {
        let x: Double, ritardo: Double, velocita: Double, oscillazione: Double, giro: Double, colore: Color, largo: Bool
    }
    @State private var inizio = Date()
    @State private var finito = false
    @Environment(\.accessibilityReduceMotion) private var menoMovimento
    private let pezzi: [Pezzo] = (0..<70).map { _ in
        Pezzo(x: .random(in: 0...1), ritardo: .random(in: 0...0.25), velocita: .random(in: 0.7...1.3),
              oscillazione: .random(in: 0...6.28), giro: .random(in: 2...8),
              colore: [Theme.rosaChiaro, Color(hex: 0xF2A07B), Color(hex: 0x7EA4DD), Color(hex: 0x7CD3B0), Color(hex: 0xA23E6E)].randomElement()!,
              largo: Bool.random())
    }

    var body: some View {
        // Dopo due secondi (o con «Riduci movimento») il disegno si ferma: niente ridisegni inutili
        TimelineView(.animation(paused: finito || menoMovimento)) { tempo in
            Canvas { ctx, size in
                let t = tempo.date.timeIntervalSince(inizio)
                for p in pezzi {
                    let tt = max(0, t - p.ritardo)
                    let y = -20 + tt * tt * 520 * p.velocita + tt * 120
                    guard y < size.height + 20 else { continue }
                    let x = p.x * size.width + sin(tt * 5 + p.oscillazione) * 18
                    var c = ctx
                    c.translateBy(x: x, y: y)
                    c.rotate(by: .radians(tt * p.giro))
                    c.opacity = max(0, 1 - tt / 1.6)
                    let r = p.largo ? CGRect(x: -5, y: -3, width: 10, height: 6) : CGRect(x: -3, y: -3, width: 6, height: 6)
                    c.fill(p.largo ? Path(r) : Path(ellipseIn: r), with: .color(p.colore))
                }
            }
        }
        .opacity(menoMovimento ? 0 : 1)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .task {
            try? await Task.sleep(for: .seconds(2))
            finito = true
        }
    }
}

extension Theme {

    /// Lo stesso cliente ha sempre lo stesso colore
    static func colori(per nome: String) -> (Color, Color) {
        let somma = nome.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
        return tavolozza[abs(somma) % tavolozza.count]
    }
}
