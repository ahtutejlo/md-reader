# Sidebar File List: Path Disambiguation & Reveal in Finder — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make sidebar rows distinguish files with identical names by showing a home-collapsed, middle-truncated path, and add a "Reveal in Finder" action.

**Architecture:** `CachedFile` gains a computed `displayPath` that substitutes `$HOME` with `~`. `FileRow` gets a third caption line showing that path with middle truncation and a `.help` tooltip with the full absolute path. The row's existing context menu gains a "Reveal in Finder" item (calling `NSWorkspace.shared.activateFileViewerSelecting`) above the existing "Remove from List".

**Tech Stack:** Swift 5, SwiftUI, AppKit (`NSWorkspace`), Swift Package Manager (`swift build` / `swift test`), existing XCTest target under `Tests/`.

**Spec:** `docs/superpowers/specs/2026-04-12-sidebar-file-list-path-design.md`

---

## File Structure

- Modify: `Sources/MDReaderApp/Models/CachedFile.swift` — add `displayPath` computed property.
- Modify: `Sources/MDReaderApp/Views/SidebarView.swift` — add third text line in `FileRow`, add `.help` tooltip, add "Reveal in Finder" context menu item, ensure `AppKit` import.
- Test: `Tests/MDReaderAppTests/CachedFileTests.swift` — add tests for `displayPath`. (If the file does not exist yet, create it; otherwise extend it.)

The UI-level changes in `SidebarView.swift` are verified manually — SwiftUI previews and `NSWorkspace.activateFileViewerSelecting` are not unit-testable here. The model-level logic (`displayPath`) is where the real behavior to regress-test lives.

---

## Task 1: `displayPath` on `CachedFile`

**Files:**
- Modify: `Sources/MDReaderApp/Models/CachedFile.swift`
- Test: `Tests/MDReaderAppTests/CachedFileTests.swift` (create if missing)

- [ ] **Step 1: Check whether the test file already exists**

Run: `ls Tests/MDReaderAppTests/CachedFileTests.swift`

If it exists, you'll extend it. If not (exit status non-zero), you'll create it in Step 2.

- [ ] **Step 2: Write the failing tests**

If `Tests/MDReaderAppTests/CachedFileTests.swift` does not exist, create it with the full content below. If it does exist, add the three `test_displayPath_*` methods inside the existing `final class CachedFileTests: XCTestCase` (adjust the class name if different — read the file first and match).

```swift
import XCTest
@testable import MDReaderApp

final class CachedFileTests: XCTestCase {
    private func makeFile(path: String) -> CachedFile {
        // Bypass the throwing init(url:) which hits the filesystem — decode from JSON instead.
        let json = """
        {"path":"\(path)","lastOpened":0,"isFavorite":false}
        """.data(using: .utf8)!
        return try! JSONDecoder().decode(CachedFile.self, from: json)
    }

    func test_displayPath_collapsesHomeDirectoryToTilde() {
        let home = NSHomeDirectory()
        let file = makeFile(path: "\(home)/projects/md-reader/README.md")
        XCTAssertEqual(file.displayPath, "~/projects/md-reader/README.md")
    }

    func test_displayPath_leavesNonHomePathsUntouched() {
        let file = makeFile(path: "/tmp/scratch/notes.md")
        XCTAssertEqual(file.displayPath, "/tmp/scratch/notes.md")
    }

    func test_displayPath_doesNotCollapsePathsThatMerelyStartWithHomePrefix() {
        // e.g. NSHomeDirectory() is "/Users/alice" and the path is "/Users/alice-backup/foo.md".
        let home = NSHomeDirectory()
        let sibling = home + "-backup/foo.md"
        let file = makeFile(path: sibling)
        XCTAssertEqual(file.displayPath, sibling)
    }
}
```

Note on the third test: a naive `hasPrefix(home)` check incorrectly collapses `/Users/alice-backup/...` when home is `/Users/alice`. The implementation must guard against this (see Step 4).

- [ ] **Step 3: Run the tests and watch them fail**

Run: `swift test --filter CachedFileTests`
Expected: compilation error on `file.displayPath` ("value of type 'CachedFile' has no member 'displayPath'"). That is a valid failing-test state.

- [ ] **Step 4: Implement `displayPath`**

Open `Sources/MDReaderApp/Models/CachedFile.swift` and add the computed property inside the struct, right below the existing `exists` property:

```swift
    var displayPath: String {
        let home = NSHomeDirectory()
        if path == home {
            return "~"
        }
        let prefix = home + "/"
        if path.hasPrefix(prefix) {
            return "~/" + path.dropFirst(prefix.count)
        }
        return path
    }
```

The `home + "/"` guard is what prevents `/Users/alice-backup/...` from matching when home is `/Users/alice`.

- [ ] **Step 5: Run the tests and verify they pass**

Run: `swift test --filter CachedFileTests`
Expected: all three `test_displayPath_*` tests pass.

- [ ] **Step 6: Commit**

```bash
git add Sources/MDReaderApp/Models/CachedFile.swift Tests/MDReaderAppTests/CachedFileTests.swift
git commit -m "feat(model): add displayPath to CachedFile"
```

---

## Task 2: Path line in `FileRow`

**Files:**
- Modify: `Sources/MDReaderApp/Views/SidebarView.swift`

- [ ] **Step 1: Ensure `AppKit` is imported**

Open `Sources/MDReaderApp/Views/SidebarView.swift`. The current top of the file is:

```swift
import SwiftUI
```

Replace with:

```swift
import AppKit
import SwiftUI
```

AppKit isn't strictly needed for this task (it's used in Task 3) but adding it now keeps the import list stable across the two commits.

- [ ] **Step 2: Add the path line to `FileRow`**

In `Sources/MDReaderApp/Views/SidebarView.swift`, replace the `FileRow` `body` with the version below. The only changes versus the current code are: a new `Text(file.displayPath)` line between the name `HStack` and the date `Text`, and a `.help(file.path)` modifier on the outer `VStack`.

```swift
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Image(systemName: file.exists ? "doc.text" : "doc.text.fill")
                    .foregroundStyle(file.exists ? Color.primary : Color.red)
                Text(file.name)
                    .lineLimit(1)
                Spacer()
                if file.isFavorite || isHovering {
                    Button {
                        onToggleFavorite()
                    } label: {
                        Image(systemName: file.isFavorite ? "star.fill" : "star")
                            .foregroundStyle(file.isFavorite ? .yellow : .secondary)
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                }
            }
            Text(file.displayPath)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            Text(file.lastOpened, style: .relative)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
        .help(file.path)
        .onHover { hovering in
            isHovering = hovering
        }
    }
```

- [ ] **Step 3: Build and make sure it compiles**

Run: `swift build`
Expected: Build succeeds with no errors.

- [ ] **Step 4: Manual sanity check (optional but recommended)**

Launch the app (`make run` or whatever the project uses — see `Makefile`) and confirm:
- Each sidebar row now shows three lines: name, path (with `~` prefix for files under `$HOME`), relative date.
- A very long path is truncated in the middle with an ellipsis and the full absolute path appears as a tooltip on hover.

If you can't easily run the app, skip this step and trust the compile + Task 1 tests.

- [ ] **Step 5: Commit**

```bash
git add Sources/MDReaderApp/Views/SidebarView.swift
git commit -m "feat(sidebar): show displayPath as third line in file row"
```

---

## Task 3: "Reveal in Finder" context menu

**Files:**
- Modify: `Sources/MDReaderApp/Views/SidebarView.swift`

- [ ] **Step 1: Extend the context menu**

In `Sources/MDReaderApp/Views/SidebarView.swift`, the current `List` row is:

```swift
            List(filteredFiles, selection: $selectedFilePath) { file in
                FileRow(file: file, onToggleFavorite: { onToggleFavorite(file.path) })
                    .contextMenu {
                        Button("Remove from List", role: .destructive) {
                            onRemove(file)
                        }
                    }
            }
```

Replace the `.contextMenu { ... }` block with:

```swift
                    .contextMenu {
                        Button("Reveal in Finder") {
                            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: file.path)])
                        }
                        Divider()
                        Button("Remove from List", role: .destructive) {
                            onRemove(file)
                        }
                    }
```

`NSWorkspace` is available via the `AppKit` import added in Task 2.

- [ ] **Step 2: Build**

Run: `swift build`
Expected: Build succeeds with no errors.

- [ ] **Step 3: Manual verification**

Launch the app. Right-click a file in the sidebar. Confirm:
- The menu now shows "Reveal in Finder", a separator, then "Remove from List".
- Clicking "Reveal in Finder" opens Finder with the file selected.
- Clicking "Remove from List" still removes the entry.

If you cannot run the app in this environment, state that explicitly in the task write-up — don't claim success you didn't verify.

- [ ] **Step 4: Commit**

```bash
git add Sources/MDReaderApp/Views/SidebarView.swift
git commit -m "feat(sidebar): add Reveal in Finder to row context menu"
```

---

## Task 4: Full test + build pass

**Files:** none modified

- [ ] **Step 1: Run the full test suite**

Run: `swift test`
Expected: All tests pass, including the three new ones from Task 1.

- [ ] **Step 2: Build release-style to catch anything debug-only missed**

Run: `swift build -c release`
Expected: Build succeeds.

- [ ] **Step 3: Check git status is clean**

Run: `git status`
Expected: `nothing to commit, working tree clean` with three new commits on the branch (Tasks 1–3).

---

## Notes on testing UI changes

`FileRow` is small and its logic is a straight mapping from `CachedFile` to SwiftUI views. The only branchy piece (`displayPath`) is covered by unit tests in Task 1. The rest — text placement, truncation, tooltip, context menu — is presentation that XCTest cannot meaningfully assert without an `XCUITest` target the project doesn't currently have. Manual verification in Tasks 2–3 is the right tool here; adding a UI test target would be out of scope.
