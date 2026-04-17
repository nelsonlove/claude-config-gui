import Foundation
import Combine

@Observable
final class ConfigEditor {
    var settings: ClaudeSettings
    var isDirty: Bool = false
    var loadError: String?
    var lastSaved: Date?

    let scope: ConfigScope
    let fileURL: URL

    private var saveTask: Task<Void, Never>?
    private var fileMonitorSource: DispatchSourceFileSystemObject?
    private var fileDescriptor: Int32 = -1
    private var suppressNextReload = false

    init(scope: ConfigScope, projectRoot: URL? = nil) {
        self.scope = scope
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
            let decoder = JSONDecoder()
            settings = try decoder.decode(ClaudeSettings.self, from: data)
            isDirty = false
            loadError = nil
            startWatching()
        } catch let error as DecodingError {
            loadError = "Parse error: \(error.localizedDescription)"
        } catch {
            if (error as NSError).code == NSFileReadNoSuchFileError {
                // File doesn't exist yet — start with empty settings
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

            // Ensure parent directory exists
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
