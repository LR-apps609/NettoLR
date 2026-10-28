import SwiftUI

// «Prova»: il cursore «e se incassassi altri…» e tre domande con una risposta secca.

struct ProvaView: View {
    @EnvironmentObject private var store: Store
    @State private var extra: Double = 1_000
    @State private var domanda: Domanda?

    enum Domanda: String, Identifiable {
        case conviene, obiettivo, dipendente
        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if let p = store.profilo {
                    let s = Calcolo.seFatturoAncora(p, anno: store.anno, ricaviAttuali: store.riepilogo.ricavi, extra: extra)
                    let dopo = Calcolo.forfettario(p, anno: store.anno, ricavi: store.riepilogo.ricavi + extra)
                    let prima = Calcolo.forfettario(p, anno: store.anno, ricavi: store.riepilogo.ricavi)
                    VStack(alignment: .leading, spacing: 18) {
                        Titolo(testo: "Prova")
                        VStack(alignment: .leading, spacing: 14) {
                            Text("E se incassassi altri…").font(.app(18, .semibold))
                            Text(Formato.euroTondo(extra)).font(.cifra(40)).contentTransition(.numericText(value: extra))
                            Slider(value: $extra, in: 0...20_000, step: 100)
                                .tint(Theme.prugna)
                                .accessibilityIdentifier("prova.cursore")
                                .sensoryFeedback(.selection, trigger: Int(extra / 1_000))
                            Divider()
                            Text("te ne restano").font(.app(16)).foregroundStyle(Theme.muted)
                            Text(Formato.euroTondo(s.nettoExtra)).font(.cifra(52)).foregroundStyle(Theme.prugna)
                                .contentTransition(.numericText(value: s.nettoExtra))
                                .scaleEffect(1 + min(extra, 20_000) / 200_000, anchor: .leading)
                            GeometryReader { geo in
                                let pensione = dopo.contributi - prima.contributi
                                let tot = max(extra, 1)
                                HStack(spacing: 3) {
                                    Theme.prugna.frame(width: max(0, geo.size.width * s.nettoExtra / tot - 3))
                                    Theme.pensione.frame(width: max(0, geo.size.width * pensione / tot - 3))
                                    Theme.tasse
                                }
                                .clipShape(Capsule())
                            }
                            .frame(height: 16)
                            HStack {
                                Text("Pensione \(Formato.euroTondo(dopo.contributi - prima.contributi))")
                                Spacer()
                                Text("Tasse \(Formato.euroTondo(dopo.imposta - prima.imposta))")
                            }
                            .font(.app(14)).foregroundStyle(Theme.muted)
                            if s.superaUscitaImmediata {
                                Avviso(testo: "Così superi 100.000 €: esci subito dal forfettario. Senti un commercialista prima.")
                            } else if s.superaSoglia {
                                Avviso(testo: "Così superi 85.000 €: dal prossimo anno cambi regime.")
                            }
                        }
                        .scheda(padding: 22)
                        .animation(.easeOut(duration: 0.2), value: extra)

                        voce(.conviene, "Mi conviene il forfettario?", "scalemass.fill", Theme.prugna, Theme.prugnaSoft).entrata(1)
                        voce(.obiettivo, "Quanto devo fatturare?", "target", Theme.tasseTesto, Theme.tasseSoft).entrata(2)
                        voce(.dipendente, "E se fossi dipendente?", "briefcase.fill", Theme.pensione, Theme.pensioneSoft).entrata(3)
                    }
                    .padding(.horizontal, 20).padding(.vertical, 12)
                }
            }
            .background(Theme.ground)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $domanda) { d in
                switch d {
                case .conviene: ConvieneView()
                case .obiettivo: ObiettivoView()
                case .dipendente: DipendenteView()
                }
            }
        }
    }

    private func voce(_ d: Domanda, _ testo: String, _ icona: String, _ colore: Color, _ fondo: Color) -> some View {
        Button { domanda = d } label: {
            HStack(spacing: 14) {
                Image(systemName: icona).font(.system(size: 20, weight: .semibold)).foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(colore, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                Text(testo.tradotto).font(.app(17, .bold)).foregroundStyle(Theme.ink)
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(colore)
            }
            .padding(14)
            .background(fondo, in: RoundedRectangle(cornerRadius: Theme.raggio, style: .continuous))
        }
        .buttonStyle(Molla())
        .accessibilityIdentifier("prova.\(d.rawValue)")
    }
}

/// Una risposta grande in un riquadro scuro
struct RispostaSecca: View {
    let sopra: String
    let grande: String
    let sotto: String
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(sopra.tradotto).font(.app(15, .semibold)).foregroundStyle(Theme.rosaChiaro)
            Text(grande).font(.cifra(30)).minimumScaleFactor(0.6).lineLimit(1)
            Text(sotto.tradotto).font(.app(15)).foregroundStyle(Theme.suNotte.opacity(0.85))
        }
        .riquadroNotte()
    }
}

/// Struttura comune dei fogli di «Prova»
struct FoglioProva<Contenuto: View>: View {
    let titolo: String
    @ViewBuilder let contenuto: () -> Contenuto
    @Environment(\.dismiss) private var chiudi
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) { contenuto() }.padding(20)
            }
            .background(Theme.ground)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(titolo.tradotto)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fatto") { chiudi() } } }
        }
        .presentationDetents([.large])
    }
}

/// 22 · Forfettario o regime normale, con le spese vere
struct ConvieneView: View {
    @EnvironmentObject private var store: Store
    @State private var incasso = ""
    @State private var spese = "3000"

    var body: some View {
        FoglioProva(titolo: "Mi conviene?") {
            if let p = store.profilo {
                let ricavi = Formato.leggiEuro(incasso) > 0 ? Formato.leggiEuro(incasso) : max(store.riepilogo.ricavi, 30_000)
                let costi = Formato.leggiEuro(spese)
                let forf = Calcolo.forfettario(p, anno: store.anno, ricavi: ricavi).netto - costi
                let ord = Calcolo.ordinario(p, ricavi: ricavi, costi: costi, r: store.regole)
                let diff = forf - ord.netto
                CampoEuro(etichetta: "Quanto incassi in un anno", testo: $incasso, segnaposto: Formato.campo(ricavi))
                CampoEuro(etichetta: "Quanto spendi per lavorare (computer, affitto, auto…)", testo: $spese)
                if abs(diff) < 50 {
                    RispostaSecca(sopra: "È uguale", grande: "± \(Formato.euroTondo(abs(diff)))", sotto: "I due regimi si equivalgono.")
                } else if diff > 0 {
                    RispostaSecca(sopra: "Sì, per te conviene", grande: String(localized: "+\(Formato.euroTondo(diff)) all'anno"), sotto: "rispetto al regime normale, con queste spese.")
                } else {
                    RispostaSecca(sopra: "Con queste spese conviene il regime normale", grande: String(localized: "+\(Formato.euroTondo(-diff)) all'anno"), sotto: "Parlane con un commercialista prima di cambiare.")
                }
                Text("Nel forfettario le spese non si scaricano: c'è una percentuale fissa. Nel regime normale sì. Stima semplificata, senza IVA e senza detrazioni personali.")
                    .font(.app(14)).foregroundStyle(Theme.muted)
            }
        }
    }
}

/// 18 e 19 · Quanto fatturare per un netto al mese, e la tariffa oraria minima
struct ObiettivoView: View {
    @EnvironmentObject private var store: Store
    @State private var mensile = "2000"
    @State private var ore = "30"

    var body: some View {
        FoglioProva(titolo: "Il tuo obiettivo") {
            if let p = store.profilo {
                let netto = Formato.leggiEuro(mensile)
                let lordo = Calcolo.incassoPerNetto(p, anno: store.anno, netto: netto * 12)
                let oreAnno = Formato.leggiEuro(ore) * 46          // 46 settimane di lavoro
                CampoEuro(etichetta: "Quanto vuoi che ti resti al mese", testo: $mensile)
                RispostaSecca(sopra: "Devi incassare", grande: String(localized: "\(Formato.euroTondo(lordo / 12)) al mese"),
                              sotto: String(localized: "cioè \(Formato.euroTondo(lordo)) in un anno."))
                VStack(alignment: .leading, spacing: 6) {
                    Text("Quante ore a settimana fatturi davvero?").font(.app(14)).foregroundStyle(Theme.muted)
                    TextField("30", text: $ore).keyboardType(.numberPad).font(.app(20, .semibold))
                        .padding(.horizontal, 14).frame(height: 50)
                        .background(Theme.raised, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                if oreAnno > 0 {
                    RispostaSecca(sopra: "Chiedi almeno", grande: String(localized: "\(Formato.euroTondo((lordo / oreAnno).rounded(.up))) l'ora"),
                                  sotto: "contando 46 settimane di lavoro all'anno.")
                }
                if lordo > store.regole.forfettario.sogliaRicavi.valore {
                    Avviso(testo: "Serve più di 85.000 € all'anno: con questo obiettivo usciresti dal forfettario.")
                }
            }
        }
    }
}

/// 20 · Partita IVA o lavoro da dipendente
struct DipendenteView: View {
    @EnvironmentObject private var store: Store

    var body: some View {
        FoglioProva(titolo: "E se fossi dipendente?") {
            if let res = store.risultato {
                let ral = Calcolo.ralEquivalente(netto: res.netto)
                Text("Con la partita IVA quest'anno ti restano \(Formato.euroTondo(res.netto)).").font(.app(17))
                RispostaSecca(sopra: "Da dipendente ti servirebbe uno stipendio lordo di", grande: String(localized: "\(Formato.euroTondo(ral)) all'anno"),
                              sotto: String(localized: "circa \(Formato.euroTondo(ral / 13)) lordi al mese, su 13 mensilità."))
                Text("Il dipendente ha anche ferie pagate, malattia e TFR, che qui non sono contati. Stima semplificata.")
                    .font(.app(14)).foregroundStyle(Theme.muted)
            }
        }
    }
}
