import PDFKit
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

// Le fatture in PDF o fotografate: il telefono legge il testo (PDFKit, o Vision per le foto)
// e propone importo, data, numero e cliente. La persona controlla e salva. Niente esce dal telefono.

enum LettoreFatturaFoto {
    struct Proposta: Equatable {
        var importo: Double?
        var data: Date?
        var numero: String?
        var cliente: String?
        var vuota: Bool { importo == nil && data == nil && numero == nil && cliente == nil }
    }

    /// Il testo di un PDF; se il PDF è una scansione (senza testo) legge le pagine come immagini
    static func testo(pdf url: URL) async -> String {
        guard let doc = PDFDocument(url: url) else { return "" }
        let scritto = doc.string ?? ""
        if scritto.trimmingCharacters(in: .whitespacesAndNewlines).count > 20 { return scritto }
        var immagini: [CGImage] = []
        for i in 0..<min(doc.pageCount, 4) {
            guard let pagina = doc.page(at: i) else { continue }
            let box = pagina.bounds(for: .mediaBox)
            let scala = 2000 / max(box.width, 1)
            let img = pagina.thumbnail(of: CGSize(width: box.width * scala, height: box.height * scala), for: .mediaBox)
            if let cg = img.cgImage { immagini.append(cg) }
        }
        return await LettoreCertificato.testo(immagini)
    }

    /// Cerca nel testo i dati della fattura
    static func analizza(_ testo: String) -> Proposta {
        var p = Proposta()
        let righe = testo.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        let minuscole = righe.map { $0.lowercased() }

        // Importo: la riga del totale (anche quella dopo), altrimenti la cifra più alta
        let paroleTotale = ["totale documento", "totale fattura", "totale da pagare", "netto a pagare", "totale a pagare", "importo totale", "totale"]
        cerca: for parola in paroleTotale {
            for (i, r) in minuscole.enumerated() where r.contains(parola) {
                if let v = (importi(in: righe[i]) + (i + 1 < righe.count ? importi(in: righe[i + 1]) : [])).first {
                    p.importo = v
                    break cerca
                }
            }
        }
        if p.importo == nil { p.importo = importi(in: testo).max() }

        // Data: quella vicina a «data», altrimenti la prima
        let trovate = righe.enumerated().flatMap { i, r in date(in: r).map { (i, $0) } }
        p.data = trovate.first { minuscole[$0.0].contains("data") }?.1 ?? trovate.first?.1


        // Numero: «fattura n. 12», «n° 12/2026», «numero 12»
        let numero = try? NSRegularExpression(pattern: #"(?i)(?:fattura\s*(?:n\.?|nr\.?|n°|numero)?|numero|n°|nr\.)\s*[:.]?\s*([A-Z0-9][A-Z0-9/\-_.]{0,15})"#)
        for r in righe {
            if let m = numero?.firstMatch(in: r, range: NSRange(r.startIndex..., in: r)), let g = Range(m.range(at: 1), in: r) {
                let n = String(r[g]).trimmingCharacters(in: CharacterSet(charactersIn: ".-"))
                if n.contains(where: \.isNumber) { p.numero = n; break }
            }
        }

        // Cliente: dopo «Spett.le», «Cliente:», «Destinatario»… sulla stessa riga, oppure la riga sotto
        let prefisso = try? NSRegularExpression(pattern: #"(?i)^(spett\.?\s*le|spettabile|cessionario\s*/\s*committente|cessionario|committente|destinatario|cliente|intestata a|fatturare a)\b\s*[:.]?\s*"#)
        for (i, r) in righe.enumerated() {
            guard let m = prefisso?.firstMatch(in: r, range: NSRange(r.startIndex..., in: r)), let fine = Range(m.range, in: r) else { continue }
            let resto = r[fine.upperBound...].trimmingCharacters(in: .whitespaces)
            let candidato = resto.count > 2 ? resto : (i + 1 < righe.count ? righe[i + 1] : "")
            if candidato.count > 2 && candidato.contains(where: \.isLetter) {
                p.cliente = candidato
                break
            }
        }
        return p
    }

    /// «1.234,56» «1234,56» «450.00» «€ 450» → valori. Contano solo le cifre con i centesimi o con il simbolo dell'euro:
    /// così anni, CAP, partite IVA e numeri di telefono restano fuori.
    static func importi(in testo: String) -> [Double] {
        let re = try? NSRegularExpression(pattern: #"(€\s*)?(?<![\d.,])(\d{1,3}(?:\.\d{3})+|\d+)(?:,(\d{2})|\.(\d{2}))?(?![\d.,]\d)(\s*€)?"#)
        func gruppo(_ m: NSTextCheckingResult, _ i: Int) -> String? {
            Range(m.range(at: i), in: testo).map { String(testo[$0]) }
        }
        var out: [Double] = []
        for m in re?.matches(in: testo, range: NSRange(testo.startIndex..., in: testo)) ?? [] {
            let euro = gruppo(m, 1) != nil || gruppo(m, 5) != nil
            let centesimi = gruppo(m, 3) ?? gruppo(m, 4)
            guard centesimi != nil || euro, let intero = gruppo(m, 2).map({ $0.replacingOccurrences(of: ".", with: "") }),
                  let v = Double(intero) else { continue }
            let totale = v + (Double(centesimi ?? "0") ?? 0) / 100
            if totale > 0 && totale < 1_000_000 { out.append(totale) }
        }
        return out
    }

    /// «20/10/2026», «20-10-2026», «20.10.26»
    static func date(in testo: String) -> [Date] {
        let re = try? NSRegularExpression(pattern: #"(?<!\d)(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{4}|\d{2})(?!\d)"#)
        return (re?.matches(in: testo, range: NSRange(testo.startIndex..., in: testo)) ?? []).compactMap { m in
            let parti = (1...3).compactMap { Range(m.range(at: $0), in: testo).flatMap { Int(testo[$0]) } }
            guard parti.count == 3, (1...31).contains(parti[0]), (1...12).contains(parti[1]) else { return nil }
            let anno = parti[2] < 100 ? 2000 + parti[2] : parti[2]
            guard (2000...2100).contains(anno) else { return nil }
            return Giorno.data(anno, parti[1], parti[0])
        }
    }
}

/// Il pulsante «Leggi da una foto o un PDF» del nuovo incasso: riempie i campi da controllare
struct LeggiFattura: View {
    let letta: (LettoreFatturaFoto.Proposta) -> Void
    @State private var fotoScelta: PhotosPickerItem?
    @State private var pdf = false
    @State private var scanner = false
    @State private var leggendo = false
    @State private var avviso: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Menu {
                Button { scanner = true } label: { Label("Fotografa la fattura", systemImage: "doc.viewfinder") }
                PhotosPicker(selection: $fotoScelta, matching: .images) { Label("Scegli una foto", systemImage: "photo") }
                Button { pdf = true } label: { Label("Apri un PDF", systemImage: "doc.richtext") }
            } label: {
                HStack(spacing: 10) {
                    if leggendo { ProgressView() } else { Image(systemName: "text.viewfinder") }
                    Text(leggendo ? "Leggo la fattura…" : "Leggi da una foto o un PDF")
                }
                .font(.app(16, .semibold))
                .foregroundStyle(Theme.prugna)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(Theme.prugnaSoft, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .disabled(leggendo)
            .accessibilityIdentifier("nuovo.leggi")
            if let avviso {
                Text(avviso.tradotto).font(.app(13)).foregroundStyle(Theme.muted)
            }
        }
        .fileImporter(isPresented: $pdf, allowedContentTypes: [.pdf]) { esito in
            guard case .success(let url) = esito else { return }
            Task {
                leggendo = true
                let accesso = url.startAccessingSecurityScopedResource()
                let testo = await LettoreFatturaFoto.testo(pdf: url)
                if accesso { url.stopAccessingSecurityScopedResource() }
                fine(testo)
            }
        }
        .fullScreenCover(isPresented: $scanner) {
            ScannerDocumenti { immagini in
                scanner = false
                guard !immagini.isEmpty else { return }
                Task {
                    leggendo = true
                    fine(await LettoreCertificato.testo(immagini))
                }
            }
            .ignoresSafeArea()
        }
        .onChange(of: fotoScelta) { _, voce in
            guard let voce else { return }
            Task {
                leggendo = true
                if let dati = try? await voce.loadTransferable(type: Data.self), let ui = UIImage(data: dati), let cg = ui.cgImage {
                    fine(await LettoreCertificato.testo([cg]))
                } else {
                    leggendo = false
                }
                fotoScelta = nil
            }
        }
    }

    private func fine(_ testo: String) {
        leggendo = false
        let p = LettoreFatturaFoto.analizza(testo)
        avviso = p.vuota ? "Non sono riuscito a leggere i dati: prova con una foto più nitida o scrivili tu."
                         : "Ho riempito i campi: controllali prima di salvare."
        if !p.vuota {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            letta(p)
        }
    }
}
