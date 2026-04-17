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

/// A read-only MCP server discovered from an installed plugin's .mcp.json.
struct PluginMCPServer: Identifiable {
    let id: String
    let serverName: String
    let pluginName: String
    let marketplace: String

    static func scanAll() -> [PluginMCPServer] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let cacheDir = home.appendingPathComponent(".claude/plugins/cache")
        let fm = FileManager.default
        var results: [PluginMCPServer] = []
        var seen = Set<String>()

        guard let marketplaces = try? fm.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: nil) else {
            return []
        }

        for mpDir in marketplaces {
            let mpName = mpDir.lastPathComponent
            // Skip temp directories
            guard !mpName.hasPrefix("temp_") else { continue }

            guard let plugins = try? fm.contentsOfDirectory(at: mpDir, includingPropertiesForKeys: nil) else { continue }

            for pluginDir in plugins {
                // Find the latest version directory
                guard let versions = try? fm.contentsOfDirectory(at: pluginDir, includingPropertiesForKeys: nil) else { continue }

                for versionDir in versions {
                    let mcpJSON = versionDir.appendingPathComponent(".mcp.json")
                    guard fm.fileExists(atPath: mcpJSON.path),
                          let data = try? Data(contentsOf: mcpJSON),
                          let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                          let servers = dict["mcpServers"] as? [String: Any] else { continue }

                    for serverName in servers.keys {
                        let key = "\(serverName)@\(pluginDir.lastPathComponent)"
                        guard !seen.contains(key) else { continue }
                        seen.insert(key)
                        results.append(PluginMCPServer(
                            id: key,
                            serverName: serverName,
                            pluginName: pluginDir.lastPathComponent,
                            marketplace: mpName
                        ))
                    }
                }
            }
        }

        return results.sorted { $0.serverName < $1.serverName }
    }
}

// MCPConfigScope removed — ConfigScope now handles all file URL routing.
