# MDReader Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a native macOS markdown reader with sidebar navigation, file caching, and CLI integration.

**Architecture:** Pure SwiftUI app with `NavigationSplitView`, `AttributedString` markdown rendering, JSON file cache in Application Support, and a separate CLI executable communicating via custom URL scheme `mdreader://`.

**Tech Stack:** Swift, SwiftUI, Foundation, Xcode project via Swift Package Manager

---

### Task 1: Project Scaffold

**Files:**
- Create: `Package.swift`
- Create: `Sources/MDReaderApp/MDReaderApp.swift`
- Create: `Sources/mdreader-cli/main.swift`

**Step 1: Create Package.swift**

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MDReader",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "MDReaderApp",
            path: "Sources/MDReaderApp"
        ),
        .executableTarget(
            name: "mdreader-cli",
            path: "Sources/mdreader-cli"
        )
    ]
)
```

**Step 2: Create minimal app entry point**

```swift
// Sources/MDReaderApp/MDReaderApp.swift
import SwiftUI

@main
struct MDReaderApp: App {
    var body: some Scene {
        WindowGroup {
            Text("MDReader")
        }
    }
}
```

**Step 3: Create minimal CLI entry point**

```swift
// Sources/mdreader-cli/main.swift
import Foundation
print("mdreader cli")
```

**Step 4: Create directory structure**

```bash
mkdir -p Sources/MDReaderApp/Models
mkdir -p Sources/MDReaderApp/Services
mkdir -p Sources/MDReaderApp/Views
mkdir -p Sources/mdreader-cli
```

**Step 5: Build to verify**

Run: `swift build`
Expected: Build succeeds

**Step 6: Commit**

```bash
git init
git add -A
git commit -m "chore: scaffold MDReader project with Package.swift"
```

---

### Task 2: CachedFile Model

**Files:**
- Create: `Sources/MDReaderApp/Models/CachedFile.swift`

**Step 1: Create the CachedFile model**

```swift
// Sources/MDReaderApp/Models/CachedFile.swift
import Foundation

struct CachedFile: Identifiable, Codable, Equatable {
    var id: String { path }
    let path: String
    let name: String
    var lastOpened: Date
    var fileSize: Int64

    var exists: Bool {
        FileManager.default.fileExists(atPath: path)
    }

    init(url: URL) throws {
        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        self.path = url.path
        self.name = url.lastPathComponent
        self.lastOpened = Date()
        self.fileSize = attrs[.size] as? Int64 ?? 0
    }
}
```

**Step 2: Build to verify**

Run: `swift build`
Expected: Build succeeds

**Step 3: Commit**

```bash
git add Sources/MDReaderApp/Models/CachedFile.swift
git commit -m "feat: add CachedFile model"
```

---

### Task 3: FileCache Service

**Files:**
- Create: `Sources/MDReaderApp/Services/FileCache.swift`

**Step 1: Create FileCache service**

```swift
// Sources/MDReaderApp/Services/FileCache.swift
import Foundation
import SwiftUI

@Observable
class FileCache {
    private(set) var files: [CachedFile] = []

    private var cacheURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("MDReader", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("cache.json")
    }

    init() {
        load()
    }

    func addFile(url: URL) {
        // Update existing or add new
        if let index = files.firstIndex(where: { $0.path == url.path }) {
            files[index].lastOpened = Date()
        } else {
            guard let file = try? CachedFile(url: url) else { return }
            files.append(file)
        }
        files.sort { $0.lastOpened > $1.lastOpened }
        save()
    }

    func removeFile(_ file: CachedFile) {
        files.removeAll { $0.id == file.id }
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: cacheURL),
              let decoded = try? JSONDecoder.withISO8601.decode([CachedFile].self, from: data) else {
            return
        }
        files = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder.withISO8601.encode(files) else { return }
        try? data.write(to: cacheURL, options: .atomic)
    }
}

extension JSONDecoder {
    static var withISO8601: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }
}

extension JSONEncoder {
    static var withISO8601: JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = .prettyPrinted
        return e
    }
}
```

**Step 2: Build to verify**

Run: `swift build`
Expected: Build succeeds

**Step 3: Commit**

```bash
git add Sources/MDReaderApp/Services/FileCache.swift
git commit -m "feat: add FileCache service with JSON persistence"
```

---

### Task 4: ContentView — Markdown Rendering

**Files:**
- Create: `Sources/MDReaderApp/Views/ContentView.swift`

**Step 1: Create ContentView**

```swift
// Sources/MDReaderApp/Views/ContentView.swift
import SwiftUI

struct ContentView: View {
    let fileURL: URL?

    var body: some View {
        if let url = fileURL {
            ScrollView {
                markdownContent(for: url)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
        } else {
            ContentUnavailableView(
                "No File Selected",
                systemImage: "doc.text",
                description: Text("Select a file from the sidebar or open one via terminal:\nmdreader <path>")
            )
        }
    }

    @ViewBuilder
    private func markdownContent(for url: URL) -> some View {
        if let content = try? String(contentsOf: url, encoding: .utf8),
           let attributed = try? AttributedString(markdown: content, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
            Text(attributed)
                .font(.body)
        } else {
            ContentUnavailableView(
                "Cannot Read File",
                systemImage: "exclamationmark.triangle",
                description: Text(url.path)
            )
        }
    }
}
```

**Step 2: Build to verify**

Run: `swift build`
Expected: Build succeeds

**Step 3: Commit**

```bash
git add Sources/MDReaderApp/Views/ContentView.swift
git commit -m "feat: add ContentView with markdown rendering"
```

---

### Task 5: SidebarView

**Files:**
- Create: `Sources/MDReaderApp/Views/SidebarView.swift`

**Step 1: Create SidebarView**

```swift
// Sources/MDReaderApp/Views/SidebarView.swift
import SwiftUI

struct SidebarView: View {
    let files: [CachedFile]
    @Binding var selectedFilePath: String?
    var onRemove: (CachedFile) -> Void

    @State private var searchText = ""

    private var filteredFiles: [CachedFile] {
        if searchText.isEmpty { return files }
        return files.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        List(filteredFiles, selection: $selectedFilePath) { file in
            FileRow(file: file)
                .contextMenu {
                    Button("Remove from List", role: .destructive) {
                        onRemove(file)
                    }
                }
        }
        .searchable(text: $searchText, prompt: "Search files")
        .navigationSplitViewColumnWidth(min: 200, ideal: 250)
    }
}

struct FileRow: View {
    let file: CachedFile

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Image(systemName: file.exists ? "doc.text" : "doc.text.fill")
                    .foregroundStyle(file.exists ? .primary : .red)
                Text(file.name)
                    .lineLimit(1)
            }
            Text(file.lastOpened, style: .relative)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
```

**Step 2: Build to verify**

Run: `swift build`
Expected: Build succeeds

**Step 3: Commit**

```bash
git add Sources/MDReaderApp/Views/SidebarView.swift
git commit -m "feat: add SidebarView with search and context menu"
```

---

### Task 6: Wire Up MDReaderApp with URL Scheme

**Files:**
- Modify: `Sources/MDReaderApp/MDReaderApp.swift`
- Create: `Sources/MDReaderApp/Info.plist`

**Step 1: Create Info.plist with URL scheme**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleURLTypes</key>
    <array>
        <dict>
            <key>CFBundleURLName</key>
            <string>com.mdreader.open</string>
            <key>CFBundleURLSchemes</key>
            <array>
                <string>mdreader</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
```

**Step 2: Update MDReaderApp.swift**

```swift
// Sources/MDReaderApp/MDReaderApp.swift
import SwiftUI

@main
struct MDReaderApp: App {
    @State private var fileCache = FileCache()
    @State private var selectedFilePath: String?

    var body: some Scene {
        WindowGroup {
            NavigationSplitView {
                SidebarView(
                    files: fileCache.files,
                    selectedFilePath: $selectedFilePath,
                    onRemove: { fileCache.removeFile($0) }
                )
            } detail: {
                ContentView(fileURL: selectedFilePath.map { URL(fileURLWithPath: $0) })
            }
            .onOpenURL { url in
                handleURL(url)
            }
            .frame(minWidth: 700, minHeight: 500)
        }
    }

    private func handleURL(_ url: URL) {
        // mdreader:///absolute/path/to/file.md -> /absolute/path/to/file.md
        let filePath = url.path
        let fileURL = URL(fileURLWithPath: filePath)
        fileCache.addFile(url: fileURL)
        selectedFilePath = filePath
    }
}
```

**Step 3: Update Package.swift to include Info.plist**

Update the MDReaderApp target in Package.swift to reference the plist:

```swift
.executableTarget(
    name: "MDReaderApp",
    path: "Sources/MDReaderApp",
    resources: [.copy("Info.plist")]
),
```

Note: For URL scheme registration to work, the app needs to be built as a proper .app bundle via Xcode or `xcodebuild`. During development, we can test by manually opening URLs.

**Step 4: Build to verify**

Run: `swift build`
Expected: Build succeeds

**Step 5: Commit**

```bash
git add Sources/MDReaderApp/MDReaderApp.swift Sources/MDReaderApp/Info.plist Package.swift
git commit -m "feat: wire up main app with NavigationSplitView and URL scheme"
```

---

### Task 7: CLI Utility

**Files:**
- Modify: `Sources/mdreader-cli/main.swift`

**Step 1: Implement CLI**

```swift
// Sources/mdreader-cli/main.swift
import Foundation

guard CommandLine.arguments.count > 1 else {
    fputs("Usage: mdreader <path-to-markdown-file>\n", stderr)
    exit(1)
}

let inputPath = CommandLine.arguments[1]
let fileURL = URL(fileURLWithPath: inputPath, relativeTo: URL(fileURLWithPath: FileManager.default.currentDirectoryPath))
let absolutePath = fileURL.standardized.path

guard FileManager.default.fileExists(atPath: absolutePath) else {
    fputs("Error: file not found: \(absolutePath)\n", stderr)
    exit(1)
}

guard absolutePath.hasSuffix(".md") || absolutePath.hasSuffix(".markdown") else {
    fputs("Error: not a markdown file: \(absolutePath)\n", stderr)
    exit(1)
}

let encoded = absolutePath.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? absolutePath
let urlString = "mdreader://\(encoded)"

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
process.arguments = [urlString]

do {
    try process.run()
    process.waitUntilExit()
} catch {
    fputs("Error: could not open MDReader app: \(error.localizedDescription)\n", stderr)
    exit(1)
}
```

**Step 2: Build to verify**

Run: `swift build`
Expected: Build succeeds

**Step 3: Commit**

```bash
git add Sources/mdreader-cli/main.swift
git commit -m "feat: implement CLI utility for opening markdown files"
```

---

### Task 8: Open File via Sidebar Click + Drag & Drop

**Files:**
- Modify: `Sources/MDReaderApp/MDReaderApp.swift`

**Step 1: Add file open dialog and drag & drop support**

Add a toolbar button to open files via system file picker and support drag & drop of .md files onto the window:

```swift
// Add to the NavigationSplitView in MDReaderApp.swift, after .onOpenURL:
.toolbar {
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
            if let url, url.pathExtension == "md" || url.pathExtension == "markdown" {
                DispatchQueue.main.async {
                    fileCache.addFile(url: url)
                    selectedFilePath = url.path
                }
            }
        }
    }
    return true
}
```

Add the helper method to MDReaderApp:

```swift
private func openFilePanel() {
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [.init(filenameExtension: "md")!]
    panel.allowsMultipleSelection = false
    if panel.runModal() == .OK, let url = panel.url {
        fileCache.addFile(url: url)
        selectedFilePath = url.path
    }
}
```

**Step 2: Build to verify**

Run: `swift build`
Expected: Build succeeds

**Step 3: Commit**

```bash
git add Sources/MDReaderApp/MDReaderApp.swift
git commit -m "feat: add file open dialog and drag & drop support"
```

---

### Task 9: Final Build & Manual Testing

**Step 1: Full build**

Run: `swift build`
Expected: Build succeeds with no warnings

**Step 2: Run the app**

Run: `.build/debug/MDReaderApp`
Expected: App window opens with empty sidebar and "No File Selected" placeholder

**Step 3: Test CLI**

Create a test markdown file and open it:
```bash
echo "# Hello MDReader\n\nThis is a **test** file." > /tmp/test.md
.build/debug/mdreader-cli /tmp/test.md
```
Expected: App opens and displays the test file

**Step 4: Commit final state**

```bash
git add -A
git commit -m "chore: final build verification"
```
