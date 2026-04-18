import SwiftUI

struct MemoryBrowserView: View {
    @Environment(AppState.self) private var appState
    @State private var projects: [ProjectMemory] = []
    @State private var selectedEntry: MemoryEntry?
    @State private var editingEntry: MemoryEntry?
    @State private var showNewMemory = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Memory Files")
                    .font(.headline)
                Spacer()
                Button {
                    showNewMemory = true
                } label: {
                    Label("New", systemImage: "plus")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button {
                    projects = ProjectMemory.scanAll()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            if showNewMemory {
                MemoryEditorView(entry: newMemoryEntry()) { saved in
                    saveEntry(saved)
                    showNewMemory = false
                } onCancel: {
                    showNewMemory = false
                }
            } else if projects.isEmpty && editingEntry == nil {
                ContentUnavailableView(
                    "No Memory Files",
                    systemImage: "brain.head.profile",
                    description: Text("Memory files are created by Claude Code as it learns your preferences.")
                )
            } else if let editing = editingEntry {
                MemoryEditorView(entry: editing) { saved in
                    saveEntry(saved)
                    editingEntry = nil
                } onCancel: {
                    editingEntry = nil
                }
            } else {
                List(selection: $selectedEntry) {
                    ForEach(projects) { project in
                        Section {
                            ForEach(project.entries) { entry in
                                MemoryEntryRow(entry: entry)
                                    .tag(entry)
                                    .contextMenu {
                                        Button("Edit") { editingEntry = entry }
                                        Divider()
                                        Button("Delete", role: .destructive) {
                                            deleteEntry(entry)
                                        }
                                    }
                            }
                        } header: {
                            Text(project.displayName)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            projects = ProjectMemory.scanAll()
        }
    }

    private func saveEntry(_ entry: MemoryEntry) {
        var entry = entry
        // For new files, derive filename from name field
        if entry.fileURL.lastPathComponent == "new_memory.md" && !entry.name.isEmpty {
            let sanitized = entry.name
                .replacingOccurrences(of: " ", with: "_")
                .replacingOccurrences(of: "/", with: "_")
                .lowercased()
            entry = MemoryEntry(
                id: entry.fileURL.deletingLastPathComponent().appendingPathComponent("\(sanitized).md"),
                fileURL: entry.fileURL.deletingLastPathComponent().appendingPathComponent("\(sanitized).md"),
                projectPath: entry.projectPath,
                name: entry.name,
                description: entry.description,
                type: entry.type,
                body: entry.body
            )
        }
        let dir = entry.fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let content = entry.serialize()
        try? content.write(to: entry.fileURL, atomically: true, encoding: .utf8)
        projects = ProjectMemory.scanAll()
    }

    private func deleteEntry(_ entry: MemoryEntry) {
        try? FileManager.default.removeItem(at: entry.fileURL)
        projects = ProjectMemory.scanAll()
    }

    private func newMemoryEntry() -> MemoryEntry {
        // Save to the global project memory dir by default,
        // or to the selected project if one is chosen
        let home = FileManager.default.homeDirectoryForCurrentUser
        let memoryDir: URL
        let projectPath: String

        if let projectRoot = appState.selectedProjectRoot, appState.selectedScope != .user {
            let escaped = projectRoot.path.replacingOccurrences(of: "/", with: "-")
            memoryDir = home.appendingPathComponent(".claude/projects/\(escaped)/memory")
            projectPath = escaped
        } else {
            memoryDir = home.appendingPathComponent(".claude/projects/-Users-\(NSUserName())/memory")
            projectPath = "-Users-\(NSUserName())"
        }

        let filename = "new_memory.md"
        let fileURL = memoryDir.appendingPathComponent(filename)

        return MemoryEntry(
            id: fileURL,
            fileURL: fileURL,
            projectPath: projectPath,
            name: "new_memory",
            description: "",
            type: .feedback,
            body: ""
        )
    }
}

// MARK: - Memory Entry Row

struct MemoryEntryRow: View {
    let entry: MemoryEntry

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: entry.type.icon)
                .foregroundStyle(.tint)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name)
                    .font(.body)
                if !entry.description.isEmpty {
                    Text(entry.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            Text(entry.type.rawValue)
                .font(.caption)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.quaternary)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Memory Editor

struct MemoryEditorView: View {
    @State var entry: MemoryEntry
    let onSave: (MemoryEntry) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Button("Cancel") { onCancel() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Text(entry.fileURL.lastPathComponent)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Save") { onSave(entry) }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            Form {
                Section("Frontmatter") {
                    TextField("Name", text: $entry.name, prompt: Text("memory_name"))
                    TextField("Description", text: $entry.description, prompt: Text("One-line description"))
                    Picker("Type", selection: $entry.type) {
                        ForEach(MemoryEntry.MemoryType.allCases) { type in
                            Label(type.rawValue.capitalized, systemImage: type.icon)
                                .tag(type)
                        }
                    }
                }

                Section("Content") {
                    TextEditor(text: $entry.body)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 200)
                }
            }
            .formStyle(.grouped)
        }
    }
}
