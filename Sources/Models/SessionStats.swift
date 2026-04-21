import Foundation

/// Aggregated statistics from usage-data/session-meta/*.json
struct SessionStats {
    var totalSessions: Int = 0
    var validSessions: Int = 0
    var totalTokens: Int = 0
    var totalInputTokens: Int = 0
    var totalOutputTokens: Int = 0
    var totalDurationMinutes: Int = 0
    var totalCommits: Int = 0
    var totalPushes: Int = 0
    var toolCounts: [String: Int] = [:]
    var languageCounts: [String: Int] = [:]
    var recentSessions: [SessionMeta] = []

    var totalHours: Double { Double(totalDurationMinutes) / 60.0 }
    var avgDurationMinutes: Double {
        validSessions > 0 ? Double(totalDurationMinutes) / Double(validSessions) : 0
    }
    var avgTokensPerSession: Int {
        validSessions > 0 ? totalTokens / validSessions : 0
    }

    static func load() -> SessionStats {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let metaDir = claudePath("usage-data/session-meta")
        let fm = FileManager.default

        guard let files = try? fm.contentsOfDirectory(at: metaDir, includingPropertiesForKeys: [.contentModificationDateKey])
        else { return SessionStats() }

        var stats = SessionStats()
        stats.totalSessions = files.count

        // Sort by modification date, newest first
        let sortedFiles = files.sorted { a, b in
            let aDate = (try? a.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let bDate = (try? b.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return aDate > bDate
        }

        for (index, file) in sortedFiles.enumerated() {
            guard file.pathExtension == "json",
                  let data = try? Data(contentsOf: file),
                  let meta = try? JSONDecoder().decode(SessionMeta.self, from: data) else { continue }

            stats.validSessions += 1
            stats.totalInputTokens += meta.input_tokens ?? 0
            stats.totalOutputTokens += meta.output_tokens ?? 0
            stats.totalTokens += (meta.input_tokens ?? 0) + (meta.output_tokens ?? 0)
            stats.totalDurationMinutes += meta.duration_minutes ?? 0
            stats.totalCommits += meta.git_commits ?? 0
            stats.totalPushes += meta.git_pushes ?? 0

            for (tool, count) in meta.tool_counts ?? [:] {
                stats.toolCounts[tool, default: 0] += count
            }
            for (lang, count) in meta.languages ?? [:] {
                stats.languageCounts[lang, default: 0] += count
            }

            if index < 20 {
                stats.recentSessions.append(meta)
            }
        }

        return stats
    }
}

/// A single session's metadata from usage-data/session-meta/*.json
struct SessionMeta: Codable, Identifiable {
    var id: String { session_id ?? UUID().uuidString }

    let session_id: String?
    let project_path: String?
    let start_time: String?
    let duration_minutes: Int?
    let user_message_count: Int?
    let assistant_message_count: Int?
    let tool_counts: [String: Int]?
    let languages: [String: Int]?
    let git_commits: Int?
    let git_pushes: Int?
    let input_tokens: Int?
    let output_tokens: Int?
    let first_prompt: String?
    let lines_added: Int?
    let lines_removed: Int?
    let files_modified: Int?
}

/// Facet summary from usage-data/facets/*.json
struct SessionFacet: Codable, Identifiable {
    var id: String { session_id ?? UUID().uuidString }

    let session_id: String?
    let underlying_goal: String?
    let outcome: String?
    let claude_helpfulness: String?
    let session_type: String?
    let brief_summary: String?
    let goal_categories: [String: Int]?
}

/// Disk usage breakdown
struct DiskUsage {
    var entries: [DirEntry] = []
    var totalBytes: UInt64 = 0

    struct DirEntry: Identifiable {
        let id = UUID()
        let name: String
        let path: URL
        let bytes: UInt64
        let fileCount: Int

        var formattedSize: String {
            ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
        }
    }

    static func scan() -> DiskUsage {
        let claudeDir = claudeDirURL()
        let fm = FileManager.default

        guard let contents = try? fm.contentsOfDirectory(at: claudeDir, includingPropertiesForKeys: nil)
        else { return DiskUsage() }

        var usage = DiskUsage()

        for item in contents {
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: item.path, isDirectory: &isDir) else { continue }

            if isDir.boolValue {
                let (bytes, count) = dirSize(item)
                usage.entries.append(DirEntry(name: item.lastPathComponent, path: item, bytes: bytes, fileCount: count))
                usage.totalBytes += bytes
            } else {
                if let attrs = try? fm.attributesOfItem(atPath: item.path),
                   let size = attrs[.size] as? UInt64 {
                    usage.entries.append(DirEntry(name: item.lastPathComponent, path: item, bytes: size, fileCount: 1))
                    usage.totalBytes += size
                }
            }
        }

        usage.entries.sort { $0.bytes > $1.bytes }
        return usage
    }

    private static func dirSize(_ url: URL) -> (UInt64, Int) {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) else {
            return (0, 0)
        }
        var total: UInt64 = 0
        var count = 0
        for case let file as URL in enumerator {
            if let size = try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                total += UInt64(size)
                count += 1
            }
        }
        return (total, count)
    }
}
