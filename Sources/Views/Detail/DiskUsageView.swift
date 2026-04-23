import SwiftUI

struct DiskUsageView: View {
    @State private var usage = DiskUsage()
    @State private var isLoading = true
    @State private var cleanupTarget: CleanupTarget?
    @State private var showCleanupConfirm = false
    @State private var showPruneConfirm = false
    @State private var pruneCount = 0
    @State private var pruneSessionIds: [String] = []

    enum CleanupTarget: Identifiable {
        case debug, cache, shellSnapshots, fileHistory
        var id: Self { self }

        var label: String {
            switch self {
            case .debug: "debug logs"
            case .cache: "cache"
            case .shellSnapshots: "shell snapshots"
            case .fileHistory: "file history"
            }
        }

        var dirName: String {
            switch self {
            case .debug: "debug"
            case .cache: "cache"
            case .shellSnapshots: "shell-snapshots"
            case .fileHistory: "file-history"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Disk Usage")
                    .font(.headline)
                Spacer()
                Text(ByteCountFormatter.string(fromByteCount: Int64(usage.totalBytes), countStyle: .file))
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(.tint)
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
                ProgressView("Scanning…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        // Directory breakdown
                        GroupBox("Directories") {
                            VStack(spacing: 4) {
                                ForEach(usage.entries) { entry in
                                    HStack {
                                        Image(systemName: dirIcon(entry.name))
                                            .foregroundStyle(.tint)
                                            .frame(width: 20)
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(entry.name)
                                                .font(.system(.body, design: .monospaced))
                                            Text("\(entry.fileCount) files")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()

                                        let fraction = usage.totalBytes > 0
                                            ? CGFloat(entry.bytes) / CGFloat(usage.totalBytes) : 0
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(.tint.opacity(0.3))
                                            .frame(width: max(2, fraction * 120), height: 12)

                                        Text(entry.formattedSize)
                                            .font(.system(.body, design: .monospaced))
                                            .frame(width: 80, alignment: .trailing)
                                    }
                                    .padding(.vertical, 3)
                                    if entry.id != usage.entries.last?.id {
                                        Divider()
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .padding(.horizontal, 16)

                        // Cleanup actions
                        GroupBox("Cleanup") {
                            VStack(spacing: 8) {
                                cleanupRow(.debug, icon: "ladybug")
                                cleanupRow(.shellSnapshots, icon: "terminal")
                                cleanupRow(.fileHistory, icon: "clock.arrow.circlepath")
                                cleanupRow(.cache, icon: "archivebox")
                            }
                            .padding(.vertical, 4)

                            Text("Remove temporary data to free disk space. Settings, memory, and plugins are not affected.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .padding(.top, 4)
                        }
                        .padding(.horizontal, 16)

                        // Session pruning
                        GroupBox("Session Pruning") {
                            VStack(alignment: .leading, spacing: 8) {
                                Button {
                                    preparePrune()
                                } label: {
                                    HStack {
                                        Image(systemName: "scissors")
                                            .foregroundStyle(.red)
                                            .frame(width: 20)
                                        Text("Prune old sessions")
                                        Spacer()
                                    }
                                }
                                .buttonStyle(.plain)

                                Text("Deletes session transcripts, metadata, and file history older than the configured cleanup period (default 30 days).")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                        .padding(.horizontal, 16)
                    }
                    .padding(.vertical, 16)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { reload() }
        .alert("Prune \(pruneCount) old sessions?", isPresented: $showPruneConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Prune", role: .destructive) {
                performPrune()
            }
        } message: {
            Text("This will delete transcripts, metadata, facets, and file history for \(pruneCount) sessions. This cannot be undone.")
        }
        .alert("Delete \(cleanupTarget?.label ?? "")?", isPresented: $showCleanupConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let target = cleanupTarget {
                    performCleanup(target)
                }
            }
        } message: {
            if let target = cleanupTarget, let entry = usage.entries.first(where: { $0.name == target.dirName }) {
                Text("This will delete \(entry.fileCount) files (\(entry.formattedSize)). This cannot be undone.")
            } else {
                Text("This cannot be undone.")
            }
        }
    }

    private func cleanupRow(_ target: CleanupTarget, icon: String) -> some View {
        let entry = usage.entries.first { $0.name == target.dirName }
        return Button {
            cleanupTarget = target
            showCleanupConfirm = true
        } label: {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(.red)
                    .frame(width: 20)
                Text("Clear \(target.label)")
                Spacer()
                if let entry {
                    Text(entry.formattedSize)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(entry == nil || entry?.bytes == 0)
        .opacity(entry == nil || entry?.bytes == 0 ? 0.4 : 1)
    }

    private func preparePrune() {
        let settingsURL = ConfigScope.user.settingsURL()
        var cleanupDays = 30 // default
        if let data = try? Data(contentsOf: settingsURL),
           let settings = try? JSONDecoder().decode(ClaudeSettings.self, from: data),
           let days = settings.cleanupPeriodDays {
            cleanupDays = days
        }

        guard cleanupDays > 0 else { return } // 0 means disabled

        let cutoff = Date().addingTimeInterval(-Double(cleanupDays) * 86400)
        let metaDir = claudePath("usage-data/session-meta")
        let fm = FileManager.default

        guard let files = try? fm.contentsOfDirectory(at: metaDir, includingPropertiesForKeys: [.contentModificationDateKey])
        else { return }

        pruneSessionIds = []
        for file in files where file.pathExtension == "json" {
            guard let attrs = try? file.resourceValues(forKeys: [.contentModificationDateKey]),
                  let modDate = attrs.contentModificationDate,
                  modDate < cutoff else { continue }
            let sessionId = file.deletingPathExtension().lastPathComponent
            pruneSessionIds.append(sessionId)
        }

        pruneCount = pruneSessionIds.count
        if pruneCount > 0 {
            showPruneConfirm = true
        }
    }

    private func performPrune() {
        let fm = FileManager.default
        for sessionId in pruneSessionIds {
            // Remove session-meta
            let metaFile = claudePath("usage-data/session-meta/\(sessionId).json")
            try? fm.removeItem(at: metaFile)

            // Remove facets
            let facetFile = claudePath("usage-data/facets/\(sessionId).json")
            try? fm.removeItem(at: facetFile)

            // Remove file history
            let historyDir = claudePath("file-history/\(sessionId)")
            try? fm.removeItem(at: historyDir)

            // Remove session transcripts from all projects
            let projectsDir = claudePath("projects")
            if let projects = try? fm.contentsOfDirectory(at: projectsDir, includingPropertiesForKeys: nil) {
                for projectDir in projects {
                    let sessionFile = projectDir.appendingPathComponent("\(sessionId).jsonl")
                    try? fm.removeItem(at: sessionFile)
                    let subagentDir = projectDir.appendingPathComponent(sessionId)
                    if fm.fileExists(atPath: subagentDir.path) {
                        try? fm.removeItem(at: subagentDir)
                    }
                }
            }
        }
        reload()
    }

    private func performCleanup(_ target: CleanupTarget) {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let dir = claudePath(target.dirName)
        let fm = FileManager.default

        if let files = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) {
            for file in files {
                try? fm.removeItem(at: file)
            }
        }
        reload()
    }

    private func reload() {
        isLoading = true
        Task {
            let scanned = DiskUsage.scan()
            await MainActor.run {
                usage = scanned
                isLoading = false
            }
        }
    }

    private func dirIcon(_ name: String) -> String {
        switch name {
        case "plugins": return "puzzlepiece.extension"
        case "projects": return "folder"
        case "usage-data": return "chart.bar"
        case "file-history": return "clock.arrow.circlepath"
        case "debug": return "ladybug"
        case "sessions", "session-env", "session-names": return "bubble.left"
        case "shell-snapshots": return "terminal"
        case "local": return "shippingbox"
        case "cache": return "archivebox"
        case "tasks", "todos": return "checklist"
        case "plans": return "map"
        case "backups": return "externaldrive"
        default: return "doc"
        }
    }
}
