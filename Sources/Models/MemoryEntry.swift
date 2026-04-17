import Foundation

/// A single memory file parsed from ~/.claude/projects/*/memory/*.md
struct MemoryEntry: Identifiable, Hashable {
    let id: URL
    let fileURL: URL
    let projectPath: String
    var name: String
    var description: String
    var type: MemoryType
    var body: String

    enum MemoryType: String, CaseIterable, Identifiable {
        case user
        case feedback
        case project
        case reference
        var id: Self { self }

        var icon: String {
            switch self {
            case .user: "person"
            case .feedback: "bubble.left"
            case .project: "folder"
            case .reference: "link"
            }
        }
    }

    /// Parse a memory file from its URL.
    static func parse(from url: URL, projectPath: String) -> MemoryEntry? {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        // Skip MEMORY.md index files
        if url.lastPathComponent == "MEMORY.md" { return nil }

        var name = url.deletingPathExtension().lastPathComponent
        var description = ""
        var type: MemoryType = .project
        var body = content

        // Parse YAML frontmatter
        if content.hasPrefix("---\n") {
            let parts = content.dropFirst(4).components(separatedBy: "\n---\n")
            if parts.count >= 2 {
                let frontmatter = parts[0]
                body = parts.dropFirst().joined(separator: "\n---\n").trimmingCharacters(in: .whitespacesAndNewlines)

                for line in frontmatter.components(separatedBy: "\n") {
                    let kv = line.split(separator: ":", maxSplits: 1)
                    guard kv.count == 2 else { continue }
                    let key = kv[0].trimmingCharacters(in: .whitespaces)
                    let value = kv[1].trimmingCharacters(in: .whitespaces)
                    switch key {
                    case "name": name = value
                    case "description": description = value
                    case "type":
                        type = MemoryType(rawValue: value) ?? .project
                    default: break
                    }
                }
            }
        }

        return MemoryEntry(
            id: url,
            fileURL: url,
            projectPath: projectPath,
            name: name,
            description: description,
            type: type,
            body: body
        )
    }

    /// Serialize back to markdown with frontmatter.
    func serialize() -> String {
        """
        ---
        name: \(name)
        description: \(description)
        type: \(type.rawValue)
        ---

        \(body)
        """
    }
}

/// Represents a project directory with its memory files.
struct ProjectMemory: Identifiable {
    let id: String
    let path: String
    let displayName: String
    let memoryDir: URL
    var entries: [MemoryEntry]

    /// Scan ~/.claude/projects/ for all projects with memory directories.
    static func scanAll() -> [ProjectMemory] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let projectsDir = home.appendingPathComponent(".claude/projects")
        let fm = FileManager.default

        guard let projectDirs = try? fm.contentsOfDirectory(
            at: projectsDir,
            includingPropertiesForKeys: [.isDirectoryKey]
        ) else { return [] }

        return projectDirs.compactMap { projectDir in
            let memoryDir = projectDir.appendingPathComponent("memory")
            guard fm.fileExists(atPath: memoryDir.path) else { return nil }

            let dirName = projectDir.lastPathComponent
            let displayName = dirName
                .replacingOccurrences(of: "-", with: "/")
                .replacingOccurrences(of: "/Users/", with: "~/")

            guard let files = try? fm.contentsOfDirectory(
                at: memoryDir,
                includingPropertiesForKeys: nil
            ) else { return nil }

            let entries = files
                .filter { $0.pathExtension == "md" }
                .compactMap { MemoryEntry.parse(from: $0, projectPath: dirName) }

            guard !entries.isEmpty else { return nil }

            return ProjectMemory(
                id: dirName,
                path: dirName,
                displayName: displayName,
                memoryDir: memoryDir,
                entries: entries
            )
        }
        .sorted { $0.entries.count > $1.entries.count }
    }
}
