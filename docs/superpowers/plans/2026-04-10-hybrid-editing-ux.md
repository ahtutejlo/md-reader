# Hybrid Editing UX Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the split (editor + preview) view mode pleasant to use by fixing preview flicker, adding cursor-driven scroll sync, and adding a formatting toolbar with keyboard shortcuts.

**Architecture:** Extract the markdown renderer into a pure service that emits `data-line` attributes; add a pure `MarkdownFormatter` service driven from both a SwiftUI toolbar and `CommandGroup` keyboard shortcuts; rewrite `MarkdownWebView` to load an HTML shell once and push updates via `evaluateJavaScript` (`DOMParser` + `replaceChildren` for content, `scrollIntoView` for sync).

**Tech Stack:** Swift 5.9, SwiftUI, AppKit (`NSTextView`), WebKit (`WKWebView`), Swift Testing framework (`@Test`, `#expect`).

**Spec:** `docs/superpowers/specs/2026-04-10-hybrid-editing-ux-design.md`

---

## File Structure

### New files

| File | Responsibility |
|---|---|
| `Sources/MDReaderApp/Services/MarkdownRenderer.swift` | Pure `String` → HTML. Emits `data-line="N"` on every top-level block. No AppKit/WebKit deps. |
| `Sources/MDReaderApp/Services/MarkdownFormatter.swift` | Pure `(String, NSRange, action)` → `(String, NSRange)`. Wrap/toggle and prefix/toggle logic. Foundation only. |
| `Sources/MDReaderApp/Views/MarkdownFormattingToolbar.swift` | SwiftUI `View` exposing formatting actions as buttons; writes to `EditorViewModel.pendingFormat`. |
| `Tests/MDReaderAppTests/MarkdownRendererTests.swift` | Verifies `data-line` attributes and parity for existing output. |
| `Tests/MDReaderAppTests/MarkdownFormatterTests.swift` | Covers all `MarkdownFormatAction` cases, toggle semantics, edge cases. |

### Modified files

| File | Changes |
|---|---|
| `Sources/MDReaderApp/Services/EditorViewModel.swift` | Add `activeLine: Int`, `pendingFormat: MarkdownFormatAction?`. Reset `activeLine` in `loadFile` and `clearFile`. |
| `Sources/MDReaderApp/Views/MarkdownEditorView.swift` | Subscribe to `didChangeSelectionNotification` → publish `activeLine`; consume `pendingFormat` in `updateNSView`. |
| `Sources/MDReaderApp/Views/MarkdownWebView.swift` | Remove embedded `markdownToHTML`; switch input from `markdown: String` to `@Bindable viewModel: EditorViewModel`; load HTML shell once; push updates through `evaluateJavaScript`. |
| `Sources/MDReaderApp/Views/ContentView.swift` | Call-site: `MarkdownWebView(viewModel: viewModel)` in `.split` and `.preview` arms. |
| `Sources/MDReaderApp/MDReaderApp.swift` | Add `MarkdownFormattingToolbar` to the window toolbar; add `CommandGroup(after: .textFormatting)` with keyboard shortcuts. |
| `Tests/MDReaderAppTests/MarkdownTableTests.swift` | Switch test helper from `MarkdownWebView(markdown:).markdownToHTML(...)` to `MarkdownRenderer.renderHTML(from:)`. |

---

## Phase 1 — Extract MarkdownRenderer with `data-line` attributes

Pure refactor followed by a small additive change. Keeps `MarkdownWebView` behavior identical until Phase 3. Unlocks both scroll sync (needs `data-line`) and cleaner testing.

### Task 1.1: Extract `markdownToHTML` into `MarkdownRenderer`

**Files:**
- Create: `Sources/MDReaderApp/Services/MarkdownRenderer.swift`
- Modify: `Sources/MDReaderApp/Views/MarkdownWebView.swift`
- Modify: `Tests/MDReaderAppTests/MarkdownTableTests.swift`

- [ ] **Step 1: Create `MarkdownRenderer.swift` with the extracted logic**

Copy the entire `markdownToHTML(_:)` method and its private helpers (`isTableStart`, `parseTableRow`, `normalizeCells`, `parseAlignments`, `escapeHTML`, `inlineMarkdown`) from `MarkdownWebView.swift` into a new file:

```swift
import Foundation

enum MarkdownRenderer {
    /// Converts markdown source to HTML using line-by-line parsing.
    /// Input is local file content — no untrusted user input.
    static func renderHTML(from source: String) -> String {
        let lines = source.components(separatedBy: "\n")
        var html: [String] = []
        var i = 0

        while i < lines.count {
            let line = lines[i]

            // Fenced code block
            if line.hasPrefix("```") {
                let lang = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                var codeLines: [String] = []
                i += 1
                while i < lines.count && !lines[i].hasPrefix("```") {
                    codeLines.append(escapeHTML(lines[i]))
                    i += 1
                }
                let langAttr = lang.isEmpty ? "" : " class=\"language-\(escapeHTML(lang))\""
                html.append("<pre><code\(langAttr)>\(codeLines.joined(separator: "\n"))</code></pre>")
                i += 1
                continue
            }

            // Headings
            if line.hasPrefix("######") {
                html.append("<h6>\(inlineMarkdown(String(line.dropFirst(7))))</h6>")
                i += 1; continue
            }
            if line.hasPrefix("#####") {
                html.append("<h5>\(inlineMarkdown(String(line.dropFirst(6))))</h5>")
                i += 1; continue
            }
            if line.hasPrefix("####") {
                html.append("<h4>\(inlineMarkdown(String(line.dropFirst(5))))</h4>")
                i += 1; continue
            }
            if line.hasPrefix("###") {
                html.append("<h3>\(inlineMarkdown(String(line.dropFirst(4))))</h3>")
                i += 1; continue
            }
            if line.hasPrefix("##") {
                html.append("<h2>\(inlineMarkdown(String(line.dropFirst(3))))</h2>")
                i += 1; continue
            }
            if line.hasPrefix("#") {
                html.append("<h1>\(inlineMarkdown(String(line.dropFirst(2))))</h1>")
                i += 1; continue
            }

            // Horizontal rule
            if line.trimmingCharacters(in: .whitespaces) == "---" ||
               line.trimmingCharacters(in: .whitespaces) == "***" ||
               line.trimmingCharacters(in: .whitespaces) == "___" {
                html.append("<hr>")
                i += 1; continue
            }

            // Blockquote
            if line.hasPrefix(">") {
                var quoteLines: [String] = []
                while i < lines.count && lines[i].hasPrefix(">") {
                    let content = String(lines[i].dropFirst(1)).trimmingCharacters(in: .init(charactersIn: " "))
                    quoteLines.append(inlineMarkdown(content))
                    i += 1
                }
                html.append("<blockquote><p>\(quoteLines.joined(separator: "<br>"))</p></blockquote>")
                continue
            }

            // Unordered list
            if line.hasPrefix("- ") || line.hasPrefix("* ") {
                html.append("<ul>")
                while i < lines.count && (lines[i].hasPrefix("- ") || lines[i].hasPrefix("* ")) {
                    let content = String(lines[i].dropFirst(2))
                    html.append("<li>\(inlineMarkdown(content))</li>")
                    i += 1
                }
                html.append("</ul>")
                continue
            }

            // Ordered list
            if let _ = line.range(of: #"^\d+\. "#, options: .regularExpression) {
                html.append("<ol>")
                while i < lines.count, let range = lines[i].range(of: #"^\d+\. "#, options: .regularExpression) {
                    let content = String(lines[i][range.upperBound...])
                    html.append("<li>\(inlineMarkdown(content))</li>")
                    i += 1
                }
                html.append("</ol>")
                continue
            }

            // Table
            if isTableStart(lines: lines, at: i) {
                let headers = parseTableRow(line)
                let colCount = headers.count
                let alignments = parseAlignments(lines[i + 1], count: colCount)
                i += 2
                html.append("<table><thead><tr>")
                for (j, h) in headers.enumerated() {
                    let style = alignments[j].isEmpty ? "" : " style=\"text-align:\(alignments[j])\""
                    html.append("<th\(style)>\(inlineMarkdown(h))</th>")
                }
                html.append("</tr></thead><tbody>")
                while i < lines.count && lines[i].contains("|") {
                    let raw = parseTableRow(lines[i])
                    let cells = normalizeCells(raw, count: colCount)
                    html.append("<tr>")
                    for (j, c) in cells.enumerated() {
                        let style = alignments[j].isEmpty ? "" : " style=\"text-align:\(alignments[j])\""
                        html.append("<td\(style)>\(inlineMarkdown(c))</td>")
                    }
                    html.append("</tr>")
                    i += 1
                }
                html.append("</tbody></table>")
                continue
            }

            // Empty line
            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                i += 1; continue
            }

            // Paragraph
            var paraLines: [String] = []
            while i < lines.count &&
                  !lines[i].trimmingCharacters(in: .whitespaces).isEmpty &&
                  !lines[i].hasPrefix("#") &&
                  !lines[i].hasPrefix("```") &&
                  !lines[i].hasPrefix(">") &&
                  !lines[i].hasPrefix("- ") &&
                  !lines[i].hasPrefix("* ") &&
                  lines[i].range(of: #"^\d+\. "#, options: .regularExpression) == nil &&
                  lines[i].trimmingCharacters(in: .whitespaces) != "---" &&
                  !isTableStart(lines: lines, at: i) {
                paraLines.append(inlineMarkdown(lines[i]))
                i += 1
            }
            if !paraLines.isEmpty {
                html.append("<p>\(paraLines.joined(separator: "\n"))</p>")
            }
        }

        return html.joined(separator: "\n")
    }

    // MARK: - Private helpers

    private static func isTableStart(lines: [String], at i: Int) -> Bool {
        guard i + 1 < lines.count, lines[i].contains("|") else { return false }
        return lines[i + 1].range(
            of: #"^\|?(\s*:?-{3,}:?\s*\|)+\s*:?-{3,}:?\s*\|?\s*$"#,
            options: .regularExpression
        ) != nil
    }

    private static func parseTableRow(_ row: String) -> [String] {
        var trimmed = row.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("|") { trimmed = String(trimmed.dropFirst()) }
        if trimmed.hasSuffix("|") { trimmed = String(trimmed.dropLast()) }
        var cells: [String] = []
        var current = ""
        var escaped = false
        for ch in trimmed {
            if escaped {
                if ch == "|" { current.append(ch) } else { current.append("\\"); current.append(ch) }
                escaped = false
            } else if ch == "\\" {
                escaped = true
            } else if ch == "|" {
                cells.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
            } else {
                current.append(ch)
            }
        }
        if escaped { current.append("\\") }
        cells.append(current.trimmingCharacters(in: .whitespaces))
        return cells
    }

    private static func normalizeCells(_ cells: [String], count: Int) -> [String] {
        if cells.count >= count { return Array(cells.prefix(count)) }
        return cells + Array(repeating: "", count: count - cells.count)
    }

    private static func parseAlignments(_ separator: String, count: Int) -> [String] {
        let parts = separator.trimmingCharacters(in: .whitespaces)
            .trimmingCharacters(in: .init(charactersIn: "|"))
            .components(separatedBy: "|")
            .map { $0.trimmingCharacters(in: .whitespaces) }
        var alignments: [String] = []
        for part in parts {
            let left = part.hasPrefix(":")
            let right = part.hasSuffix(":")
            if left && right { alignments.append("center") }
            else if right { alignments.append("right") }
            else if left { alignments.append("left") }
            else { alignments.append("") }
        }
        return normalizeCells(alignments, count: count)
    }

    private static func escapeHTML(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private static func inlineMarkdown(_ text: String) -> String {
        var result = escapeHTML(text)

        result = result.replacingOccurrences(
            of: #"`([^`]+)`"#, with: "<code>$1</code>",
            options: .regularExpression)

        result = result.replacingOccurrences(
            of: #"\*\*\*(.+?)\*\*\*"#, with: "<strong><em>$1</em></strong>",
            options: .regularExpression)

        result = result.replacingOccurrences(
            of: #"\*\*(.+?)\*\*"#, with: "<strong>$1</strong>",
            options: .regularExpression)

        result = result.replacingOccurrences(
            of: #"\*(.+?)\*"#, with: "<em>$1</em>",
            options: .regularExpression)

        result = result.replacingOccurrences(
            of: #"\[([^\]]+)\]\(([^)]+)\)"#, with: #"<a href="$2">$1</a>"#,
            options: .regularExpression)

        return result
    }
}
```

- [ ] **Step 2: Delete the copied methods from `MarkdownWebView.swift`**

Remove from `Sources/MDReaderApp/Views/MarkdownWebView.swift`:
- `func markdownToHTML(_ source: String) -> String` (currently at line 273)
- `private func isTableStart(...)` through `private func inlineMarkdown(...)` (the tail of the file)

Replace the call in `buildHTML(from:)`:

```swift
private func buildHTML(from source: String) -> String {
    let rendered = MarkdownRenderer.renderHTML(from: source)
    return """
    <!DOCTYPE html>
    ...existing HTML shell...
    """
}
```

Leave everything else (the CSS, `makeNSView`, `updateNSView`) untouched.

- [ ] **Step 3: Update `MarkdownTableTests.swift` to use the new API**

Replace the file-level helper:

```swift
import Testing
@testable import MDReaderApp

@Test func basicTable() {
    let md = """
    | Name | Age |
    | --- | --- |
    | Alice | 30 |
    | Bob | 25 |
    """
    let html = MarkdownRenderer.renderHTML(from: md)
    #expect(html.contains("<table>"))
    // ...same expectations
}
```

Find/replace every `view.markdownToHTML(md)` with `MarkdownRenderer.renderHTML(from: md)` and remove the `private let view = MarkdownWebView(markdown: "")` line at the top.

- [ ] **Step 4: Build and run existing tests**

Run: `swift test --filter MarkdownTableTests`
Expected: all existing table tests still pass.

Run: `swift build`
Expected: clean build, no warnings about unused methods.

- [ ] **Step 5: Commit**

```bash
git add Sources/MDReaderApp/Services/MarkdownRenderer.swift \
        Sources/MDReaderApp/Views/MarkdownWebView.swift \
        Tests/MDReaderAppTests/MarkdownTableTests.swift
git commit -m "refactor: extract MarkdownRenderer from MarkdownWebView"
```

---

### Task 1.2: Add `data-line` attributes to rendered blocks

**Files:**
- Modify: `Sources/MDReaderApp/Services/MarkdownRenderer.swift`
- Create: `Tests/MDReaderAppTests/MarkdownRendererTests.swift`

- [ ] **Step 1: Write the failing test for `data-line` on headings**

Create `Tests/MDReaderAppTests/MarkdownRendererTests.swift`:

```swift
import Testing
@testable import MDReaderApp

@Test func dataLineOnHeadings() {
    let md = """
    # First

    ## Second

    ### Third
    """
    let html = MarkdownRenderer.renderHTML(from: md)
    #expect(html.contains("<h1 data-line=\"0\">First</h1>"))
    #expect(html.contains("<h2 data-line=\"2\">Second</h2>"))
    #expect(html.contains("<h3 data-line=\"4\">Third</h3>"))
}
```

- [ ] **Step 2: Run the test to confirm failure**

Run: `swift test --filter dataLineOnHeadings`
Expected: FAIL — the current output has `<h1>First</h1>` without the attribute.

- [ ] **Step 3: Thread the current line index through the renderer**

In `MarkdownRenderer.swift`, modify `renderHTML(from:)` so each heading emission includes `data-line="\(blockStart)"`. Track `blockStart` as the line index `i` captured at the start of the block:

Replace the headings section:

```swift
// Headings
if line.hasPrefix("######") {
    html.append("<h6 data-line=\"\(i)\">\(inlineMarkdown(String(line.dropFirst(7))))</h6>")
    i += 1; continue
}
if line.hasPrefix("#####") {
    html.append("<h5 data-line=\"\(i)\">\(inlineMarkdown(String(line.dropFirst(6))))</h5>")
    i += 1; continue
}
if line.hasPrefix("####") {
    html.append("<h4 data-line=\"\(i)\">\(inlineMarkdown(String(line.dropFirst(5))))</h4>")
    i += 1; continue
}
if line.hasPrefix("###") {
    html.append("<h3 data-line=\"\(i)\">\(inlineMarkdown(String(line.dropFirst(4))))</h3>")
    i += 1; continue
}
if line.hasPrefix("##") {
    html.append("<h2 data-line=\"\(i)\">\(inlineMarkdown(String(line.dropFirst(3))))</h2>")
    i += 1; continue
}
if line.hasPrefix("#") {
    html.append("<h1 data-line=\"\(i)\">\(inlineMarkdown(String(line.dropFirst(2))))</h1>")
    i += 1; continue
}
```

- [ ] **Step 4: Run the test again**

Run: `swift test --filter dataLineOnHeadings`
Expected: PASS.

- [ ] **Step 5: Write the failing test for `data-line` on paragraphs**

Append to `MarkdownRendererTests.swift`:

```swift
@Test func dataLineOnParagraph() {
    let md = """
    First paragraph.

    Second paragraph
    continues here.
    """
    let html = MarkdownRenderer.renderHTML(from: md)
    #expect(html.contains("<p data-line=\"0\">First paragraph.</p>"))
    #expect(html.contains("<p data-line=\"2\">Second paragraph\ncontinues here.</p>"))
}
```

- [ ] **Step 6: Run the test to confirm failure**

Run: `swift test --filter dataLineOnParagraph`
Expected: FAIL.

- [ ] **Step 7: Add `data-line` to paragraph emission**

Replace the paragraph block in `renderHTML(from:)`:

```swift
// Paragraph
let paraStart = i
var paraLines: [String] = []
while i < lines.count &&
      !lines[i].trimmingCharacters(in: .whitespaces).isEmpty &&
      !lines[i].hasPrefix("#") &&
      !lines[i].hasPrefix("```") &&
      !lines[i].hasPrefix(">") &&
      !lines[i].hasPrefix("- ") &&
      !lines[i].hasPrefix("* ") &&
      lines[i].range(of: #"^\d+\. "#, options: .regularExpression) == nil &&
      lines[i].trimmingCharacters(in: .whitespaces) != "---" &&
      !isTableStart(lines: lines, at: i) {
    paraLines.append(inlineMarkdown(lines[i]))
    i += 1
}
if !paraLines.isEmpty {
    html.append("<p data-line=\"\(paraStart)\">\(paraLines.joined(separator: "\n"))</p>")
}
```

- [ ] **Step 8: Run the test**

Run: `swift test --filter dataLineOnParagraph`
Expected: PASS.

- [ ] **Step 9: Write the failing test for lists, fenced code, blockquote, table, hr**

Append to `MarkdownRendererTests.swift`:

```swift
@Test func dataLineOnUnorderedList() {
    let md = """
    Intro.

    - one
    - two
    """
    let html = MarkdownRenderer.renderHTML(from: md)
    #expect(html.contains("<ul data-line=\"2\">"))
}

@Test func dataLineOnOrderedList() {
    let md = """
    1. first
    2. second
    """
    let html = MarkdownRenderer.renderHTML(from: md)
    #expect(html.contains("<ol data-line=\"0\">"))
}

@Test func dataLineOnFencedCodeBlock() {
    let md = """
    para

    ```swift
    let x = 1
    ```
    """
    let html = MarkdownRenderer.renderHTML(from: md)
    #expect(html.contains("<pre data-line=\"2\">"))
}

@Test func dataLineOnBlockquote() {
    let md = """
    intro

    > quoted line
    > second line
    """
    let html = MarkdownRenderer.renderHTML(from: md)
    #expect(html.contains("<blockquote data-line=\"2\">"))
}

@Test func dataLineOnTable() {
    let md = """
    before

    | A | B |
    | --- | --- |
    | 1 | 2 |
    """
    let html = MarkdownRenderer.renderHTML(from: md)
    #expect(html.contains("<table data-line=\"2\">"))
}

@Test func dataLineOnHorizontalRule() {
    let md = """
    above

    ---

    below
    """
    let html = MarkdownRenderer.renderHTML(from: md)
    #expect(html.contains("<hr data-line=\"2\">"))
}
```

- [ ] **Step 10: Run the tests to confirm failure**

Run: `swift test --filter MarkdownRendererTests`
Expected: the six new tests FAIL.

- [ ] **Step 11: Add `data-line` to the remaining block emissions**

Update `renderHTML(from:)`:

```swift
// Fenced code block
if line.hasPrefix("```") {
    let blockStart = i
    let lang = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
    var codeLines: [String] = []
    i += 1
    while i < lines.count && !lines[i].hasPrefix("```") {
        codeLines.append(escapeHTML(lines[i]))
        i += 1
    }
    let langAttr = lang.isEmpty ? "" : " class=\"language-\(escapeHTML(lang))\""
    html.append("<pre data-line=\"\(blockStart)\"><code\(langAttr)>\(codeLines.joined(separator: "\n"))</code></pre>")
    i += 1
    continue
}
```

```swift
// Horizontal rule
if line.trimmingCharacters(in: .whitespaces) == "---" ||
   line.trimmingCharacters(in: .whitespaces) == "***" ||
   line.trimmingCharacters(in: .whitespaces) == "___" {
    html.append("<hr data-line=\"\(i)\">")
    i += 1; continue
}
```

```swift
// Blockquote
if line.hasPrefix(">") {
    let blockStart = i
    var quoteLines: [String] = []
    while i < lines.count && lines[i].hasPrefix(">") {
        let content = String(lines[i].dropFirst(1)).trimmingCharacters(in: .init(charactersIn: " "))
        quoteLines.append(inlineMarkdown(content))
        i += 1
    }
    html.append("<blockquote data-line=\"\(blockStart)\"><p>\(quoteLines.joined(separator: "<br>"))</p></blockquote>")
    continue
}
```

```swift
// Unordered list
if line.hasPrefix("- ") || line.hasPrefix("* ") {
    let blockStart = i
    html.append("<ul data-line=\"\(blockStart)\">")
    while i < lines.count && (lines[i].hasPrefix("- ") || lines[i].hasPrefix("* ")) {
        let content = String(lines[i].dropFirst(2))
        html.append("<li>\(inlineMarkdown(content))</li>")
        i += 1
    }
    html.append("</ul>")
    continue
}
```

```swift
// Ordered list
if let _ = line.range(of: #"^\d+\. "#, options: .regularExpression) {
    let blockStart = i
    html.append("<ol data-line=\"\(blockStart)\">")
    while i < lines.count, let range = lines[i].range(of: #"^\d+\. "#, options: .regularExpression) {
        let content = String(lines[i][range.upperBound...])
        html.append("<li>\(inlineMarkdown(content))</li>")
        i += 1
    }
    html.append("</ol>")
    continue
}
```

```swift
// Table
if isTableStart(lines: lines, at: i) {
    let blockStart = i
    let headers = parseTableRow(line)
    let colCount = headers.count
    let alignments = parseAlignments(lines[i + 1], count: colCount)
    i += 2
    html.append("<table data-line=\"\(blockStart)\"><thead><tr>")
    // ...rest unchanged
```

- [ ] **Step 12: Run all the new tests plus existing ones**

Run: `swift test --filter MarkdownRendererTests`
Expected: all six new tests PASS.

Run: `swift test --filter MarkdownTableTests`
Expected: all existing table tests still PASS (they check for `<table>`, `<tr>`, `<td>`; none of them assert the absence of attributes, so `<table data-line="N">` matches `contains("<table>")` as a substring match? **Verify:** the assertion is `contains("<table>")` — `"<table data-line=..."` does NOT contain `"<table>"` because of the space before `data-line`. This test will FAIL.

- [ ] **Step 13: Update `MarkdownTableTests.swift` expectations**

Find every occurrence of `"<table>"`, `"<blockquote>"`, `"<ul>"`, `"<ol>"`, `"<pre"` in `MarkdownTableTests.swift` that is used as a `contains` probe and widen them to match the attributed form:

```swift
// Before
#expect(html.contains("<table>"))
// After
#expect(html.contains("<table data-line=\""))
```

Also update the `columnNormalization` test helpers if they assert exact structure. Inspect each `contains` call and adjust.

- [ ] **Step 14: Run the full test suite**

Run: `swift test`
Expected: all tests pass.

- [ ] **Step 15: Commit**

```bash
git add Sources/MDReaderApp/Services/MarkdownRenderer.swift \
        Tests/MDReaderAppTests/MarkdownRendererTests.swift \
        Tests/MDReaderAppTests/MarkdownTableTests.swift
git commit -m "feat(renderer): emit data-line attributes on top-level blocks"
```

---

## Phase 2 — MarkdownFormatter + toolbar + keyboard shortcuts

Independent of Phase 3. Ships formatting UX on its own.

### Task 2.1: Scaffold `MarkdownFormatAction` and `MarkdownFormatter`

**Files:**
- Create: `Sources/MDReaderApp/Services/MarkdownFormatter.swift`
- Create: `Tests/MDReaderAppTests/MarkdownFormatterTests.swift`

- [ ] **Step 1: Write the scaffolding file (no behavior yet)**

Create `Sources/MDReaderApp/Services/MarkdownFormatter.swift`:

```swift
import Foundation

enum MarkdownFormatAction: Equatable {
    case bold
    case italic
    case code
    case strikethrough
    case link
    case heading(level: Int)
    case unorderedList
    case orderedList
    case quote
    case codeBlock
}

struct FormattedResult: Equatable {
    let text: String
    let selection: NSRange
}

enum MarkdownFormatter {
    static func apply(_ action: MarkdownFormatAction,
                      to text: String,
                      selection: NSRange) -> FormattedResult {
        // Filled in by subsequent tasks
        FormattedResult(text: text, selection: selection)
    }
}
```

- [ ] **Step 2: Create empty test file**

Create `Tests/MDReaderAppTests/MarkdownFormatterTests.swift`:

```swift
import Testing
import Foundation
@testable import MDReaderApp
```

- [ ] **Step 3: Build**

Run: `swift build`
Expected: clean build.

- [ ] **Step 4: Commit**

```bash
git add Sources/MDReaderApp/Services/MarkdownFormatter.swift \
        Tests/MDReaderAppTests/MarkdownFormatterTests.swift
git commit -m "feat(formatter): scaffold MarkdownFormatter service"
```

---

### Task 2.2: Implement `.bold` with TDD (wrap + toggle)

**Files:**
- Modify: `Sources/MDReaderApp/Services/MarkdownFormatter.swift`
- Modify: `Tests/MDReaderAppTests/MarkdownFormatterTests.swift`

- [ ] **Step 1: Write the failing wrap test**

Append to `MarkdownFormatterTests.swift`:

```swift
@Test func boldWrapsSelection() {
    let input = "hello world"
    let selection = NSRange(location: 6, length: 5)  // "world"
    let result = MarkdownFormatter.apply(.bold, to: input, selection: selection)
    #expect(result.text == "hello **world**")
    #expect(result.selection == NSRange(location: 8, length: 5))
}
```

- [ ] **Step 2: Run the test**

Run: `swift test --filter boldWrapsSelection`
Expected: FAIL (scaffold returns input unchanged).

- [ ] **Step 3: Implement wrap-style handling**

Replace the body of `MarkdownFormatter.apply` with a dispatch that handles wrap-style actions. Add a private helper:

```swift
enum MarkdownFormatter {
    static func apply(_ action: MarkdownFormatAction,
                      to text: String,
                      selection: NSRange) -> FormattedResult {
        guard selection.location >= 0,
              selection.location + selection.length <= (text as NSString).length else {
            return FormattedResult(text: text, selection: selection)
        }

        switch action {
        case .bold:
            return wrap(text, selection: selection, marker: "**")
        default:
            return FormattedResult(text: text, selection: selection)
        }
    }

    private static func wrap(_ text: String, selection: NSRange, marker: String) -> FormattedResult {
        let ns = text as NSString
        if isWrapped(ns, selection: selection, marker: marker) {
            let markerLen = (marker as NSString).length
            let newText = ns.replacingCharacters(
                in: NSRange(location: selection.location - markerLen,
                            length: selection.length + 2 * markerLen),
                with: ns.substring(with: selection)
            )
            return FormattedResult(
                text: newText,
                selection: NSRange(location: selection.location - markerLen, length: selection.length)
            )
        }
        let selected = ns.substring(with: selection)
        let replacement = "\(marker)\(selected)\(marker)"
        let newText = ns.replacingCharacters(in: selection, with: replacement)
        let markerLen = (marker as NSString).length
        return FormattedResult(
            text: newText,
            selection: NSRange(location: selection.location + markerLen, length: selection.length)
        )
    }

    private static func isWrapped(_ ns: NSString, selection: NSRange, marker: String) -> Bool {
        let markerLen = (marker as NSString).length
        guard selection.location >= markerLen,
              selection.location + selection.length + markerLen <= ns.length else {
            return false
        }
        let before = ns.substring(with: NSRange(location: selection.location - markerLen, length: markerLen))
        let after = ns.substring(with: NSRange(location: selection.location + selection.length, length: markerLen))
        return before == marker && after == marker
    }
}
```

- [ ] **Step 4: Run the test**

Run: `swift test --filter boldWrapsSelection`
Expected: PASS.

- [ ] **Step 5: Write the failing toggle test**

Append:

```swift
@Test func boldToggleRemoves() {
    let input = "hello **world**"
    let selection = NSRange(location: 8, length: 5)  // "world"
    let result = MarkdownFormatter.apply(.bold, to: input, selection: selection)
    #expect(result.text == "hello world")
    #expect(result.selection == NSRange(location: 6, length: 5))
}
```

- [ ] **Step 6: Run the test**

Run: `swift test --filter boldToggleRemoves`
Expected: PASS (the `isWrapped` path handles it).

- [ ] **Step 7: Write the empty-string safety test**

Append:

```swift
@Test func boldOnEmptyString() {
    let result = MarkdownFormatter.apply(.bold, to: "", selection: NSRange(location: 0, length: 0))
    #expect(result.text == "****")
    #expect(result.selection == NSRange(location: 2, length: 0))
}
```

- [ ] **Step 8: Run the test**

Run: `swift test --filter boldOnEmptyString`
Expected: PASS.

- [ ] **Step 9: Commit**

```bash
git add Sources/MDReaderApp/Services/MarkdownFormatter.swift \
        Tests/MDReaderAppTests/MarkdownFormatterTests.swift
git commit -m "feat(formatter): implement bold wrap and toggle"
```

---

### Task 2.3: Implement `.italic`, `.code`, `.strikethrough`

**Files:**
- Modify: `Sources/MDReaderApp/Services/MarkdownFormatter.swift`
- Modify: `Tests/MDReaderAppTests/MarkdownFormatterTests.swift`

- [ ] **Step 1: Write failing tests for all three**

Append:

```swift
@Test func italicWrapsSelection() {
    let result = MarkdownFormatter.apply(
        .italic,
        to: "an apple",
        selection: NSRange(location: 3, length: 5)
    )
    #expect(result.text == "an *apple*")
    #expect(result.selection == NSRange(location: 4, length: 5))
}

@Test func codeWrapsSelection() {
    let result = MarkdownFormatter.apply(
        .code,
        to: "call foo now",
        selection: NSRange(location: 5, length: 3)
    )
    #expect(result.text == "call `foo` now")
    #expect(result.selection == NSRange(location: 6, length: 3))
}

@Test func strikethroughWrapsSelection() {
    let result = MarkdownFormatter.apply(
        .strikethrough,
        to: "old value",
        selection: NSRange(location: 0, length: 3)
    )
    #expect(result.text == "~~old~~ value")
    #expect(result.selection == NSRange(location: 2, length: 3))
}
```

- [ ] **Step 2: Run tests to confirm failure**

Run: `swift test --filter MarkdownFormatterTests`
Expected: the three new tests FAIL.

- [ ] **Step 3: Extend the `switch` in `apply`**

Replace the `switch action` block:

```swift
switch action {
case .bold:
    return wrap(text, selection: selection, marker: "**")
case .italic:
    return wrap(text, selection: selection, marker: "*")
case .code:
    return wrap(text, selection: selection, marker: "`")
case .strikethrough:
    return wrap(text, selection: selection, marker: "~~")
default:
    return FormattedResult(text: text, selection: selection)
}
```

- [ ] **Step 4: Run the tests**

Run: `swift test --filter MarkdownFormatterTests`
Expected: the three new tests PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/MDReaderApp/Services/MarkdownFormatter.swift \
        Tests/MDReaderAppTests/MarkdownFormatterTests.swift
git commit -m "feat(formatter): add italic, code, strikethrough"
```

---

### Task 2.4: Implement `.link`

**Files:**
- Modify: `Sources/MDReaderApp/Services/MarkdownFormatter.swift`
- Modify: `Tests/MDReaderAppTests/MarkdownFormatterTests.swift`

- [ ] **Step 1: Write the failing tests**

Append:

```swift
@Test func linkWrapsSelectionCursorOnURL() {
    let result = MarkdownFormatter.apply(
        .link,
        to: "click here to learn",
        selection: NSRange(location: 0, length: 10)  // "click here"
    )
    #expect(result.text == "[click here](url) to learn")
    #expect(result.selection == NSRange(location: 13, length: 3))  // "url"
}

@Test func linkEmptySelectionCursorBetweenBrackets() {
    let result = MarkdownFormatter.apply(
        .link,
        to: "hello",
        selection: NSRange(location: 5, length: 0)
    )
    #expect(result.text == "hello[](url)")
    #expect(result.selection == NSRange(location: 6, length: 0))
}
```

- [ ] **Step 2: Run the tests to confirm failure**

Run: `swift test --filter linkWrapsSelectionCursorOnURL`
Expected: FAIL.

- [ ] **Step 3: Implement `.link`**

Add a case in the switch and a helper:

```swift
case .link:
    return insertLink(text, selection: selection)
```

```swift
private static func insertLink(_ text: String, selection: NSRange) -> FormattedResult {
    let ns = text as NSString
    let selected = ns.substring(with: selection)
    if selected.isEmpty {
        let replacement = "[](url)"
        let newText = ns.replacingCharacters(in: selection, with: replacement)
        return FormattedResult(
            text: newText,
            selection: NSRange(location: selection.location + 1, length: 0)
        )
    }
    let replacement = "[\(selected)](url)"
    let newText = ns.replacingCharacters(in: selection, with: replacement)
    let urlStart = selection.location + 1 + (selected as NSString).length + 2  // "[" + text + "]("
    return FormattedResult(
        text: newText,
        selection: NSRange(location: urlStart, length: 3)  // "url"
    )
}
```

- [ ] **Step 4: Run the tests**

Run: `swift test --filter MarkdownFormatterTests`
Expected: both new tests PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/MDReaderApp/Services/MarkdownFormatter.swift \
        Tests/MDReaderAppTests/MarkdownFormatterTests.swift
git commit -m "feat(formatter): add link action"
```

---

### Task 2.5: Implement `.heading(level:)` with prefix/upgrade/toggle

**Files:**
- Modify: `Sources/MDReaderApp/Services/MarkdownFormatter.swift`
- Modify: `Tests/MDReaderAppTests/MarkdownFormatterTests.swift`

- [ ] **Step 1: Write the failing tests**

Append:

```swift
@Test func headingPrefixesCurrentLine() {
    let result = MarkdownFormatter.apply(
        .heading(level: 1),
        to: "title\nbody",
        selection: NSRange(location: 2, length: 0)  // cursor inside "title"
    )
    #expect(result.text == "# title\nbody")
    #expect(result.selection == NSRange(location: 4, length: 0))
}

@Test func headingOnMultilineSelection() {
    let result = MarkdownFormatter.apply(
        .heading(level: 2),
        to: "one\ntwo\nthree",
        selection: NSRange(location: 0, length: 7)  // "one\ntwo"
    )
    #expect(result.text == "## one\n## two\nthree")
}

@Test func headingToggleRemoves() {
    let result = MarkdownFormatter.apply(
        .heading(level: 1),
        to: "# title",
        selection: NSRange(location: 3, length: 0)  // cursor inside "title"
    )
    #expect(result.text == "title")
}

@Test func headingUpgradeReplacesLevel() {
    let result = MarkdownFormatter.apply(
        .heading(level: 2),
        to: "# title",
        selection: NSRange(location: 3, length: 0)
    )
    #expect(result.text == "## title")
}
```

- [ ] **Step 2: Run the tests**

Run: `swift test --filter MarkdownFormatterTests`
Expected: the four new tests FAIL.

- [ ] **Step 3: Implement `.heading`**

Add the case and helpers:

```swift
case .heading(let level):
    return applyLinePrefix(
        text,
        selection: selection,
        prefix: String(repeating: "#", count: level) + " ",
        matchAny: { line in
            guard let match = line.range(of: #"^#{1,6} "#, options: .regularExpression) else { return nil }
            return (line as NSString).substring(with: NSRange(match, in: line))
        }
    )
```

```swift
/// Applies a line prefix to every line that the selection intersects.
/// Behavior rules:
///   • If every selected line already starts with `prefix` → remove it (toggle off).
///   • Else if `matchAny` returns a different existing prefix for a line → replace it.
///   • Else → prepend `prefix` to the line.
private static func applyLinePrefix(
    _ text: String,
    selection: NSRange,
    prefix: String,
    matchAny: (String) -> String?
) -> FormattedResult {
    let ns = text as NSString
    let lineRange = ns.lineRange(for: selection)
    let block = ns.substring(with: lineRange)
    let hadTrailingNewline = block.hasSuffix("\n")
    let body = hadTrailingNewline ? String(block.dropLast()) : block
    let lines = body.components(separatedBy: "\n")

    let allHavePrefix = !lines.isEmpty && lines.allSatisfy { $0.hasPrefix(prefix) }

    let newLines: [String]
    if allHavePrefix {
        newLines = lines.map { String($0.dropFirst(prefix.count)) }
    } else {
        newLines = lines.map { line -> String in
            if let existing = matchAny(line) {
                return prefix + String(line.dropFirst(existing.count))
            }
            return prefix + line
        }
    }

    let joined = newLines.joined(separator: "\n") + (hadTrailingNewline ? "\n" : "")
    let newText = ns.replacingCharacters(in: lineRange, with: joined)

    // Cursor math: the cursor sits inside the first selected line, so shift its
    // location by the delta applied to that first line. Any extra delta on
    // following lines lands in the trailing length.
    let firstLineDelta = (newLines.first?.count ?? 0) - (lines.first?.count ?? 0)
    let totalDelta = (joined as NSString).length - (block as NSString).length
    let newLocation = max(0, selection.location + firstLineDelta)
    let newLength = max(0, selection.length + (totalDelta - firstLineDelta))

    return FormattedResult(
        text: newText,
        selection: NSRange(location: newLocation, length: newLength)
    )
}
```

- [ ] **Step 4: Run the tests**

Run: `swift test --filter MarkdownFormatterTests`
Expected: all four heading tests PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/MDReaderApp/Services/MarkdownFormatter.swift \
        Tests/MDReaderAppTests/MarkdownFormatterTests.swift
git commit -m "feat(formatter): add heading action with upgrade and toggle"
```

---

### Task 2.6: Implement `.unorderedList`, `.orderedList`, `.quote`

**Files:**
- Modify: `Sources/MDReaderApp/Services/MarkdownFormatter.swift`
- Modify: `Tests/MDReaderAppTests/MarkdownFormatterTests.swift`

- [ ] **Step 1: Write the failing tests**

Append:

```swift
@Test func unorderedListMultiline() {
    let result = MarkdownFormatter.apply(
        .unorderedList,
        to: "one\ntwo\nthree",
        selection: NSRange(location: 0, length: 13)
    )
    #expect(result.text == "- one\n- two\n- three")
}

@Test func unorderedListToggleRemoves() {
    let result = MarkdownFormatter.apply(
        .unorderedList,
        to: "- one\n- two",
        selection: NSRange(location: 0, length: 11)
    )
    #expect(result.text == "one\ntwo")
}

@Test func orderedListNumbersLines() {
    let result = MarkdownFormatter.apply(
        .orderedList,
        to: "apple\nbanana\ncherry",
        selection: NSRange(location: 0, length: 19)
    )
    #expect(result.text == "1. apple\n2. banana\n3. cherry")
}

@Test func quoteMultiline() {
    let result = MarkdownFormatter.apply(
        .quote,
        to: "line a\nline b",
        selection: NSRange(location: 0, length: 13)
    )
    #expect(result.text == "> line a\n> line b")
}
```

- [ ] **Step 2: Run the tests**

Run: `swift test --filter MarkdownFormatterTests`
Expected: four new tests FAIL.

- [ ] **Step 3: Implement the three cases**

Add cases to the switch:

```swift
case .unorderedList:
    return applyLinePrefix(
        text,
        selection: selection,
        prefix: "- ",
        matchAny: { _ in nil }
    )
case .quote:
    return applyLinePrefix(
        text,
        selection: selection,
        prefix: "> ",
        matchAny: { _ in nil }
    )
case .orderedList:
    return applyOrderedList(text, selection: selection)
```

Add the ordered-list helper:

```swift
private static func applyOrderedList(_ text: String, selection: NSRange) -> FormattedResult {
    let ns = text as NSString
    let lineRange = ns.lineRange(for: selection)
    let block = ns.substring(with: lineRange)
    let hasTrailingNewline = block.hasSuffix("\n")
    let rawLines = hasTrailingNewline
        ? Array(block.split(separator: "\n", omittingEmptySubsequences: false).dropLast())
        : block.split(separator: "\n", omittingEmptySubsequences: false).map { $0 }
    let lines = rawLines.map(String.init)

    // Toggle off if every line starts with "<n>. "
    let numberedRE = #"^\d+\. "#
    let allNumbered = !lines.isEmpty && lines.allSatisfy {
        $0.range(of: numberedRE, options: .regularExpression) != nil
    }

    let newLines: [String]
    if allNumbered {
        newLines = lines.map { line in
            guard let range = line.range(of: numberedRE, options: .regularExpression) else { return line }
            return String(line[range.upperBound...])
        }
    } else {
        newLines = lines.enumerated().map { idx, line in "\(idx + 1). \(line)" }
    }

    let joined = newLines.joined(separator: "\n") + (hasTrailingNewline ? "\n" : "")
    let newText = ns.replacingCharacters(in: lineRange, with: joined)
    let delta = (joined as NSString).length - (block as NSString).length
    return FormattedResult(
        text: newText,
        selection: NSRange(location: selection.location, length: max(0, selection.length + delta))
    )
}
```

- [ ] **Step 4: Run the tests**

Run: `swift test --filter MarkdownFormatterTests`
Expected: all new tests PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/MDReaderApp/Services/MarkdownFormatter.swift \
        Tests/MDReaderAppTests/MarkdownFormatterTests.swift
git commit -m "feat(formatter): add list and quote actions"
```

---

### Task 2.7: Implement `.codeBlock`

**Files:**
- Modify: `Sources/MDReaderApp/Services/MarkdownFormatter.swift`
- Modify: `Tests/MDReaderAppTests/MarkdownFormatterTests.swift`

- [ ] **Step 1: Write the failing test**

Append:

```swift
@Test func codeBlockWrapsSelection() {
    let result = MarkdownFormatter.apply(
        .codeBlock,
        to: "before\nlet x = 1\nafter",
        selection: NSRange(location: 7, length: 9)  // "let x = 1"
    )
    #expect(result.text == "before\n```\nlet x = 1\n```\nafter")
}
```

- [ ] **Step 2: Run the test**

Run: `swift test --filter codeBlockWrapsSelection`
Expected: FAIL.

- [ ] **Step 3: Implement `.codeBlock`**

Add to the switch and a helper:

```swift
case .codeBlock:
    return wrapCodeBlock(text, selection: selection)
```

```swift
private static func wrapCodeBlock(_ text: String, selection: NSRange) -> FormattedResult {
    let ns = text as NSString
    let lineRange = ns.lineRange(for: selection)
    var block = ns.substring(with: lineRange)
    let hadTrailingNewline = block.hasSuffix("\n")
    if hadTrailingNewline { block = String(block.dropLast()) }
    let replacement = "```\n\(block)\n```" + (hadTrailingNewline ? "\n" : "")
    let newText = ns.replacingCharacters(in: lineRange, with: replacement)
    return FormattedResult(
        text: newText,
        selection: NSRange(location: selection.location + 4, length: selection.length)  // past "```\n"
    )
}
```

- [ ] **Step 4: Run the test**

Run: `swift test --filter codeBlockWrapsSelection`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/MDReaderApp/Services/MarkdownFormatter.swift \
        Tests/MDReaderAppTests/MarkdownFormatterTests.swift
git commit -m "feat(formatter): add code block action"
```

---

### Task 2.8: Edge cases — empty, out-of-bounds

**Files:**
- Modify: `Tests/MDReaderAppTests/MarkdownFormatterTests.swift`

- [ ] **Step 1: Write the tests**

Append:

```swift
@Test func selectionOutOfBoundsReturnsUnchanged() {
    let result = MarkdownFormatter.apply(
        .bold,
        to: "hi",
        selection: NSRange(location: 0, length: 99)
    )
    #expect(result.text == "hi")
    #expect(result.selection == NSRange(location: 0, length: 99))
}

@Test func emptyDocumentHeading() {
    let result = MarkdownFormatter.apply(
        .heading(level: 1),
        to: "",
        selection: NSRange(location: 0, length: 0)
    )
    #expect(result.text == "# ")
}
```

- [ ] **Step 2: Run the tests**

Run: `swift test --filter MarkdownFormatterTests`
Expected: both PASS (the bounds guard in `apply` and the prefix logic already cover these).

- [ ] **Step 3: Commit**

```bash
git add Tests/MDReaderAppTests/MarkdownFormatterTests.swift
git commit -m "test(formatter): edge cases for bounds and empty input"
```

---

### Task 2.9: Add `pendingFormat` to `EditorViewModel`

**Files:**
- Modify: `Sources/MDReaderApp/Services/EditorViewModel.swift`

- [ ] **Step 1: Add the property**

In `Sources/MDReaderApp/Services/EditorViewModel.swift`, add after `var saveError: Error?`:

```swift
var pendingFormat: MarkdownFormatAction?
```

- [ ] **Step 2: Build**

Run: `swift build`
Expected: clean build.

- [ ] **Step 3: Commit**

```bash
git add Sources/MDReaderApp/Services/EditorViewModel.swift
git commit -m "feat(viewmodel): add pendingFormat command slot"
```

---

### Task 2.10: Consume `pendingFormat` in `MarkdownEditorView.Coordinator`

**Files:**
- Modify: `Sources/MDReaderApp/Views/MarkdownEditorView.swift`

- [ ] **Step 1: Extend `updateNSView` to consume the command**

Replace `updateNSView` with:

```swift
func updateNSView(_ scrollView: NSScrollView, context: Context) {
    let textView = scrollView.documentView as! NSTextView

    // Consume pending format command before external text updates.
    if let action = viewModel.pendingFormat {
        let current = textView.string
        let result = MarkdownFormatter.apply(
            action,
            to: current,
            selection: textView.selectedRange()
        )
        context.coordinator.isUpdating = true
        textView.string = result.text
        textView.selectedRange = result.selection
        context.coordinator.applyHighlighting()
        context.coordinator.isUpdating = false
        viewModel.text = result.text
        viewModel.textDidChange()
        viewModel.pendingFormat = nil
        return
    }

    // Existing external-text update path.
    guard context.coordinator.lastTextVersion != viewModel.textVersion else { return }
    context.coordinator.lastTextVersion = viewModel.textVersion
    context.coordinator.isUpdating = true
    textView.string = viewModel.text
    context.coordinator.applyHighlighting()
    context.coordinator.isUpdating = false
}
```

- [ ] **Step 2: Build**

Run: `swift build`
Expected: clean build.

- [ ] **Step 3: Commit**

```bash
git add Sources/MDReaderApp/Views/MarkdownEditorView.swift
git commit -m "feat(editor): consume pendingFormat in editor coordinator"
```

---

### Task 2.11: Create `MarkdownFormattingToolbar`

**Files:**
- Create: `Sources/MDReaderApp/Views/MarkdownFormattingToolbar.swift`

- [ ] **Step 1: Write the view**

Create `Sources/MDReaderApp/Views/MarkdownFormattingToolbar.swift`:

```swift
import SwiftUI

struct MarkdownFormattingToolbar: View {
    @Bindable var viewModel: EditorViewModel

    var body: some View {
        HStack(spacing: 2) {
            Button {
                viewModel.pendingFormat = .bold
            } label: {
                Image(systemName: "bold")
            }
            .help("Bold (⌘B)")

            Button {
                viewModel.pendingFormat = .italic
            } label: {
                Image(systemName: "italic")
            }
            .help("Italic (⌘I)")

            Button {
                viewModel.pendingFormat = .link
            } label: {
                Image(systemName: "link")
            }
            .help("Link (⌘K)")

            Button {
                viewModel.pendingFormat = .code
            } label: {
                Image(systemName: "chevron.left.forwardslash.chevron.right")
            }
            .help("Inline code (⌘E)")

            Divider().frame(height: 16)

            Menu {
                Button("Heading 1") { viewModel.pendingFormat = .heading(level: 1) }
                Button("Heading 2") { viewModel.pendingFormat = .heading(level: 2) }
                Button("Heading 3") { viewModel.pendingFormat = .heading(level: 3) }
            } label: {
                Image(systemName: "textformat.size")
            }
            .help("Heading")

            Button {
                viewModel.pendingFormat = .unorderedList
            } label: {
                Image(systemName: "list.bullet")
            }
            .help("Bulleted list")

            Button {
                viewModel.pendingFormat = .orderedList
            } label: {
                Image(systemName: "list.number")
            }
            .help("Numbered list")

            Button {
                viewModel.pendingFormat = .quote
            } label: {
                Image(systemName: "text.quote")
            }
            .help("Quote")
        }
    }
}
```

- [ ] **Step 2: Build**

Run: `swift build`
Expected: clean build.

- [ ] **Step 3: Commit**

```bash
git add Sources/MDReaderApp/Views/MarkdownFormattingToolbar.swift
git commit -m "feat(toolbar): add markdown formatting toolbar view"
```

---

### Task 2.12: Wire the toolbar into `MDReaderApp`

**Files:**
- Modify: `Sources/MDReaderApp/MDReaderApp.swift`

- [ ] **Step 1: Add a new `ToolbarItem` for the formatting toolbar**

Locate the `.toolbar { ... }` block in `MDReaderApp.swift`. Insert a new `ToolbarItem` **before** the existing `Picker("View Mode", ...)` item:

```swift
.toolbar {
    ToolbarItem(placement: .automatic) {
        if selectedFilePath != nil && viewModel.viewMode != .preview {
            MarkdownFormattingToolbar(viewModel: viewModel)
        }
    }
    ToolbarItem {
        Picker("View Mode", selection: $viewModel.viewMode) {
            // ...unchanged
        }
        // ...
    }
    ToolbarItem {
        Button {
            openFilePanel()
        } label: {
            Image(systemName: "plus")
        }
    }
}
```

- [ ] **Step 2: Build**

Run: `swift build`
Expected: clean build.

- [ ] **Step 3: Commit**

```bash
git add Sources/MDReaderApp/MDReaderApp.swift
git commit -m "feat(app): mount formatting toolbar in window toolbar"
```

---

### Task 2.13: Add `CommandGroup` with keyboard shortcuts

**Files:**
- Modify: `Sources/MDReaderApp/MDReaderApp.swift`

- [ ] **Step 1: Add a new `CommandGroup`**

In the existing `.commands { ... }` block, add a new group after the save command:

```swift
.commands {
    CommandGroup(replacing: .saveItem) {
        Button("Save") {
            viewModel.save()
        }
        .keyboardShortcut("s", modifiers: .command)
        .disabled(!viewModel.hasUnsavedChanges)
    }
    CommandGroup(after: .textFormatting) {
        Button("Bold") { viewModel.pendingFormat = .bold }
            .keyboardShortcut("b", modifiers: .command)
            .disabled(selectedFilePath == nil || viewModel.viewMode == .preview)
        Button("Italic") { viewModel.pendingFormat = .italic }
            .keyboardShortcut("i", modifiers: .command)
            .disabled(selectedFilePath == nil || viewModel.viewMode == .preview)
        Button("Link") { viewModel.pendingFormat = .link }
            .keyboardShortcut("k", modifiers: .command)
            .disabled(selectedFilePath == nil || viewModel.viewMode == .preview)
        Button("Inline Code") { viewModel.pendingFormat = .code }
            .keyboardShortcut("e", modifiers: .command)
            .disabled(selectedFilePath == nil || viewModel.viewMode == .preview)
        Divider()
        Button("Heading 1") { viewModel.pendingFormat = .heading(level: 1) }
            .keyboardShortcut("1", modifiers: [.command, .shift])
            .disabled(selectedFilePath == nil || viewModel.viewMode == .preview)
        Button("Heading 2") { viewModel.pendingFormat = .heading(level: 2) }
            .keyboardShortcut("2", modifiers: [.command, .shift])
            .disabled(selectedFilePath == nil || viewModel.viewMode == .preview)
        Button("Heading 3") { viewModel.pendingFormat = .heading(level: 3) }
            .keyboardShortcut("3", modifiers: [.command, .shift])
            .disabled(selectedFilePath == nil || viewModel.viewMode == .preview)
        Divider()
        Button("Bulleted List") { viewModel.pendingFormat = .unorderedList }
            .keyboardShortcut("8", modifiers: [.command, .shift])
            .disabled(selectedFilePath == nil || viewModel.viewMode == .preview)
        Button("Numbered List") { viewModel.pendingFormat = .orderedList }
            .keyboardShortcut("7", modifiers: [.command, .shift])
            .disabled(selectedFilePath == nil || viewModel.viewMode == .preview)
        Button("Quote") { viewModel.pendingFormat = .quote }
            .keyboardShortcut("'", modifiers: [.command, .shift])
            .disabled(selectedFilePath == nil || viewModel.viewMode == .preview)
    }
    CommandGroup(after: .sidebar) {
        // ...existing toggle favorite
    }
}
```

- [ ] **Step 2: Build**

Run: `swift build`
Expected: clean build.

- [ ] **Step 3: Manual smoke test**

Run: `swift run MDReaderApp`

In the running app:
1. Open a markdown file.
2. Switch to `editor` or `split` view mode.
3. Select a word, press ⌘B — verify it becomes `**word**`.
4. Press ⌘B again on the same selection — verify it becomes `word`.
5. Select a word, press ⌘I — `*word*`.
6. With cursor on a line, press Shift-⌘-1 — verify `# ` is prepended.
7. Press Shift-⌘-1 again — verify `# ` is removed.
8. Press Shift-⌘-2 — verify `## ` is prepended.
9. Click the bold button in the toolbar — same as ⌘B.
10. Switch to `preview` view mode — verify the formatting toolbar disappears and the keyboard shortcuts do nothing (menu items greyed out).

- [ ] **Step 4: Commit**

```bash
git add Sources/MDReaderApp/MDReaderApp.swift
git commit -m "feat(app): add formatting keyboard shortcuts via CommandGroup"
```

---

## Phase 3 — Incremental preview updates + cursor-driven scroll sync

Depends on Phase 1 (`data-line` attributes). Replaces the brittle `loadHTMLString`-per-keystroke path.

### Task 3.1: Add `activeLine` to `EditorViewModel`

**Files:**
- Modify: `Sources/MDReaderApp/Services/EditorViewModel.swift`

- [ ] **Step 1: Add the property and wire resets**

Add near `pendingFormat`:

```swift
var activeLine: Int = 0
```

In `loadFile(url:)`, after `textVersion += 1`, add:

```swift
activeLine = 0
```

In `clearFile()`, add:

```swift
activeLine = 0
```

- [ ] **Step 2: Build**

Run: `swift build`
Expected: clean build.

- [ ] **Step 3: Commit**

```bash
git add Sources/MDReaderApp/Services/EditorViewModel.swift
git commit -m "feat(viewmodel): add activeLine for cursor-driven scroll sync"
```

---

### Task 3.2: Publish active cursor line from the editor

**Files:**
- Modify: `Sources/MDReaderApp/Views/MarkdownEditorView.swift`

- [ ] **Step 1: Add the selection-change handler in `Coordinator`**

`MarkdownEditorView.Coordinator` is already the `NSTextViewDelegate`. Add a debounce work item field and the callback:

```swift
private var activeLineWorkItem: DispatchWorkItem?

func textViewDidChangeSelection(_ notification: Notification) {
    guard !isUpdating, let textView else { return }
    let location = textView.selectedRange().location
    let string = textView.string as NSString
    var count = 0
    var idx = 0
    let limit = min(location, string.length)
    while idx < limit {
        if string.character(at: idx) == 10 { count += 1 }  // '\n'
        idx += 1
    }
    activeLineWorkItem?.cancel()
    let item = DispatchWorkItem { [weak self] in
        self?.viewModel.activeLine = count
    }
    activeLineWorkItem = item
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: item)
}
```

`NSTextView` will deliver `textViewDidChangeSelection(_:)` to the existing delegate automatically — no extra subscription needed.

- [ ] **Step 2: Cancel the work item in the same places as `highlightWorkItem`**

No explicit cleanup needed beyond the `Coordinator`'s lifetime — weak self guards against leaks. Leave it.

- [ ] **Step 3: Build**

Run: `swift build`
Expected: clean build.

- [ ] **Step 4: Commit**

```bash
git add Sources/MDReaderApp/Views/MarkdownEditorView.swift
git commit -m "feat(editor): publish active cursor line on selection change"
```

---

### Task 3.3: Switch `MarkdownWebView` API from `markdown: String` to `viewModel: EditorViewModel`

**Files:**
- Modify: `Sources/MDReaderApp/Views/MarkdownWebView.swift`
- Modify: `Sources/MDReaderApp/Views/ContentView.swift`

- [ ] **Step 1: Change the struct signature**

In `MarkdownWebView.swift`, replace:

```swift
struct MarkdownWebView: NSViewRepresentable {
    let markdown: String
    ...
}
```

with:

```swift
struct MarkdownWebView: NSViewRepresentable {
    @Bindable var viewModel: EditorViewModel
    ...
}
```

Update `updateNSView` to read `viewModel.text`:

```swift
func updateNSView(_ webView: WKWebView, context: Context) {
    let html = buildHTML(from: viewModel.text)
    webView.loadHTMLString(html, baseURL: nil)
}
```

(This preserves Phase 3's baseline behavior before the next task rewrites `updateNSView`.)

- [ ] **Step 2: Update `ContentView.swift` call sites**

Replace both `MarkdownWebView(markdown: viewModel.text)` call sites with `MarkdownWebView(viewModel: viewModel)`:

```swift
case .split:
    HSplitView {
        MarkdownEditorView(viewModel: viewModel)
            .frame(minWidth: 200)
        MarkdownWebView(viewModel: viewModel)
            .frame(minWidth: 200)
    }

case .preview:
    MarkdownWebView(viewModel: viewModel)
```

- [ ] **Step 3: Build and run tests**

Run: `swift build && swift test`
Expected: clean build, all tests still pass.

- [ ] **Step 4: Commit**

```bash
git add Sources/MDReaderApp/Views/MarkdownWebView.swift \
        Sources/MDReaderApp/Views/ContentView.swift
git commit -m "refactor(webview): accept EditorViewModel instead of markdown string"
```

---

### Task 3.4: Introduce the HTML shell and a `Coordinator`

**Files:**
- Modify: `Sources/MDReaderApp/Views/MarkdownWebView.swift`

- [ ] **Step 1: Add a Coordinator with load-state tracking**

Replace the current `MarkdownWebView` body. Add `makeCoordinator`, a `Coordinator` class that conforms to `WKNavigationDelegate`, and separate the shell from the content update:

```swift
import SwiftUI
import WebKit
import os

struct MarkdownWebView: NSViewRepresentable {
    @Bindable var viewModel: EditorViewModel

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView
        webView.loadHTMLString(Self.shellHTML, baseURL: nil)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.onUpdate(
            markdown: viewModel.text,
            activeLine: viewModel.activeLine
        )
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        let viewModel: EditorViewModel
        weak var webView: WKWebView?
        var isLoaded = false
        var lastMarkdown: String?
        var lastActiveLine: Int?
        var pendingMarkdown: String?
        var pendingActiveLine: Int?
        private var updateWorkItem: DispatchWorkItem?
        private let log = Logger(subsystem: "dev.mdreader", category: "MarkdownWebView")

        init(viewModel: EditorViewModel) {
            self.viewModel = viewModel
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isLoaded = true
            if let md = pendingMarkdown {
                pushUpdate(markdown: md)
                pendingMarkdown = nil
            }
            if let line = pendingActiveLine {
                pushScroll(line: line)
                pendingActiveLine = nil
            }
        }

        func onUpdate(markdown: String, activeLine: Int) {
            guard isLoaded else {
                pendingMarkdown = markdown
                pendingActiveLine = activeLine
                return
            }
            if markdown != lastMarkdown {
                scheduleUpdate(markdown: markdown)
            }
            if activeLine != lastActiveLine {
                pushScroll(line: activeLine)
            }
        }

        private func scheduleUpdate(markdown: String) {
            updateWorkItem?.cancel()
            let item = DispatchWorkItem { [weak self] in
                self?.pushUpdate(markdown: markdown)
            }
            updateWorkItem = item
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: item)
        }

        private func pushUpdate(markdown: String) {
            guard let webView else { return }
            let html = MarkdownRenderer.renderHTML(from: markdown)
            guard let encoded = jsStringLiteral(html) else {
                log.error("Failed to encode HTML for JS")
                return
            }
            let script = "window.mdUpdate(\(encoded));"
            webView.evaluateJavaScript(script) { [weak self] _, error in
                if let error {
                    self?.log.error("mdUpdate failed: \(error.localizedDescription)")
                }
            }
            lastMarkdown = markdown
        }

        private func pushScroll(line: Int) {
            guard let webView else { return }
            webView.evaluateJavaScript("window.mdScrollToLine(\(line));") { [weak self] _, error in
                if let error {
                    self?.log.error("mdScrollToLine failed: \(error.localizedDescription)")
                }
            }
            lastActiveLine = line
        }

        /// Encodes a Swift String as a valid JavaScript string literal via JSON.
        private func jsStringLiteral(_ s: String) -> String? {
            guard let data = try? JSONSerialization.data(withJSONObject: [s], options: []),
                  let jsonArray = String(data: data, encoding: .utf8) else { return nil }
            // jsonArray is like `["..."]`; strip brackets to get the quoted literal.
            var trimmed = jsonArray
            if trimmed.hasPrefix("[") { trimmed.removeFirst() }
            if trimmed.hasSuffix("]") { trimmed.removeLast() }
            return trimmed
        }
    }

    private static let shellHTML: String = """
    <!DOCTYPE html>
    <html>
    <head>
    <meta charset="utf-8">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/styles/github.min.css" media="(prefers-color-scheme: light)">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/styles/github-dark.min.css" media="(prefers-color-scheme: dark)">
    <script src="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/highlight.min.js"></script>
    <style>
    \(Self.previewCSS)
    </style>
    </head>
    <body>
    <div id="content"></div>
    <script>
    window.mdUpdate = function(html) {
        const target = document.getElementById("content");
        const parsed = new DOMParser().parseFromString(html, "text/html");
        const incoming = Array.from(parsed.body.children);
        target.replaceChildren(...incoming);
        target.querySelectorAll("pre code").forEach(function(el) {
            hljs.highlightElement(el);
        });
    };
    window.mdScrollToLine = function(line) {
        const blocks = document.querySelectorAll("[data-line]");
        if (!blocks.length) return;
        let match = blocks[0];
        for (const b of blocks) {
            const n = parseInt(b.getAttribute("data-line"), 10);
            if (n <= line) match = b; else break;
        }
        match.scrollIntoView({ block: "center", behavior: "smooth" });
    };
    </script>
    </body>
    </html>
    """

    private static let previewCSS: String = """
    :root {
        color-scheme: light dark;
        --text:          light-dark(#1f1b16, #ebe5db);
        --text-muted:    light-dark(#6b6359, #9b928a);
        --text-subtle:   light-dark(#8c8478, #766e66);
        --accent:        light-dark(#9a4a12, #e3995a);
        --accent-soft:   light-dark(#c2784a, #c68860);
        --border:        light-dark(#e8e2d6, #2b2823);
        --border-strong: light-dark(#d2ccbe, #3a3630);
        --surface:       light-dark(#f4efe4, #1c1a16);
        --code-text:     light-dark(#8a3a0c, #f1a775);
        --selection:     light-dark(rgba(154, 74, 18, 0.18), rgba(227, 153, 90, 0.24));
        --font-serif:    ui-serif, "New York", "Charter", "Iowan Old Style", Georgia, serif;
        --font-sans:     -apple-system, BlinkMacSystemFont, "SF Pro Text", "Helvetica Neue", sans-serif;
        --font-mono:     ui-monospace, "SF Mono", "JetBrains Mono", Menlo, Consolas, monospace;
    }

    * { box-sizing: border-box; }
    ::selection { background: var(--selection); }
    html { scroll-behavior: smooth; }

    body {
        font-family: var(--font-sans);
        font-size: 15px;
        line-height: 1.72;
        color: var(--text);
        background: transparent;
        padding: clamp(24px, 3.5vw, 52px) clamp(24px, 4vw, 56px) clamp(48px, 7vw, 88px);
        max-width: 90ch;
        margin: 0 auto;
        -webkit-font-smoothing: antialiased;
        font-feature-settings: "kern", "liga", "calt";
        text-rendering: optimizeLegibility;
    }

    #content > *:first-child { margin-top: 0; }
    #content > *:last-child { margin-bottom: 0; }

    h1, h2, h3, h4 {
        font-family: var(--font-serif);
        font-weight: 600;
        line-height: 1.18;
        letter-spacing: -0.015em;
        text-wrap: balance;
        color: var(--text);
    }

    h1 {
        font-size: 2.35em;
        font-weight: 700;
        letter-spacing: -0.028em;
        margin: 0 0 0.55em;
        padding-bottom: 0.32em;
        border-bottom: 1px solid var(--border);
    }

    h2 { font-size: 1.68em; margin: 2em 0 0.5em; }
    h3 { font-size: 1.32em; margin: 1.8em 0 0.4em; }
    h4 { font-size: 1.1em; margin: 1.4em 0 0.3em; }

    h5, h6 {
        font-family: var(--font-sans);
        font-size: 0.82em;
        font-weight: 600;
        text-transform: uppercase;
        letter-spacing: 0.06em;
        color: var(--text-muted);
        margin: 1.4em 0 0.3em;
    }

    h1 + p, h2 + p, h3 + p, h4 + p { margin-top: 0.15em; }

    p { margin: 0 0 1.05em; text-wrap: pretty; }

    strong { font-weight: 600; color: var(--text); }
    em { font-style: italic; }

    a {
        color: var(--accent);
        text-decoration: none;
        border-bottom: 1px solid color-mix(in oklab, var(--accent) 35%, transparent);
        transition: border-color 160ms ease, color 160ms ease;
    }
    a:hover { border-bottom-color: var(--accent); }
    a:focus-visible {
        outline: 2px solid var(--accent);
        outline-offset: 3px;
        border-radius: 2px;
    }

    code {
        font-family: var(--font-mono);
        font-size: 0.86em;
        background: var(--surface);
        color: var(--code-text);
        padding: 0.12em 0.42em;
        border-radius: 4px;
        border: 1px solid var(--border);
        font-variant-ligatures: none;
    }

    pre {
        font-family: var(--font-mono);
        background: var(--surface);
        padding: 18px 22px;
        border-radius: 10px;
        overflow-x: auto;
        margin: 1.4em 0;
        border: 1px solid var(--border);
        font-size: 0.87em;
        line-height: 1.62;
    }
    pre code {
        background: none;
        padding: 0;
        border: 0;
        color: var(--text);
        font-size: 1em;
    }

    pre code.hljs,
    .hljs {
        background: transparent !important;
        padding: 0 !important;
    }

    blockquote {
        margin: 1.5em 0;
        padding: 0.2em 0 0.2em 1.4em;
        border-left: 2px solid var(--accent-soft);
        font-family: var(--font-serif);
        font-style: italic;
        font-size: 1.06em;
        color: var(--text-muted);
        text-wrap: pretty;
    }
    blockquote p { margin: 0.3em 0; }

    ul, ol { padding-left: 1.45em; margin: 0 0 1.1em; }
    li { margin: 0.35em 0; padding-left: 0.2em; }
    li::marker { color: var(--text-subtle); }
    ul ul, ol ol, ul ol, ol ul { margin: 0.25em 0 0.4em; }

    hr {
        border: none;
        height: 1px;
        background: var(--border);
        margin: 2.4em auto;
        width: 42%;
    }

    table {
        width: 100%;
        border-collapse: separate;
        border-spacing: 0;
        margin: 1.4em 0;
        font-size: 0.93em;
        font-variant-numeric: tabular-nums;
        border: 1px solid var(--border);
        border-radius: 8px;
        overflow: hidden;
    }
    thead th {
        font-weight: 600;
        text-align: left;
        padding: 10px 14px;
        background: color-mix(in oklab, var(--surface) 65%, transparent);
        border-bottom: 1px solid var(--border-strong);
        border-right: 1px solid var(--border);
        color: var(--text);
    }
    thead th:last-child { border-right: none; }
    tbody td {
        padding: 10px 14px;
        border-bottom: 1px solid var(--border);
        border-right: 1px solid var(--border);
        color: var(--text);
    }
    tbody td:last-child { border-right: none; }
    tbody tr:last-child td { border-bottom: none; }
    tbody tr { transition: background 140ms ease; }
    tbody tr:hover td {
        background: color-mix(in oklab, var(--surface) 55%, transparent);
    }

    img {
        max-width: 100%;
        border-radius: 6px;
        margin: 1em 0;
    }

    @media (prefers-reduced-motion: reduce) {
        html { scroll-behavior: auto; }
        a, tbody tr { transition: none; }
    }
    """
}
```

Delete the old `buildHTML(from:)` function — it is no longer used (shell is static, updates go through JS).

- [ ] **Step 2: Build**

Run: `swift build`
Expected: clean build.

- [ ] **Step 3: Manual smoke test**

Run: `swift run MDReaderApp`

1. Open a markdown file — the preview renders correctly.
2. Type in the editor (split mode) — preview updates without full-page flash; scroll position is preserved.
3. Move the cursor to a heading several blocks down via arrow keys — the preview scrolls to center that heading.
4. Open a different file from the sidebar — preview updates, no flash.
5. Trigger an external file change (`echo "new content" >> file.md` in another terminal, choose `Reload` in the dialog) — preview updates.

- [ ] **Step 4: Commit**

```bash
git add Sources/MDReaderApp/Views/MarkdownWebView.swift
git commit -m "feat(webview): incremental preview updates + cursor scroll sync"
```

---

### Task 3.5: Final regression sweep

**Files:**
- None modified — validation only.

- [ ] **Step 1: Run the full test suite**

Run: `swift test`
Expected: all tests pass.

- [ ] **Step 2: Full manual smoke pass**

Run: `swift run MDReaderApp`

Walk through the complete checklist from the spec:

1. Open a longer markdown file, enter split mode, type — no flicker, scroll position in preview stays put.
2. Move the cursor with arrow keys through different sections — preview scrolls to show the block around the cursor.
3. Select a word, press ⌘B — wrapped in `**...**`. Press again — unwrapped.
4. Select several lines, Shift-⌘-2 — each line prefixed with `## `.
5. Switch to preview mode — formatting toolbar disappears, keyboard shortcuts are disabled.
6. Load a new file — preview shows the file, no flash.
7. External file change → reload — preview updates, no flash.
8. ⌘K on a word — creates `[word](url)` with selection on `url`.
9. Click toolbar buttons for each action — all work.
10. ⌘S saves as expected.

- [ ] **Step 3: Tag the completed work**

```bash
git log --oneline -20
```
Confirm the commit history cleanly separates the three phases.
