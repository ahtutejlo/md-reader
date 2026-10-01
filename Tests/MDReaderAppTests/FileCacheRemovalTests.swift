import Testing
import Foundation
@testable import MDReaderApp

@Test func fileCacheRemoveFilesDropsOnlyGivenPaths() throws {
    let cacheURL = FileManager.default.temporaryDirectory.appendingPathComponent("cache-\(UUID()).json")
    let notes = try (0..<4).map { _ in try writeTempNote() }
    defer {
        for note in notes { try? FileManager.default.removeItem(at: note) }
        try? FileManager.default.removeItem(at: cacheURL)
    }

    let cache = FileCache(cacheURL: cacheURL)
    for note in notes { cache.addFile(url: note) }
    cache.toggleFavorite(path: notes[3].path)

    cache.removeFiles(paths: [notes[0].path, notes[2].path])

    #expect(Set(cache.files.map(\.path)) == [notes[1].path, notes[3].path])
    #expect(cache.files.first { $0.path == notes[3].path }?.isFavorite == true)

    let reloaded = FileCache(cacheURL: cacheURL)
    #expect(Set(reloaded.files.map(\.path)) == [notes[1].path, notes[3].path], "removal must be saved to disk")

    reloaded.removeFiles(paths: Set(reloaded.files.map(\.path)))
    #expect(reloaded.files.isEmpty)
    #expect(FileCache(cacheURL: cacheURL).files.isEmpty, "emptied list must be saved to disk")
}

@Test func fileCacheRemoveFilesIgnoresUnknownPaths() throws {
    let cacheURL = FileManager.default.temporaryDirectory.appendingPathComponent("cache-\(UUID()).json")
    let note = try writeTempNote()
    defer {
        try? FileManager.default.removeItem(at: note)
        try? FileManager.default.removeItem(at: cacheURL)
    }

    let cache = FileCache(cacheURL: cacheURL)
    cache.addFile(url: note)

    cache.removeFiles(paths: ["/nowhere/unknown.md"])

    #expect(cache.files.map(\.path) == [note.path])
}
