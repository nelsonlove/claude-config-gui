import SwiftUI

@main
struct ClaudeConfigApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .frame(minWidth: 720, minHeight: 480)
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 900, height: 600)
    }
}
