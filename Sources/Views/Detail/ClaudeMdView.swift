import SwiftUI

struct ClaudeMdView: View {
    @Environment(AppState.self) private var appState
    @State private var editor = MarkdownFileEditor()
    @State private var showPreview = false

    private var fileURL: URL {
        appState.selectedScope.claudeMdURL(projectRoot: appState.selectedProjectRoot)
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

                Toggle(isOn: $showPreview) {
                    Label("Preview", systemImage: "eye")
                }
                .toggleStyle(.button)
                .controlSize(.small)
                .help("Toggle markdown preview")
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

            if showPreview {
                HSplitView {
                    TextEditor(text: Binding(
                        get: { editor.content },
                        set: { editor.content = $0; editor.markDirty() }
                    ))
                    .font(.system(.body, design: .monospaced))
                    .scrollContentBackground(.visible)
                    .frame(minWidth: 200)

                    ScrollView {
                        MarkdownPreview(source: editor.content)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                    }
                    .frame(minWidth: 200)
                    .background(Color(.textBackgroundColor))
                }
            } else {
                TextEditor(text: Binding(
                    get: { editor.content },
                    set: { editor.content = $0; editor.markDirty() }
                ))
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.visible)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { loadForCurrentScope() }
        .onChange(of: appState.selectedScope) { _, _ in loadForCurrentScope() }
        .onChange(of: appState.selectedProjectRoot) { _, _ in loadForCurrentScope() }
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

// MARK: - Markdown Preview

/// Renders markdown using AttributedString for zero-dependency preview.
struct MarkdownPreview: View {
    let source: String

    var body: some View {
        if source.isEmpty {
            Text("Empty file")
                .foregroundStyle(.tertiary)
                .italic()
        } else if let attributed = try? AttributedString(
            markdown: source,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            Text(attributed)
                .textSelection(.enabled)
        } else {
            // Fallback: plain text if markdown parsing fails
            Text(source)
                .textSelection(.enabled)
        }
    }
}
