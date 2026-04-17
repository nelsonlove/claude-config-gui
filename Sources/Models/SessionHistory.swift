import Foundation

/// A session entry from history.jsonl, grouped.
struct SessionEntry: Identifiable, Hashable {
    let id: String  // sessionId
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

/// A single message from a session JSONL file.
struct SessionMessage: Identifiable {
    let id: String
    let type: MessageType
    let text: String
    let toolCalls: [String]
    let timestamp: Date?

    enum MessageType: String {
        case user, assistant, system, result, other
    }
}

/// Loads session data from history.jsonl and project session files.
struct SessionHistory {
    /// Scan history.jsonl for all sessions, most recent first.
    static func loadSessions() -> [SessionEntry] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let historyURL = home.appendingPathComponent(".claude/history.jsonl")

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
                sessions[sessionId] = (
                    first: display,
                    project: project,
                    count: 1,
                    firstTS: ts,
                    lastTS: ts
                )
            }
        }

        return sessions.map { sid, info in
            SessionEntry(
                id: sid,
                sessionId: sid,
                project: info.project,
                firstPrompt: info.first,
                messageCount: info.count,
                firstTimestamp: Date(timeIntervalSince1970: info.firstTS / 1000),
                lastTimestamp: Date(timeIntervalSince1970: info.lastTS / 1000)
            )
        }
        .sorted { $0.lastTimestamp > $1.lastTimestamp }
    }

    /// Load messages from a session's JSONL file.
    static func loadMessages(sessionId: String) -> [SessionMessage] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let projectsDir = home.appendingPathComponent(".claude/projects")
        let fm = FileManager.default

        // Search all project directories for this session's JSONL
        guard let projects = try? fm.contentsOfDirectory(at: projectsDir, includingPropertiesForKeys: nil)
        else { return [] }

        for projectDir in projects {
            let sessionFile = projectDir.appendingPathComponent("\(sessionId).jsonl")
            if fm.fileExists(atPath: sessionFile.path) {
                return parseSessionFile(sessionFile)
            }
        }
        return []
    }

    private static func parseSessionFile(_ url: URL) -> [SessionMessage] {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return [] }

        var messages: [SessionMessage] = []

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
            var tools: [String] = []

            if let str = rawContent as? String {
                text = str
            } else if let arr = rawContent as? [[String: Any]] {
                for block in arr {
                    let blockType = block["type"] as? String ?? ""
                    if blockType == "text", let t = block["text"] as? String {
                        text += t
                    } else if blockType == "tool_use", let name = block["name"] as? String {
                        tools.append(name)
                    }
                }
            }

            // Skip empty assistant messages (just tool calls with no text)
            if type == "assistant" && text.isEmpty && tools.isEmpty { continue }

            messages.append(SessionMessage(
                id: uuid,
                type: type == "user" ? .user : .assistant,
                text: text,
                toolCalls: tools,
                timestamp: ts
            ))
        }

        return messages
    }
}
