# MD Editor Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add three view modes (Editor, Split, Preview) with editing, auto-save, and external file change detection to MDReader.

**Architecture:** New `EditorViewModel` (@Observable) manages text content, view mode, save state, and file monitoring. Native `NSTextView` wrapped in `NSViewRepresentable` provides the editor with custom syntax highlighting. `ContentView` switches between editor, split, and preview layouts based on view mode.

**Tech Stack:** Swift 5.9, SwiftUI, AppKit (NSTextView), WebKit (WKWebView), DispatchSource for file monitoring.

---

## File Structure

**New files:**
| File | Responsibility |
|------|---------------|
| `Sources/MDReaderApp/Models/ViewMode.swift` | ViewMode enum |
| `Sources/MDReaderApp/Services/EditorViewModel.swift` | Text state, save logic, file monitoring, debounce |
| `Sources/MDReaderApp/Views/MarkdownEditorView.swift` | NSTextView wrapper with syntax highlighting |
| `Sources/MDReaderApp/Services/MarkdownSyntaxHighlighter.swift` | NSAttributedString-based markdown highlighting |
| `Tests/MDReaderAppTests/EditorViewModelTests.swift` | Unit tests for EditorViewModel |
| `Tests/MDReaderAppTests/MarkdownSyntaxHighlighterTests.swift` | Unit tests for syntax highlighter |

**Modified files:**
| File | Changes |
|------|---------|
| `Package.swift` | Add test target |
| `Sources/MDReaderApp/Views/ContentView.swift` | Three view modes layout |
| `Sources/MDReaderApp/MDReaderApp.swift` | Toolbar segmented control, Cmd+S, pass EditorViewModel |

---

## Chunk 1: Foundation — ViewMode, EditorViewModel, Tests

### Task 1: Add test target to Package.swift

**Files:**
- Modify: `Package.swift`

- [ ] **Step 1: Add test target**

In `Package.swift`, add a library target for testable code and a test target:

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MDReader",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "MDReaderApp",
            path: "Sources/MDReaderApp",
            exclude: ["Info.plist"],
            resources: [.copy("Resources/AppIcon.icns")]
        ),
        .executableTarget(
            name: "mdreader",
            path: "Sources/mdreader"
        ),
        .testTarget(
            name: "MDReaderAppTests",
            dependencies: ["MDReaderApp"],
            path: "Tests/MDReaderAppTests"
        )
    ]
)
```

- [ ] **Step 2: Create test directory and placeholder test**

Create `Tests/MDReaderAppTests/PlaceholderTests.swift`:

```swift
import Testing

@Test func placeholder() {
    #expect(true)
}
```

- [ ] **Step 3: Build and run tests**

Run: `swift test`
Expected: 1 test passes

- [ ] **Step 4: Commit**

```bash
git add Package.swift Tests/
git commit -m "chore: add test target for MDReaderApp"
```

### Task 2: ViewMode enum

**Files:**
- Create: `Sources/MDReaderApp/Models/ViewMode.swift`

- [ ] **Step 1: Create ViewMode**

```swift
import Foundation

enum ViewMode: String, CaseIterable {
    case editor
    case split
    case preview

    var icon: String {
        switch self {
        case .editor: "square.and.pencil"
        case .split: "rectangle.split.2x1"
        case .preview: "eye"
        }
    }

    var label: String {
        switch self {
        case .editor: "Editor"
        case .split: "Split"
        case .preview: "Preview"
        }
    }
}
```

- [ ] **Step 2: Build**

Run: `swift build`
Expected: Build succeeds

- [ ] **Step 3: Commit**

```bash
git add Sources/MDReaderApp/Models/ViewMode.swift
git commit -m "feat: add ViewMode enum with editor/split/preview"
```

### Task 3: EditorViewModel — core logic

**Files:**
- Create: `Sources/MDReaderApp/Services/EditorViewModel.swift`
- Create: `Tests/MDReaderAppTests/EditorViewModelTests.swift`

- [ ] **Step 1: Write failing tests for EditorViewModel**

Create `Tests/MDReaderAppTests/EditorViewModelTests.swift`:

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

    // Simulate external change
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

    // Should show conflict, not auto-reload
    #expect(vm.showExternalChangeAlert == true)
    #expect(vm.text == "my changes")
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter MDReaderAppTests`
Expected: FAIL — EditorViewModel not defined

- [ ] **Step 3: Implement EditorViewModel**

Create `Sources/MDReaderApp/Services/EditorViewModel.swift`:

```swift
import Foundation
import Combine

@Observable
class EditorViewModel {
    var text: String = ""
    var viewMode: ViewMode = .preview
    var hasUnsavedChanges: Bool = false
    var showExternalChangeAlert: Bool = false
    private(set) var fileURL: URL?

    private var fileMonitor: DispatchSourceFileSystemObject?
    private var autoSaveTask: DispatchWorkItem?
    private var isReloading = false

    func loadFile(url: URL) {
        stopMonitoring()
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return }
        fileURL = url
        text = content
        hasUnsavedChanges = false
        showExternalChangeAlert = false
        startMonitoring()
    }

    func textDidChange() {
        guard !isReloading else { return }
        hasUnsavedChanges = true
        scheduleAutoSave()
    }

    func save() {
        guard let url = fileURL else { return }
        autoSaveTask?.cancel()
        // Pause monitoring to avoid self-triggered change
        stopMonitoring()
        try? text.write(to: url, atomically: true, encoding: .utf8)
        hasUnsavedChanges = false
        startMonitoring()
    }

    func handleExternalChange() {
        guard let url = fileURL else { return }
        if hasUnsavedChanges {
            showExternalChangeAlert = true
        } else {
            reloadFromDisk()
        }
    }

    func reloadFromDisk() {
        guard let url = fileURL,
              let content = try? String(contentsOf: url, encoding: .utf8) else { return }
        isReloading = true
        text = content
        hasUnsavedChanges = false
        showExternalChangeAlert = false
        isReloading = false
    }

    func dismissExternalChange() {
        showExternalChangeAlert = false
    }

    // MARK: - Auto-save

    private func scheduleAutoSave() {
        autoSaveTask?.cancel()
        let task = DispatchWorkItem { [weak self] in
            DispatchQueue.main.async {
                self?.save()
            }
        }
        autoSaveTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: task)
    }

    // MARK: - File Monitoring

    private func startMonitoring() {
        guard let url = fileURL else { return }
        let fd = open(url.path, O_EVTONLY)
        guard fd >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename],
            queue: .main
        )
        source.setEventHandler { [weak self] in
            self?.handleExternalChange()
        }
        source.setCancelHandler {
            close(fd)
        }
        source.resume()
        fileMonitor = source
    }

    private func stopMonitoring() {
        fileMonitor?.cancel()
        fileMonitor = nil
    }

    deinit {
        autoSaveTask?.cancel()
        stopMonitoring()
    }
}
```

- [ ] **Step 4: Run tests**

Run: `swift test --filter MDReaderAppTests`
Expected: All 6 tests pass

- [ ] **Step 5: Commit**

```bash
git add Sources/MDReaderApp/Services/EditorViewModel.swift Tests/MDReaderAppTests/EditorViewModelTests.swift
git commit -m "feat: add EditorViewModel with save, auto-save, and file monitoring"
```

---

## Chunk 2: Syntax Highlighting

### Task 4: MarkdownSyntaxHighlighter

**Files:**
- Create: `Sources/MDReaderApp/Services/MarkdownSyntaxHighlighter.swift`
- Create: `Tests/MDReaderAppTests/MarkdownSyntaxHighlighterTests.swift`

- [ ] **Step 1: Write failing tests**

Create `Tests/MDReaderAppTests/MarkdownSyntaxHighlighterTests.swift`:

```swift
import Testing
import AppKit
@testable import MDReaderApp

@Test func highlightsHeading() {
    let text = "# Hello World"
    let highlighted = MarkdownSyntaxHighlighter.highlight(text)
    // Heading should have bold trait
    var attrs = highlighted.attributes(at: 0, effectiveRange: nil)
    let font = attrs[.font] as! NSFont
    #expect(font.fontDescriptor.symbolicTraits.contains(.bold))
}

@Test func highlightsInlineCode() {
    let text = "Use `code` here"
    let highlighted = MarkdownSyntaxHighlighter.highlight(text)
    // "code" starts at index 5 (after "Use `")
    let attrs = highlighted.attributes(at: 5, effectiveRange: nil)
    let font = attrs[.font] as! NSFont
    #expect(font.isFixedPitch)
}

@Test func highlightsCodeBlock() {
    let text = "```swift\nlet x = 1\n```"
    let highlighted = MarkdownSyntaxHighlighter.highlight(text)
    // The fence line should have a color
    let attrs = highlighted.attributes(at: 0, effectiveRange: nil)
    #expect(attrs[.foregroundColor] != nil)
}

@Test func plainTextUnchanged() {
    let text = "Just normal text"
    let highlighted = MarkdownSyntaxHighlighter.highlight(text)
    #expect(highlighted.string == text)
}
```

- [ ] **Step 2: Run tests to verify failure**

Run: `swift test --filter MarkdownSyntaxHighlighter`
Expected: FAIL — MarkdownSyntaxHighlighter not defined

- [ ] **Step 3: Implement MarkdownSyntaxHighlighter**

Create `Sources/MDReaderApp/Services/MarkdownSyntaxHighlighter.swift`:

```swift
import AppKit

enum MarkdownSyntaxHighlighter {
    private static let monoFont = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
    private static let boldMonoFont = NSFont.monospacedSystemFont(ofSize: 14, weight: .bold)

    private static var headingFont: NSFont {
        NSFont.monospacedSystemFont(ofSize: 18, weight: .bold)
    }

    private static var subheadingFont: NSFont {
        NSFont.monospacedSystemFont(ofSize: 16, weight: .bold)
    }

    private static var fenceColor: NSColor {
        .secondaryLabelColor
    }

    private static var inlineCodeColor: NSColor {
        NSColor(red: 0.78, green: 0.24, blue: 0.24, alpha: 1.0)
    }

    private static var headingColor: NSColor {
        NSColor(red: 0.0, green: 0.35, blue: 0.85, alpha: 1.0)
    }

    private static var boldColor: NSColor {
        .labelColor
    }

    private static var linkColor: NSColor {
        NSColor(red: 0.0, green: 0.44, blue: 0.88, alpha: 1.0)
    }

    static func highlight(_ text: String) -> NSMutableAttributedString {
        let result = NSMutableAttributedString(
            string: text,
            attributes: [
                .font: monoFont,
                .foregroundColor: NSColor.labelColor
            ]
        )

        let fullRange = NSRange(location: 0, length: result.length)
        let nsString = text as NSString

        // Code blocks (fenced) — must be processed before inline patterns
        applyPattern(#"^```.*$"#, to: result, in: fullRange, nsString: nsString, attrs: [
            .foregroundColor: fenceColor,
            .font: monoFont
        ])

        // Headings
        applyPattern(#"^#{1,6}\s+.*$"#, to: result, in: fullRange, nsString: nsString, attrs: [
            .foregroundColor: headingColor,
            .font: boldMonoFont
        ])

        // Bold **text**
        applyPattern(#"\*\*[^*]+\*\*"#, to: result, in: fullRange, nsString: nsString, attrs: [
            .font: boldMonoFont
        ])

        // Italic *text*
        applyPattern(#"(?<!\*)\*(?!\*)[^*]+\*(?!\*)"#, to: result, in: fullRange, nsString: nsString, attrs: [
            .font: NSFontManager.shared.convert(monoFont, toHaveTrait: .italicTrait)
        ])

        // Inline code `text`
        applyPattern(#"`[^`]+`"#, to: result, in: fullRange, nsString: nsString, attrs: [
            .foregroundColor: inlineCodeColor,
            .font: monoFont
        ])

        // Links [text](url)
        applyPattern(#"\[[^\]]+\]\([^)]+\)"#, to: result, in: fullRange, nsString: nsString, attrs: [
            .foregroundColor: linkColor
        ])

        // Blockquote lines
        applyPattern(#"^>.*$"#, to: result, in: fullRange, nsString: nsString, attrs: [
            .foregroundColor: NSColor.secondaryLabelColor
        ])

        return result
    }

    private static func applyPattern(
        _ pattern: String,
        to attrString: NSMutableAttributedString,
        in range: NSRange,
        nsString: NSString,
        attrs: [NSAttributedString.Key: Any]
    ) {
        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: [.anchorsMatchLines]
        ) else { return }

        let matches = regex.matches(in: nsString as String, range: range)
        for match in matches {
            attrString.addAttributes(attrs, range: match.range)
        }
    }
}
```

- [ ] **Step 4: Run tests**

Run: `swift test --filter MarkdownSyntaxHighlighter`
Expected: All 4 tests pass

- [ ] **Step 5: Commit**

```bash
git add Sources/MDReaderApp/Services/MarkdownSyntaxHighlighter.swift Tests/MDReaderAppTests/MarkdownSyntaxHighlighterTests.swift
git commit -m "feat: add markdown syntax highlighter for editor"
```

---

## Chunk 3: Editor View

### Task 5: MarkdownEditorView (NSTextView wrapper)

**Files:**
- Create: `Sources/MDReaderApp/Views/MarkdownEditorView.swift`

- [ ] **Step 1: Implement MarkdownEditorView**

Create `Sources/MDReaderApp/Views/MarkdownEditorView.swift`:

```swift
import SwiftUI
import AppKit

struct MarkdownEditorView: NSViewRepresentable {
    @Bindable var viewModel: EditorViewModel

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView

        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.font = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        textView.textColor = .labelColor
        textView.backgroundColor = .textBackgroundColor
        textView.insertionPointColor = .labelColor
        textView.textContainerInset = NSSize(width: 16, height: 16)
        textView.delegate = context.coordinator
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true

        context.coordinator.textView = textView

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let textView = scrollView.documentView as! NSTextView
        if textView.string != viewModel.text {
            let selectedRanges = textView.selectedRanges
            context.coordinator.isUpdating = true
            textView.string = viewModel.text
            context.coordinator.applyHighlighting()
            textView.selectedRanges = selectedRanges
            context.coordinator.isUpdating = false
        }
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var viewModel: EditorViewModel
        weak var textView: NSTextView?
        var isUpdating = false
        private var highlightWorkItem: DispatchWorkItem?

        init(viewModel: EditorViewModel) {
            self.viewModel = viewModel
        }

        func textDidChange(_ notification: Notification) {
            guard !isUpdating, let textView else { return }
            viewModel.text = textView.string
            viewModel.textDidChange()
            scheduleHighlighting()
        }

        func applyHighlighting() {
            guard let textView, let textStorage = textView.textStorage else { return }
            let highlighted = MarkdownSyntaxHighlighter.highlight(textView.string)
            let selectedRanges = textView.selectedRanges
            textStorage.beginEditing()
            textStorage.setAttributedString(highlighted)
            textStorage.endEditing()
            textView.selectedRanges = selectedRanges
        }

        private func scheduleHighlighting() {
            highlightWorkItem?.cancel()
            let item = DispatchWorkItem { [weak self] in
                self?.applyHighlighting()
            }
            highlightWorkItem = item
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: item)
        }
    }
}
```

- [ ] **Step 2: Build**

Run: `swift build`
Expected: Build succeeds

- [ ] **Step 3: Commit**

```bash
git add Sources/MDReaderApp/Views/MarkdownEditorView.swift
git commit -m "feat: add MarkdownEditorView with NSTextView and syntax highlighting"
```

---

## Chunk 4: Wire Everything Together

### Task 6: Update ContentView for three view modes

**Files:**
- Modify: `Sources/MDReaderApp/Views/ContentView.swift`

- [ ] **Step 1: Rewrite ContentView**

Replace `Sources/MDReaderApp/Views/ContentView.swift` with:

```swift
import SwiftUI

struct ContentView: View {
    let fileURL: URL?
    @Bindable var viewModel: EditorViewModel

    var body: some View {
        Group {
            if let _ = fileURL {
                switch viewModel.viewMode {
                case .editor:
                    MarkdownEditorView(viewModel: viewModel)

                case .split:
                    HSplitView {
                        MarkdownEditorView(viewModel: viewModel)
                            .frame(minWidth: 200)
                        MarkdownWebView(markdown: viewModel.text)
                            .frame(minWidth: 200)
                    }

                case .preview:
                    MarkdownWebView(markdown: viewModel.text)
                }
            } else {
                ContentUnavailableView(
                    "No File Selected",
                    systemImage: "doc.text",
                    description: Text("Select a file from the sidebar or open one via terminal:\nmdreader <path>")
                )
            }
        }
        .onChange(of: fileURL) { _, newURL in
            if let url = newURL {
                viewModel.loadFile(url: url)
            }
        }
        .task(id: fileURL) {
            if let url = fileURL {
                viewModel.loadFile(url: url)
            }
        }
        .alert("File Changed Externally", isPresented: $viewModel.showExternalChangeAlert) {
            Button("Reload", role: .destructive) {
                viewModel.reloadFromDisk()
            }
            Button("Ignore") {
                viewModel.dismissExternalChange()
            }
            Button("Save My Version") {
                viewModel.save()
                viewModel.dismissExternalChange()
            }
        } message: {
            Text("The file has been modified by another application. What would you like to do?")
        }
    }
}
```

- [ ] **Step 2: Build**

Run: `swift build`
Expected: Build succeeds

- [ ] **Step 3: Commit**

```bash
git add Sources/MDReaderApp/Views/ContentView.swift
git commit -m "feat: update ContentView with editor/split/preview modes"
```

### Task 7: Update MDReaderApp — toolbar, Cmd+S, EditorViewModel

**Files:**
- Modify: `Sources/MDReaderApp/MDReaderApp.swift`

- [ ] **Step 1: Update MDReaderApp**

Replace `Sources/MDReaderApp/MDReaderApp.swift` with:

```swift
import SwiftUI
import UniformTypeIdentifiers

private let markdownExtensions: Set<String> = ["md", "markdown"]

@main
struct MDReaderApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
    @State private var fileCache = FileCache()
    @State private var selectedFilePath: String?
    @State private var viewModel = EditorViewModel()

    var body: some Scene {
        WindowGroup {
            NavigationSplitView {
                SidebarView(
                    files: fileCache.files,
                    selectedFilePath: $selectedFilePath,
                    onRemove: { fileCache.removeFile($0) }
                )
            } detail: {
                ContentView(
                    fileURL: selectedFilePath.map { URL(fileURLWithPath: $0) },
                    viewModel: viewModel
                )
            }
            .onOpenURL { url in
                let fileURL = URL(fileURLWithPath: url.path)
                openMarkdownFile(fileURL)
            }
            .toolbar {
                ToolbarItem {
                    Picker("View Mode", selection: $viewModel.viewMode) {
                        ForEach(ViewMode.allCases, id: \.self) { mode in
                            Image(systemName: mode.icon)
                                .help(mode.label)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 120)
                }
                ToolbarItem {
                    Button {
                        openFilePanel()
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                for provider in providers {
                    _ = provider.loadObject(ofClass: URL.self) { url, _ in
                        if let url, markdownExtensions.contains(url.pathExtension) {
                            DispatchQueue.main.async {
                                openMarkdownFile(url)
                            }
                        }
                    }
                }
                return true
            }
            .frame(minWidth: 700, minHeight: 500)
            .navigationTitle(windowTitle)
        }
        .commands {
            CommandGroup(replacing: .saveItem) {
                Button("Save") {
                    viewModel.save()
                }
                .keyboardShortcut("s", modifiers: .command)
                .disabled(!viewModel.hasUnsavedChanges)
            }
        }
    }

    private var windowTitle: String {
        guard let path = selectedFilePath else { return "MDReader" }
        let name = URL(fileURLWithPath: path).lastPathComponent
        return viewModel.hasUnsavedChanges ? "\(name) — Edited" : name
    }

    private func openMarkdownFile(_ url: URL) {
        fileCache.addFile(url: url)
        selectedFilePath = url.path
    }

    private func openFilePanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = markdownExtensions.compactMap { UTType(filenameExtension: $0) }
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            openMarkdownFile(url)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        if let iconURL = Bundle.module.url(forResource: "AppIcon", withExtension: "icns"),
           let icon = NSImage(contentsOf: iconURL) {
            NSApp.applicationIconImage = icon
        }
    }
}
```

- [ ] **Step 2: Build**

Run: `swift build`
Expected: Build succeeds

- [ ] **Step 3: Run the app and manually test**

Run: `.build/debug/MDReaderApp`

Test:
1. Open a markdown file
2. Switch between Preview, Split, and Editor modes using toolbar
3. Edit text in Editor mode — verify syntax highlighting
4. Wait 1.5s — verify auto-save (title changes from "— Edited" back to clean)
5. Press Cmd+S — verify immediate save
6. In split mode, edit text — verify preview updates
7. Externally edit the file (from terminal) while no unsaved changes — verify auto-reload
8. Edit text, then externally modify the file — verify alert appears

- [ ] **Step 4: Commit**

```bash
git add Sources/MDReaderApp/MDReaderApp.swift
git commit -m "feat: add toolbar view mode picker, Cmd+S save, and window title indicator"
```

- [ ] **Step 5: Delete placeholder test**

Remove `Tests/MDReaderAppTests/PlaceholderTests.swift` (no longer needed).

```bash
rm Tests/MDReaderAppTests/PlaceholderTests.swift
git add -A Tests/MDReaderAppTests/PlaceholderTests.swift
git commit -m "chore: remove placeholder test"
```

### Task 8: Final integration test

- [ ] **Step 1: Run all tests**

Run: `swift test`
Expected: All tests pass

- [ ] **Step 2: Full build**

Run: `swift build`
Expected: Clean build with no warnings

- [ ] **Step 3: Final commit (if any fixes needed)**

```bash
git add -A
git commit -m "fix: address integration issues"
```
