import Foundation

@Observable
class EditorViewModel {
    var text: String = ""
    var viewMode: ViewMode = .preview
    var hasUnsavedChanges: Bool = false
    var showExternalChangeAlert: Bool = false
    var loadError: Error?
    var saveError: Error?
    var pendingFormat: MarkdownFormatAction?
    var activeLine: Int = 0
    private(set) var fileURL: URL?
    private(set) var textVersion: Int = 0

    private var fileMonitor: DispatchSourceFileSystemObject?
    private var autoSaveTask: DispatchWorkItem?
    private var isReloading = false

    func loadFile(url: URL) {
        autoSaveTask?.cancel()
        stopMonitoring()
        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            fileURL = url
            text = content
            hasUnsavedChanges = false
            showExternalChangeAlert = false
            loadError = nil
            textVersion += 1
            activeLine = 0
            startMonitoring()
        } catch {
            loadError = error
        }
    }

    func clearFile() {
        autoSaveTask?.cancel()
        stopMonitoring()
        fileURL = nil
        text = ""
        hasUnsavedChanges = false
        showExternalChangeAlert = false
        loadError = nil
        saveError = nil
        textVersion += 1
        activeLine = 0
    }

    func textDidChange() {
        guard !isReloading else { return }
        hasUnsavedChanges = true
        scheduleAutoSave()
    }

    func save() {
        guard let url = fileURL else { return }
        autoSaveTask?.cancel()
        stopMonitoring()
        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
            hasUnsavedChanges = false
            saveError = nil
        } catch {
            saveError = error
        }
        startMonitoring()
    }

    func handleExternalChange() {
        guard fileURL != nil else { return }
        if hasUnsavedChanges {
            showExternalChangeAlert = true
        } else {
            reloadFromDisk()
        }
    }

    func reloadFromDisk() {
        guard let url = fileURL,
              let content = try? String(contentsOf: url, encoding: .utf8) else { return }
        isReloading = true
        text = content
        hasUnsavedChanges = false
        showExternalChangeAlert = false
        isReloading = false
        textVersion += 1
        activeLine = 0
    }

    func dismissExternalChange() {
        showExternalChangeAlert = false
    }

    /// Toggle the GFM task marker (`[ ]` ↔ `[x]`) on the given 0-based source line.
    /// Triggered by clicks on rendered checkboxes in the preview WebView.
    func toggleTaskAt(line: Int) {
        var lines = text.components(separatedBy: "\n")
        guard lines.indices.contains(line) else { return }
        let source = lines[line]
        guard let regex = try? NSRegularExpression(pattern: #"^[ \t]*[-*]\s+\[([ xX])\]"#),
              let match = regex.firstMatch(in: source, range: NSRange(source.startIndex..., in: source)),
              let markerRange = Range(match.range(at: 1), in: source)
        else { return }
        let newMarker: Character = (source[markerRange] == " ") ? "x" : " "
        var newLine = source
        newLine.replaceSubrange(markerRange, with: String(newMarker))
        lines[line] = newLine
        text = lines.joined(separator: "\n")
        textDidChange()
    }

    // MARK: - Auto-save

    private func scheduleAutoSave() {
        autoSaveTask?.cancel()
        let task = DispatchWorkItem { [weak self] in
            self?.save()
        }
        autoSaveTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: task)
    }

    // MARK: - File Monitoring

    private func startMonitoring() {
        guard let url = fileURL else { return }
        let fd = open(url.path, O_EVTONLY)
        guard fd >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename, .delete],
            queue: .main
        )
        source.setEventHandler { [weak self, weak source] in
            guard let self, let source else { return }
            let events = source.data
            self.handleExternalChange()
            // Atomic writes (rename/delete) orphan the fd — re-establish on the path.
            if events.contains(.rename) || events.contains(.delete) {
                self.reopenMonitoring(attempt: 0)
            }
        }
        source.setCancelHandler {
            close(fd)
        }
        source.resume()
        fileMonitor = source
    }

    private func reopenMonitoring(attempt: Int) {
        fileMonitor?.cancel()
        fileMonitor = nil
        guard let url = fileURL else { return }
        if !FileManager.default.fileExists(atPath: url.path) {
            guard attempt < 3 else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                self?.reopenMonitoring(attempt: attempt + 1)
            }
            return
        }
        startMonitoring()
    }

    private func stopMonitoring() {
        fileMonitor?.cancel()
        fileMonitor = nil
    }

    deinit {
        autoSaveTask?.cancel()
        stopMonitoring()
    }
}
