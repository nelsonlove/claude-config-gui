import Foundation

/// Top-level structure of ~/.claude.json or .mcp.json (only the MCP parts).
/// Uses permissive decoding — unknown keys are preserved in `otherKeys`.
struct MCPConfigFile: Codable {
    var mcpServers: [String: MCPServer]

    init(mcpServers: [String: MCPServer] = [:]) {
        self.mcpServers = mcpServers
    }
}

/// A single MCP server configuration.
struct MCPServer: Codable, Identifiable {
    var id: String { name }

    // Not encoded — set externally after decoding
    var name: String = ""

    // stdio transport (default)
    var command: String?
    var args: [String]?
    var env: [String: String]?

    // sse/http/ws transports
    var type: String?  // "sse", "http", "ws"
    var url: String?
    var headers: [String: String]?

    enum CodingKeys: String, CodingKey {
        case command, args, env, type, url, headers
    }

    var transportType: TransportType {
        get {
            if let t = type {
                return TransportType(rawValue: t) ?? .stdio
            }
            return .stdio
        }
        set {
            type = newValue == .stdio ? nil : newValue.rawValue
        }
    }

    var displaySummary: String {
        switch transportType {
        case .stdio:
            [command, args?.joined(separator: " ")].compactMap { $0 }.joined(separator: " ")
        case .sse, .http, .ws:
            url ?? "(no url)"
        }
    }
}

enum TransportType: String, CaseIterable, Identifiable {
    case stdio
    case sse
    case http
    case ws

    var id: Self { self }

    var label: String {
        switch self {
        case .stdio: "stdio"
        case .sse: "SSE"
        case .http: "HTTP"
        case .ws: "WebSocket"
        }
    }

    var icon: String {
        switch self {
        case .stdio: "terminal"
        case .sse: "antenna.radiowaves.left.and.right"
        case .http: "globe"
        case .ws: "bolt.horizontal"
        }
    }
}

enum MCPConfigScope: String, CaseIterable, Identifiable {
    case user
    case project
    case desktop

    var id: Self { self }

    var label: String {
        switch self {
        case .user: "User"
        case .project: "Project"
        case .desktop: "Desktop"
        }
    }

    var description: String {
        switch self {
        case .user: "~/.claude.json"
        case .project: ".mcp.json"
        case .desktop: "claude_desktop_config.json"
        }
    }

    func fileURL(projectRoot: URL? = nil) -> URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        switch self {
        case .user:
            return home.appendingPathComponent(".claude.json")
        case .project:
            let root = projectRoot ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            return root.appendingPathComponent(".mcp.json")
        case .desktop:
            return home.appendingPathComponent(".claude/claude_desktop_config.json")
        }
    }
}
