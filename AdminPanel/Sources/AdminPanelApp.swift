import SwiftUI

@main
struct AdminPanelApp: App {
    var body: some Scene {
        WindowGroup {
            AdminWebView()
                // Pantalla completa. El HTML ya respeta el notch con env(safe-area-inset-*).
                // Se deja fuera el teclado para que los campos no queden tapados.
                .ignoresSafeArea(.container, edges: .all)
                .background(Color.black.ignoresSafeArea())
                .preferredColorScheme(.dark)
        }
    }
}
