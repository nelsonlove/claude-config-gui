import Foundation

/// Caches the result of scanning each session transcript for its last `custom-title` line.
///
/// Invalidation is automatic: each lookup stats the transcript file and re-scans only
/// when the mtime or size has changed. JSONL transcripts are append-only, so growth
/// (new bytes, new mtime) is the only way the title can change.
///
/// Persisted as JSON at ~/.cache/claude-config/title-cache.json.
struct SessionTitleCache {
    private struct Entry: Codable {
        var title: String?
        var mtime: Double
        var size: Int64
    }

    private var entries: [String: Entry]
    private var dirty: Bool = false

    private static let cacheURL: URL = {
        let cacheRoot = (ProcessInfo.processInfo.environment["XDG_CACHE_HOME"].map { URL(fileURLWithPath: $0) })
            ?? homeURL().appendingPathComponent(".cache")
        return cacheRoot.appendingPathComponent("claude-config/title-cache.json")
    }()

    static func load() -> SessionTitleCache {
        guard let data = try? Data(contentsOf: cacheURL),
              let entries = try? JSONDecoder().decode([String: Entry].self, from: data)
        else { return SessionTitleCache(entries: [:]) }
        return SessionTitleCache(entries: entries)
    }

    /// Returns the cached title for `sessionId` if the transcript at `url` hasn't changed,
    /// otherwise rescans, updates the cache, and returns the fresh value.
    mutating func title(for sessionId: String, at url: URL) -> String? {
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        let mtime = (attrs?[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
        let size = (attrs?[.size] as? NSNumber)?.int64Value ?? 0

        if let entry = entries[sessionId], entry.mtime == mtime, entry.size == size {
            return entry.title
        }

        let title = SessionHistory.scanLastCustomTitle(at: url)
        entries[sessionId] = Entry(title: title, mtime: mtime, size: size)
        dirty = true
        return title
    }

    /// Drop cache entries for sessions whose transcripts no longer exist.
    mutating func pruneMissing(keeping liveIDs: Set<String>) {
        let stale = Set(entries.keys).subtracting(liveIDs)
        guard !stale.isEmpty else { return }
        for id in stale { entries.removeValue(forKey: id) }
        dirty = true
    }

    func saveIfDirty() {
        guard dirty else { return }
        let dir = Self.cacheURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(entries) {
            try? data.write(to: Self.cacheURL, options: .atomic)
        }
    }
}
