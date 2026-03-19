# Coding Conventions

**Analysis Date:** 2026-03-19

## Naming Patterns

**Files:**
- Swift files use PascalCase for types/structs: `EditorViewModel.swift`, `MarkdownSyntaxHighlighter.swift`, `CachedFile.swift`
- View files are named descriptively with "View" suffix: `ContentView.swift`, `MarkdownEditorView.swift`, `SidebarView.swift`
- Service/utility files are named by their purpose: `FileCache.swift`, `MarkdownSyntaxHighlighter.swift`
- Model files live in `Models/` directory: `ViewMode.swift`, `CachedFile.swift`
- Main entry point: `main.swift` for CLI, `MDReaderApp.swift` for app entry

**Functions:**
- Use camelCase for function names: `loadFile()`, `textDidChange()`, `toggleFavorite()`, `applyHighlighting()`
- Private functions use leading underscore convention is NOT used; instead `private` keyword is explicit
- Helper methods are marked `private`: `scheduleAutoSave()`, `startMonitoring()`, `stopMonitoring()`
- Delegate/callback methods follow Apple conventions: `textDidChange(_:)`, `makeNSView(context:)`, `updateNSView(_:context:)`

**Variables:**
- Properties use camelCase: `fileURL`, `hasUnsavedChanges`, `viewMode`, `fileCache`
- State properties use `@State` annotation in SwiftUI
- Observable properties in classes use `@Observable` macro
- Private storage uses `private(set)` for controlled access: `private(set) var fileURL: URL?`
- Local variables follow camelCase: `searchText`, `isHovering`, `selectedFilePath`

**Types:**
- Enums use PascalCase with lowercase cases: `enum ViewMode { case editor, split, preview }`
- Structs use PascalCase: `struct CachedFile`, `struct ContentView`
- Classes use PascalCase: `class EditorViewModel`, `class FileCache`
- Protocol conformance is documented via type declaration: `struct CachedFile: Identifiable, Codable, Equatable`

## Code Style

**Formatting:**
- No explicit formatter configured (no .swiftformat or SwiftLint config files detected)
- Indentation: 4 spaces (standard Swift)
- Line length: No enforced limit observed; files stay reasonably compact
- Spacing: Single blank line between sections within files

**Linting:**
- No linting configuration detected
- Code follows Apple's Swift style guidelines implicitly

## Import Organization

**Order:**
1. Standard library imports: `import Foundation`
2. Framework imports: `import SwiftUI`, `import AppKit`, `import UniformTypeIdentifiers`
3. Testing framework (in test files): `import Testing`
4. Module imports with @testable: `@testable import MDReaderApp`

**Path Aliases:**
- No path aliases detected; relative imports used
- Files reference types directly: `EditorViewModel`, `FileCache`, `CachedFile`

## Error Handling

**Patterns:**
- Do-catch blocks for file operations: `do { try ... } catch { ... }`
- Error assignment to properties for display: `var loadError: Error?`, `var saveError: Error?`
- Guard statements with early return for validation: `guard let url = fileURL else { return }`
- Optional try with implicit success/failure: `try? FileManager.default.removeItem(at: tmp)`
- Chaining guards for multiple conditions: `guard let url = fileURL, let content = try? String(contentsOf: ...) else { return }`
- Error messages displayed via alerts: See `ContentView.swift` lines 62-69 for save error alert

**Precedent in codebase:**
- `EditorViewModel.swift`: Stores errors in properties, caller views handle display
- `FileCache.swift`: Silent failures with optional try (`try?`) for non-critical operations
- `mdreader/main.swift`: Explicit error messages to stderr via `fputs()`, exit codes for CLI

## Logging

**Framework:** No explicit logging framework; uses `print()` and `fputs()` implicitly

**Patterns:**
- CLI errors written to stderr: `fputs("Error: file not found: \(absolutePath)\n", stderr)`
- No in-app logging framework detected; errors flow through property bindings to UI

## Comments

**When to Comment:**
- Mark sections with `// MARK: - Section Name` for logical grouping
- Complex algorithms documented: See `MarkdownEditorView.swift` lines 38-41 explaining textVersion optimization
- Implementation notes for non-obvious behavior: See `MarkdownSyntaxHighlighter.swift` line 38 using `try!` for cached regex

**JSDoc/TSDoc:**
- Not used in Swift codebase; Swift lacks equivalent conventions
- Doc comments are minimal; code is self-documenting through clear naming

## Function Design

**Size:**
- Functions stay concise; most 10-20 lines
- Single-responsibility focus: `loadFile()` loads, `save()` saves, `textDidChange()` marks unsaved
- Complex operations broken into private helpers: `scheduleAutoSave()`, `applyHighlighting()`

**Parameters:**
- Named parameters with labels: `func loadFile(url: URL)`, `func toggleFavorite(path: String)`
- Use `_` to omit labels when appropriate: `func textDidChange()` (notification parameter omitted)
- Closures passed as trailing parameters: `var onRemove: (CachedFile) -> Void`

**Return Values:**
- Explicit return types in function signatures
- Void for side-effect-only functions: `func save()`, `func clearFile()`
- Optional returns for fallible operations: `private func startMonitoring()` returns Void (implicit success)

## Module Design

**Exports:**
- Top-level `@main` annotation marks app entry: `@main struct MDReaderApp: App`
- Nested types within structs: `FileRow` nested in `SidebarView.swift`
- Coordinator pattern for NSViewRepresentable: `MarkdownEditorView.Coordinator` (lines 50-86)

**Barrel Files:**
- No barrel files (index.ts equivalents) in Swift
- Each file is imported directly: `@testable import MDReaderApp`

## Architectural Patterns Reflected in Code

**Observable Pattern:**
- `@Observable` macro on ViewModels: `@Observable class EditorViewModel`
- `@Bindable` for binding to observable objects in SwiftUI
- Property-based state updates flow through bindings

**MVVM:**
- ViewModels encapsulate logic: `EditorViewModel` handles file operations
- Views bind to ViewModel properties: `@Bindable var viewModel: EditorViewModel`
- Models are value types: `struct CachedFile`, `enum ViewMode`

**Separation of Concerns:**
- Services layer: `EditorViewModel`, `FileCache`, `MarkdownSyntaxHighlighter`
- Views layer: `ContentView`, `MarkdownEditorView`, `SidebarView`
- Models layer: `ViewMode`, `CachedFile`
- CLI layer: `main.swift` standalone script

---

*Convention analysis: 2026-03-19*
