import Foundation
import Security

// Il portachiavi dell'iPhone: quello che ci si scrive resta anche se si cancella e si reinstalla l'app.
// Serve solo per la prova gratuita (quando è iniziata e l'ultimo giorno visto), niente dati personali.
enum Portachiavi {
    private static let servizio = "it.ledion.NettoLR.prova"

    static func data(_ chiave: String) -> Date? {
        var domanda = base(chiave)
        domanda[kSecReturnData as String] = true
        domanda[kSecMatchLimit as String] = kSecMatchLimitOne
        var risultato: AnyObject?
        guard SecItemCopyMatching(domanda as CFDictionary, &risultato) == errSecSuccess,
              let dati = risultato as? Data, let secondi = Double(String(decoding: dati, as: UTF8.self)) else { return nil }
        return Date(timeIntervalSince1970: secondi)
    }

    static func salva(_ data: Date, _ chiave: String) {
        let dati = Data(String(data.timeIntervalSince1970).utf8)
        let aggiornato = SecItemUpdate(base(chiave) as CFDictionary, [kSecValueData as String: dati] as CFDictionary)
        if aggiornato == errSecItemNotFound {
            var nuovo = base(chiave)
            nuovo[kSecValueData as String] = dati
            nuovo[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            SecItemAdd(nuovo as CFDictionary, nil)
        }
    }

    private static func base(_ chiave: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: servizio, kSecAttrAccount as String: chiave]
    }
}
