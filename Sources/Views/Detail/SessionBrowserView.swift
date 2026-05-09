import SwiftUI
import AppKit

struct SessionBrowserView: View {
    @Environment(AppState.self) private var appState
    @State private var sessions: [SessionEntry] = []
    @State private var selectedSessionIDs: Set<SessionEntry.ID> = []
    @State private var messages: [SessionMessage] = []
    @State private var isHistoryFallback = false
    @State private var isLoading = true
    @State private var searchText = ""
    @State private var showDeleteConfirm = false

    private var selectedSessions: [SessionEntry] {
        sessions.filter { selectedSessionIDs.contains($0.id) }
    }

    private var singleSelectedSession: SessionEntry? {
        guard selectedSessionIDs.count == 1, let id = selectedSessionIDs.first else { return nil }
        return sessions.first { $0.id == id }
    }

    private var filteredSessions: [SessionEntry] {
        var result = sessions

        // Filter by project when a project is selected
        if appState.selectedScope != .user, let projectRoot = appState.selectedProjectRoot {
            let projectPath = projectRoot.path
            result = result.filter { $0.project == projectPath }
        }

        if !searchText.isEmpty {
            let q = searchText.lowercased()
            result = result.filter {
                $0.firstPrompt.lowercased().contains(q) ||
                $0.displayProject.lowercased().contains(q) ||
                ($0.customTitle?.lowercased().contains(q) ?? false)
            }
        }

        return result
    }

    var body: some View {
        HSplitView {
            // Session list
            VStack(spacing: 0) {
                HStack {
                    let isFiltered = appState.selectedScope != .user && appState.selectedProjectRoot != nil
                    Text("Sessions (\(filteredSessions.count)\(isFiltered ? " of \(sessions.count)" : ""))")
                        .font(.headline)
                    Spacer()
                    Button {
                        reload()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

                TextField("Search…", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)

                Divider()

                if isLoading {
                    ProgressView("Loading sessions…")
                        .frame(maxHeight: .infinity)
                } else {
                    List(filteredSessions, selection: $selectedSessionIDs) { session in
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                if session.customTitle != nil {
                                    Image(systemName: "tag.fill")
                                        .font(.caption2)
                                        .foregroundStyle(.tint)
                                }
                                Text(session.displayName)
                                    .lineLimit(2)
                                    .truncationMode(.tail)
                            }
                            HStack(spacing: 8) {
                                Text(session.timeAgo)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("\(session.messageCount) msgs")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(session.displayProject)
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                        }
                        .padding(.vertical, 2)
                        .contextMenu {
                            Button("Copy Resume Command") {
                                copyResumeCommand(for: session)
                            }
                            Divider()
                            let actingCount = selectedSessionIDs.contains(session.id) ? selectedSessionIDs.count : 1
                            Button(actingCount > 1 ? "Delete \(actingCount) Sessions" : "Delete Session", role: .destructive) {
                                if !selectedSessionIDs.contains(session.id) {
                                    selectedSessionIDs = [session.id]
                                }
                                showDeleteConfirm = true
                            }
                        }
                    }
                    .listStyle(.inset)
                }

                // Hidden Cmd-Delete shortcut to delete selection from the list
                Button {
                    showDeleteConfirm = true
                } label: {
                    EmptyView()
                }
                .keyboardShortcut(.delete, modifiers: .command)
                .disabled(selectedSessionIDs.isEmpty)
                .frame(width: 0, height: 0)
                .opacity(0)
                .accessibilityHidden(true)
            }
            .frame(minWidth: 280, idealWidth: 320)

            // Message viewer
            VStack(spacing: 0) {
                if let session = singleSelectedSession {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(session.displayName)
                                .font(.headline)
                                .lineLimit(1)
                            if session.customTitle != nil, !session.firstPrompt.isEmpty {
                                Text(session.firstPrompt)
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                                    .lineLimit(1)
                            }
                            Text("\(session.displayProject) · \(session.lastTimestamp.formatted(date: .abbreviated, time: .shortened))")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            copyResumeCommand(for: session)
                        } label: {
                            Label("Copy Resume", systemImage: "doc.on.doc")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .help("Copy `\(session.resumeCommand)` to the clipboard")
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)

                    Divider()

                    if messages.isEmpty {
                        ContentUnavailableView(
                            "No Transcript",
                            systemImage: "text.bubble",
                            description: Text("Session transcript has been cleaned up.")
                        )
                    } else {
                        if isHistoryFallback {
                            HStack(spacing: 6) {
                                Image(systemName: "info.circle")
                                    .foregroundStyle(.secondary)
                                Text("Full transcript cleaned up — showing user prompts from history")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .background(.quaternary.opacity(0.5))
                        }

                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 12) {
                                ForEach(messages) { msg in
                                    MessageBubble(message: msg)
                                }
                            }
                            .padding(16)
                        }
                    }
                } else if selectedSessionIDs.count > 1 {
                    VStack(spacing: 16) {
                        Image(systemName: "checklist")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("\(selectedSessionIDs.count) sessions selected")
                            .font(.title2)
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Label("Delete \(selectedSessionIDs.count) Sessions", systemImage: "trash")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ContentUnavailableView(
                        "Select a Session",
                        systemImage: "bubble.left.and.bubble.right",
                        description: Text("Choose a session from the list to view its transcript.")
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear { reload() }
        .onChange(of: selectedSessionIDs) { _, _ in
            loadTranscript(for: singleSelectedSession)
        }
        .alert(deleteAlertTitle, isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                let toDelete = selectedSessions
                let deletedIDs = Set(toDelete.map { $0.id })
                for s in toDelete {
                    SessionHistory.deleteSession(s)
                }
                sessions.removeAll { deletedIDs.contains($0.id) }
                selectedSessionIDs = []
                messages = []
            }
            .keyboardShortcut("d", modifiers: .command)
        } message: {
            Text("This will remove the transcript, analytics, and history entries. This cannot be undone.")
        }
    }

    private var deleteAlertTitle: String {
        let n = selectedSessionIDs.count
        return n > 1 ? "Delete \(n) Sessions?" : "Delete Session?"
    }

    private func reload() {
        isLoading = true
        Task {
            let loaded = SessionHistory.loadSessions()
            await MainActor.run {
                sessions = loaded
                isLoading = false
            }
        }
    }

    private func copyResumeCommand(for session: SessionEntry) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(session.resumeCommand, forType: .string)
    }

    private func loadTranscript(for session: SessionEntry?) {
        guard let session else {
            messages = []
            isHistoryFallback = false
            return
        }
        let transcript = SessionHistory.loadFromTranscript(sessionId: session.sessionId)
        if let transcript, !transcript.isEmpty {
            messages = transcript
            isHistoryFallback = false
        } else {
            messages = SessionHistory.loadMessages(sessionId: session.sessionId)
            isHistoryFallback = !messages.isEmpty
        }
    }
}

// MARK: - Message bubble

struct MessageBubble: View {
    let message: SessionMessage

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: message.type == .user ? "person.circle.fill" : "sparkle")
                .foregroundStyle(message.type == .user ? .blue : .orange)
                .font(.title3)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 6) {
                if !message.text.isEmpty {
                    Text(message.text)
                        .textSelection(.enabled)
                }

                ForEach(message.toolCalls) { tool in
                    ToolCallView(tool: tool)
                }

                if let ts = message.timestamp {
                    Text(ts.formatted(date: .omitted, time: .shortened))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Collapsible tool call

struct ToolCallView: View {
    let tool: ToolCall
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header — always visible
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(width: 10)
                    Image(systemName: toolIcon)
                        .foregroundStyle(.tint)
                        .font(.caption)
                    Text(tool.name)
                        .font(.system(.caption, design: .monospaced))
                        .fontWeight(.medium)
                    Text(tool.inputSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            .buttonStyle(.plain)

            // Expanded detail
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    // Input
                    if !tool.inputSummary.isEmpty {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Input")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                            Text(formatInput(tool.input))
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .padding(6)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(.quaternary.opacity(0.5))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                    }

                    // Result
                    if !tool.result.isEmpty {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Result")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                            Text(String(tool.result.prefix(2000)))
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .lineLimit(20)
                                .padding(6)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(.green.opacity(0.05))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                    }
                }
                .padding(.leading, 16)
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 8)
        .background(.tint.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var toolIcon: String {
        switch tool.name {
        case "Bash": return "terminal"
        case "Read": return "doc"
        case "Edit": return "pencil"
        case "Write": return "doc.badge.plus"
        case "Glob": return "magnifyingglass"
        case "Grep": return "text.magnifyingglass"
        case "Agent", "Task": return "person.2"
        case "TaskCreate", "TaskUpdate": return "checklist"
        case "WebSearch": return "globe"
        case "WebFetch": return "arrow.down.doc"
        default: return "wrench"
        }
    }

    private func formatInput(_ input: [String: Any]) -> String {
        // Show key fields in a readable format
        var lines: [String] = []
        for key in input.keys.sorted() {
            let val = input[key]
            if let str = val as? String {
                let display = str.count > 200 ? String(str.prefix(200)) + "…" : str
                lines.append("\(key): \(display)")
            } else if let arr = val as? [Any] {
                lines.append("\(key): [\(arr.count) items]")
            } else if let num = val as? NSNumber {
                lines.append("\(key): \(num)")
            }
        }
        return lines.joined(separator: "\n")
    }
}
