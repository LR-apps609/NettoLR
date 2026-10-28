import SwiftUI
import StoreKit

// Prova gratuita di 14 giorni (senza carta), poi l'abbonamento a NettoLR completo: mensile o annuale.
// I prezzi li decide App Store Connect; qui si legge solo quello che mostra l'App Store.
// Nelle versioni installate da Xcode (Debug) l'app non si blocca mai: con l'Apple ID gratuito non si può comprare.

@MainActor
final class Acquisto: ObservableObject {
    static let shared = Acquisto()
    static let idMensile = "it.ledion.NettoLR.mensile"
    static let idAnnuale = "it.ledion.NettoLR.annuale"
    static let giorniProva = 14

    @Published private(set) var mensile: Product?
    @Published private(set) var annuale: Product?
    @Published private(set) var completo = false
    /// Il piano attivo, per dirlo in «Tu»
    @Published private(set) var piano: String?
    @Published private(set) var inCorso = false
    @Published var messaggio: String?
    let inizioProva: Date
    private var ascolto: Task<Void, Never>?
    private let uitest = ProcessInfo.processInfo.arguments.contains("-uitest")

    init() {
        let d = UserDefaults.standard
        if let inizio = d.object(forKey: "inizioProva") as? Date {
            inizioProva = inizio
        } else {
            inizioProva = Date()
            d.set(inizioProva, forKey: "inizioProva")
        }
        // Nel giro delle foto: abbonamento attivo, oppure («-uiProva») la schermata con i piani
        if uitest && !ProcessInfo.processInfo.arguments.contains("-uiProva") { completo = true; piano = "Annuale" }
        // Acquisti fatti su un altro dispositivo, rinnovi, rimborsi, approvazioni dei genitori
        ascolto = Task { [weak self] in
            for await esito in StoreKit.Transaction.updates { await self?.gestisci(esito) }
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

    /// Quanto si risparmia con l'annuale rispetto a 12 mesi (es. 44), dai prezzi veri dell'App Store
    var risparmioAnnuale: Int? {
        guard let mensile, let annuale, mensile.price > 0 else { return nil }
        let dodici = NSDecimalNumber(decimal: mensile.price * 12).doubleValue
        let anno = NSDecimalNumber(decimal: annuale.price).doubleValue
        let r = Int(((1 - anno / dodici) * 100).rounded(.down))
        return r > 0 ? r : nil
    }

    func aggiorna() async {
        if mensile == nil || annuale == nil, let prodotti = try? await Product.products(for: [Self.idMensile, Self.idAnnuale]) {
            mensile = prodotti.first { $0.id == Self.idMensile }
            annuale = prodotti.first { $0.id == Self.idAnnuale }
        }
        guard !uitest else { return }
        // Le iscrizioni attive (quelle scadute o rimborsate non compaiono)
        var attivo: String?
        for await esito in StoreKit.Transaction.currentEntitlements {
            if case .verified(let t) = esito, valida(t) { attivo = nome(t.productID) }
        }
        completo = attivo != nil
        piano = attivo
    }

    func compra(_ prodotto: Product?) async {
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
        messaggio = completo ? nil : "Non trovo abbonamenti attivi con questo Apple ID."
    }

    private func valida(_ t: StoreKit.Transaction) -> Bool {
        [Self.idMensile, Self.idAnnuale].contains(t.productID) && t.revocationDate == nil
            && (t.expirationDate ?? .distantFuture) > Date()
    }

    private func nome(_ id: String) -> String { id == Self.idAnnuale ? "Annuale" : "Mensile" }

    private func gestisci(_ esito: VerificationResult<StoreKit.Transaction>) async {
        guard case .verified(let t) = esito else { return }
        if valida(t) {
            completo = true
            piano = nome(t.productID)
        } else if [Self.idMensile, Self.idAnnuale].contains(t.productID) {
            await aggiorna()
        }
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
    @State private var gestisci = false
    @State private var annualeScelto = true

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
                        Group {
                            if let piano = acquisto.piano {
                                Text("NettoLR completo è attivo, piano \(piano.tradotto.lowercased()).")
                            } else {
                                Text("NettoLR completo è attivo.")
                            }
                        }
                        .font(.app(19))
                        Button("Gestisci l'abbonamento") { gestisci = true }
                            .buttonStyle(PulsanteBordo())
                    } else {
                        Text((bloccato ? "La prova è finita" : "NettoLR completo").tradotto)
                            .font(.system(size: 40, weight: .heavy, design: .rounded))
                        Text(sottotitolo).font(.app(19)).opacity(0.9)
                        VStack(alignment: .leading, spacing: 12) {
                            vantaggio("lock.fill", "I tuoi dati restano sul telefono")
                            vantaggio("arrow.triangle.2.circlepath", "Regole aggiornate ogni anno")
                            vantaggio("bell.fill", "Promemoria di tutti i pagamenti")
                            vantaggio("wifi.slash", "Funziona anche senza internet")
                        }
                        .padding(.vertical, 6)
                        pianoScheda(annuale: true)
                        pianoScheda(annuale: false)
                        Button {
                            Task { await acquisto.compra(annualeScelto ? acquisto.annuale : acquisto.mensile) }
                        } label: {
                            HStack {
                                if acquisto.inCorso { ProgressView().tint(Theme.notte) }
                                Text("Continua")
                            }
                        }
                        .buttonStyle(PulsantePieno(colore: .white, testo: Theme.notte))
                        .disabled(acquisto.inCorso)
                        .accessibilityIdentifier("completo.compra")
                        Text("Si rinnova da solo. Disdici quando vuoi da Impostazioni › il tuo nome › Abbonamenti, almeno 24 ore prima del rinnovo.")
                            .font(.app(13)).opacity(0.8)
                        Link("Condizioni d'uso (Apple)", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                            .font(.app(13, .semibold))
                        HStack {
                            Button("Ripristina acquisto") { Task { await acquisto.ripristina() } }
                            Spacer()
                            Button("Ho un codice regalo") { codice = true }
                        }
                        .font(.app(15, .semibold))
                        if let m = acquisto.messaggio {
                            Text(m.tradotto).font(.app(15, .semibold)).padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 14))
                        }
                        if bloccato {
                            Button { backup = true } label: {
                                Label("Fai una copia dei tuoi dati", systemImage: "icloud.and.arrow.up")
                            }
                            .font(.app(15, .semibold))
                            Text("I tuoi dati non si cancellano: li ritrovi tutti appena ti abboni.").font(.app(14)).opacity(0.8)
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
        .manageSubscriptionsSheet(isPresented: $gestisci)
        .sensoryFeedback(.success, trigger: acquisto.completo)
    }

    private var sottotitolo: String {
        if bloccato { return "Abbonati per continuare a vedere quanto ti resta.".tradotto }
        let g = acquisto.giorniRimasti
        return g == 1 ? "Ti resta 1 giorno di prova gratuita.".tradotto : String(localized: "Ti restano \(g) giorni di prova gratuita.")

    }

    /// Una delle due scelte: annuale (con il risparmio) o mensile
    private func pianoScheda(annuale: Bool) -> some View {
        let scelto = annualeScelto == annuale
        let prodotto = annuale ? acquisto.annuale : acquisto.mensile
        return Button { withAnimation(.spring(duration: 0.3)) { annualeScelto = annuale } } label: {
            HStack(spacing: 14) {
                Image(systemName: scelto ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24, weight: .semibold))
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text((annuale ? "Annuale" : "Mensile").tradotto).font(.app(18, .bold))
                        if annuale, let r = acquisto.risparmioAnnuale {
                            Text("risparmi il \(r)%").font(.app(13, .heavy)).foregroundStyle(Theme.notte)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(Theme.rosaChiaro, in: Capsule())
                        }
                    }
                    Text((annuale ? "Paghi una volta all'anno" : "Paghi ogni mese").tradotto).font(.app(14)).opacity(0.8)
                }
                Spacer()
                Text(prodotto.map { $0.displayPrice + (annuale ? "/anno" : "/mese").tradotto } ?? "…").font(.app(17, .heavy))
            }
            .padding(16)
            .background(Color.white.opacity(scelto ? 0.24 : 0.1), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.white.opacity(scelto ? 0.9 : 0.2), lineWidth: 2))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(scelto ? .isSelected : [])
        .accessibilityIdentifier(annuale ? "completo.annuale" : "completo.mensile")
    }

    private func vantaggio(_ icona: String, _ testo: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icona).font(.system(size: 17, weight: .bold)).foregroundStyle(Theme.notte)
                .frame(width: 34, height: 34).background(Color.white, in: Circle())
            Text(testo.tradotto).font(.app(17, .semibold))
        }
    }
}
