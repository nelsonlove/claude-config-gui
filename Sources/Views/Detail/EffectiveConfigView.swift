import SwiftUI

struct EffectiveConfigView: View {
    @Environment(AppState.self) private var appState

    private var editor: ConfigEditor { appState.configEditor }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "eye")
                    .foregroundStyle(.secondary)
                Text(scopeSummary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(editor.effectiveJSON, forType: .string)
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Copy effective config to clipboard")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.quaternary.opacity(0.5))

            ScrollView {
                Text(editor.effectiveJSON)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var scopeSummary: String {
        switch appState.selectedScope {
        case .user:
            return "Effective config — User scope only"
        case .project:
            return "Effective config — User + Project merged"
        case .local:
            return "Effective config — User + Project + Local merged"
        }
    }
}
