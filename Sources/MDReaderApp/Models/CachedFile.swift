import Foundation

struct CachedFile: Identifiable, Codable, Equatable {
    var id: String { path }
    let path: String
    var lastOpened: Date

    var name: String {
        URL(fileURLWithPath: path).lastPathComponent
    }

    var exists: Bool {
        FileManager.default.fileExists(atPath: path)
    }

    enum CodingKeys: String, CodingKey {
        case path, lastOpened
    }

    init(url: URL) throws {
        // Verify file exists by accessing attributes
        _ = try FileManager.default.attributesOfItem(atPath: url.path)
        self.path = url.path
        self.lastOpened = Date()
    }
}
