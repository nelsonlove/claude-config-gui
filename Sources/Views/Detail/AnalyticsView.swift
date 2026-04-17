import SwiftUI

struct AnalyticsView: View {
    @State private var stats = SessionStats()
    @State private var isLoading = true

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Session Analytics")
                    .font(.headline)
                Spacer()
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
                ProgressView("Scanning sessions…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        // Summary cards
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 12) {
                            StatCard(label: "Sessions", value: "\(stats.validSessions)", icon: "bubble.left.and.bubble.right")
                            StatCard(label: "Total Hours", value: String(format: "%.0f", stats.totalHours), icon: "clock")
                            StatCard(label: "Tokens", value: formatCount(stats.totalTokens), icon: "number")
                            StatCard(label: "Git Commits", value: "\(stats.totalCommits)", icon: "arrow.triangle.branch")
                        }
                        .padding(.horizontal, 16)

                        // Tool usage
                        GroupBox("Tool Usage") {
                            let sorted = stats.toolCounts.sorted { $0.value > $1.value }
                            let maxCount = sorted.first?.value ?? 1
                            VStack(spacing: 6) {
                                ForEach(sorted.prefix(12), id: \.key) { tool, count in
                                    HStack(spacing: 8) {
                                        Text(tool)
                                            .font(.system(.body, design: .monospaced))
                                            .frame(width: 100, alignment: .trailing)
                                        GeometryReader { geo in
                                            RoundedRectangle(cornerRadius: 3)
                                                .fill(.tint)
                                                .frame(width: geo.size.width * CGFloat(count) / CGFloat(maxCount))
                                        }
                                        .frame(height: 16)
                                        Text("\(count)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .frame(width: 50, alignment: .trailing)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .padding(.horizontal, 16)

                        // Languages
                        if !stats.languageCounts.isEmpty {
                            GroupBox("Languages") {
                                let sorted = stats.languageCounts.sorted { $0.value > $1.value }
                                FlowLayout(spacing: 6) {
                                    ForEach(sorted.prefix(15), id: \.key) { lang, count in
                                        Text("\(lang) (\(count))")
                                            .font(.caption)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(.quaternary)
                                            .clipShape(RoundedRectangle(cornerRadius: 6))
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                            .padding(.horizontal, 16)
                        }

                        // Recent sessions
                        GroupBox("Recent Sessions") {
                            VStack(spacing: 0) {
                                ForEach(stats.recentSessions) { session in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(session.first_prompt ?? "No prompt")
                                                .lineLimit(1)
                                                .truncationMode(.tail)
                                            HStack(spacing: 8) {
                                                if let time = session.start_time {
                                                    Text(formatDate(time))
                                                        .font(.caption)
                                                        .foregroundStyle(.secondary)
                                                }
                                                if let dur = session.duration_minutes {
                                                    Text("\(dur)m")
                                                        .font(.caption)
                                                        .foregroundStyle(.secondary)
                                                }
                                                if let path = session.project_path {
                                                    Text(path.replacingOccurrences(of: "/Users/nelson", with: "~"))
                                                        .font(.caption)
                                                        .foregroundStyle(.tertiary)
                                                }
                                            }
                                        }
                                        Spacer()
                                        if let tokens = session.output_tokens {
                                            Text(formatCount(tokens))
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .padding(.vertical, 6)
                                    Divider()
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    .padding(.vertical, 16)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { reload() }
    }

    private func reload() {
        isLoading = true
        Task {
            let loaded = SessionStats.load()
            await MainActor.run {
                stats = loaded
                isLoading = false
            }
        }
    }

    private func formatCount(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 1_000 { return String(format: "%.1fK", Double(n) / 1_000) }
        return "\(n)"
    }

    private func formatDate(_ iso: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: iso) else { return iso }
        let display = DateFormatter()
        display.dateStyle = .medium
        display.timeStyle = .short
        return display.string(from: date)
    }
}

// MARK: - Stat card

struct StatCard: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.tint)
            Text(value)
                .font(.title)
                .fontWeight(.semibold)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.quaternary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Simple flow layout for tags

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: ProposedViewSize(width: bounds.width, height: bounds.height), subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return (CGSize(width: maxWidth, height: y + rowHeight), positions)
    }
}
