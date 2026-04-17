import SwiftUI

struct DiskUsageView: View {
    @State private var usage = DiskUsage()
    @State private var isLoading = true

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
                List {
                    ForEach(usage.entries) { entry in
                        HStack {
                            Image(systemName: dirIcon(entry.name))
                                .foregroundStyle(.tint)
                                .frame(width: 20)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.name)
                                    .font(.system(.body, design: .monospaced))
                                Text("\(entry.fileCount) files")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()

                            // Size bar
                            let fraction = usage.totalBytes > 0
                                ? CGFloat(entry.bytes) / CGFloat(usage.totalBytes) : 0
                            RoundedRectangle(cornerRadius: 2)
                                .fill(.tint.opacity(0.3))
                                .frame(width: max(2, fraction * 100), height: 12)

                            Text(entry.formattedSize)
                                .font(.system(.body, design: .monospaced))
                                .frame(width: 70, alignment: .trailing)
                        }
                        .padding(.vertical, 2)
                    }
                }
                .listStyle(.inset)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { reload() }
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
