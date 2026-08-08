import SwiftUI

@main
struct AppUninstallerApp: App {
    @StateObject private var appManager = AppManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appManager)
                .frame(minWidth: 800, minHeight: 500)
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 900, height: 600)
    }
}
