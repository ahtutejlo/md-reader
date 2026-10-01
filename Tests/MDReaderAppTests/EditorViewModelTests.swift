import Testing
import Foundation
@testable import MDReaderApp

@Test func initialState() {
    let vm = EditorViewModel()
    #expect(vm.text == "")
    #expect(vm.viewMode == .preview)
    #expect(vm.hasUnsavedChanges == false)
    #expect(vm.fileURL == nil)
}

@Test func loadFile() throws {
    let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("test-\(UUID()).md")
    try "# Hello".write(to: tmp, atomically: true, encoding: .utf8)
    defer { try? FileManager.default.removeItem(at: tmp) }

    let vm = EditorViewModel()
    vm.loadFile(url: tmp)
    #expect(vm.text == "# Hello")
    #expect(vm.fileURL == tmp)
    #expect(vm.hasUnsavedChanges == false)
}

@Test func textChangeMarksUnsaved() throws {
    let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("test-\(UUID()).md")
    try "original".write(to: tmp, atomically: true, encoding: .utf8)
    defer { try? FileManager.default.removeItem(at: tmp) }

    let vm = EditorViewModel()
    vm.loadFile(url: tmp)
    vm.text = "modified"
    vm.textDidChange()
    #expect(vm.hasUnsavedChanges == true)
}

@Test func saveFile() throws {
    let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("test-\(UUID()).md")
    try "original".write(to: tmp, atomically: true, encoding: .utf8)
    defer { try? FileManager.default.removeItem(at: tmp) }

    let vm = EditorViewModel()
    vm.loadFile(url: tmp)
    vm.text = "updated"
    vm.textDidChange()
    vm.save()
    #expect(vm.hasUnsavedChanges == false)

    let saved = try String(contentsOf: tmp, encoding: .utf8)
    #expect(saved == "updated")
}

@Test func externalChangeNoUnsaved() throws {
    let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("test-\(UUID()).md")
    try "original".write(to: tmp, atomically: true, encoding: .utf8)
    defer { try? FileManager.default.removeItem(at: tmp) }

    let vm = EditorViewModel()
    vm.loadFile(url: tmp)

    try "external change".write(to: tmp, atomically: true, encoding: .utf8)
    vm.handleExternalChange()

    #expect(vm.text == "external change")
    #expect(vm.hasUnsavedChanges == false)
}

@Test @MainActor func externalChangeViaAtomicRenameReloads() async throws {
    let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("test-\(UUID()).md")
    try "A".write(to: tmp, atomically: true, encoding: .utf8)
    defer { try? FileManager.default.removeItem(at: tmp) }

    let vm = EditorViewModel()
    vm.loadFile(url: tmp)

    // `atomically: true` writes to a temp file then renames — the same pattern
    // Claude Code, VS Code, and Obsidian use. Must survive two consecutive writes.
    try "B".write(to: tmp, atomically: true, encoding: .utf8)
    try await waitUntil(timeout: .seconds(1)) { vm.text == "B" }

    try "C".write(to: tmp, atomically: true, encoding: .utf8)
    try await waitUntil(timeout: .seconds(1)) { vm.text == "C" }
}

@MainActor
private func waitUntil(
    timeout: Duration,
    condition: @escaping () -> Bool
) async throws {
    let deadline = ContinuousClock.now.advanced(by: timeout)
    while ContinuousClock.now < deadline {
        if condition() { return }
        try await Task.sleep(for: .milliseconds(20))
    }
    #expect(condition())
}

@Test func externalChangeWithUnsaved() throws {
    let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("test-\(UUID()).md")
    try "original".write(to: tmp, atomically: true, encoding: .utf8)
    defer { try? FileManager.default.removeItem(at: tmp) }

    let vm = EditorViewModel()
    vm.loadFile(url: tmp)
    vm.text = "my changes"
    vm.textDidChange()

    try "external change".write(to: tmp, atomically: true, encoding: .utf8)
    vm.handleExternalChange()

    #expect(vm.showExternalChangeAlert == true)
    #expect(vm.text == "my changes")
}

@Test func toggleTaskUncheckedBecomesChecked() {
    let vm = EditorViewModel()
    vm.text = "- [ ] one"
    vm.toggleTaskAt(line: 0)
    #expect(vm.text == "- [x] one")
    #expect(vm.hasUnsavedChanges == true)
}

@Test func toggleTaskCheckedBecomesUnchecked() {
    let vm = EditorViewModel()
    vm.text = "- [x] done"
    vm.toggleTaskAt(line: 0)
    #expect(vm.text == "- [ ] done")
}

@Test func toggleTaskCapitalXBecomesUnchecked() {
    let vm = EditorViewModel()
    vm.text = "- [X] done"
    vm.toggleTaskAt(line: 0)
    #expect(vm.text == "- [ ] done")
}

@Test func toggleTaskPreservesIndentAndBullet() {
    let vm = EditorViewModel()
    vm.text = "  * [ ] indented"
    vm.toggleTaskAt(line: 0)
    #expect(vm.text == "  * [x] indented")
}

@Test func toggleTaskOnlyAffectsTargetLine() {
    let vm = EditorViewModel()
    vm.text = """
    - [ ] one
    - [ ] two
    - [x] three
    """
    vm.toggleTaskAt(line: 1)
    #expect(vm.text == """
    - [ ] one
    - [x] two
    - [x] three
    """)
}

@Test func toggleTaskIgnoresNonTaskLine() {
    let vm = EditorViewModel()
    vm.text = "just a paragraph"
    vm.toggleTaskAt(line: 0)
    #expect(vm.text == "just a paragraph")
    #expect(vm.hasUnsavedChanges == false)
}

@Test func toggleTaskIgnoresOutOfRangeLine() {
    let vm = EditorViewModel()
    vm.text = "- [ ] one"
    vm.toggleTaskAt(line: 99)
    #expect(vm.text == "- [ ] one")
    #expect(vm.hasUnsavedChanges == false)
}

@Test(arguments: [
    ("+ [ ] plus", "+ [x] plus"),
    ("1. [ ] first", "1. [x] first"),
    ("1) [x] paren", "1) [ ] paren"),
    ("   10. [X] nested", "   10. [ ] nested"),
])
func toggleTaskAcceptsEveryListMarker(_ source: String, _ toggled: String) {
    let vm = EditorViewModel()
    vm.text = source
    vm.toggleTaskAt(line: 0)
    #expect(vm.text == toggled)
    #expect(vm.hasUnsavedChanges == true)
}

@Test(arguments: ["1.5 [ ] version", "[ ] no marker", "-[ ] no space", "1.[ ] no space", "a. [ ] letter"])
func toggleTaskIgnoresBracketsWithoutListMarker(_ source: String) {
    let vm = EditorViewModel()
    vm.text = source
    vm.toggleTaskAt(line: 0)
    #expect(vm.text == source)
    #expect(vm.hasUnsavedChanges == false)
}

@Test func toggleNestedOrderedTaskAtRenderedLine() throws {
    let md = "1. parent\n   1) [ ] child\n2. sibling"
    let html = MarkdownRenderer.renderHTML(from: md)
    let line = try #require(html.firstMatch(of: #/data-md-line="(\d+)"/#).flatMap { Int($0.1) })

    let vm = EditorViewModel()
    vm.text = md
    vm.toggleTaskAt(line: line)
    #expect(vm.text == "1. parent\n   1) [x] child\n2. sibling")
}

@Test func openingAnotherFileSavesPendingEdit() throws {
    let first = try writeTempNote("original A")
    let second = try writeTempNote("original B")
    defer {
        try? FileManager.default.removeItem(at: first)
        try? FileManager.default.removeItem(at: second)
    }
    let vm = EditorViewModel()
    vm.loadFile(url: first)
    vm.text = "edited A"
    vm.textDidChange()

    vm.loadFile(url: second)

    #expect(try String(contentsOf: first, encoding: .utf8) == "edited A")
    #expect(try String(contentsOf: second, encoding: .utf8) == "original B")
    #expect(vm.fileURL == second)
    #expect(vm.text == "original B")
    #expect(vm.hasUnsavedChanges == false)
}

@Test func closingFileSavesPendingEdit() throws {
    let file = try writeTempNote("original")
    defer { try? FileManager.default.removeItem(at: file) }
    let vm = EditorViewModel()
    vm.loadFile(url: file)
    vm.text = "edited"
    vm.textDidChange()

    vm.clearFile()

    #expect(try String(contentsOf: file, encoding: .utf8) == "edited")
    #expect(vm.fileURL == nil)
    #expect(vm.text == "")
    #expect(vm.hasUnsavedChanges == false)
}

@Test func openingAnotherFileWithoutEditsDoesNotRewritePrevious() throws {
    let first = try writeTempNote("original A")
    let second = try writeTempNote("original B")
    defer {
        try? FileManager.default.removeItem(at: first)
        try? FileManager.default.removeItem(at: second)
    }
    let savedAt = Date(timeIntervalSince1970: 1_750_000_000)
    try setModificationDate(of: first, to: savedAt)
    let vm = EditorViewModel()
    vm.loadFile(url: first)

    vm.loadFile(url: second)

    #expect(try modificationDate(of: first) == savedAt)
}

@Test func closingFileWithoutEditsDoesNotRewriteIt() throws {
    let file = try writeTempNote("original")
    defer { try? FileManager.default.removeItem(at: file) }
    let savedAt = Date(timeIntervalSince1970: 1_750_000_000)
    try setModificationDate(of: file, to: savedAt)
    let vm = EditorViewModel()
    vm.loadFile(url: file)

    vm.clearFile()

    #expect(try modificationDate(of: file) == savedAt)
}
