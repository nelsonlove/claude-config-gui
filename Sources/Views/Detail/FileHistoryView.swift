import SwiftUI

struct FileHistoryView: View {
    @State private var sessions: [FileHistorySession] = []
    @State private var selectedSession: FileHistorySession?
    @State private var selectedFile: FileHistoryEntry?
    @State private var isLoading = true

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("File History")
                    .font(.headline)
                Spacer()
                Text("\(sessions.count) sessions")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button {
                    reload()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            if isLoading {
                ProgressView("Scanning file history…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if sessions.isEmpty {
                ContentUnavailableView(
                    "No File History",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("File snapshots are saved when Claude edits files during sessions.")
                )
            } else {
                HSplitView {
                    // Left: session list with file entries
                    List(selection: $selectedFile) {
                        ForEach(sessions) { session in
                            Section {
                                ForEach(session.entries) { entry in
                                    HStack(spacing: 8) {
                                        Image(systemName: "doc.text")
                                            .foregroundStyle(.tint)
                                            .frame(width: 16)
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(entry.fileHash)
                                                .font(.system(.caption, design: .monospaced))
                                            Text("v\(entry.version)")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Text(entry.formattedSize)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    .tag(entry)
                                    .padding(.vertical, 1)
                                }
                            } header: {
                                HStack {
                                    Text(String(session.sessionId.prefix(8)))
                                        .font(.system(.caption, design: .monospaced))
                                    Spacer()
                                    Text("\(session.entries.count) files")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                    }
                    .listStyle(.inset)
                    .frame(minWidth: 200, idealWidth: 260)

                    // Right: file content viewer
                    if let file = selectedFile {
                        VStack(spacing: 0) {
                            HStack {
                                Text("\(file.fileHash)@v\(file.version)")
                                    .font(.system(.subheadline, design: .monospaced))
                                Spacer()
                                Text(file.formattedSize)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Button {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(file.content, forType: .string)
                                } label: {
                                    Label("Copy", systemImage: "doc.on.doc")
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(.quaternary.opacity(0.5))

                            ScrollView {
                                Text(file.content)
                                    .font(.system(.body, design: .monospaced))
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(16)
                            }
                        }
                        .frame(minWidth: 300)
                    } else {
                        ContentUnavailableView(
                            "Select a file",
                            systemImage: "doc.text",
                            description: Text("Choose a file snapshot to view its contents.")
                        )
                        .frame(minWidth: 300)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { reload() }
    }

    private func reload() {
        isLoading = true
        Task {
            let loaded = FileHistorySession.scanAll()
            await MainActor.run {
                sessions = loaded
                isLoading = false
            }
        }
    }
}

// MARK: - Data model

struct FileHistoryEntry: Identifiable, Hashable {
    let id: String
    let fileHash: String
    let version: Int
    let fileURL: URL
    let size: UInt64
    let content: String

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
    }
}

struct FileHistorySession: Identifiable {
    let id: String
    let sessionId: String
    let entries: [FileHistoryEntry]

    static func scanAll() -> [FileHistorySession] {
        let historyDir = claudePath("file-history")
        let fm = FileManager.default

        guard let sessionDirs = try? fm.contentsOfDirectory(
            at: historyDir,
            includingPropertiesForKeys: [.contentModificationDateKey]
        ) else { return [] }

        // Sort by modification date, newest first
        let sorted = sessionDirs.sorted { a, b in
            let aDate = (try? a.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let bDate = (try? b.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return aDate > bDate
        }

        return sorted.compactMap { sessionDir -> FileHistorySession? in
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: sessionDir.path, isDirectory: &isDir),
                  isDir.boolValue else { return nil }

            let sessionId = sessionDir.lastPathComponent

            guard let files = try? fm.contentsOfDirectory(
                at: sessionDir,
                includingPropertiesForKeys: [.fileSizeKey]
            ) else { return nil }

            let entries: [FileHistoryEntry] = files.compactMap { fileURL in
                let name = fileURL.lastPathComponent
                // Parse "hash@vN" format
                let parts = name.split(separator: "@")
                guard parts.count == 2,
                      let versionStr = parts.last,
                      versionStr.hasPrefix("v"),
                      let version = Int(versionStr.dropFirst()) else { return nil }

                let hash = String(parts[0])
                let size = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize).map { UInt64($0) } ?? 0
                let content = (try? String(contentsOf: fileURL, encoding: .utf8)) ?? "(binary or unreadable)"

                return FileHistoryEntry(
                    id: "\(sessionId)/\(name)",
                    fileHash: hash,
                    version: version,
                    fileURL: fileURL,
                    size: size,
                    content: content
                )
            }
            .sorted { $0.fileHash == $1.fileHash ? $0.version < $1.version : $0.fileHash < $1.fileHash }

            guard !entries.isEmpty else { return nil }

            return FileHistorySession(id: sessionId, sessionId: sessionId, entries: entries)
        }
    }
}
