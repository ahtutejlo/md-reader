import Foundation

struct CachedFile: Identifiable, Codable, Equatable {
    var id: String { path }
    let path: String
    var lastOpened: Date
    var isFavorite: Bool = false
    var lastLine: Int?

    var name: String {
        URL(fileURLWithPath: path).lastPathComponent
    }

    var exists: Bool {
        FileManager.default.fileExists(atPath: path)
    }

    var displayPath: String {
        let home = NSHomeDirectory()
        if path == home {
            return "~"
        }
        let prefix = home + "/"
        if path.hasPrefix(prefix) {
            return "~/" + path.dropFirst(prefix.count)
        }
        return path
    }

    var displayDirectory: String {
        (displayPath as NSString).deletingLastPathComponent
    }

    enum CodingKeys: String, CodingKey {
        case path, lastOpened, isFavorite, lastLine
    }

    init(url: URL) throws {
        // Verify file exists by accessing attributes
        _ = try FileManager.default.attributesOfItem(atPath: url.path)
        self.path = url.path
        self.lastOpened = Date()
        self.isFavorite = false
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        path = try container.decode(String.self, forKey: .path)
        lastOpened = try container.decode(Date.self, forKey: .lastOpened)
        isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        lastLine = try container.decodeIfPresent(Int.self, forKey: .lastLine)
    }
}
