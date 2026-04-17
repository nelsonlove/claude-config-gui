import SwiftUI

struct SessionBrowserView: View {
    @State private var sessions: [SessionEntry] = []
    @State private var selectedSession: SessionEntry?
    @State private var messages: [SessionMessage] = []
    @State private var isHistoryFallback = false
    @State private var isLoading = true
    @State private var searchText = ""

    private var filteredSessions: [SessionEntry] {
        if searchText.isEmpty { return sessions }
        let q = searchText.lowercased()
        return sessions.filter {
            $0.firstPrompt.lowercased().contains(q) ||
            $0.displayProject.lowercased().contains(q)
        }
    }

    var body: some View {
        HSplitView {
            // Session list
            VStack(spacing: 0) {
                HStack {
                    Text("Sessions (\(sessions.count))")
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
                    List(filteredSessions, selection: $selectedSession) { session in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(session.firstPrompt.isEmpty ? "(no prompt)" : session.firstPrompt)
                                .lineLimit(2)
                                .truncationMode(.tail)
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
                        .tag(session)
                    }
                    .listStyle(.inset)
                }
            }
            .frame(minWidth: 280, idealWidth: 320)

            // Message viewer
            VStack(spacing: 0) {
                if let session = selectedSession {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(session.firstPrompt.isEmpty ? "Session" : session.firstPrompt)
                                .font(.headline)
                                .lineLimit(1)
                            Text("\(session.displayProject) · \(session.lastTimestamp.formatted(date: .abbreviated, time: .shortened))")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
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
        .onChange(of: selectedSession) { _, session in
            if let session {
                let transcript = SessionHistory.loadFromTranscript(sessionId: session.sessionId)
                if let transcript, !transcript.isEmpty {
                    messages = transcript
                    isHistoryFallback = false
                } else {
                    messages = SessionHistory.loadMessages(sessionId: session.sessionId)
                    isHistoryFallback = !messages.isEmpty
                }
            } else {
                messages = []
                isHistoryFallback = false
            }
        }
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

            VStack(alignment: .leading, spacing: 4) {
                if !message.text.isEmpty {
                    Text(message.text)
                        .textSelection(.enabled)
                        .font(message.type == .user ? .body : .system(.body, design: .default))
                }

                if !message.toolCalls.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(message.toolCalls, id: \.self) { tool in
                            Text(tool)
                                .font(.caption2)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(.tint.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                        }
                    }
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
