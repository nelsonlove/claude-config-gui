import SwiftUI

struct DetailView: View {
    let section: ConfigSection
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            if appState.showRawJSON && section.group == .settings {
                RawJSONView()
            } else {
                switch section {
                // Settings panels use Form which needs ScrollView
                case .general:
                    ScrollView { GeneralSettingsView() }
                case .permissions:
                    ScrollView { PermissionsView() }
                case .hooks:
                    ScrollView { HooksView() }
                case .plugins:
                    ScrollView { PluginsView() }
                case .sandbox:
                    ScrollView { SandboxView() }
                case .advanced:
                    ScrollView { AdvancedSettingsView() }
                // These manage their own scrolling (List, TextEditor)
                case .claudeMd:
                    ClaudeMdView()
                case .memory:
                    MemoryBrowserView()
                case .mcpServers:
                    MCPServersView()
                case .sessions:
                    SessionBrowserView()
                case .analytics:
                    AnalyticsView()
                case .diskUsage:
                    DiskUsageView()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.windowBackgroundColor))
    }
}
