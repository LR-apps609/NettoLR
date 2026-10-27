import SwiftUI

// Il punto d'ingresso dell'app, da solo in questo file: i test automatici compilano tutto il resto.
@main
struct NettoLRApp: App {
    @StateObject private var store = Store.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .tint(Theme.prugna)
                // Solo per il giro automatico delle foto: forza il tema scuro
                .preferredColorScheme(ProcessInfo.processInfo.arguments.contains("-uiDark") ? .dark : nil)
        }
    }
}
