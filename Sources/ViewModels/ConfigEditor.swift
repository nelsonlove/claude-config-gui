import SwiftUI

@Observable
final class ConfigEditor {
    var settings: ClaudeSettings
    /// Merged settings from parent scopes (read-only). Used to show inherited values.
    var inherited: ClaudeSettings?
    var isDirty: Bool = false
    var loadError: String?
    var lastSaved: Date?
    var rawJSON: String = ""
    var rawJSONError: String?

    let scope: ConfigScope
    let fileURL: URL
    let projectRoot: URL?
    let undoManager = UndoManager()

    private var saveTask: Task<Void, Never>?
    private var fileMonitorSource: DispatchSourceFileSystemObject?
    private var fileDescriptor: Int32 = -1
    private var suppressNextReload = false

    init(scope: ConfigScope, projectRoot: URL? = nil) {
        self.scope = scope
        self.projectRoot = projectRoot
        self.fileURL = scope.fileURL(projectRoot: projectRoot)
        self.settings = ClaudeSettings()
    }

    deinit {
        stopWatching()
    }

    // MARK: - Load

    func load() {
        do {
            let data = try Data(contentsOf: fileURL)
            settings = try JSONDecoder().decode(ClaudeSettings.self, from: data)
            isDirty = false
            loadError = nil
            undoManager.removeAllActions()
            loadInherited()
            startWatching()
        } catch let error as DecodingError {
            loadError = "Parse error: \(error.localizedDescription)"
        } catch {
            if (error as NSError).code == NSFileReadNoSuchFileError {
                settings = ClaudeSettings()
                isDirty = false
                loadError = nil
            } else {
                loadError = "Load error: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Save (debounced)

    func markDirty() {
        isDirty = true
        scheduleSave()
    }

    /// Call before mutating settings to register an undo snapshot.
    func registerUndo() {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        undoManager.registerUndo(withTarget: self) { editor in
            editor.registerUndo()
            if let previous = try? JSONDecoder().decode(ClaudeSettings.self, from: data) {
                editor.settings = previous
                editor.markDirty()
            }
        }
    }

    /// Registers undo, applies the mutation, and marks dirty.
    func mutate(_ block: (inout ClaudeSettings) -> Void) {
        registerUndo()
        block(&settings)
        markDirty()
    }

    /// A Binding to settings that registers undo on each set.
    var settingsBinding: Binding<ClaudeSettings> {
        Binding(
            get: { self.settings },
            set: { newValue in self.mutate { $0 = newValue } }
        )
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.save()
            }
        }
    }

    func save() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            let data = try encoder.encode(settings)

            let dir = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

            suppressNextReload = true
            try data.write(to: fileURL, options: .atomic)
            isDirty = false
            lastSaved = Date()
            loadError = nil
        } catch {
            loadError = "Save error: \(error.localizedDescription)"
        }
    }

    // MARK: - Inherited settings

    /// Load parent scope settings for ghost value display.
    /// Precedence: Local overrides Project overrides User.
    private func loadInherited() {
        var parentURLs: [URL] = []
        let home = FileManager.default.homeDirectoryForCurrentUser
        let userURL = claudePath("settings.json")

        switch scope {
        case .user:
            inherited = nil
            return
        case .project:
            parentURLs = [userURL]
        case .local:
            let projectURL = ConfigScope.project.fileURL(projectRoot: projectRoot)
            parentURLs = [userURL, projectURL]
        }

        // Merge parent scopes: later entries override earlier ones for scalar fields
        var merged = ClaudeSettings()
        for url in parentURLs {
            guard let data = try? Data(contentsOf: url),
                  let layer = try? JSONDecoder().decode(ClaudeSettings.self, from: data) else { continue }
            merged = mergeSettings(base: merged, overlay: layer)
        }
        inherited = merged
    }

    /// Shallow merge: overlay's non-nil values replace base.
    /// For arrays (permissions), concatenates.
    private func mergeSettings(base: ClaudeSettings, overlay: ClaudeSettings) -> ClaudeSettings {
        // Encode both, merge as dictionaries, decode back
        guard let baseData = try? JSONEncoder().encode(base),
              let overlayData = try? JSONEncoder().encode(overlay),
              var baseDict = try? JSONSerialization.jsonObject(with: baseData) as? [String: Any],
              let overlayDict = try? JSONSerialization.jsonObject(with: overlayData) as? [String: Any] else {
            return overlay
        }

        for (key, value) in overlayDict {
            if let baseArray = baseDict[key] as? [Any], let overlayArray = value as? [Any] {
                // Arrays: concatenate (like Claude Code does for permissions.allow etc.)
                baseDict[key] = baseArray + overlayArray
            } else {
                baseDict[key] = value
            }
        }

        guard let mergedData = try? JSONSerialization.data(withJSONObject: baseDict),
              let merged = try? JSONDecoder().decode(ClaudeSettings.self, from: mergedData) else {
            return overlay
        }
        return merged
    }

    // MARK: - Effective config

    /// The fully merged settings as Claude Code would see them.
    /// User → Project → Local, with the current scope applied last.
    var effectiveSettings: ClaudeSettings {
        guard let base = inherited else { return settings }
        return mergeSettings(base: base, overlay: settings)
    }

    var effectiveJSON: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(effectiveSettings),
              let json = String(data: data, encoding: .utf8) else {
            return "{ }"
        }
        return json
    }

    // MARK: - Raw JSON

    func syncRawFromSettings() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        if let data = try? encoder.encode(settings),
           let json = String(data: data, encoding: .utf8) {
            rawJSON = json
            rawJSONError = nil
        }
    }

    func syncSettingsFromRaw() -> Bool {
        guard let data = rawJSON.data(using: .utf8) else {
            rawJSONError = "Invalid text encoding"
            return false
        }
        do {
            registerUndo()
            settings = try JSONDecoder().decode(ClaudeSettings.self, from: data)
            rawJSONError = nil
            markDirty()
            return true
        } catch {
            rawJSONError = error.localizedDescription
            return false
        }
    }

    // MARK: - File watching

    private func startWatching() {
        stopWatching()

        fileDescriptor = open(fileURL.path, O_EVTONLY)
        guard fileDescriptor >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .rename, .delete],
            queue: .main
        )

        source.setEventHandler { [weak self] in
            guard let self, !self.suppressNextReload else {
                self?.suppressNextReload = false
                return
            }
            self.load()
        }

        source.setCancelHandler { [weak self] in
            if let fd = self?.fileDescriptor, fd >= 0 {
                close(fd)
            }
            self?.fileDescriptor = -1
        }

        source.resume()
        fileMonitorSource = source
    }

    private func stopWatching() {
        fileMonitorSource?.cancel()
        fileMonitorSource = nil
    }
}
