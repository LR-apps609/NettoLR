import SwiftUI
import StoreKit

// Prova gratuita di 14 giorni, poi un acquisto una tantum («NettoLR completo»): niente abbonamento.
// Il prezzo lo decide App Store Connect; qui si legge solo quello che mostra l'App Store.
// Nelle versioni installate da Xcode (Debug) l'app non si blocca mai: con l'Apple ID gratuito non si può comprare.

@MainActor
final class Acquisto: ObservableObject {
    static let shared = Acquisto()
    static let idProdotto = "it.ledion.NettoLR.completo"
    static let giorniProva = 14

    @Published private(set) var prodotto: Product?
    @Published private(set) var completo = false
    @Published private(set) var inCorso = false
    @Published var messaggio: String?
    let inizioProva: Date
    private var ascolto: Task<Void, Never>?

    init() {
        let d = UserDefaults.standard
        if let inizio = d.object(forKey: "inizioProva") as? Date {
            inizioProva = inizio
        } else {
            inizioProva = Date()
            d.set(inizioProva, forKey: "inizioProva")
        }
        if ProcessInfo.processInfo.arguments.contains("-uitest") { completo = true }
        // Acquisti fatti su un altro dispositivo, rimborsi, approvazioni dei genitori
        ascolto = Task { [weak self] in
            for await esito in Transaction.updates { await self?.gestisci(esito) }
        }
    }

    var giorniRimasti: Int {
        let passati = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: inizioProva),
                                                      to: Calendar.current.startOfDay(for: Date())).day ?? 0
        return max(0, Self.giorniProva - passati)
    }

    var bloccato: Bool {
        #if DEBUG
        return false
        #else
        return !completo && giorniRimasti == 0
        #endif
    }

    func aggiorna() async {
        if prodotto == nil { prodotto = try? await Product.products(for: [Self.idProdotto]).first }
        for await esito in Transaction.currentEntitlements {
            if case .verified(let t) = esito, t.productID == Self.idProdotto, t.revocationDate == nil { completo = true }
        }
    }

    func compra() async {
        if prodotto == nil { await aggiorna() }
        guard let prodotto else {
            messaggio = "L'App Store non risponde. Controlla la connessione e riprova."
            return
        }
        inCorso = true
        defer { inCorso = false }
        do {
            switch try await prodotto.purchase() {
            case .success(let esito): await gestisci(esito)
            case .pending: messaggio = "L'acquisto aspetta un'approvazione (per esempio di In famiglia)."
            default: break
            }
        } catch {
            messaggio = "Acquisto non riuscito. Riprova tra poco."
        }
    }

    func ripristina() async {
        inCorso = true
        defer { inCorso = false }
        try? await AppStore.sync()
        await aggiorna()
        messaggio = completo ? nil : "Non trovo acquisti con questo Apple ID."
    }

    private func gestisci(_ esito: VerificationResult<Transaction>) async {
        guard case .verified(let t) = esito else { return }
        if t.productID == Self.idProdotto { completo = t.revocationDate == nil }
        await t.finish()
    }
}

/// La schermata di NettoLR completo: dal «Tu» oppure, a prova finita, sopra tutta l'app
struct CompletoView: View {
    @EnvironmentObject private var acquisto: Acquisto
    @Environment(\.dismiss) private var chiudi
    /// A prova finita: non si chiude, ma si può sempre fare la copia dei dati
    var bloccato = false
    @State private var codice = false
    @State private var backup = false

    var body: some View {
        ZStack {
            Aurora(colori: [Theme.rosaChiaro, Theme.brass, Color(hex: 0xB9A0E0)]).ignoresSafeArea()
            if acquisto.completo { Coriandoli().ignoresSafeArea().allowsHitTesting(false) }
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Marca().frame(width: 64, height: 64).rotationEffect(.degrees(-6))
                        Spacer()
                        if !bloccato {
                            Button { chiudi() } label: {
                                Image(systemName: "xmark").font(.app(15, .bold)).frame(width: 40, height: 40)
                                    .background(Color.white.opacity(0.16), in: Circle())
                            }
                            .accessibilityLabel("Chiudi")
                        }
                    }
                    if acquisto.completo {
                        Text("Grazie!").font(.system(size: 44, weight: .heavy, design: .rounded))
                        Text("NettoLR è tuo, per sempre. Anche gli aggiornamenti.").font(.app(19))
                    } else {
                        Text(bloccato ? "La prova è finita" : "NettoLR completo")
                            .font(.system(size: 40, weight: .heavy, design: .rounded))
                        Text(sottotitolo).font(.app(19)).opacity(0.9)
                        VStack(alignment: .leading, spacing: 12) {
                            vantaggio("checkmark.seal.fill", "Paghi una volta, niente abbonamento")
                            vantaggio("lock.fill", "I tuoi dati restano sul telefono")
                            vantaggio("arrow.triangle.2.circlepath", "Regole aggiornate ogni anno")
                            vantaggio("wifi.slash", "Funziona anche senza internet")
                        }
                        .padding(.vertical, 6)
                        Button {
                            Task { await acquisto.compra() }
                        } label: {
                            HStack {
                                if acquisto.inCorso { ProgressView().tint(Theme.notte) }
                                Text(acquisto.prodotto.map { "Sblocca per \($0.displayPrice)" } ?? "Sblocca NettoLR")
                            }
                        }
                        .buttonStyle(PulsantePieno(colore: .white, testo: Theme.notte))
                        .disabled(acquisto.inCorso)
                        .accessibilityIdentifier("completo.compra")
                        HStack {
                            Button("Ripristina acquisto") { Task { await acquisto.ripristina() } }
                            Spacer()
                            Button("Ho un codice regalo") { codice = true }
                        }
                        .font(.app(15, .semibold))
                        if let m = acquisto.messaggio {
                            Text(m).font(.app(15, .semibold)).padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 14))
                        }
                        if bloccato {
                            Button { backup = true } label: {
                                Label("Fai una copia dei tuoi dati", systemImage: "icloud.and.arrow.up")
                            }
                            .font(.app(15, .semibold))
                            Text("I tuoi dati non si cancellano: li ritrovi tutti appena sblocchi.").font(.app(14)).opacity(0.8)
                        }
                    }
                }
                .padding(20)
            }
            .foregroundStyle(.white)
        }
        .task { await acquisto.aggiorna() }
        .offerCodeRedemption(isPresented: $codice) { _ in Task { await acquisto.aggiorna() } }
        .sheet(isPresented: $backup) { BackupView().environmentObject(Store.shared) }
        .sensoryFeedback(.success, trigger: acquisto.completo)
    }

    private var sottotitolo: String {
        if bloccato { return "Sblocca NettoLR per continuare a vedere quanto ti resta." }
        let g = acquisto.giorniRimasti
        return g == 1 ? "Ti resta 1 giorno di prova gratuita." : "Ti restano \(g) giorni di prova gratuita."
    }

    private func vantaggio(_ icona: String, _ testo: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icona).font(.system(size: 17, weight: .bold)).foregroundStyle(Theme.notte)
                .frame(width: 34, height: 34).background(Color.white, in: Circle())
            Text(testo).font(.app(17, .semibold))
        }
    }
}
