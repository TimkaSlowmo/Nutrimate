import SwiftUI

@main
struct NutriMateApp: App {
    @StateObject private var store = AppStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .fontDesign(.serif)
                .tint(.burgundy)
                .preferredColorScheme(store.data.appearance.scheme)
                .onAppear { FPSProbe.shared.startLater() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { store.saveNow() } // гарантированно сохраняем при сворачивании
        }
    }
}
