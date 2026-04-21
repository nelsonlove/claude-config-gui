import SwiftUI

@Observable
final class AppState {
    var selectedSection: ConfigSection = .general
    var selectedScope: ConfigScope = .user
    var showRawJSON: Bool = false
    var configEditor: ConfigEditor
    var selectedProjectRoot: URL?
    var knownProjects: [KnownProject] = []

    init() {
        self.configEditor = ConfigEditor(scope: .user)
        self.knownProjects = KnownProject.scanAll()
    }

    func switchScope(_ scope: ConfigScope) {
        selectedScope = scope
        reloadEditor()
    }

    func selectProject(_ project: KnownProject?) {
        selectedProjectRoot = project?.rootURL
        if selectedScope != .user {
            reloadEditor()
        }
    }

    private func reloadEditor() {
        configEditor = ConfigEditor(scope: selectedScope, projectRoot: selectedProjectRoot)
        configEditor.load()
    }
}

/// A project discovered from ~/.claude/projects/
struct KnownProject: Identifiable, Hashable {
    let id: String          // escaped dir name
    let dirName: String     // e.g. "-Users-nelson-repos-dotfiles"
    let displayName: String // e.g. "~/repos/dotfiles"
    let rootURL: URL        // e.g. /Users/nelson/repos/dotfiles

    static func scanAll() -> [KnownProject] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let projectsDir = claudePath("projects")
        let fm = FileManager.default

        guard let dirs = try? fm.contentsOfDirectory(
            at: projectsDir,
            includingPropertiesForKeys: [.isDirectoryKey]
        ) else { return [] }

        return dirs.compactMap { dir in
            let dirName = dir.lastPathComponent
            // Decode the escaped path: "-Users-nelson-repos-dotfiles" → "/Users/nelson/repos/dotfiles"
            let decoded = dirName.replacingOccurrences(of: "-", with: "/")
            let rootPath = decoded.hasPrefix("/") ? decoded : "/\(decoded)"
            let rootURL = URL(fileURLWithPath: rootPath)

            // Only include if the directory actually exists on disk
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: rootPath, isDirectory: &isDir), isDir.boolValue else {
                return nil
            }

            let displayName = rootPath.replacingOccurrences(of: home.path, with: "~")

            return KnownProject(
                id: dirName,
                dirName: dirName,
                displayName: displayName,
                rootURL: rootURL
            )
        }
        .sorted { $0.displayName < $1.displayName }
    }
}
