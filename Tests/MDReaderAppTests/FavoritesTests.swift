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

@Test func fileCacheLoadDropsFileInDeletedFolder() throws {
    let cacheURL = FileManager.default.temporaryDirectory.appendingPathComponent("cache-\(UUID()).json")
    let alive = FileManager.default.temporaryDirectory.appendingPathComponent("alive-\(UUID()).md")
    let deletedFolder = FileManager.default.temporaryDirectory.appendingPathComponent("deleted-\(UUID())", isDirectory: true)
    let fileInDeletedFolder = deletedFolder.appendingPathComponent("note.md")
    try FileManager.default.createDirectory(at: deletedFolder, withIntermediateDirectories: true)
    try "# Gone".write(to: fileInDeletedFolder, atomically: true, encoding: .utf8)
    try "# Alive".write(to: alive, atomically: true, encoding: .utf8)
    defer {
        try? FileManager.default.removeItem(at: deletedFolder)
        try? FileManager.default.removeItem(at: alive)
        try? FileManager.default.removeItem(at: cacheURL)
    }

    let cache = FileCache(cacheURL: cacheURL)
    cache.addFile(url: fileInDeletedFolder)
    cache.addFile(url: alive)
    #expect(cache.files.count == 2)

    try FileManager.default.removeItem(at: deletedFolder)

    let reloaded = FileCache(cacheURL: cacheURL)
    #expect(reloaded.files.map(\.path) == [alive.path])
}

@Test func fileCacheKeepsEntryOnUnmountedVolume() throws {
    let cacheURL = FileManager.default.temporaryDirectory.appendingPathComponent("cache-\(UUID()).json")
    let alive = FileManager.default.temporaryDirectory.appendingPathComponent("alive-\(UUID()).md")
    let offlinePath = "/Volumes/mdreader-offline-\(UUID())/note.md"
    try "# Alive".write(to: alive, atomically: true, encoding: .utf8)
    defer {
        try? FileManager.default.removeItem(at: alive)
        try? FileManager.default.removeItem(at: cacheURL)
    }
    try writeCache(paths: [offlinePath, alive.path], to: cacheURL)

    let cache = FileCache(cacheURL: cacheURL)
    #expect(cache.files.map(\.path) == [offlinePath, alive.path])

    cache.pruneMissingFiles()
    #expect(cache.files.map(\.path) == [offlinePath, alive.path])
}

@Test(.enabled(if: mountedVolume != nil, "no mounted volume under /Volumes"))
func fileCacheDropsMissingFileOnMountedVolume() throws {
    let volume = try #require(mountedVolume)
    let cacheURL = FileManager.default.temporaryDirectory.appendingPathComponent("cache-\(UUID()).json")
    let alive = FileManager.default.temporaryDirectory.appendingPathComponent("alive-\(UUID()).md")
    let missingOnVolume = "/Volumes/\(volume)/mdreader-missing-\(UUID()).md"
    try "# Alive".write(to: alive, atomically: true, encoding: .utf8)
    defer {
        try? FileManager.default.removeItem(at: alive)
        try? FileManager.default.removeItem(at: cacheURL)
    }
    try writeCache(paths: [missingOnVolume, alive.path], to: cacheURL)

    let cache = FileCache(cacheURL: cacheURL)
    #expect(cache.files.map(\.path) == [alive.path])
}

@Test func fileCachePruneKeepsOpenMissingFileOnlyUntilRelaunch() throws {
    let tmp = FileManager.default.temporaryDirectory
    let cacheURL = tmp.appendingPathComponent("cache-\(UUID()).json")
    let alive = tmp.appendingPathComponent("alive-\(UUID()).md")
    let deletedOpen = tmp.appendingPathComponent("deleted-open-\(UUID()).md")
    let deletedOther = tmp.appendingPathComponent("deleted-other-\(UUID()).md")
    for file in [alive, deletedOpen, deletedOther] {
        try "# Note".write(to: file, atomically: true, encoding: .utf8)
    }
    defer {
        for file in [alive, deletedOpen, deletedOther, cacheURL] {
            try? FileManager.default.removeItem(at: file)
        }
    }

    let cache = FileCache(cacheURL: cacheURL)
    for file in [alive, deletedOpen, deletedOther] {
        cache.addFile(url: file)
    }
    try FileManager.default.removeItem(at: deletedOpen)
    try FileManager.default.removeItem(at: deletedOther)

    cache.pruneMissingFiles(keeping: deletedOpen.path)
    #expect(cache.files.map(\.path).sorted() == [alive.path, deletedOpen.path].sorted())

    let saved = try JSONDecoder.iso8601.decode([CachedFile].self, from: Data(contentsOf: cacheURL))
    #expect(saved.map(\.path).sorted() == [alive.path, deletedOpen.path].sorted(), "prune must be saved to disk")

    let relaunched = FileCache(cacheURL: cacheURL)
    #expect(relaunched.files.map(\.path) == [alive.path])
}

@Test func fileCacheDropsMissingFavorite() throws {
    let cacheURL = FileManager.default.temporaryDirectory.appendingPathComponent("cache-\(UUID()).json")
    let alive = FileManager.default.temporaryDirectory.appendingPathComponent("alive-\(UUID()).md")
    let favorite = FileManager.default.temporaryDirectory.appendingPathComponent("favorite-\(UUID()).md")
    try "# Alive".write(to: alive, atomically: true, encoding: .utf8)
    try "# Favorite".write(to: favorite, atomically: true, encoding: .utf8)
    defer {
        try? FileManager.default.removeItem(at: alive)
        try? FileManager.default.removeItem(at: favorite)
        try? FileManager.default.removeItem(at: cacheURL)
    }

    let cache = FileCache(cacheURL: cacheURL)
    cache.addFile(url: alive)
    cache.addFile(url: favorite)
    cache.toggleFavorite(path: favorite.path)
    #expect(cache.files.first { $0.path == favorite.path }?.isFavorite == true)

    try FileManager.default.removeItem(at: favorite)
    cache.pruneMissingFiles()

    #expect(cache.files.map(\.path) == [alive.path])
}

private let mountedVolume: String? = (try? FileManager.default.contentsOfDirectory(atPath: "/Volumes"))?
    .first { !$0.hasPrefix(".") }

private func writeCache(paths: [String], to url: URL) throws {
    let lastOpened = ISO8601DateFormatter().string(from: Date())
    let entries = paths.map { ["path": $0, "lastOpened": lastOpened] }
    try JSONSerialization.data(withJSONObject: entries).write(to: url)
}
