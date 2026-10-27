import SwiftUI

// «Tu»: chi sei, la partita IVA, il lavoro, la pensione, le preferenze. Tutto resta su questo iPhone.

struct TuView: View {
    @EnvironmentObject private var store: Store
    @State private var modifica = false
    @State private var piva = ""
    @State private var conferma = false

    var body: some View {
        NavigationStack {
            ScrollView {
                if let p = store.profilo {
                    VStack(alignment: .leading, spacing: 16) {
                        Titolo(testo: "Tu")
                        intestazione(p)
                        certificato
                        VStack(spacing: 0) {
                            Button { modifica = true } label: {
                                riga("house", Theme.prugna, "Il tuo lavoro", valore: lavoro(p), freccia: true)
                            }
                            .buttonStyle(.plain)
                            Divider().padding(.leading, 66)
                            riga("person.2", Theme.pensione, "Pensione", valore: nomePensione(p))
                            Divider().padding(.leading, 66)
                            riga("percent", Theme.tasseTesto, "Tasse", valore: tasse(p))
                            if p.gestione == .separata {
                                Divider().padding(.leading, 66)
                                interruttore("plus.forwardslash.minus", "4% INPS in fattura", acceso: Binding(
                                    get: { store.profilo?.rivalsa4 ?? false },
                                    set: { store.profilo?.rivalsa4 = $0 }))
                            }
                            Divider().padding(.leading, 66)
                            interruttore("bell", "Promemoria", acceso: Binding(
                                get: { store.profilo?.promemoria ?? true },
                                set: { store.profilo?.promemoria = $0 }))
                        }
                        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.raggio, style: .continuous))

                        HStack(spacing: 8) {
                            Image(systemName: "lock.fill")
                            Text("Tutto resta su questo iPhone")
                        }
                        .font(.app(13)).foregroundStyle(Theme.muted)
                        .frame(maxWidth: .infinity)

                        Button("Cancella tutti i dati", role: .destructive) { conferma = true }
                            .font(.app(15))
                            .frame(maxWidth: .infinity)
                        Text("NettoLR \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "") · regole \(String(Regole.attuali.anno)) · È un calcolo, non una consulenza fiscale.")
                            .font(.app(12)).foregroundStyle(Theme.muted)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 20).padding(.vertical, 12)
                }
            }
            .background(Theme.ground)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $modifica) {
                DomandeProfilo(iniziale: store.profilo) { nuovo in
                    store.profilo = nuovo
                    modifica = false
                }
            }
            .confirmationDialog("Cancellare profilo e incassi da questo iPhone?", isPresented: $conferma, titleVisibility: .visible) {
                Button("Cancella tutto", role: .destructive) { store.cancellaTutto() }
            }
            .onAppear { piva = store.profilo?.partitaIVA ?? "" }
        }
    }

    private func intestazione(_ p: Profilo) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                Text(p.nome.isEmpty ? "?" : String(p.nome.prefix(1)).uppercased())
                    .font(.app(24, .heavy)).foregroundStyle(Theme.notte)
                    .frame(width: 56, height: 56)
                    .background(Theme.rosaChiaro, in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(p.nome.isEmpty ? "Ciao" : p.nome).font(.app(20, .bold))
                    Text("\(lavoro(p)) · dal \(String(p.annoApertura))").font(.app(15)).foregroundStyle(Theme.suNotte.opacity(0.8))
                }
            }
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Partita IVA").font(.app(13)).foregroundStyle(Theme.suNotte.opacity(0.8))
                    TextField("11 cifre", text: $piva)
                        .keyboardType(.numberPad)
                        .font(.app(17, .semibold)).monospacedDigit()
                        .foregroundStyle(.white)
                        .onChange(of: piva) { _, nuova in
                            let cifre = String(nuova.filter(\.isNumber).prefix(11))
                            if cifre != nuova { piva = cifre }
                            store.profilo?.partitaIVA = cifre
                        }
                }
                Spacer()
                if piva.count == 11 {
                    let valida = PartitaIVA.valida(piva)
                    Label(valida ? "Giusta" : "Controlla", systemImage: valida ? "checkmark" : "exclamationmark.triangle")
                        .font(.app(13, .bold))
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .foregroundStyle(Theme.notte)
                        .background(valida ? Theme.rosaChiaro : Color(hex: 0xF09A85), in: Capsule())
                }
            }
            .padding(14)
            .background(Theme.notteRialzo, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .riquadroNotte()
    }

    private var certificato: some View {
        HStack(spacing: 14) {
            Image(systemName: "doc.viewfinder").font(.system(size: 28)).foregroundStyle(Theme.prugna)
                .frame(width: 52, height: 60)
                .background(Theme.prugnaSoft, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text("Fotografa il certificato").font(.app(17, .bold))
                Text("Leggerò io il tuo codice di attività · in arrivo").font(.app(14)).foregroundStyle(Theme.muted)
            }
            Spacer()
        }
        .padding(16)
        .overlay(RoundedRectangle(cornerRadius: Theme.raggio, style: .continuous).strokeBorder(Theme.line, style: StrokeStyle(lineWidth: 2, dash: [6, 5])))
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.raggio, style: .continuous))
    }

    private func riga(_ icona: String, _ colore: Color, _ titolo: String, valore: String, freccia: Bool = false) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icona).font(.system(size: 17, weight: .semibold)).foregroundStyle(colore)
                .frame(width: 36, height: 36)
                .background(colore.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            Text(titolo).font(.app(16, .semibold))
            Spacer()
            Text(valore).font(.app(15)).foregroundStyle(Theme.muted).lineLimit(1)
            if freccia { Image(systemName: "chevron.right").font(.app(13)).foregroundStyle(Theme.muted) }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    private func interruttore(_ icona: String, _ titolo: String, acceso: Binding<Bool>) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icona).font(.system(size: 17, weight: .semibold)).foregroundStyle(Theme.prugna)
                .frame(width: 36, height: 36)
                .background(Theme.prugnaSoft, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            Toggle(titolo, isOn: acceso).font(.app(16, .semibold)).tint(Theme.prugna)
        }
        .padding(.horizontal, 16).padding(.vertical, 8)
    }

    private func lavoro(_ p: Profilo) -> String {
        if let a = Ateco.attivita.first(where: { $0.ateco2007 == p.ateco }) { return DomandeProfilo.nomeSemplice(a) }
        return Ateco.gruppo(ateco2007: p.ateco)?.nome ?? p.ateco
    }

    private func nomePensione(_ p: Profilo) -> String {
        switch p.gestione {
        case .separata: "INPS"
        case .artigiani: "INPS artigiani"
        case .commercianti: "INPS commercianti"
        case .cassa: "La tua cassa"
        }
    }

    private func tasse(_ p: Profilo) -> String {
        if let ultimo = Calcolo.ultimoAnnoStartup(p), ultimo >= store.anno { return "5% fino al \(ultimo)" }
        return "15%"
    }
}

enum PartitaIVA {
    /// Controlla la cifra finale di una partita IVA italiana (11 cifre)
    static func valida(_ s: String) -> Bool {
        let c = s.compactMap(\.wholeNumberValue)
        guard c.count == 11 else { return false }
        var somma = 0
        for i in 0..<10 {
            if i % 2 == 0 {
                somma += c[i]
            } else {
                let d = c[i] * 2
                somma += d > 9 ? d - 9 : d
            }
        }
        return (10 - somma % 10) % 10 == c[10]
    }
}
