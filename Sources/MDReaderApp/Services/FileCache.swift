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

    func removeFile(_ file: CachedFile) {
        files.removeAll { $0.id == file.id }
        save()
    }

    func toggleFavorite(path: String) {
        guard let index = files.firstIndex(where: { $0.path == path }) else { return }
        files[index].isFavorite.toggle()
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: cacheURL),
              let decoded = try? JSONDecoder.iso8601.decode([CachedFile].self, from: data) else {
            return
        }
        let existing = decoded.filter { Self.shouldKeep(cached: $0) }
        files = existing
        if existing.count != decoded.count {
            save()
        }
    }

    /// Keep a cached entry if its file exists, OR if its parent directory is
    /// unreachable (e.g. unmounted external/network volume) — we can't tell a
    /// deleted file apart from a temporarily offline one, so err on the side of
    /// preserving user favorites.
    private static func shouldKeep(cached: CachedFile) -> Bool {
        let fm = FileManager.default
        if fm.fileExists(atPath: cached.path) { return true }
        let parent = (cached.path as NSString).deletingLastPathComponent
        return !fm.fileExists(atPath: parent)
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
