import SwiftUI
import UniformTypeIdentifiers

// La copia di sicurezza: un file con tutti i dati, da tenere in iCloud Drive o in File
// (la sincronizzazione automatica con iCloud arriverà con l'account sviluppatore Apple).

struct FileCopia: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var dati: Data
    init(dati: Data) { self.dati = dati }
    init(configuration: ReadConfiguration) throws { dati = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: dati) }
}

struct BackupView: View {
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var chiudi
    @State private var salva = false
    @State private var apri = false
    @State private var documento: FileCopia?
    @State private var esito: (ok: Bool, testo: String)?
    @State private var conferma: Data?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Salva una copia di profilo, incassi, pagamenti e ricevute. Mettila in iCloud Drive: se cambi telefono la ritrovi.")
                        .font(.app(17))
                    Button {
                        if let d = try? store.copiaDiSicurezza() { documento = FileCopia(dati: d); salva = true }
                    } label: { Label("Salva una copia", systemImage: "icloud.and.arrow.up") }
                    .buttonStyle(PulsantePieno())
                    Button { apri = true } label: { Label("Ripristina da una copia", systemImage: "icloud.and.arrow.down") }
                        .buttonStyle(PulsanteBordo())
                    if let esito {
                        Label(esito.testo, systemImage: esito.ok ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .font(.app(15, .semibold)).foregroundStyle(esito.ok ? Theme.menta : Theme.avviso)
                    }
                    if conferma != nil {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Il ripristino sostituisce i dati che hai adesso su questo iPhone. Vuoi continuare?").font(.app(15, .semibold))
                            HStack {
                                Button("Sì, ripristina") { ripristina() }.buttonStyle(PulsantePieno())
                                Button("Annulla") { conferma = nil }.buttonStyle(PulsanteBordo())
                            }
                        }
                        .scheda(padding: 14)
                    }
                    Text("La copia contiene i tuoi dati: tienila in un posto sicuro. iCloud Drive la protegge con il tuo Apple ID.")
                        .font(.app(13)).foregroundStyle(Theme.muted)
                }
                .padding(20)
            }
            .background(Theme.ground)
            .navigationTitle("Copia di sicurezza")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fatto") { chiudi() } } }
            .fileExporter(isPresented: $salva, document: documento, contentType: .json,
                          defaultFilename: "NettoLR copia \(Formato.dataCorta(Date()).replacingOccurrences(of: "/", with: "-"))") { r in
                if case .success = r { esito = (true, "Copia salvata.") }
            }
            .fileImporter(isPresented: $apri, allowedContentTypes: [.json]) { r in
                guard case .success(let url) = r else { return }
                let accesso = url.startAccessingSecurityScopedResource()
                defer { if accesso { url.stopAccessingSecurityScopedResource() } }
                if let d = try? Data(contentsOf: url) { withAnimation { conferma = d } } else { esito = (false, "Non riesco ad aprire il file.") }
            }
        }
    }

    private func ripristina() {
        guard let d = conferma else { return }
        do {
            try store.ripristina(d)
            esito = (true, "Dati ripristinati.")
        } catch {
            esito = (false, "Questo file non è una copia di NettoLR.")
        }
        conferma = nil
    }
}
