import Testing
import Foundation
@testable import MDReaderApp

@Test func cachedFileDefaultNotFavorite() throws {
    let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("fav-\(UUID()).md")
    try "# Test".write(to: tmp, atomically: true, encoding: .utf8)
    defer { try? FileManager.default.removeItem(at: tmp) }

    let file = try CachedFile(url: tmp)
    #expect(file.isFavorite == false)
}

@Test func cachedFileFavoriteSerializes() throws {
    let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("fav-\(UUID()).md")
    try "# Test".write(to: tmp, atomically: true, encoding: .utf8)
    defer { try? FileManager.default.removeItem(at: tmp) }

    var file = try CachedFile(url: tmp)
    file.isFavorite = true

    let data = try JSONEncoder.iso8601.encode(file)
    let decoded = try JSONDecoder.iso8601.decode(CachedFile.self, from: data)
    #expect(decoded.isFavorite == true)
}

@Test func cachedFileBackwardCompatibility() throws {
    let json = """
    {"path":"/tmp/test.md","lastOpened":"2024-01-01T00:00:00Z"}
    """
    let data = json.data(using: .utf8)!
    let decoded = try JSONDecoder.iso8601.decode(CachedFile.self, from: data)
    #expect(decoded.isFavorite == false)
}

@Test func fileCacheToggleFavorite() throws {
    let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("fav-\(UUID()).md")
    try "# Test".write(to: tmp, atomically: true, encoding: .utf8)
    defer { try? FileManager.default.removeItem(at: tmp) }

    let cache = FileCache()
    cache.addFile(url: tmp)
    #expect(cache.files.first?.isFavorite == false)

    cache.toggleFavorite(path: tmp.path)
    #expect(cache.files.first?.isFavorite == true)

    cache.toggleFavorite(path: tmp.path)
    #expect(cache.files.first?.isFavorite == false)
}
