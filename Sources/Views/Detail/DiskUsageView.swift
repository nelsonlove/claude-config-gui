import SwiftUI

struct DiskUsageView: View {
    @State private var usage = DiskUsage()
    @State private var isLoading = true
    @State private var cleanupTarget: CleanupTarget?
    @State private var showCleanupConfirm = false

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
                    }
                    .padding(.vertical, 16)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { reload() }
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

    private func performCleanup(_ target: CleanupTarget) {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let dir = home.appendingPathComponent(".claude/\(target.dirName)")
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
