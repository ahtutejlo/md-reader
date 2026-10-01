import Foundation
import Testing
@testable import MDReaderApp

private func cacheLocation() -> URL {
    FileManager.default.temporaryDirectory.appendingPathComponent("cache-\(UUID()).json")
}

@Test func cachedFileWithoutLastLineStillDecodes() throws {
    let json = #"{"path":"/tmp/test.md","lastOpened":"2024-01-01T00:00:00Z","isFavorite":true}"#
    let decoded = try JSONDecoder.iso8601.decode(CachedFile.self, from: Data(json.utf8))
    #expect(decoded.path == "/tmp/test.md")
    #expect(decoded.isFavorite == true)
    #expect(decoded.lastLine == nil)
}

@Test func fileCacheRemembersLastLineAcrossRelaunch() throws {
    let note = try writeTempNote()
    let cacheURL = cacheLocation()
    defer {
        try? FileManager.default.removeItem(at: note)
        try? FileManager.default.removeItem(at: cacheURL)
    }
    let cache = FileCache(cacheURL: cacheURL)
    cache.addFile(url: note)
    #expect(cache.lastLine(for: note.path) == nil)

    cache.setLastLine(42, for: note.path)

    #expect(cache.lastLine(for: note.path) == 42)
    #expect(FileCache(cacheURL: cacheURL).lastLine(for: note.path) == 42)
}

@Test func fileCacheKeepsLastLineWhenFileReopened() throws {
    let note = try writeTempNote()
    let cacheURL = cacheLocation()
    defer {
        try? FileManager.default.removeItem(at: note)
        try? FileManager.default.removeItem(at: cacheURL)
    }
    let cache = FileCache(cacheURL: cacheURL)
    cache.addFile(url: note)
    cache.setLastLine(42, for: note.path)

    cache.addFile(url: note)

    #expect(cache.lastLine(for: note.path) == 42)
    #expect(FileCache(cacheURL: cacheURL).lastLine(for: note.path) == 42)
}

@Test func setLastLineForUnknownPathChangesNothing() throws {
    let note = try writeTempNote()
    let cacheURL = cacheLocation()
    let unknown = "/nowhere/\(UUID()).md"
    defer {
        try? FileManager.default.removeItem(at: note)
        try? FileManager.default.removeItem(at: cacheURL)
    }
    let cache = FileCache(cacheURL: cacheURL)
    cache.addFile(url: note)
    let savedAt = Date(timeIntervalSince1970: 1_750_000_000)
    try setModificationDate(of: cacheURL, to: savedAt)

    cache.setLastLine(7, for: unknown)

    #expect(cache.files.map(\.path) == [note.path])
    #expect(cache.lastLine(for: note.path) == nil)
    #expect(cache.lastLine(for: unknown) == nil)
    #expect(try modificationDate(of: cacheURL) == savedAt, "cache file must not be rewritten")
}
