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
