import Foundation

@Observable
class EditorViewModel {
    var text: String = ""
    var viewMode: ViewMode = .preview
    var hasUnsavedChanges: Bool = false
    var showExternalChangeAlert: Bool = false
    var loadError: Error?
    var saveError: Error?
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
    }

    func dismissExternalChange() {
        showExternalChangeAlert = false
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
            eventMask: [.write, .rename],
            queue: .main
        )
        source.setEventHandler { [weak self] in
            self?.handleExternalChange()
        }
        source.setCancelHandler {
            close(fd)
        }
        source.resume()
        fileMonitor = source
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
