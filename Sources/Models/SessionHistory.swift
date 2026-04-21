import Foundation

/// A session entry from history.jsonl, grouped.
struct SessionEntry: Identifiable, Hashable {
    let id: String
    let sessionId: String
    let project: String
    let firstPrompt: String
    let messageCount: Int
    let firstTimestamp: Date
    let lastTimestamp: Date

    var displayProject: String {
        project.replacingOccurrences(
            of: FileManager.default.homeDirectoryForCurrentUser.path,
            with: "~"
        )
    }

    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: lastTimestamp, relativeTo: Date())
    }
}

/// A tool call with its result.
struct ToolCall: Identifiable {
    let id: String
    let name: String
    let input: [String: Any]
    var result: String = ""

    var inputSummary: String {
        if let cmd = input["command"] as? String { return cmd }
        if let path = input["file_path"] as? String { return path }
        if let pattern = input["pattern"] as? String { return pattern }
        if let prompt = input["prompt"] as? String { return String(prompt.prefix(80)) }
        if let subject = input["subject"] as? String { return subject }
        return input.keys.sorted().joined(separator: ", ")
    }
}

/// A single message from a session JSONL file.
struct SessionMessage: Identifiable {
    let id: String
    let type: MessageType
    let text: String
    let toolCalls: [ToolCall]
    let timestamp: Date?

    enum MessageType: String {
        case user, assistant, system, other
    }
}

/// Loads session data from history.jsonl and project session files.
struct SessionHistory {
    /// Scan history.jsonl for all sessions, most recent first.
    static func loadSessions() -> [SessionEntry] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let historyURL = claudePath("history.jsonl")

        guard let data = try? String(contentsOf: historyURL, encoding: .utf8) else { return [] }

        var sessions: [String: (first: String, project: String, count: Int, firstTS: Double, lastTS: Double)] = [:]

        for line in data.components(separatedBy: "\n") where !line.isEmpty {
            guard let lineData = line.data(using: .utf8),
                  let dict = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                  let sessionId = dict["sessionId"] as? String else { continue }

            let ts = dict["timestamp"] as? Double ?? 0
            let display = dict["display"] as? String ?? ""
            let project = dict["project"] as? String ?? ""

            if var existing = sessions[sessionId] {
                existing.count += 1
                if ts < existing.firstTS {
                    existing.firstTS = ts
                    if !display.isEmpty { existing.first = display }
                }
                if ts > existing.lastTS { existing.lastTS = ts }
                sessions[sessionId] = existing
            } else {
                sessions[sessionId] = (first: display, project: project, count: 1, firstTS: ts, lastTS: ts)
            }
        }

        return sessions.map { sid, info in
            SessionEntry(
                id: sid, sessionId: sid, project: info.project,
                firstPrompt: info.first, messageCount: info.count,
                firstTimestamp: Date(timeIntervalSince1970: info.firstTS / 1000),
                lastTimestamp: Date(timeIntervalSince1970: info.lastTS / 1000)
            )
        }
        .sorted { $0.lastTimestamp > $1.lastTimestamp }
    }

    /// Load messages, preferring full transcript, falling back to history.
    static func loadMessages(sessionId: String) -> [SessionMessage] {
        if let messages = loadFromTranscript(sessionId: sessionId), !messages.isEmpty {
            return messages
        }
        return loadFromHistory(sessionId: sessionId)
    }

    static func loadFromTranscript(sessionId: String) -> [SessionMessage]? {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let projectsDir = claudePath("projects")
        let fm = FileManager.default

        guard let projects = try? fm.contentsOfDirectory(at: projectsDir, includingPropertiesForKeys: nil)
        else { return nil }

        for projectDir in projects {
            let sessionFile = projectDir.appendingPathComponent("\(sessionId).jsonl")
            if fm.fileExists(atPath: sessionFile.path) {
                return parseSessionFile(sessionFile)
            }
        }
        return nil
    }

    private static func loadFromHistory(sessionId: String) -> [SessionMessage] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let historyURL = claudePath("history.jsonl")
        guard let content = try? String(contentsOf: historyURL, encoding: .utf8) else { return [] }

        var messages: [SessionMessage] = []
        for line in content.components(separatedBy: "\n") where !line.isEmpty {
            guard let data = line.data(using: .utf8),
                  let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  dict["sessionId"] as? String == sessionId else { continue }

            let display = dict["display"] as? String ?? ""
            let ts = (dict["timestamp"] as? Double).map { Date(timeIntervalSince1970: $0 / 1000) }
            if display.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { continue }

            messages.append(SessionMessage(
                id: UUID().uuidString, type: .user,
                text: display, toolCalls: [], timestamp: ts
            ))
        }
        return messages
    }

    private static func parseSessionFile(_ url: URL) -> [SessionMessage] {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return [] }

        var messages: [SessionMessage] = []
        // Collect tool results keyed by tool_use_id for pairing
        var toolResults: [String: String] = [:]

        // First pass: collect all tool results
        for line in content.components(separatedBy: "\n") where !line.isEmpty {
            guard let data = line.data(using: .utf8),
                  let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }

            let type = dict["type"] as? String ?? ""
            if type == "user" {
                let msg = dict["message"] as? [String: Any] ?? [:]
                if let arr = msg["content"] as? [[String: Any]] {
                    for block in arr {
                        if block["type"] as? String == "tool_result",
                           let toolId = block["tool_use_id"] as? String {
                            let resultContent = block["content"]
                            if let str = resultContent as? String {
                                toolResults[toolId] = str
                            } else if let arr = resultContent as? [[String: Any]] {
                                let texts = arr.compactMap { $0["text"] as? String }
                                toolResults[toolId] = texts.joined(separator: "\n")
                            }
                        }
                    }
                }
            }
        }

        // Second pass: build messages with paired tool results
        for line in content.components(separatedBy: "\n") where !line.isEmpty {
            guard let data = line.data(using: .utf8),
                  let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }

            let type = dict["type"] as? String ?? ""
            guard type == "user" || type == "assistant" else { continue }

            let ts = (dict["timestamp"] as? Double).map { Date(timeIntervalSince1970: $0 / 1000) }
            let uuid = dict["uuid"] as? String ?? UUID().uuidString
            let msg = dict["message"] as? [String: Any] ?? [:]
            let rawContent = msg["content"]

            var text = ""
            var tools: [ToolCall] = []

            if let str = rawContent as? String {
                text = str
            } else if let arr = rawContent as? [[String: Any]] {
                for block in arr {
                    let blockType = block["type"] as? String ?? ""
                    if blockType == "text", let t = block["text"] as? String {
                        text += t
                    } else if blockType == "tool_use" {
                        let toolId = block["id"] as? String ?? UUID().uuidString
                        let name = block["name"] as? String ?? "?"
                        let input = block["input"] as? [String: Any] ?? [:]
                        var tc = ToolCall(id: toolId, name: name, input: input)
                        tc.result = toolResults[toolId] ?? ""
                        tools.append(tc)
                    }
                }
            }

            // Skip empty messages
            if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && tools.isEmpty { continue }
            // Skip user messages that are just tool results
            if type == "user" && text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { continue }

            messages.append(SessionMessage(
                id: uuid, type: type == "user" ? .user : .assistant,
                text: text, toolCalls: tools, timestamp: ts
            ))
        }

        return messages
    }

    // MARK: - Delete

    /// Delete a session's data across all locations.
    static func deleteSession(_ session: SessionEntry) {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let fm = FileManager.default

        // Remove JSONL transcript
        let projectsDir = claudePath("projects")
        if let projects = try? fm.contentsOfDirectory(at: projectsDir, includingPropertiesForKeys: nil) {
            for projectDir in projects {
                let sessionFile = projectDir.appendingPathComponent("\(session.sessionId).jsonl")
                try? fm.removeItem(at: sessionFile)
                // Also remove subagent dir
                let subagentDir = projectDir.appendingPathComponent(session.sessionId)
                if fm.fileExists(atPath: subagentDir.path) {
                    try? fm.removeItem(at: subagentDir)
                }
            }
        }

        // Remove session-meta
        let metaFile = claudePath("usage-data/session-meta/\(session.sessionId).json")
        try? fm.removeItem(at: metaFile)

        // Remove facets
        let facetFile = claudePath("usage-data/facets/\(session.sessionId).json")
        try? fm.removeItem(at: facetFile)

        // Remove from history.jsonl (rewrite without this session's entries)
        let historyURL = claudePath("history.jsonl")
        if let content = try? String(contentsOf: historyURL, encoding: .utf8) {
            let filtered = content.components(separatedBy: "\n")
                .filter { line in
                    guard !line.isEmpty,
                          let data = line.data(using: .utf8),
                          let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                    else { return true }
                    return dict["sessionId"] as? String != session.sessionId
                }
                .joined(separator: "\n")
            try? filtered.write(to: historyURL, atomically: true, encoding: .utf8)
        }
    }
}
