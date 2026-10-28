import SwiftUI

// «Manda al commercialista»: un PDF con il riepilogo dell'anno e un file per Excel con gli incassi.
// I file si creano sul telefono e si condividono con il foglio di iOS (Mail, WhatsApp, AirDrop…).

enum Esporta {
    /// Incassi in CSV per Excel italiano: «;» come separatore, virgola nei decimali, BOM per gli accenti
    static func csv(_ fatture: [Fattura]) -> String {
        let righe = fatture.sorted { $0.data < $1.data }.map { f -> String in
            let incasso = f.dataIncasso.map(Formato.dataCorta) ?? ""
            let importo = String(format: "%.2f", f.importo).replacingOccurrences(of: ".", with: ",")
            let cliente = "\"" + f.cliente.replacingOccurrences(of: "\"", with: "\"\"") + "\""
            return [f.numero, Formato.dataCorta(f.data), cliente, importo, f.incassata ? "sì" : "no", incasso].joined(separator: ";")
        }
        return "\u{FEFF}" + (["Numero;Data fattura;Cliente;Importo;Incassata;Data incasso"] + righe).joined(separator: "\r\n")
    }

    @MainActor
    static func file(_ store: Store) -> [URL] {
        let cartella = URL.temporaryDirectory.appending(path: "NettoLR-\(store.anno)")
        try? FileManager.default.createDirectory(at: cartella, withIntermediateDirectories: true)
        var out: [URL] = []

        let csvURL = cartella.appending(path: "Incassi \(store.anno).csv")
        if (try? csv(store.fatture).write(to: csvURL, atomically: true, encoding: .utf8)) != nil { out.append(csvURL) }

        let pdfURL = cartella.appending(path: "NettoLR riepilogo \(store.anno).pdf")
        let renderer = ImageRenderer(content: RiepilogoPDF(store: store).environment(\.colorScheme, .light))
        renderer.proposedSize = .init(width: 595, height: nil)
        renderer.render { size, disegna in
            var riquadro = CGRect(origin: .zero, size: size)
            guard let pdf = CGContext(pdfURL as CFURL, mediaBox: &riquadro, nil) else { return }
            pdf.beginPDFPage(nil)
            disegna(pdf)
            pdf.endPDFPage()
            pdf.closePDF()
        }
        if FileManager.default.fileExists(atPath: pdfURL.path) { out.append(pdfURL) }
        return out
    }
}

/// La pagina del PDF: chi, il calcolo, gli incassi, i pagamenti
struct RiepilogoPDF: View {
    let store: Store

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Marca().frame(width: 36, height: 36)
                Text("NettoLR · riepilogo \(String(store.anno))").font(.system(size: 20, weight: .bold))
                Spacer()
                Text(Formato.dataCorta(Date())).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            if let p = store.profilo {
                VStack(alignment: .leading, spacing: 3) {
                    if !p.nome.isEmpty { Text(p.nome).font(.system(size: 13, weight: .semibold)) }
                    if !p.partitaIVA.isEmpty { Text("Partita IVA \(p.partitaIVA)").font(.system(size: 11)) }
                    Text("\(Ateco.nomeLavoro(p.ateco)) · ATECO 2007 \(p.ateco)").font(.system(size: 11))
                    Text("Pensione: \(p.gestione.nome) · aperta nel \(String(p.annoApertura))").font(.system(size: 11))
                }
            }
            if let res = store.risultato {
                sezione("Il calcolo (regime forfettario)")
                ForEach(res.righe) { r in
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(r.etichetta.tradotto).font(.system(size: 11, weight: .semibold))
                            Text(r.formula.tradotto).font(.system(size: 9)).foregroundStyle(.secondary)

                        }
                        Spacer()
                        Text(Formato.euro(r.importo)).font(.system(size: 11).monospacedDigit())
                    }
                }
            }
            sezione("Incassi")
            ForEach(store.fatture.sorted { $0.data < $1.data }) { f in
                HStack {
                    Text(Formato.dataCorta(f.dataIncasso ?? f.data)).frame(width: 70, alignment: .leading)
                    Text(f.cliente).lineLimit(1)
                    Spacer()
                    Text((f.incassata ? "incassata" : "da incassare").tradotto).foregroundStyle(.secondary)
                    Text(Formato.euro(f.importo)).monospacedDigit().frame(width: 90, alignment: .trailing)
                }
                .font(.system(size: 10))
            }
            sezione("Pagamenti \(String(store.anno))")
            ForEach(store.pagamenti) { p in
                HStack(alignment: .top) {
                    Text(Formato.dataCorta(p.data)).frame(width: 70, alignment: .leading)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(p.titolo)
                        Text(p.codice).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text((store.pagati[p.id] != nil ? "pagato" : "").tradotto).foregroundStyle(.secondary)

                    Text(Formato.euro(p.importo)).monospacedDigit().frame(width: 90, alignment: .trailing)
                }
                .font(.system(size: 10))
            }
            Text("Calcolo fatto con NettoLR, non una consulenza fiscale. Regole aggiornate al \(Formato.dataCorta(Giorno.da(Regole.attuali.aggiornatoAl))).")
                .font(.system(size: 9)).foregroundStyle(.secondary)
                .padding(.top, 8)
        }
        .padding(36)
        .frame(width: 595, alignment: .leading)
        .background(Color.white)
        .foregroundStyle(Color.black)
    }

    private func sezione(_ t: String) -> some View {
        Text(t.tradotto).font(.system(size: 13, weight: .bold)).padding(.top, 6)
    }
}

/// Il foglio «Manda al commercialista»
struct EsportaView: View {
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var chiudi
    @State private var file: [URL] = []

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Text("Prepariamo due file da mandare a chi ti segue la contabilità.").font(.app(17))
                voce("doc.richtext", Theme.prugna, String(localized: "Riepilogo \(String(store.anno)) in PDF"), "Il calcolo riga per riga, gli incassi, i pagamenti")
                voce("tablecells", Theme.menta, "Incassi per Excel", "Un file .csv che si apre con Excel o Numbers")
                Spacer()
                if file.isEmpty {
                    ProgressView().frame(maxWidth: .infinity)
                } else {
                    ShareLink(items: file) { Label("Manda", systemImage: "square.and.arrow.up") }
                        .buttonStyle(PulsantePieno())
                }
            }
            .padding(20)
            .background(Theme.ground)
            .navigationTitle("Per il commercialista")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Chiudi") { chiudi() } } }
            .task { file = Esporta.file(store) }
        }
        .presentationDetents([.medium, .large])
    }

    private func voce(_ icona: String, _ colore: Color, _ titolo: String, _ sotto: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icona).font(.app(20)).foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(colore, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(titolo.tradotto).font(.app(16, .semibold))
                Text(sotto.tradotto).font(.app(13)).foregroundStyle(Theme.muted)
            }
        }
        .scheda(padding: 14)
    }
}
