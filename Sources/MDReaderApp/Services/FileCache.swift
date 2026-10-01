import Foundation

@Observable
class FileCache {
    private(set) var files: [CachedFile] = []
    private let cacheURL: URL

    init(cacheURL: URL? = nil) {
        if let cacheURL {
            self.cacheURL = cacheURL
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let dir = appSupport.appendingPathComponent("MDReader", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            self.cacheURL = dir.appendingPathComponent("cache.json")
        }
        load()
    }

    func addFile(url: URL) {
        if let index = files.firstIndex(where: { $0.path == url.path }) {
            files[index].lastOpened = Date()
        } else {
            guard let file = try? CachedFile(url: url) else { return }
            files.append(file)
        }
        files.sort { $0.lastOpened > $1.lastOpened }
        save()
    }

    func removeFiles(paths: Set<String>) {
        guard files.contains(where: { paths.contains($0.path) }) else { return }
        files.removeAll { paths.contains($0.path) }
        save()
    }

    func toggleFavorite(path: String) {
        guard let index = files.firstIndex(where: { $0.path == path }) else { return }
        files[index].isFavorite.toggle()
        save()
    }

    func lastLine(for path: String) -> Int? {
        files.first { $0.path == path }?.lastLine
    }

    func setLastLine(_ line: Int, for path: String) {
        guard let index = files.firstIndex(where: { $0.path == path }), files[index].lastLine != line else { return }
        files[index].lastLine = line
        save()
    }

    func pruneMissingFiles(keeping keptPath: String? = nil) {
        let kept = files.filter { $0.path == keptPath || Self.shouldKeep(path: $0.path) }
        guard kept.count != files.count else { return }
        files = kept
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: cacheURL),
              let decoded = try? JSONDecoder.iso8601.decode([CachedFile].self, from: data) else {
            return
        }
        files = decoded
        pruneMissingFiles()
    }

    /// A missing file on an unmounted external volume may come back, so its
    /// entry is kept; anywhere else a missing file means it was deleted.
    private static func shouldKeep(path: String) -> Bool {
        let fm = FileManager.default
        if fm.fileExists(atPath: path) { return true }
        let components = (path as NSString).pathComponents
        guard components.count > 2, components[1] == "Volumes" else { return false }
        let volumeRoot = NSString.path(withComponents: Array(components.prefix(3)))
        return !fm.fileExists(atPath: volumeRoot)
    }

    private func save() {
        guard let data = try? JSONEncoder.iso8601.encode(files) else { return }
        try? data.write(to: cacheURL, options: .atomic)
    }
}

extension JSONDecoder {
    static let iso8601: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}

extension JSONEncoder {
    static let iso8601: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = .prettyPrinted
        return e
    }()
}
