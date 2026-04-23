import SwiftUI

struct DetailView: View {
    let section: ConfigSection
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            if section.group == .settings && appState.settingsViewMode == .rawJSON {
                RawJSONView()
            } else if section.group == .settings && appState.settingsViewMode == .effective {
                EffectiveConfigView()
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
                case .fileHistory:
                    FileHistoryView()
                case .diskUsage:
                    DiskUsageView()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.windowBackgroundColor))
    }
}
