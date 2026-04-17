import SwiftUI

@main
struct ClaudeConfigApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        Window("Claude Config", id: "main") {
            ContentView()
                .environment(appState)
                .frame(minWidth: 600, minHeight: 400)
        }
        .defaultSize(width: 780, height: 540)
        .windowResizability(.contentMinSize)
    }
}
