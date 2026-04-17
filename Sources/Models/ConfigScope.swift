import Foundation

/// Represents which settings file we're editing.
/// Claude Code merges settings across scopes with this precedence:
/// Managed > CLI args > Local > Project > User
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

    func fileURL(projectRoot: URL? = nil) -> URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        switch self {
        case .user:
            return home.appendingPathComponent(".claude/settings.json")
        case .project:
            let root = projectRoot ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            return root.appendingPathComponent(".claude/settings.json")
        case .local:
            let root = projectRoot ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            return root.appendingPathComponent(".claude/settings.local.json")
        }
    }
}
