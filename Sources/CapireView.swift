import SwiftUI

// «Capire in 1 minuto»: tre passi come le storie, con i numeri veri dell'utente.
// Più avanti: la voce che racconta (generata una volta e inclusa nell'app) e i sottotitoli.

struct CapireView: View {
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var chiudi
    @State private var passo = 0

    var body: some View {
        let res = store.risultato
        let soldi = res.map(Calcolo.doveVannoISoldi) ?? (stato: 3, inps: 20, te: 77)
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                HStack(spacing: 6) {
                    ForEach(0..<3) { i in
                        Capsule().fill(i <= passo ? Theme.prugna : Theme.line).frame(width: 28, height: 6)
                    }
                }
                Spacer()
                Button { chiudi() } label: {
                    Image(systemName: "xmark").font(.app(16, .bold)).foregroundStyle(Theme.ink)
                        .frame(width: 44, height: 44).background(Theme.prugnaSoft, in: Circle())
                }
                .accessibilityLabel("Chiudi")
            }

            Group {
                switch passo {
                case 0:
                    VStack(alignment: .leading, spacing: 22) {
                        titolo("Ogni 100 € che ti pagano…")
                        Colonne(parti: [
                            (soldi.te, Theme.prugna, "restano a te"),
                            (soldi.inps, Theme.pensione, "vanno alla tua pensione"),
                            (soldi.stato, Theme.tasse, "sono tasse"),
                        ])
                        .frame(height: 340)
                    }
                case 1:
                    VStack(alignment: .leading, spacing: 22) {
                        titolo("I soldi della pensione non sono persi.")
                        VStack(spacing: 14) {
                            Image(systemName: "figure.walk.motion").font(.system(size: 90)).foregroundStyle(Theme.pensione)
                            Text("Li ritrovi quando smetti di lavorare.").font(.app(20, .bold)).foregroundStyle(Theme.pensione)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity, minHeight: 300)
                        .background(Theme.card, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                    }
                default:
                    VStack(alignment: .leading, spacing: 22) {
                        titolo("Si paga dopo. Per questo conviene mettere da parte.")
                        VStack(alignment: .leading, spacing: 10) {
                            (Text("Netto").foregroundStyle(Theme.rosaChiaro) + Text("LR").foregroundStyle(Theme.rosaChiaro).fontWeight(.heavy) + Text(" ti avvisa prima").foregroundStyle(Theme.rosaChiaro))
                                .font(.app(16, .semibold))
                            if let prossimo = store.prossimoPagamento {
                                Text("«Metti da parte \(Formato.euroTondo(prossimo.importo)) entro il \(prossimo.data.formatted(.dateTime.day().month(.wide).locale(Formato.it)))»")
                                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                            } else {
                                Text("«Tra un mese tocca pagare: tieni pronti i soldi»")
                                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 260, alignment: .leading)
                        .riquadroNotte(padding: 24)
                    }
                }
            }
            .id(passo)
            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))

            Spacer()
            Button(passo < 2 ? "Avanti" : "Ho capito") {
                if passo < 2 { withAnimation(.spring(duration: 0.4)) { passo += 1 } } else { chiudi() }
            }
            .buttonStyle(PulsantePieno())
            .sensoryFeedback(.selection, trigger: passo)
        }
        .padding(20)
        .background(Theme.ground.ignoresSafeArea())
        .foregroundStyle(Theme.ink)
    }

    private func titolo(_ t: String) -> some View {
        Text(t).font(.system(size: 34, weight: .heavy, design: .rounded)).fixedSize(horizontal: false, vertical: true)
    }
}

/// Tre colonne che crescono dal basso, alte quanto la loro parte
struct Colonne: View {
    let parti: [(Double, Color, String)]
    @State private var cresciute = false

    var body: some View {
        GeometryReader { geo in
            HStack(alignment: .bottom, spacing: 12) {
                ForEach(Array(parti.enumerated()), id: \.offset) { i, parte in
                    VStack(alignment: .leading, spacing: 8) {
                        Spacer(minLength: 0)
                        Text("\(Int(parte.0.rounded())) €").font(.cifra(30)).foregroundStyle(parte.1)
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(parte.1)
                            .frame(height: cresciute ? max(10, (geo.size.height - 110) * parte.0 / 100) : 0)
                            .animation(.spring(duration: 0.8, bounce: 0.2).delay(Double(i) * 0.15), value: cresciute)
                        Text(parte.2).font(.app(16, .semibold)).frame(height: 44, alignment: .top)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .onAppear { cresciute = true }
    }
}
