import Foundation

/// Represents which scope we're editing.
/// The sidebar picker sets this once; all views read from it.
enum ConfigScope: String, CaseIterable, Identifiable {
    case user
    case project
    case local

    var id: Self { self }

    var label: String {
        switch self {
        case .user: "User"
        case .project: "Project"
        case .local: "Local"
        }
    }

    var description: String {
        switch self {
        case .user: "~/.claude/settings.json — applies to all projects"
        case .project: ".claude/settings.json — shared via git"
        case .local: ".claude/settings.local.json — gitignored overrides"
        }
    }

    // MARK: - File URLs per scope

    func settingsURL(projectRoot: URL? = nil) -> URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        switch self {
        case .user:
            return claudePath("settings.json")
        case .project:
            let root = projectRoot ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            return root.appendingPathComponent(".claude/settings.json")
        case .local:
            let root = projectRoot ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            return root.appendingPathComponent(".claude/settings.local.json")
        }
    }

    // Keep old name for compatibility
    func fileURL(projectRoot: URL? = nil) -> URL {
        settingsURL(projectRoot: projectRoot)
    }

    func claudeMdURL(projectRoot: URL? = nil) -> URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        switch self {
        case .user, .local:
            return claudePath("CLAUDE.md")
        case .project:
            let root = projectRoot ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            return root.appendingPathComponent(".claude/CLAUDE.md")
        }
    }

    func mcpURL(projectRoot: URL? = nil) -> URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        switch self {
        case .user:
            return home.appendingPathComponent(".claude.json")
        case .local:
            return claudePath("claude_desktop_config.json")
        case .project:
            let root = projectRoot ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            return root.appendingPathComponent(".mcp.json")
        }
    }

    var mcpDescription: String {
        switch self {
        case .user: "~/.claude.json"
        case .project: ".mcp.json"
        case .local: "claude_desktop_config.json"
        }
    }
}
