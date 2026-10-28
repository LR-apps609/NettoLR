import SwiftUI
import AVFoundation

// «La partita IVA in un minuto»: scene animate con sottotitoli e una voce che legge.
// Per ora la voce è quella italiana dell'iPhone; le voci registrate (ElevenLabs) prenderanno il suo posto
// come file audio nell'app, uno per scena, con lo stesso testo dei sottotitoli.

struct Scena {
    let illustrazione: String
    let colore: Color
    let testo: String
}

enum Video {
    static let partitaIVA: [Scena] = [
        Scena(illustrazione: "apri", colore: Theme.menta,
              testo: "Aprire la partita IVA è gratis: basta una richiesta online all'Agenzia delle Entrate, oppure un commercialista che la fa per te."),
        Scena(illustrazione: "forfettario", colore: Theme.prugna,
              testo: "Nel forfettario non conti le spese: lo Stato prende una parte fissa di quello che incassi e la considera il tuo guadagno."),
        Scena(illustrazione: "iva", colore: Theme.pensione,

              testo: "Nelle fatture non metti l'IVA. Sopra 77 euro aggiungi solo una marca da bollo da 2 euro."),
        Scena(illustrazione: "cassa", colore: Theme.lilla,
              testo: "Conta il giorno in cui ti pagano, non quello della fattura. Per questo NettoLR ti chiede: ti hanno pagato?"),
        Scena(illustrazione: "chiudi", colore: Theme.tasseTesto,
              testo: "Su quella parte paghi la pensione e una sola tassa. NettoLR mette da parte i conti per te, e ti avvisa quando pagare."),
    ]
}

struct VideoView: View {
    var scene: [Scena] = Video.partitaIVA
    @Environment(\.dismiss) private var chiudi
    @StateObject private var voce = Narratore()
    @State private var indice = 0
    @State private var avanzamento = 0.0
    @State private var conVoce = true
    @State private var inPausa = false
    @State private var giro = 0

    var body: some View {
        ZStack {
            Aurora(colori: [Theme.rosaChiaro, scene[indice].colore, Theme.brass]).ignoresSafeArea()
            VStack(spacing: 20) {
                HStack(spacing: 4) {
                    ForEach(scene.indices, id: \.self) { i in
                        GeometryReader { geo in
                            Capsule().fill(Color.white.opacity(0.25))
                                .overlay(alignment: .leading) {
                                    Capsule().fill(Color.white)
                                        .frame(width: geo.size.width * (i < indice ? 1 : i == indice ? avanzamento : 0))
                                }
                        }
                        .frame(height: 4)
                    }
                    Button { chiudi() } label: {
                        Image(systemName: "xmark").font(.app(15, .bold)).frame(width: 40, height: 40)
                    }
                    .accessibilityLabel("Chiudi")
                }
                Spacer()
                Illustrazione(guida: scene[indice].illustrazione, colore: scene[indice].colore, conFondo: false)
                    .padding(28)
                    .background(Theme.card.opacity(0.9), in: RoundedRectangle(cornerRadius: 32, style: .continuous))
                    .id(indice)
                    .transition(.asymmetric(insertion: .scale(scale: 0.8).combined(with: .opacity), removal: .opacity))
                Spacer()
                Text(scene[indice].testo.tradotto)
                    .font(.app(21, .semibold))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .id("t\(indice)")
                    .transition(.opacity)
                    .accessibilityAddTraits(.updatesFrequently)
                HStack(spacing: 14) {
                    tasto(conVoce ? "speaker.wave.2.fill" : "speaker.slash.fill", conVoce ? "Togli la voce" : "Metti la voce") {
                        conVoce.toggle()
                        if conVoce { voce.leggi(scene[indice].testo.tradotto) } else { voce.ferma() }
                    }
                    tasto("backward.fill", "Indietro") { vai(max(indice - 1, 0)) }
                    tasto(inPausa ? "play.fill" : "pause.fill", inPausa ? "Riprendi" : "Pausa", grande: true) {
                        if inPausa { vai(indice) } else { inPausa = true; voce.ferma() }
                    }
                    tasto("forward.fill", "Avanti") { vai(min(indice + 1, scene.count - 1)) }
                    tasto("arrow.counterclockwise", "Da capo") { vai(0) }
                }
            }
            .foregroundStyle(.white)
            .padding(20)
        }
        .task(id: "\(indice)-\(inPausa)-\(giro)") { await scena() }
        .onDisappear { voce.chiudi() }
        .sensoryFeedback(.selection, trigger: indice)
    }

    private func tasto(_ icona: String, _ etichetta: String, grande: Bool = false, _ azione: @escaping () -> Void) -> some View {
        Button(action: azione) {
            Image(systemName: icona)
                .font(.system(size: grande ? 24 : 17, weight: .bold))
                .frame(width: grande ? 64 : 46, height: grande ? 64 : 46)
                .background(Color.white.opacity(grande ? 0.3 : 0.16), in: Circle())
        }
        .buttonStyle(Molla())
        .accessibilityLabel(etichetta.tradotto)
    }

    private func vai(_ i: Int) {
        voce.ferma()
        inPausa = false
        withAnimation(.spring(duration: 0.5)) { indice = i }
        giro += 1
    }

    /// Una scena dura quanto la voce che la legge (o il tempo di leggerla, senza voce)
    private func scena() async {
        guard !inPausa else { return }
        let testo = scene[indice].testo.tradotto
        let durata = max(4, Double(testo.count) / 14)
        avanzamento = 0
        if conVoce { voce.leggi(testo) }
        withAnimation(.linear(duration: durata)) { avanzamento = 1 }
        try? await Task.sleep(for: .seconds(durata))
        while conVoce && voce.parla && !Task.isCancelled { try? await Task.sleep(for: .milliseconds(200)) }
        guard !Task.isCancelled, !inPausa else { return }
        try? await Task.sleep(for: .seconds(0.6))
        guard !Task.isCancelled, !inPausa else { return }
        if indice < scene.count - 1 {
            withAnimation(.spring(duration: 0.5)) { indice += 1 }
        } else {
            inPausa = true
        }
    }
}

/// La voce italiana dell'iPhone
@MainActor
final class Narratore: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    private let sintetizzatore = AVSpeechSynthesizer()
    @Published var parla = false
    /// La frase in corso: la fine di una frase interrotta non deve fermare quella nuova
    private var corrente: ObjectIdentifier?

    override init() {
        super.init()
        sintetizzatore.delegate = self
    }

    func leggi(_ testo: String) {
        ferma()
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        let frase = AVSpeechUtterance(string: testo)
        let lingua = Bundle.main.preferredLocalizations.first == "en" ? "en-GB" : "it-IT"
        frase.voice = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language == lingua }
            .max { $0.quality.rawValue < $1.quality.rawValue } ?? AVSpeechSynthesisVoice(language: lingua)

        frase.rate = AVSpeechUtteranceDefaultSpeechRate * 0.95
        parla = true
        corrente = ObjectIdentifier(frase)
        sintetizzatore.speak(frase)
    }

    func ferma() {
        corrente = nil
        sintetizzatore.stopSpeaking(at: .immediate)
        parla = false
    }

    /// Alla chiusura del video: la musica delle altre app torna al suo volume
    func chiudi() {
        ferma()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance)
        Task { @MainActor in if self.corrente == id { self.parla = false } }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance)
        Task { @MainActor in if self.corrente == id { self.parla = false } }
    }
}
