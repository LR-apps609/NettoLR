import LocalAuthentication
import SwiftUI
import UIKit

// Il blocco con Face ID (o il codice dell'iPhone): se attivo in «Tu», all'apertura i numeri restano coperti
// finché non sei tu. La copertura sta in una finestra sopra tutto, così copre anche i fogli aperti.

struct Blocco: ViewModifier {
    let attivo: Bool
    @Environment(\.scenePhase) private var fase
    @State private var sbloccato = false
    @State private var inCorso = false
    /// Face ID si chiede da solo solo all'apertura e al ritorno dallo sfondo; altrimenti c'è il pulsante
    @State private var dalloSfondo = false

    func body(content: Content) -> some View {
        content
            .onChange(of: fase) { _, nuova in
                if nuova == .background && attivo { sbloccato = false; dalloSfondo = true; aggiornaCopertura() }
                if nuova == .active && attivo && !sbloccato && dalloSfondo {
                    dalloSfondo = false
                    sblocca()
                }
            }
            // Attivato adesso da «Tu»: sei già tu, il blocco vale dalla prossima apertura
            .onChange(of: attivo) { _, nuovo in
                if nuovo { sbloccato = true }
                aggiornaCopertura()
            }
            .onAppear {
                aggiornaCopertura()
                if attivo { sblocca() }
            }
    }

    private func aggiornaCopertura() {
        if attivo && !sbloccato {
            FinestraBlocco.shared.mostra(CoperturaBlocco(sblocca: sblocca))
        } else {
            FinestraBlocco.shared.nascondi()
        }
    }

    private func sblocca() {
        // Il riquadro di Face ID rende l'app «inattiva» e poi di nuovo «attiva»: una richiesta alla volta
        guard !inCorso else { return }
        let contesto = LAContext()
        var errore: NSError?
        guard contesto.canEvaluatePolicy(.deviceOwnerAuthentication, error: &errore) else {
            sbloccato = true          // nessun Face ID né codice impostato: non si blocca nessuno fuori
            aggiornaCopertura()
            return
        }
        inCorso = true
        contesto.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Sblocca i tuoi numeri".tradotto) { ok, _ in
            DispatchQueue.main.async {
                inCorso = false
                sbloccato = ok
                aggiornaCopertura()
            }
        }
    }
}

/// La schermata che copre i numeri
struct CoperturaBlocco: View {
    let sblocca: () -> Void
    var body: some View {
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
    }
}

/// Una finestra sopra tutte le altre (fogli compresi) per la copertura
@MainActor
final class FinestraBlocco {
    static let shared = FinestraBlocco()
    private var finestra: UIWindow?

    func mostra(_ vista: CoperturaBlocco) {
        // Un campo aperto sotto la copertura non deve tenere la tastiera sopra: si chiude prima
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        if let finestra {
            (finestra.rootViewController as? UIHostingController<CoperturaBlocco>)?.rootView = vista
            finestra.isHidden = false
            return
        }
        guard let scena = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first else { return }
        let w = UIWindow(windowScene: scena)
        w.windowLevel = .alert + 1
        w.rootViewController = UIHostingController(rootView: vista)
        w.makeKeyAndVisible()
        finestra = w
    }

    /// Cose da fare appena l'app è sbloccata (per esempio una fattura arrivata con «Apri con NettoLR»)
    private var inAttesa: [() -> Void] = []

    /// Subito se l'app non è bloccata, altrimenti dopo lo sblocco
    func dopoLoSblocco(_ azione: @escaping () -> Void) {
        if let finestra, !finestra.isHidden { inAttesa.append(azione) } else { azione() }
    }

    func nascondi() {
        let eraVisibile = finestra.map { !$0.isHidden } ?? false
        finestra?.isHidden = true
        finestra = nil
        // La finestra dell'app torna principale (tastiera e VoiceOver lì)
        UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first?.windows.first?.makeKey()
        if eraVisibile || !inAttesa.isEmpty {
            let azioni = inAttesa
            inAttesa = []
            azioni.forEach { $0() }
        }
    }
}

extension View {
    func blocco(_ attivo: Bool) -> some View { modifier(Blocco(attivo: attivo)) }
}
