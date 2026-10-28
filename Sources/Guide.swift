import SwiftUI

// Le guide in parole semplici e il test «Posso aprire il forfettario?».
// Testi da far rileggere al commercialista prima del lancio.

struct Guida: Identifiable {
    let id: String
    let titolo: String
    let icona: String
    let colore: Color
    let fondo: Color
    /// Passi numerati (guide pratiche) o paragrafi (spiegazioni)
    let passi: [String]
    let numerata: Bool
}

enum Guide {
    static let tutte: [Guida] = [
        Guida(id: "apri", titolo: "Aprire la partita IVA in 7 passi", icona: "door.left.hand.open", colore: Theme.menta, fondo: Theme.mentaSoft, passi: [
            "Trova il tuo codice ATECO: cerca il tuo lavoro in NettoLR, ti mostra anche la percentuale.",
            "Fai il test «Posso aprire il forfettario?» qui sotto.",
            "Compila la richiesta di apertura (modello AA9/12) sul sito dell'Agenzia delle Entrate con SPID o CIE, oppure falla fare a un commercialista o a un CAF. Scegli il regime forfettario.",
            "Pensione: se sei un libero professionista ti iscrivi alla Gestione Separata INPS online. Se sei artigiano o commerciante passi dalla Camera di Commercio (ComUnica) e, se serve, dal Comune.",
            "Attiva la PEC, la posta certificata: per le imprese e gli iscritti a un albo è obbligatoria.",
            "Scegli come fare le fatture elettroniche: va bene anche il programma gratuito dell'Agenzia delle Entrate.",
            "Apri un conto dedicato al lavoro: non è obbligatorio, ma ti aiuta a tenere separati i soldi delle tasse.",
        ], numerata: true),
        Guida(id: "chiudi", titolo: "Chiudere la partita IVA", icona: "door.right.hand.closed", colore: Theme.tasseTesto, fondo: Theme.tasseSoft, passi: [
            "Fai e incassa le ultime fatture.",
            "Entro 30 giorni dalla fine dell'attività comunica la chiusura (modello AA9/12, o ComUnica se sei iscritto alla Camera di Commercio).",
            "Se sei artigiano o commerciante chiudi anche la posizione INPS (passa da ComUnica). In Gestione Separata non serve nulla.",
            "L'anno dopo paghi il saldo di tasse e pensione e fai l'ultima dichiarazione dei redditi.",
            "Conserva fatture e ricevute per almeno 10 anni.",
        ], numerata: true),
        Guida(id: "forfettario", titolo: "Il forfettario in 2 minuti", icona: "sparkles", colore: Theme.prugna, fondo: Theme.prugnaSoft, passi: [
            "Nel forfettario non si contano le spese vere: lo Stato considera tuo reddito una percentuale fissa di quello che incassi, che dipende dal codice ATECO (dal 40% all'86%).",
            "Su quel reddito paghi la pensione (INPS). Togli i contributi che hai versato nell'anno e sul resto paghi un'unica tassa: il 15%, o il 5% per i primi cinque anni se è la tua prima attività.",
            "Niente IRPEF, niente addizionali, niente IVA, finché incassi meno di 85.000 € all'anno.",
        ], numerata: false),
        Guida(id: "iva", titolo: "Perché non metto l'IVA in fattura", icona: "percent", colore: Theme.pensione, fondo: Theme.pensioneSoft, passi: [
            "Chi è nel forfettario non aggiunge l'IVA alle fatture e non la recupera sugli acquisti.",
            "In fattura si scrive che l'operazione è fatta «ai sensi dell'art. 1, commi 54-89, della Legge 190/2014».",
            "Sopra 77,47 € serve la marca da bollo da 2 €: NettoLR la conta da sola e te la ricorda ogni trimestre.",
        ], numerata: false),
        Guida(id: "cassa", titolo: "Conta quando ti pagano", icona: "calendar.badge.clock", colore: Theme.lilla, fondo: Theme.lillaSoft, passi: [
            "Una fattura fatta a dicembre e pagata a gennaio conta per l'anno nuovo.",
            "Per questo NettoLR ti chiede «Ti hanno pagato?»: solo gli incassi veri entrano nei calcoli e nella soglia di 85.000 €.",
        ], numerata: false),
    ]
}

/// L'elenco delle guide, con il test in cima
struct GuideView: View {
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var chiudi
    @State private var test = false
    @State private var video = false
    @State private var aperta: String? = "apri"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Button { test = true } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "checklist").font(.system(size: 26, weight: .bold)).foregroundStyle(Theme.notte)
                                .frame(width: 54, height: 54)
                                .background(Theme.rosaChiaro, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Posso aprire il forfettario?").font(.app(18, .bold))
                                Text("7 domande, un minuto").font(.app(14)).foregroundStyle(Theme.suNotte.opacity(0.8))
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .riquadroNotte()
                    }
                    .buttonStyle(Molla())
                    .entrata(0)
                    .accessibilityIdentifier("guide.test")

                    Button { video = true } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "play.fill").font(.system(size: 22, weight: .bold)).foregroundStyle(.white)
                                .frame(width: 54, height: 54)
                                .background(Theme.prugna, in: Circle())
                            VStack(alignment: .leading, spacing: 2) {
                                Text("La partita IVA in un minuto").font(.app(18, .bold)).foregroundStyle(Theme.ink)
                                Text("Guarda e ascolta").font(.app(14)).foregroundStyle(Theme.muted)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(Theme.prugna)
                        }
                        .padding(16)
                        .background(Theme.prugnaSoft, in: RoundedRectangle(cornerRadius: Theme.raggio, style: .continuous))
                    }
                    .buttonStyle(Molla())
                    .entrata(1)
                    .accessibilityIdentifier("guide.video")

                    ForEach(Array(Guide.tutte.enumerated()), id: \.element.id) { i, g in
                        scheda(g).entrata(i + 2)
                    }
                    Text("È una guida, non una consulenza: per i casi particolari senti un commercialista.")
                        .font(.app(13)).foregroundStyle(Theme.muted)
                }
                .padding(20)
            }
            .background(Theme.ground)
            .navigationTitle("Guide")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fatto") { chiudi() } } }
            .fullScreenCover(isPresented: $test) { TestForfettarioView() }
            .fullScreenCover(isPresented: $video) { VideoView() }
        }
    }

    private func scheda(_ g: Guida) -> some View {
        let open = aperta == g.id
        return VStack(alignment: .leading, spacing: 12) {
            Button { withAnimation(.spring(duration: 0.35)) { aperta = open ? nil : g.id } } label: {
                HStack(spacing: 12) {
                    Image(systemName: g.icona).font(.system(size: 18, weight: .bold)).foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(g.colore, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    Text(g.titolo.tradotto).font(.app(17, .bold)).foregroundStyle(Theme.ink).multilineTextAlignment(.leading)
                    Spacer()
                    Image(systemName: "chevron.down").rotationEffect(.degrees(open ? 180 : 0)).foregroundStyle(g.colore)
                }
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(.isHeader)
            if open {
                VStack(alignment: .leading, spacing: 12) {
                    Illustrazione(guida: g.id, colore: g.colore, coefficiente: store.risultato?.coefficiente)
                    ForEach(Array(g.passi.enumerated()), id: \.offset) { i, p in
                        HStack(alignment: .top, spacing: 12) {
                            if g.numerata {
                                Text("\(i + 1)").font(.app(14, .heavy)).foregroundStyle(g.colore)
                                    .frame(width: 26, height: 26)
                                    .background(Theme.card, in: Circle())
                            }
                            Text(p.tradotto).font(.app(16)).fixedSize(horizontal: false, vertical: true)

                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(16)
        .background(g.fondo, in: RoundedRectangle(cornerRadius: Theme.raggio, style: .continuous))
    }
}

/// «Posso aprire il forfettario?»: sette domande sì/no, poi l'esito
struct TestForfettarioView: View {
    struct Domanda {
        let testo: String
        let aiuto: String
        /// La risposta che va bene per il forfettario
        let giusta: Bool
        let problema: String
    }

    static let domande: [Domanda] = [
        Domanda(testo: "Pensi di incassare meno di 85.000 € all'anno?", aiuto: "Conta quello che ti pagano davvero in un anno.", giusta: true,
                problema: "Sopra 85.000 € di incassi all'anno non si può stare nel forfettario."),
        Domanda(testo: "Hai uno stipendio o una pensione sopra 35.000 € all'anno?", aiuto: "Lordo, dell'anno scorso. Non conta se quel lavoro è già finito.", giusta: false,
                problema: "Con più di 35.000 € da lavoro dipendente o pensione non si può aprire il forfettario."),
        Domanda(testo: "Hai quote in una società di persone, un'associazione professionale o un'impresa familiare?", aiuto: "Per esempio una snc, una sas o uno studio associato.", giusta: false,
                problema: "Chi ha quote in società di persone o associazioni professionali non può stare nel forfettario."),
        Domanda(testo: "Controlli una SRL che fa lo stesso lavoro che faresti tu?", aiuto: "Se la SRL fa cose diverse, rispondi no.", giusta: false,
                problema: "Chi controlla una SRL con attività simili non può stare nel forfettario."),
        Domanda(testo: "Lavoreresti soprattutto per chi ti ha fatto da datore di lavoro negli ultimi 2 anni?", aiuto: "Anche tramite società collegate.", giusta: false,
                problema: "Se fatturi soprattutto all'ex datore di lavoro degli ultimi due anni il forfettario non è ammesso."),
        Domanda(testo: "Spenderai più di 20.000 € all'anno per dipendenti o collaboratori?", aiuto: "Stipendi, collaboratori, lavoro accessorio.", giusta: false,
                problema: "Sopra 20.000 € di spese per lavoratori non si può stare nel forfettario."),
        Domanda(testo: "Vivi in Italia?", aiuto: "Se vivi in un altro paese UE e guadagni in Italia almeno il 75%, rispondi sì.", giusta: true,
                problema: "Il forfettario è per chi risiede in Italia (o in UE con quasi tutti i redditi in Italia)."),
    ]

    @Environment(\.dismiss) private var chiudi
    @State private var passo = 0
    @State private var risposte: [Bool] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                HStack(spacing: 4) {
                    ForEach(0..<Self.domande.count, id: \.self) { i in
                        Capsule().fill(i < risposte.count ? Theme.prugna : Theme.line).frame(height: 5)
                    }
                }
                Button { chiudi() } label: {
                    Image(systemName: "xmark").font(.app(16, .bold)).foregroundStyle(Theme.ink)
                        .frame(width: 44, height: 44).background(Theme.prugnaSoft, in: Circle())
                }
                .accessibilityLabel("Chiudi")
            }
            if risposte.count < Self.domande.count {
                let d = Self.domande[risposte.count]
                VStack(alignment: .leading, spacing: 14) {
                    Text("Domanda \(risposte.count + 1) di \(Self.domande.count)").font(.app(14, .semibold)).foregroundStyle(Theme.muted)
                    Text(d.testo.tradotto).font(.system(size: 30, weight: .heavy, design: .rounded)).fixedSize(horizontal: false, vertical: true)
                    Text(d.aiuto.tradotto).font(.app(16)).foregroundStyle(Theme.muted)
                }
                .id(risposte.count)
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
                Spacer()
                HStack(spacing: 12) {
                    Button("Sì") { rispondi(true) }.buttonStyle(PulsantePieno())
                    Button("No") { rispondi(false) }.buttonStyle(PulsantePieno(colore: Theme.notte, testo: .white))
                }
            } else {
                esito
                Spacer()
                Button("Ho capito") { chiudi() }.buttonStyle(PulsantePieno())
            }
        }
        .padding(20)
        .background(Theme.ground.ignoresSafeArea())
        .foregroundStyle(Theme.ink)
        .sensoryFeedback(.selection, trigger: risposte.count)
    }

    private func rispondi(_ r: Bool) {
        withAnimation(.spring(duration: 0.4)) { risposte.append(r) }
    }

    private var problemi: [String] {
        zip(Self.domande, risposte).filter { $0.0.giusta != $0.1 }.map(\.0.problema)
    }

    @ViewBuilder
    private var esito: some View {
        if problemi.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: "checkmark.seal.fill").font(.system(size: 56)).foregroundStyle(Theme.menta)
                    .symbolEffect(.bounce, value: risposte.count)
                Text("Sì, da quello che mi dici puoi aprire il forfettario.").font(.system(size: 28, weight: .heavy, design: .rounded))
                Text("Se è la tua prima attività in proprio, per cinque anni le tasse sono al 5% invece del 15%.").font(.app(17))
            }
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 52)).foregroundStyle(Theme.tasse)
                Text("Probabilmente il forfettario non fa per te.").font(.system(size: 28, weight: .heavy, design: .rounded))
                ForEach(problemi, id: \.self) { Avviso(testo: $0) }
                Text("Parlane con un commercialista: ci sono casi particolari.").font(.app(15)).foregroundStyle(Theme.muted)
            }
        }
    }
}
