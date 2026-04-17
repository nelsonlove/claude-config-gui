import SwiftUI

struct ClaudeMdView: View {
    @Environment(AppState.self) private var appState
    @State private var editor = MarkdownFileEditor()

    private var fileURL: URL {
        appState.selectedScope.claudeMdURL()
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("CLAUDE.md")
                    .font(.headline)
                Spacer()
                Text(shortenPath(fileURL.path))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if editor.isDirty {
                    Image(systemName: "pencil.circle.fill")
                        .foregroundStyle(.orange)
                        .font(.caption)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            if let error = editor.loadError {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(.red)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.red.opacity(0.08))
            }

            TextEditor(text: Binding(
                get: { editor.content },
                set: { editor.content = $0; editor.markDirty() }
            ))
            .font(.system(.body, design: .monospaced))
            .scrollContentBackground(.visible)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { loadForCurrentScope() }
        .onChange(of: appState.selectedScope) { _, _ in loadForCurrentScope() }
    }

    private func loadForCurrentScope() {
        if editor.isDirty { editor.save() }
        editor.load(from: fileURL)
    }

    private func shortenPath(_ path: String) -> String {
        path.replacingOccurrences(
            of: FileManager.default.homeDirectoryForCurrentUser.path,
            with: "~"
        )
    }
}
