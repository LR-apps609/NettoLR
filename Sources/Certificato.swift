import PhotosUI
import SwiftUI
import Vision
import VisionKit

// Il certificato di attribuzione della partita IVA (o la visura): si fotografa e il telefono legge
// i codici ATECO e la partita IVA. Niente esce dal telefono (Vision di Apple, sul dispositivo).

enum LettoreCertificato {
    struct Trovato: Equatable {
        var codici: [TrovatoAteco] = []
        var partitaIVA: String?
    }

    /// Legge il testo di una o più immagini
    static func testo(_ immagini: [CGImage]) async -> String {
        await withCheckedContinuation { continuazione in
            DispatchQueue.global(qos: .userInitiated).async {
                var righe: [String] = []
                for img in immagini {
                    let richiesta = VNRecognizeTextRequest()
                    richiesta.recognitionLevel = .accurate
                    richiesta.recognitionLanguages = ["it-IT"]
                    richiesta.usesLanguageCorrection = false
                    try? VNImageRequestHandler(cgImage: img).perform([richiesta])
                    righe += (richiesta.results ?? []).compactMap { $0.topCandidates(1).first?.string }
                }
                continuazione.resume(returning: righe.joined(separator: "\n"))
            }
        }
    }

    /// Nel testo letto: i codici ATECO esistenti (6 cifre, con o senza punti) e la partita IVA valida
    static func cerca(in testo: String) -> Trovato {
        var trovato = Trovato()
        let codice = try? NSRegularExpression(pattern: #"(?<!\d)(\d{2})[.\s]?(\d{2})[.\s]?(\d{2})(?!\d)"#)
        let intervallo = NSRange(testo.startIndex..., in: testo)
        var visti = Set<String>()
        for m in codice?.matches(in: testo, range: intervallo) ?? [] {
            let parti = (1...3).compactMap { Range(m.range(at: $0), in: testo).map { String(testo[$0]) } }
            guard parti.count == 3 else { continue }
            let c = parti.joined(separator: ".")
            guard !visti.contains(c) else { continue }
            visti.insert(c)
            // Solo i codici che esistono davvero; se lo stesso numero è sia 2007 sia 2025, prima il 2025 (certificati recenti)
            let esatti = Ateco.cerca(c, max: 4).filter { $0.codice == c }
            if let migliore = esatti.first(where: { $0.versione == .v2025 }) ?? esatti.first {
                trovato.codici.append(migliore)
            }
        }
        let piva = try? NSRegularExpression(pattern: #"(?<!\d)(\d{11})(?!\d)"#)
        for m in piva?.matches(in: testo, range: intervallo) ?? [] {
            if let r = Range(m.range(at: 1), in: testo), PartitaIVA.valida(String(testo[r])) {
                trovato.partitaIVA = String(testo[r])
                break
            }
        }
        return trovato
    }
}

/// Il foglio «Fotografa il certificato»: scanner o foto, lettura, conferma
struct CertificatoView: View {
    /// Se c'è, riceve il codice ATECO 2007 scelto e la partita IVA (benvenuto); altrimenti si salva nel profilo
    var scelto: ((String, String?) -> Void)? = nil
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var chiudi
    @State private var scanner = false
    @State private var fotoScelta: PhotosPickerItem?
    @State private var leggendo = false
    @State private var trovato: LettoreCertificato.Trovato?
    @State private var daScegliere: TrovatoAteco?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Fotografa il certificato di attribuzione della partita IVA o la visura camerale: leggo io il codice ATECO.")
                        .font(.app(17))
                    if VNDocumentCameraViewController.isSupported {
                        Button { scanner = true } label: { Label("Fotografa il documento", systemImage: "doc.viewfinder") }
                            .buttonStyle(PulsantePieno())
                    }
                    PhotosPicker(selection: $fotoScelta, matching: .images) {
                        Label("Scegli una foto", systemImage: "photo")
                    }
                    .buttonStyle(PulsanteBordo())

                    if leggendo {
                        HStack(spacing: 12) { ProgressView(); Text("Leggo il documento…").font(.app(16)) }
                            .scheda()
                    }
                    if let t = trovato { risultato(t) }

                    Label("La foto resta sul telefono: la lettura avviene sull'iPhone, senza internet.", systemImage: "lock.fill")
                        .font(.app(13)).foregroundStyle(Theme.muted)
                }
                .padding(20)
            }
            .background(Theme.ground)
            .navigationTitle("Certificato P.IVA")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Chiudi") { chiudi() } } }
            .fullScreenCover(isPresented: $scanner) {
                ScannerDocumenti { immagini in
                    scanner = false
                    Task { await leggi(immagini) }
                }
                .ignoresSafeArea()
            }
            .onChange(of: fotoScelta) { _, voce in
                guard let voce else { return }
                Task {
                    if let dati = try? await voce.loadTransferable(type: Data.self),
                       let ui = UIImage(data: dati), let cg = ui.cgImage {
                        await leggi([cg])
                    }
                }
            }
        }
    }

    private func leggi(_ immagini: [CGImage]) async {
        guard !immagini.isEmpty else { return }
        withAnimation { leggendo = true; trovato = nil }
        let testo = await LettoreCertificato.testo(immagini)
        let esito = LettoreCertificato.cerca(in: testo)
        withAnimation(.spring) { leggendo = false; trovato = esito }
    }

    @ViewBuilder
    private func risultato(_ t: LettoreCertificato.Trovato) -> some View {
        if t.codici.isEmpty && t.partitaIVA == nil {
            Avviso(testo: "Non ho trovato codici ATECO. Prova con una foto più dritta e ben illuminata, oppure cerca il tuo lavoro a mano.")
        }
        if let p = t.partitaIVA {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.seal.fill").foregroundStyle(Theme.menta)
                Text("Partita IVA \(p): corretta").font(.app(15, .semibold))
            }
            .scheda(padding: 14)
        }
        if let amb = daScegliere {
            VStack(alignment: .leading, spacing: 10) {
                Text("Il codice \(amb.codice) del 2025 corrisponde a più attività di prima. Quale fai?").font(.app(16, .bold))
                ForEach(amb.codici2007, id: \.self) { c in
                    Button { applica(c, piva: t.partitaIVA) } label: {
                        HStack {
                            Text(Ateco.titolo2007(c) ?? c).font(.app(15)).multilineTextAlignment(.leading)
                            Spacer()
                            Text("\(Int((Ateco.gruppo(ateco2007: c)?.coefficiente ?? 0) * 100))%").font(.app(14, .heavy)).foregroundStyle(Theme.prugna)
                        }
                        .scheda(padding: 12)
                    }
                    .buttonStyle(Molla())
                }
            }
        } else {
            ForEach(t.codici) { c in
                Button {
                    if c.ambiguo { withAnimation { daScegliere = c } } else if let c07 = c.codici2007.first { applica(c07, piva: t.partitaIVA) }
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(c.titolo).font(.app(16, .semibold)).multilineTextAlignment(.leading)
                            Text("\(c.versione.rawValue) \(c.codice)").font(.app(13)).foregroundStyle(Theme.muted)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 6) {
                            Text(c.percentuale).font(.app(14, .heavy)).foregroundStyle(Theme.prugna)
                            Text("Usa questo").font(.app(13, .bold)).foregroundStyle(Theme.suPrugna)
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(Theme.prugna, in: Capsule())
                        }
                    }
                    .scheda(padding: 14)
                }
                .buttonStyle(Molla())
            }
        }
    }

    private func applica(_ codice2007: String, piva: String?) {
        if let scelto {
            scelto(codice2007, piva)
        } else {
            store.profilo?.ateco = codice2007
            if let piva { store.profilo?.partitaIVA = piva }
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        chiudi()
    }
}

/// Lo scanner di documenti di iOS (bordi raddrizzati in automatico)
struct ScannerDocumenti: UIViewControllerRepresentable {
    let fatto: ([CGImage]) -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let vc = VNDocumentCameraViewController()
        vc.delegate = context.coordinator
        return vc
    }
    func updateUIViewController(_ vc: VNDocumentCameraViewController, context: Context) {}
    func makeCoordinator() -> Coordinatore { Coordinatore(fatto: fatto) }

    final class Coordinatore: NSObject, VNDocumentCameraViewControllerDelegate {
        let fatto: ([CGImage]) -> Void
        init(fatto: @escaping ([CGImage]) -> Void) { self.fatto = fatto }
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            fatto((0..<scan.pageCount).compactMap { scan.imageOfPage(at: $0).cgImage })
        }
        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) { fatto([]) }
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) { fatto([]) }
    }
}
