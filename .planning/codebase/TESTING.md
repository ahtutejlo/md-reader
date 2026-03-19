# Testing Patterns

**Analysis Date:** 2026-03-19

## Test Framework

**Runner:**
- Swift Testing framework (new in Swift 5.9+)
- Config: `Package.swift` target `.testTarget(name: "MDReaderAppTests", ...)`

**Assertion Library:**
- Swift Testing's built-in `#expect()` macro

**Run Commands:**
```bash
swift test                 # Run all tests
swift test --watch        # Watch mode (if supported)
swift build -c release    # Build for release (includes tests)
```

## Test File Organization

**Location:**
- Tests co-located in separate `Tests/` directory
- Mirror source structure: `Sources/MDReaderApp/` → `Tests/MDReaderAppTests/`
- Test bundle: `MDReaderAppTests`

**Naming:**
- Test files use `*Tests.swift` suffix: `EditorViewModelTests.swift`, `MarkdownSyntaxHighlighterTests.swift`, `FavoritesTests.swift`
- Import pattern: `@testable import MDReaderApp` for internal access

**Structure:**
```
Tests/
└── MDReaderAppTests/
    ├── EditorViewModelTests.swift
    ├── MarkdownSyntaxHighlighterTests.swift
    └── FavoritesTests.swift
```

## Test Structure

**Suite Organization:**
Swift Testing uses individual `@Test` functions rather than class-based suites:

```swift
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
    // Test implementation
}
```

**Patterns:**
- Each test is a standalone `@Test` function
- `throws` keyword when test uses try/catch or temporary file operations
- Setup: Create instances at test start (no setUp() method)
- Teardown: Use `defer` blocks for cleanup

**Example from codebase (EditorViewModelTests.swift):**
```swift
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
```

## Mocking

**Framework:**
- No external mocking framework; tests use real objects

**Patterns:**
Real file system used for integration-style testing:
```swift
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
```

**What to Mock:**
- File system: Uses temporary files with `FileManager.default.temporaryDirectory`
- No mocking of internal state; direct property assertion

**What NOT to Mock:**
- File I/O operations are real; tests verify actual persistence
- NSAttributedString rendering (syntax highlighting tests inspect real attributes)
- Date operations in FileCache (uses real `Date()`)

## Fixtures and Factories

**Test Data:**
Inline creation of test files:
```swift
let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("test-\(UUID()).md")
try "# Test".write(to: tmp, atomically: true, encoding: .utf8)
```

UUID used to avoid collisions between test runs.

**Location:**
- No separate fixtures file
- Test data created inline within test functions
- Real files written to temp directory

## Coverage

**Requirements:**
- Not enforced; no coverage reporting configuration detected

**View Coverage:**
- Not applicable; no coverage tool configured

## Test Types

**Unit Tests:**
- ViewModel state tests: `EditorViewModelTests.swift` - initial state, text changes, save behavior
- Model tests: `FavoritesTests.swift` - CachedFile creation, serialization, favoriting
- Utility tests: `MarkdownSyntaxHighlighterTests.swift` - syntax highlighting output
- Scope: Individual functions tested in isolation with real file I/O
- Approach: Direct property assertion via `#expect()`

**Integration Tests:**
- File persistence: `EditorViewModelTests.swift` - load, edit, save, reload cycle
- External change handling: `EditorViewModelTests.swift` - external modification detection
- Serialization: `FavoritesTests.swift` - encode/decode round-trip of CachedFile

**E2E Tests:**
- Not implemented; no E2E framework configured

## Common Patterns

**Async Testing:**
No async patterns in current tests; all operations are synchronous.

**Error Testing:**
Backward compatibility test for missing optional field:
```swift
@Test func cachedFileBackwardCompatibility() throws {
    let json = """
    {"path":"/tmp/test.md","lastOpened":"2024-01-01T00:00:00Z"}
    """
    let data = json.data(using: .utf8)!
    let decoded = try JSONDecoder.iso8601.decode(CachedFile.self, from: data)
    #expect(decoded.isFavorite == false)
}
```

**Temporary File Pattern:**
Consistent setup and cleanup across tests:
```swift
let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("test-\(UUID()).md")
try "content".write(to: tmp, atomically: true, encoding: .utf8)
defer { try? FileManager.default.removeItem(at: tmp) }
// Test body
```

## Test Coverage Summary

**Tested Areas:**
- `EditorViewModel`: Initial state, file loading, text changes, saving, external modification handling (6 tests in EditorViewModelTests.swift)
- `CachedFile`: Creation, serialization, backward compatibility (3 tests in FavoritesTests.swift)
- `FileCache`: Favoriting functionality (1 test in FavoritesTests.swift)
- `MarkdownSyntaxHighlighter`: Heading highlighting, inline code, code blocks, plain text (4 tests in MarkdownSyntaxHighlighterTests.swift)

**Untested/Partial:**
- `ContentView`: View logic untested; SwiftUI view snapshot testing not in scope
- `MarkdownEditorView`: NSTextView integration untested
- `SidebarView`: Search filtering and favorites filtering untested
- `FileCache`: Load/save persistence untested; addFile/removeFile untested
- `MDReaderApp`: WindowGroup setup, file panel, drag-and-drop untested
- CLI (`main.swift`): Command-line argument parsing untested

---

*Testing analysis: 2026-03-19*
