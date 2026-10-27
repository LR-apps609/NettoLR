import SwiftUI
import UIKit

// I colori di NettoLR: prugna per ciò che resta a te (il colore dell'app nella famiglia LR),
// blu per la pensione (INPS), pesca per le tasse, menta per «pagato». Ogni colore ha la sua versione scura.
// L'ottone resta il filo comune della famiglia LR: qui solo nei piccoli dettagli.

enum Theme {
    static let ground = Color(light: 0xF7F5F6, dark: 0x141013)
    static let card = Color(light: 0xFFFFFF, dark: 0x1F181E)
    static let raised = Color(light: 0xF1EDF0, dark: 0x2A2128)      // campi dentro le schede
    static let ink = Color(light: 0x1E1520, dark: 0xF0E9EE)
    static let muted = Color(light: 0x685E69, dark: 0xAA9DA8)
    static let line = Color(light: 0xE4DDE2, dark: 0x352A33)

    /// Il colore dell'app: ciò che resta a te
    static let prugna = Color(light: 0xA23E6E, dark: 0xD88BB2)
    static let prugnaSoft = Color(light: 0xF6ECF1, dark: 0x3A1C2A)
    /// Testo sopra il prugna pieno
    static let suPrugna = Color(light: 0xFFFFFF, dark: 0x21131B)
    /// Notte: i riquadri scuri in evidenza (uguali nei due temi)
    static let notte = Color(hex: 0x21131B)
    static let notteRialzo = Color(hex: 0x33202B)
    static let rosaChiaro = Color(hex: 0xD88BB2)
    static let suNotte = Color(hex: 0xE9DFE6)

    static let pensione = Color(light: 0x3A64A0, dark: 0x7EA4DD)
    static let tasse = Color(light: 0xE07A52, dark: 0xF2A07B)
    static let tasseTesto = Color(light: 0xB4532F, dark: 0xF2A07B)
    static let tasseSoft = Color(light: 0xFBE9E1, dark: 0x3A2219)
    static let pensioneSoft = Color(light: 0xE6ECF6, dark: 0x1D2A40)
    /// «Pagato», «giusto»
    static let menta = Color(light: 0x23866A, dark: 0x7CD3B0)
    static let mentaSoft = Color(light: 0xDDF1EA, dark: 0x16302A)
    static let lilla = Color(light: 0x7A5BA6, dark: 0xB9A0E0)
    static let lillaSoft = Color(light: 0xEDE6F6, dark: 0x2A2238)
    /// I colori delle iniziali dei clienti, a rotazione
    static let tavolozza: [(Color, Color)] = [(prugna, prugnaSoft), (pensione, pensioneSoft), (tasse, tasseSoft), (menta, mentaSoft), (lilla, lillaSoft)]
    static let avviso = Color(light: 0x9C3D2A, dark: 0xF09A85)
    static let avvisoSoft = Color(light: 0xF8E8E3, dark: 0x3A211B)
    static let brass = Color(light: 0xA97E3F, dark: 0xD6AA62)       // il filo della famiglia LR

    static let raggio: CGFloat = 22
}

extension Font {
    /// Testo arrotondato dell'app, che segue «Testo più grande» dell'iPhone fino a +30%
    static func app(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: min(size * 1.3, UIFontMetrics.default.scaledValue(for: size)), weight: weight, design: .rounded)
    }
    /// Numeri grandi: arrotondati, cifre della stessa larghezza
    static func cifra(_ size: CGFloat) -> Font {
        .system(size: size, weight: .heavy, design: .rounded).monospacedDigit()
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
    init(light: UInt32, dark: UInt32) {
        func ui(_ h: UInt32) -> UIColor {
            UIColor(red: CGFloat((h >> 16) & 0xFF) / 255, green: CGFloat((h >> 8) & 0xFF) / 255, blue: CGFloat(h & 0xFF) / 255, alpha: 1)
        }
        self.init(uiColor: UIColor { $0.userInterfaceStyle == .dark ? ui(dark) : ui(light) })
    }
}
