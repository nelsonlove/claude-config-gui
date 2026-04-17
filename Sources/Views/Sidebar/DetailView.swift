import SwiftUI

struct DetailView: View {
    let section: ConfigSection
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            if appState.showRawJSON && section.group == .settings {
                RawJSONView()
            } else {
                ScrollView {
                    switch section {
                    case .general:
                        GeneralSettingsView()
                    case .permissions:
                        PermissionsView()
                    case .hooks:
                        HooksView()
                    case .plugins:
                        PluginsView()
                    case .sandbox:
                        SandboxView()
                    case .advanced:
                        AdvancedSettingsView()
                    case .claudeMd:
                        ClaudeMdView()
                    case .memory:
                        MemoryBrowserView()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.windowBackgroundColor))
    }
}
