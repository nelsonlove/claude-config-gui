import SwiftUI

struct SidebarView: View {
    @Binding var selection: ConfigSection
    @Environment(AppState.self) private var appState

    var body: some View {
        List(ConfigSection.allCases, selection: $selection) { section in
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(section.title)
                    Text(section.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: section.icon)
                    .foregroundStyle(.tint)
            }
            .padding(.vertical, 2)
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 200, ideal: 220)
        .safeAreaInset(edge: .top) {
            scopePicker
        }
        .safeAreaInset(edge: .bottom) {
            statusBar
        }
    }

    private var scopePicker: some View {
        @Bindable var appState = appState
        return Picker("Scope", selection: $appState.selectedScope) {
            ForEach(ConfigScope.allCases) { scope in
                Text(scope.label).tag(scope)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .onChange(of: appState.selectedScope) { _, newScope in
            appState.switchScope(newScope)
        }
    }

    private var statusBar: some View {
        HStack(spacing: 6) {
            let editor = appState.configEditor
            if let error = editor.loadError {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(1)
            } else if editor.isDirty {
                Image(systemName: "pencil.circle.fill")
                    .foregroundStyle(.orange)
                Text("Unsaved changes")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if let saved = editor.lastSaved {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Saved \(saved.formatted(.relative(presentation: .named)))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Image(systemName: "doc.text")
                    .foregroundStyle(.secondary)
                Text(editor.fileURL.path.replacingOccurrences(
                    of: FileManager.default.homeDirectoryForCurrentUser.path,
                    with: "~"
                ))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}
