import LocalAuthentication
import SwiftUI

// Il blocco con Face ID (o il codice dell'iPhone): se attivo in «Tu», all'apertura i numeri restano coperti
// finché non sei tu.

struct Blocco: ViewModifier {
    let attivo: Bool
    @Environment(\.scenePhase) private var fase
    @State private var sbloccato = false

    func body(content: Content) -> some View {
        content
            .overlay {
                if attivo && !sbloccato {
                    ZStack {
                        Aurora().ignoresSafeArea()
                        VStack(spacing: 22) {
                            Marca().frame(width: 96, height: 96)
                            Text("NettoLR è bloccata").font(.system(size: 26, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                            Button { sblocca() } label: { Label("Sblocca", systemImage: "faceid") }
                                .buttonStyle(PulsantePieno(colore: Theme.rosaChiaro, testo: Theme.notte))
                                .frame(maxWidth: 260)
                        }
                    }
                    .transition(.opacity)
                }
            }
            .onChange(of: fase) { _, nuova in
                if nuova == .background { sbloccato = false }
                if nuova == .active && attivo && !sbloccato { sblocca() }
            }
            .onAppear { if attivo { sblocca() } }
    }

    private func sblocca() {
        let contesto = LAContext()
        var errore: NSError?
        guard contesto.canEvaluatePolicy(.deviceOwnerAuthentication, error: &errore) else {
            sbloccato = true          // nessun Face ID né codice impostato: non si blocca nessuno fuori
            return
        }
        contesto.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Sblocca i tuoi numeri".tradotto
) { ok, _ in
            DispatchQueue.main.async { withAnimation(.easeOut(duration: 0.3)) { sbloccato = ok } }
        }
    }
}

extension View {
    func blocco(_ attivo: Bool) -> some View { modifier(Blocco(attivo: attivo)) }
}
