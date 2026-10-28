import SwiftUI

// Le illustrazioni delle guide: piccole scene disegnate e animate, una per guida.
// Con «Riduci movimento» attivo restano ferme sulla scena finale.

struct Illustrazione: View {
    let guida: String
    let colore: Color
    /// La percentuale del lavoro dell'utente (dalle regole), per l'esempio del forfettario
    var coefficiente: Double?
    /// Il riquadro chiaro dietro la scena (nel video no: c'è già lo sfondo colorato)
    var conFondo = true
    @Environment(\.accessibilityReduceMotion) private var menoMovimento
    @State private var fase = false

    var body: some View {
        Group {
            switch guida {
            case "apri": porta
            case "chiudi": scatola
            case "forfettario": percentuale
            case "iva": fattura
            case "cassa": calendario
            default: EmptyView()
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 130)
        .background(Theme.card.opacity(conFondo ? 0.7 : 0), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .clipped()
        .accessibilityHidden(true)
        .task {
            guard !menoMovimento else { fase = true; return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(0.5))
                withAnimation(.spring(duration: 0.9, bounce: 0.3)) { fase = true }
                try? await Task.sleep(for: .seconds(2.6))
                withAnimation(.easeInOut(duration: 0.6)) { fase = false }
                try? await Task.sleep(for: .seconds(0.8))
            }
        }
    }

    // MARK: Aprire: la porta si apre e dentro c'è la marca da bollo

    private var porta: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6).fill(Theme.notte).frame(width: 74, height: 100)
            Marca().frame(width: 38, height: 38)
                .scaleEffect(fase ? 1 : 0.3)
                .opacity(fase ? 1 : 0)
            RoundedRectangle(cornerRadius: 6).fill(colore)
                .overlay(alignment: .trailing) { Circle().fill(Theme.card).frame(width: 8).padding(.trailing, 9) }
                .frame(width: 74, height: 100)
                .scaleEffect(x: fase ? 0.18 : 1, anchor: .leading)
            Image(systemName: "sparkle").font(.system(size: 18, weight: .bold)).foregroundStyle(Theme.brass)
                .offset(x: 52, y: -40)
                .scaleEffect(fase ? 1 : 0)
        }
    }

    // MARK: Chiudere: i fogli entrano nella scatola e il coperchio si chiude

    private var scatola: some View {
        ZStack {
            ForEach(0..<3) { i in
                RoundedRectangle(cornerRadius: 3).fill(Theme.raised)
                    .overlay(RoundedRectangle(cornerRadius: 3).stroke(Theme.line, lineWidth: 1))
                    .frame(width: 44, height: 54)
                    .rotationEffect(.degrees(Double(i - 1) * 8))
                    .offset(x: Double(i - 1) * 10, y: fase ? 14 : -30)
            }
            RoundedRectangle(cornerRadius: 8).fill(colore)
                .frame(width: 104, height: 52)
                .overlay(Capsule().fill(Theme.card.opacity(0.85)).frame(width: 34, height: 7))
                .offset(y: 30)
            RoundedRectangle(cornerRadius: 6).fill(colore.opacity(0.8))
                .frame(width: 112, height: 14)
                .rotationEffect(.degrees(fase ? 0 : -28), anchor: .leading)
                .offset(y: fase ? -2 : -14)
            Image(systemName: "checkmark.circle.fill").font(.system(size: 26)).foregroundStyle(Theme.menta)
                .background(Circle().fill(Theme.card))
                .offset(x: 56, y: -32)
                .scaleEffect(fase ? 1 : 0)
        }
    }

    // MARK: Il forfettario: di quello che incassi, solo una parte conta come reddito

    private var percentuale: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Incassi").font(.app(13, .semibold)).foregroundStyle(Theme.muted)
                Spacer()
                Text("100 €").font(.app(13, .bold)).foregroundStyle(Theme.ink)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.line)
                    Capsule().fill(colore)
                        .frame(width: geo.size.width * (fase ? quota : 0.04))
                    Text("\(Int((quota * 100).rounded())) €").font(.app(14, .heavy)).foregroundStyle(Theme.suPrugna)
                        .padding(.leading, 12)
                        .opacity(fase ? 1 : 0)
                }
            }
            .frame(height: 30)
            HStack(spacing: 6) {
                Image(systemName: "arrow.turn.down.right").foregroundStyle(colore)
                Text(coefficiente == nil ? "Solo una parte conta: su questa paghi pensione e tasse".tradotto : String(localized: "Per il tuo lavoro il \(Int((quota * 100).rounded()))%: su questo paghi pensione e tasse"))
                    .font(.app(13)).foregroundStyle(Theme.ink)
                    .lineLimit(2).minimumScaleFactor(0.8)
            }
            .opacity(fase ? 1 : 0.35)
        }
        .padding(.horizontal, 18)
    }

    private var quota: Double { coefficiente ?? 0.67 }

    // MARK: L'IVA: in fattura non c'è, ma sopra 77,47 € ci va la marca da bollo

    private var fattura: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 7) {
                Text("Fattura").font(.app(12, .heavy)).foregroundStyle(Theme.ink)
                ForEach([0.9, 0.6, 0.75], id: \.self) { w in
                    Capsule().fill(Theme.line).frame(width: 80 * w, height: 5)
                }
                HStack(spacing: 4) {
                    Text("IVA 22%").font(.app(12, .bold)).foregroundStyle(Theme.muted)
                        .overlay(alignment: .leading) {
                            Capsule().fill(Theme.avviso).frame(height: 2.5)
                                .frame(width: fase ? 52 : 0, alignment: .leading)
                        }
                    Text("0 €").font(.app(12, .heavy)).foregroundStyle(colore).opacity(fase ? 1 : 0)
                }
            }
            .padding(12)
            .frame(width: 112, height: 106, alignment: .topLeading)
            .background(Theme.raised, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.line, lineWidth: 1))
            Marca().frame(width: 32, height: 32)
                .overlay(Text("2 €").font(.system(size: 9, weight: .heavy, design: .rounded)).foregroundStyle(Theme.notte).offset(y: 21))
                .rotationEffect(.degrees(fase ? -10 : 20))
                .scaleEffect(fase ? 1 : 2.2)
                .opacity(fase ? 1 : 0)
                .offset(x: 46, y: 36)
        }
    }

    // MARK: Il principio di cassa: la fattura di dicembre pagata a gennaio conta nell'anno nuovo

    private var calendario: some View {
        HStack(spacing: 34) {
            foglio("DIC", "31", acceso: !fase)
            foglio("GEN", "15", acceso: fase)
        }
        .overlay {
            Image(systemName: "eurosign.circle.fill").font(.system(size: 28)).foregroundStyle(Theme.brass)
                .background(Circle().fill(Theme.card))
                .offset(x: fase ? 54 : -54, y: -38)
                .rotationEffect(.degrees(fase ? 0 : -8))
        }
    }

    private func foglio(_ mese: String, _ giorno: String, acceso: Bool) -> some View {
        VStack(spacing: 0) {
            Text(mese.tradotto).font(.app(12, .heavy)).foregroundStyle(.white)

                .frame(maxWidth: .infinity).padding(.vertical, 4)
                .background(acceso ? colore : Theme.muted.opacity(0.5))
            Text(giorno).font(.system(size: 30, weight: .heavy, design: .rounded))
                .foregroundStyle(acceso ? Theme.ink : Theme.muted.opacity(0.6))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 70, height: 80)
        .background(Theme.raised)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .scaleEffect(acceso ? 1.06 : 0.94)
    }
}
