import Foundation
import Testing
@testable import MDReaderApp

@Test(arguments: [
    ("# План\n\nДруга лінія зі Словом тут\nкінець", "слово", "Друга лінія зі Словом тут"),
    ("# Menu\n\nMenu du Café de Flore\n", "cafe", "Menu du Café de Flore"),
    ("first\r\n\t  indented needle line  \r\nthird", "NEEDLE", "indented needle line"),
])
func snippetReturnsMatchingLine(_ text: String, _ query: String, _ expected: String) throws {
    let note = try writeTempNote(text)
    defer { try? FileManager.default.removeItem(at: note) }

    #expect(FileContentIndex().snippet(in: note.path, matching: query) == expected)
}

@Test func snippetCutsLongLineBeforeMatch() throws {
    let note = try writeTempNote("intro\ncut this part 123456789 123456789 123456789 needle and the rest\n")
    defer { try? FileManager.default.removeItem(at: note) }

    #expect(FileContentIndex().snippet(in: note.path, matching: "needle") == "…123456789 123456789 123456789 needle and the rest")
}

@Test func snippetIsNilWithoutMatch() throws {
    let note = try writeTempNote("# Plan\n\nnothing to see here")
    defer { try? FileManager.default.removeItem(at: note) }

    #expect(FileContentIndex().snippet(in: note.path, matching: "needle") == nil)
}

@Test func snippetIsNilForMissingFile() {
    let missing = FileManager.default.temporaryDirectory.appendingPathComponent("missing-\(UUID()).md")
    #expect(FileContentIndex().snippet(in: missing.path, matching: "needle") == nil)
}

@Test func snippetPicksUpEditOnDisk() throws {
    let note = try writeTempNote("old wording")
    defer { try? FileManager.default.removeItem(at: note) }
    try setModificationDate(of: note, to: Date(timeIntervalSince1970: 1_750_000_000))
    let index = FileContentIndex()
    #expect(index.snippet(in: note.path, matching: "wording") == "old wording")
    #expect(index.snippet(in: note.path, matching: "fresh") == nil)

    try "fresh wording".write(to: note, atomically: true, encoding: .utf8)
    try setModificationDate(of: note, to: Date(timeIntervalSince1970: 1_750_000_060))

    #expect(index.snippet(in: note.path, matching: "fresh") == "fresh wording")
    #expect(index.snippet(in: note.path, matching: "old") == nil)
}

@Test(arguments: [
    ("123456789 123456789 123456789 needle", 30, "123456789 123456789 123456789 needle"),
    ("X123456789 123456789 123456789 needle", 30, "…123456789 123456789 123456789 needle"),
    ("abcdefghij needle end", 5, "…ghij needle end"),
])
func snippetKeepsContextBeforeMatch(_ line: String, _ context: Int, _ expected: String) throws {
    let text = "heading\n\(line)\nnext line"
    let match = try #require(text.range(of: "needle"))
    #expect(FileContentIndex.snippet(of: text, around: match, context: context) == expected)
}
