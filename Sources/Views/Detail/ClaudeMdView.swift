import SwiftUI

struct ClaudeMdView: View {
    @Environment(AppState.self) private var appState
    @State private var editor = MarkdownFileEditor()
    @State private var selectedFile: ClaudeMdFile = .global

    enum ClaudeMdFile: Hashable, CaseIterable {
        case global
        case project

        var label: String {
            switch self {
            case .global: "Global"
            case .project: "Project"
            }
        }

        var description: String {
            switch self {
            case .global: "~/.claude/CLAUDE.md — applies to all sessions"
            case .project: ".claude/CLAUDE.md — shared via git, project-specific"
            }
        }

        func url(projectRoot: URL? = nil) -> URL {
            let home = FileManager.default.homeDirectoryForCurrentUser
            switch self {
            case .global:
                return home.appendingPathComponent(".claude/CLAUDE.md")
            case .project:
                let root = projectRoot ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                return root.appendingPathComponent(".claude/CLAUDE.md")
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // File picker
            HStack {
                Picker(selection: $selectedFile) {
                    ForEach(ClaudeMdFile.allCases, id: \.self) { file in
                        Text(file.label).tag(file)
                    }
                } label: {
                    EmptyView()
                }
                .pickerStyle(.segmented)
                .frame(width: 200)

                Spacer()

                Text(shortenPath(editor.fileURL?.path ?? ""))
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

            // Editor
            TextEditor(text: Binding(
                get: { editor.content },
                set: { editor.content = $0; editor.markDirty() }
            ))
            .font(.system(.body, design: .monospaced))
            .scrollContentBackground(.visible)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            editor.load(from: selectedFile.url())
        }
        .onChange(of: selectedFile) { _, newFile in
            if editor.isDirty { editor.save() }
            editor.load(from: newFile.url())
        }
    }

    private func shortenPath(_ path: String) -> String {
        path.replacingOccurrences(
            of: FileManager.default.homeDirectoryForCurrentUser.path,
            with: "~"
        )
    }
}
