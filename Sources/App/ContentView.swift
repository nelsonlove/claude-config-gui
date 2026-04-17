import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState

        NavigationSplitView {
            SidebarView(selection: $appState.selectedSection)
        } detail: {
            DetailView(section: appState.selectedSection)
        }
        .navigationSplitViewStyle(.balanced)
    }
}
