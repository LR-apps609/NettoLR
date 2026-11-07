import Foundation

// Gli indirizzi del sito di NettoLR (cartella sito/, pubblicata su GitHub Pages) che l'app apre.
// Apple chiede che privacy e condizioni d'uso si possano aprire dall'app, anche dalla schermata dell'abbonamento.
enum Sito {
    static let base = "https://lr-apps609.github.io/NettoLR/"
    /// In inglese le pagine stanno in sito/en/
    private static var lingua: String { Locale.current.language.languageCode?.identifier == "it" ? "" : "en/" }
    static var privacy: URL { URL(string: base + lingua + "privacy.html")! }
    static var condizioni: URL { URL(string: base + lingua + "condizioni.html")! }
    /// Le condizioni d'uso standard di Apple per le app (EULA)
    static let condizioniApple = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
}
