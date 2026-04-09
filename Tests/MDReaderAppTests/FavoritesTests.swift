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
    let cacheURL = FileManager.default.temporaryDirectory.appendingPathComponent("cache-\(UUID()).json")
    defer {
        try? FileManager.default.removeItem(at: tmp)
        try? FileManager.default.removeItem(at: cacheURL)
    }

    let cache = FileCache(cacheURL: cacheURL)
    cache.addFile(url: tmp)
    #expect(cache.files.first?.isFavorite == false)

    cache.toggleFavorite(path: tmp.path)
    #expect(cache.files.first?.isFavorite == true)

    cache.toggleFavorite(path: tmp.path)
    #expect(cache.files.first?.isFavorite == false)
}

@Test func fileCacheLoadFiltersDeletedFiles() throws {
    let cacheURL = FileManager.default.temporaryDirectory.appendingPathComponent("cache-\(UUID()).json")
    let alive = FileManager.default.temporaryDirectory.appendingPathComponent("alive-\(UUID()).md")
    let dead = FileManager.default.temporaryDirectory.appendingPathComponent("dead-\(UUID()).md")
    try "# Alive".write(to: alive, atomically: true, encoding: .utf8)
    try "# Dead".write(to: dead, atomically: true, encoding: .utf8)
    defer {
        try? FileManager.default.removeItem(at: alive)
        try? FileManager.default.removeItem(at: dead)
        try? FileManager.default.removeItem(at: cacheURL)
    }

    let cache = FileCache(cacheURL: cacheURL)
    cache.addFile(url: alive)
    cache.addFile(url: dead)
    #expect(cache.files.count == 2)

    try FileManager.default.removeItem(at: dead)

    let reloaded = FileCache(cacheURL: cacheURL)
    #expect(reloaded.files.count == 1)
    #expect(reloaded.files.first?.path == alive.path)
}

@Test func fileCacheLoadPreservesUnreachableVolumeEntries() throws {
    // Simulate a file on an unmounted external volume: both the file and its
    // parent directory are absent. load() should keep the entry so favorites
    // on temporarily offline volumes don't silently disappear.
    let cacheURL = FileManager.default.temporaryDirectory.appendingPathComponent("cache-\(UUID()).json")
    let offlineParent = FileManager.default.temporaryDirectory.appendingPathComponent("offline-\(UUID())", isDirectory: true)
    let offlineFile = offlineParent.appendingPathComponent("note.md")
    try FileManager.default.createDirectory(at: offlineParent, withIntermediateDirectories: true)
    try "# Offline".write(to: offlineFile, atomically: true, encoding: .utf8)
    defer {
        try? FileManager.default.removeItem(at: offlineParent)
        try? FileManager.default.removeItem(at: cacheURL)
    }

    let cache = FileCache(cacheURL: cacheURL)
    cache.addFile(url: offlineFile)
    #expect(cache.files.count == 1)

    // Unmount the "volume": remove the entire parent directory.
    try FileManager.default.removeItem(at: offlineParent)

    let reloaded = FileCache(cacheURL: cacheURL)
    #expect(reloaded.files.count == 1)
    #expect(reloaded.files.first?.path == offlineFile.path)
}
