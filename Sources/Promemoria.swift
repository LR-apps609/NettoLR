import Foundation
import UserNotifications

// Le notifiche dei pagamenti: una settimana prima e il giorno stesso, alle 9.
// Restano sul telefono (notifiche locali): nessun server.

enum Promemoria {
    /// Ricrea tutte le notifiche dai pagamenti ancora da fare
    static func aggiorna(_ pagamenti: [Pagamento], attivi: Bool) async {
        guard !ProcessInfo.processInfo.arguments.contains(where: { $0.hasPrefix("-uitest") }) else { return }
        let centro = UNUserNotificationCenter.current()
        centro.removeAllPendingNotificationRequests()
        guard attivi, !pagamenti.isEmpty else { return }
        guard (try? await centro.requestAuthorization(options: [.alert, .sound, .badge])) == true else { return }

        let oggi = Date()
        let perGiorno = Dictionary(grouping: pagamenti) { Giorno.calendario.startOfDay(for: $0.data) }
        for (giorno, voci) in perGiorno {
            let totale = arrotonda(voci.reduce(0) { $0 + $1.importo })
            let cosa = voci.map(\.titolo).joined(separator: " · ")
            for (prima, titolo) in [(7, "Tra una settimana si paga"), (0, "Oggi si paga")] {
                guard let quando = Giorno.calendario.date(byAdding: .day, value: -prima, to: giorno),
                      let alle9 = Giorno.calendario.date(bySettingHour: 9, minute: 0, second: 0, of: quando),
                      alle9 > oggi else { continue }
                let contenuto = UNMutableNotificationContent()
                contenuto.title = "\(titolo): \(Formato.euroTondo(totale))"
                contenuto.body = prima > 0 ? "\(cosa). Tieni da parte i soldi." : "\(cosa). In NettoLR trovi i dati per l'F24."
                contenuto.sound = .default
                let quandoComponenti = Giorno.calendario.dateComponents([.year, .month, .day, .hour, .minute], from: alle9)
                let richiesta = UNNotificationRequest(
                    identifier: "pagamento-\(Int(giorno.timeIntervalSince1970))-\(prima)", content: contenuto,
                    trigger: UNCalendarNotificationTrigger(dateMatching: quandoComponenti, repeats: false))
                try? await centro.add(richiesta)
            }
        }
    }
}
