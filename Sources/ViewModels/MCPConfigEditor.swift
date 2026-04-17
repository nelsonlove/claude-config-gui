import SwiftUI

/// Loads and saves MCP server configurations.
/// Handles the fact that ~/.claude.json has many other keys besides mcpServers —
/// we preserve them by reading/writing only the mcpServers key.
@Observable
final class MCPConfigEditor {
    var servers: [MCPServer] = []
    var isDirty = false
    var loadError: String?

    let fileURL: URL

    private var saveTask: Task<Void, Never>?
    private var rawJSON: [String: Any] = [:]  // preserve unknown keys

    init(url: URL) {
        self.fileURL = url
    }

    func load() {
        do {
            let data = try Data(contentsOf: fileURL)
            // Keep the full JSON for round-tripping
            rawJSON = (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]

            // Decode just mcpServers
            if let serversData = rawJSON["mcpServers"] as? [String: Any] {
                let jsonData = try JSONSerialization.data(withJSONObject: serversData)
                var decoded = try JSONDecoder().decode([String: MCPServer].self, from: jsonData)
                // Set the name field from the dictionary key
                servers = decoded.map { key, value in
                    var server = value
                    server.name = key
                    return server
                }.sorted { $0.name < $1.name }
            } else {
                servers = []
            }
            isDirty = false
            loadError = nil
        } catch {
            if (error as NSError).code == NSFileReadNoSuchFileError {
                servers = []
                rawJSON = [:]
                isDirty = false
                loadError = nil
            } else {
                loadError = error.localizedDescription
            }
        }
    }

    func markDirty() {
        isDirty = true
        scheduleSave()
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            await MainActor.run { self?.save() }
        }
    }

    func save() {
        do {
            // Encode servers back to dictionary
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            var serversDict: [String: Any] = [:]
            for server in servers {
                let data = try encoder.encode(server)
                if let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    serversDict[server.name] = dict
                }
            }

            // Merge back into full JSON
            rawJSON["mcpServers"] = serversDict

            // Write with pretty printing
            let outputData = try JSONSerialization.data(
                withJSONObject: rawJSON,
                options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            )

            let dir = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try outputData.write(to: fileURL, options: .atomic)
            isDirty = false
            loadError = nil
        } catch {
            loadError = "Save error: \(error.localizedDescription)"
        }
    }

    func addServer(name: String) {
        var server = MCPServer()
        server.name = name
        server.command = ""
        servers.append(server)
        markDirty()
    }

    func removeServer(at index: Int) {
        servers.remove(at: index)
        markDirty()
    }

    func updateServer(_ server: MCPServer) {
        if let idx = servers.firstIndex(where: { $0.name == server.name }) {
            servers[idx] = server
            markDirty()
        }
    }
}
