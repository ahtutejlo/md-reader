import Foundation

@Observable
class FileCache {
    private(set) var files: [CachedFile] = []
    private let cacheURL: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("MDReader", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        cacheURL = dir.appendingPathComponent("cache.json")
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
        files = decoded
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
