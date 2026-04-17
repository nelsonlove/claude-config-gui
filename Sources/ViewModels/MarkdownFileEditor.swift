import SwiftUI

/// Manages loading, editing, and saving a single markdown file.
@Observable
final class MarkdownFileEditor {
    var content: String = ""
    var isDirty: Bool = false
    var loadError: String?
    var fileURL: URL?

    private var saveTask: Task<Void, Never>?

    func load(from url: URL) {
        fileURL = url
        do {
            content = try String(contentsOf: url, encoding: .utf8)
            isDirty = false
            loadError = nil
        } catch {
            if (error as NSError).code == NSFileReadNoSuchFileError {
                content = ""
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
            await MainActor.run {
                self?.save()
            }
        }
    }

    func save() {
        guard let fileURL else { return }
        do {
            let dir = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            isDirty = false
            loadError = nil
        } catch {
            loadError = "Save error: \(error.localizedDescription)"
        }
    }
}
