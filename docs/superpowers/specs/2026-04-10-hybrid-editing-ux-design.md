# Hybrid editing UX improvements

**Date:** 2026-04-10
**Status:** Design approved, ready for implementation planning
**Scope:** `split` view mode (editor + preview side-by-side) — UX convenience

## Problem

The hybrid (`split`) view mode in `ContentView.swift:21-27` is functional but painful
to use for actual writing:

1. **Preview flickers on every keystroke.** `MarkdownWebView.updateNSView`
   (`Sources/MDReaderApp/Views/MarkdownWebView.swift:14-17`) calls
   `loadHTMLString` every time `markdown` changes. This rebuilds the entire DOM,
   resets scroll position, and re-runs `highlight.js` across the whole document.
   For anything longer than a short note, typing feels janky.
2. **No scroll synchronization.** When you type in the editor, the preview shows
   whatever it showed last. You have to manually scroll the right pane to see
   the block you are working on.
3. **No quick formatting.** There is no toolbar and no keyboard shortcuts for
   bold, italic, headings, lists, links, etc. Every markdown marker has to be
   typed by hand.

## Goals

Make `split` mode pleasant for drafting and editing markdown documents by
fixing exactly these three issues.

## Non-goals (YAGNI)

Explicitly out of scope for this spec:

- Outline / TOC navigation panel
- Word / character count in statusbar
- Smart paste (URL → auto-link)
- Vertical split variant
- Persisting the split ratio across sessions
- Click-in-preview → jump-to-source (scroll sync is editor → preview only)
- Find / replace in the editor
- Headings h4–h6 in the toolbar (only h1/h2/h3)
- User-configurable keyboard shortcuts
- Inline live preview (Typora-style) — the explicit split pane stays
- Changes to auto-save, file monitoring, or multi-window support

## High-level approach

Three independent, loosely coupled improvements that share the existing
`EditorViewModel`:

1. **Incremental preview update.** Load an HTML shell once, then update the
   body by parsing the new HTML into a detached document and replacing the
   content container's children — no full page reload, no scroll loss.
2. **Cursor-driven scroll sync.** Tag rendered blocks with `data-line="N"`
   attributes, publish the editor's active line to the view model, and let the
   preview scroll the corresponding element into view.
3. **Formatting toolbar and shortcuts.** A pure `MarkdownFormatter` service
   driven either from a toolbar button group or from `CommandGroup` keyboard
   shortcuts.

The three parts can be implemented and merged independently. Each has its own
tests or manual smoke check.

## Architecture

### New files

- `Sources/MDReaderApp/Services/MarkdownFormatter.swift` — pure string service.
- `Sources/MDReaderApp/Services/MarkdownRenderer.swift` — markdown → HTML,
  extracted from `MarkdownWebView`. Each top-level block gets
  `data-line="N"` (0-based line of its first source line).
- `Sources/MDReaderApp/Views/MarkdownFormattingToolbar.swift` — SwiftUI view
  with the formatting button group.
- `Tests/MDReaderAppTests/MarkdownFormatterTests.swift`
- `Tests/MDReaderAppTests/MarkdownRendererTests.swift`

### Modified files

- `Sources/MDReaderApp/Views/MarkdownWebView.swift` — switches from a
  `markdown: String` input to `@Bindable viewModel: EditorViewModel`, so it
  can react to both `text` and `activeLine`. Loads an HTML shell once, then
  bridges through JS. The `markdownToHTML` parser moves out to
  `MarkdownRenderer.swift`.
- `Sources/MDReaderApp/Views/ContentView.swift` — call-site change only:
  `MarkdownWebView(viewModel: viewModel)` in both `.split` and `.preview`
  arms instead of passing `markdown: viewModel.text`.
- `Sources/MDReaderApp/Views/MarkdownEditorView.swift` — tracks cursor line,
  consumes `pendingFormat` commands from the view model.
- `Sources/MDReaderApp/Services/EditorViewModel.swift` — adds `activeLine` and
  `pendingFormat` observable state.
- `Sources/MDReaderApp/MDReaderApp.swift` — adds formatting `CommandGroup` with
  keyboard shortcuts and inserts `MarkdownFormattingToolbar` in the window
  toolbar.

### Components

#### `MarkdownFormatter` (service)

Pure, stateless. No AppKit dependency. Trivially unit-tested.

```swift
enum MarkdownFormatAction {
    case bold, italic, code, strikethrough
    case link                   // wraps selection in [text](url), cursor on url
    case heading(level: Int)    // 1...3 — line prefix "# "
    case unorderedList, orderedList
    case quote
    case codeBlock
}

struct FormattedResult {
    let text: String
    let selection: NSRange
}

enum MarkdownFormatter {
    static func apply(_ action: MarkdownFormatAction,
                      to text: String,
                      selection: NSRange) -> FormattedResult
}
```

Behavior rules:

- Wrap-style actions (`bold`, `italic`, `code`, `strikethrough`) wrap the
  selection in the corresponding markers. If the selection is already wrapped,
  strip the markers (toggle).
- `link` with non-empty selection → `[selection](url)`, returned selection
  covers `url`. With empty selection → `[](url)`, cursor between brackets.
- `heading(level:)` applies to whole lines intersecting the selection
  (or to the cursor's line when selection is empty). Re-applying the same
  level removes the prefix; applying a different level replaces it.
- `unorderedList` / `orderedList` / `quote` apply a per-line prefix with
  toggle semantics.
- `codeBlock` wraps the selection in ` ``` ` fences on their own lines.
- Any input where `selection` does not fit inside `text` returns the input
  unchanged — never crashes.

#### `MarkdownRenderer` (service)

```swift
enum MarkdownRenderer {
    /// Converts markdown source to HTML. Each top-level block carries
    /// `data-line="N"` where N is the 0-based line of the block's first line
    /// in the source. For lists, the attribute is on the `<ul>`/`<ol>`,
    /// not on each `<li>`. For fenced code blocks, the attribute is on the
    /// `<pre>` and N is the line of the opening ` ``` `.
    static func renderHTML(from markdown: String) -> String
}
```

This is the existing `markdownToHTML` implementation, moved out of the view
struct and extended to emit `data-line` attributes. No behavior regressions:
existing output stays byte-identical minus the attributes.

**Trust model:** the renderer consumes local markdown files opened by the
user. All inline text passes through `escapeHTML`, so the generated HTML
contains only the markup the renderer itself decided to emit. The preview
treats this HTML as trusted first-party content — no sanitization layer is
needed, but we still prefer DOM-parser insertion over direct string-to-DOM
assignment (see `MarkdownWebView` below) as defense in depth and as a
cleaner API.

#### `EditorViewModel` additions

```swift
var activeLine: Int = 0                   // 0-based cursor line
var pendingFormat: MarkdownFormatAction?  // command bus: toolbar/menu → editor coordinator
```

Both are `@Observable` state. `pendingFormat` is consumed by
`MarkdownEditorView.Coordinator` via SwiftUI's `updateNSView` and cleared back
to `nil` after handling.

#### `MarkdownEditorView.Coordinator` new responsibilities

- Subscribe to `NSTextView.didChangeSelectionNotification`. On each
  notification, compute the current line from `selectedRange.location` and
  `textView.string`, debounce 50 ms, then publish to `viewModel.activeLine`.
- In `updateNSView`, if `viewModel.pendingFormat != nil`, read
  `textView.selectedRange`, call `MarkdownFormatter.apply`, write back the
  resulting `text` and `selectedRange`, re-run `applyHighlighting`, and set
  `viewModel.pendingFormat = nil`. The resulting text change propagates to
  the preview through the normal text path.

#### `MarkdownWebView` rewrite

- `makeNSView` loads an HTML shell once via `loadHTMLString`. The shell
  contains the existing CSS, an empty `<div id="content"></div>`, and a
  script that defines two helpers on `window`:
  ```js
  window.mdUpdate = function(html) {
      const target = document.getElementById("content");
      const parsed = new DOMParser().parseFromString(html, "text/html");
      const incoming = Array.from(parsed.body.children);
      target.replaceChildren(...incoming);
      target.querySelectorAll("pre code").forEach(el => hljs.highlightElement(el));
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
  ```
  `DOMParser` parses the HTML into an inert document, and `replaceChildren`
  moves the nodes into the live container atomically. This preserves the
  scroll position of nodes that do not change near the top of the document
  and does not re-run script tags inside the rendered HTML.
- Coordinator holds `isLoaded: Bool`, `lastMarkdown: String?`,
  `lastActiveLine: Int?`, and `pendingMarkdown: String?`.
- `updateNSView`:
  - If `!isLoaded`, stash `markdown` in `pendingMarkdown`.
  - Else, if `markdown != lastMarkdown`, call
    `evaluateJavaScript("window.mdUpdate(\(encoded))")` where `encoded`
    is the HTML encoded as a JSON string via `JSONSerialization` (guarantees
    valid JS string literal; never interpolates raw HTML into JS source).
  - If `activeLine != lastActiveLine`, call
    `evaluateJavaScript("window.mdScrollToLine(\(line))")`.
- `webView(_:didFinish:)` sets `isLoaded = true` and flushes
  `pendingMarkdown` if present.
- Internal debounce for rapid `mdUpdate` calls: 100 ms — avoids calling
  `evaluateJavaScript` on every keystroke while staying snappy.
- On JS-evaluation failure, log via `os_log` and, if the shell failed
  entirely, flip an internal `useIncrementalUpdates: false` flag and fall
  back to `loadHTMLString` for subsequent updates.

#### `MarkdownFormattingToolbar`

SwiftUI view containing a button group:

- Bold (`bold` SF symbol)
- Italic (`italic`)
- Link (`link`)
- Heading 1 / 2 / 3 (`textformat.size`, menu)
- Unordered list (`list.bullet`)
- Ordered list (`list.number`)
- Quote (`text.quote`)
- Code (`chevron.left.forwardslash.chevron.right`)

Each button sets `viewModel.pendingFormat = .bold` etc. The toolbar is
inserted in `MDReaderApp.toolbar` as a `ToolbarItemGroup(placement: .automatic)`
and hidden via `if viewModel.viewMode != .preview && selectedFilePath != nil`.

#### `MDReaderApp` command group

```swift
CommandGroup(after: .textFormatting) {
    Button("Bold")      { viewModel.pendingFormat = .bold }
        .keyboardShortcut("b", modifiers: .command)
    Button("Italic")    { viewModel.pendingFormat = .italic }
        .keyboardShortcut("i", modifiers: .command)
    Button("Link")      { viewModel.pendingFormat = .link }
        .keyboardShortcut("k", modifiers: .command)
    Button("Code")      { viewModel.pendingFormat = .code }
        .keyboardShortcut("e", modifiers: .command)
    Divider()
    Button("Heading 1") { viewModel.pendingFormat = .heading(level: 1) }
        .keyboardShortcut("1", modifiers: [.command, .shift])
    Button("Heading 2") { viewModel.pendingFormat = .heading(level: 2) }
        .keyboardShortcut("2", modifiers: [.command, .shift])
    Button("Heading 3") { viewModel.pendingFormat = .heading(level: 3) }
        .keyboardShortcut("3", modifiers: [.command, .shift])
    Divider()
    Button("Bulleted List") { viewModel.pendingFormat = .unorderedList }
        .keyboardShortcut("8", modifiers: [.command, .shift])
    Button("Numbered List") { viewModel.pendingFormat = .orderedList }
        .keyboardShortcut("7", modifiers: [.command, .shift])
    Button("Quote")     { viewModel.pendingFormat = .quote }
        .keyboardShortcut("'", modifiers: [.command, .shift])
}
```

All buttons are `.disabled(selectedFilePath == nil || viewModel.viewMode == .preview)`.

## Data flow

**Typing in hybrid mode:**

1. `NSTextView.textDidChange` → Coordinator copies to `viewModel.text`,
   calls `viewModel.textDidChange()` (existing auto-save), schedules
   syntax highlighting.
2. SwiftUI sees `viewModel.text` change → `MarkdownWebView.updateNSView` runs.
3. WebView Coordinator debounces 100 ms, then calls `mdUpdate(html)` via JS.
4. If `activeLine` also differs from `lastActiveLine`, calls
   `mdScrollToLine(line)` after the update.

**Cursor-only movement:**

1. `didChangeSelectionNotification` → Coordinator computes new line,
   debounces 50 ms, publishes to `viewModel.activeLine`.
2. `MarkdownWebView.updateNSView` sees `markdown` unchanged but
   `activeLine` changed → only calls `mdScrollToLine`, no `mdUpdate`.

**⌘B (or toolbar Bold):**

1. `viewModel.pendingFormat = .bold`.
2. `MarkdownEditorView.updateNSView` runs, Coordinator sees non-nil
   `pendingFormat`, reads `textView.selectedRange`, calls
   `MarkdownFormatter.apply(.bold, textView.string, range)`.
3. Coordinator writes new text and selection back to the NSTextView, applies
   highlighting, updates `viewModel.text`, clears `viewModel.pendingFormat`.
4. Preview updates via the normal text flow.

**File load or external reload:**

- `EditorViewModel.loadFile` / `reloadFromDisk` replace `text`, reset
  `activeLine = 0`, and increment `textVersion` (existing mechanism).
- `MarkdownEditorView.Coordinator` watches `textVersion` to reset its
  `NSTextView.string` (existing logic).
- `MarkdownWebView.Coordinator` does not need `textVersion`; it detects the
  change through `viewModel.text != lastMarkdown` and calls `mdUpdate` with
  the new HTML. The shell stays loaded, so no flash.
- `viewModel.activeLine = 0` is set by `loadFile` / `clearFile`.

## Edge cases

1. **WebView not yet loaded while user types.** Stash markdown in
   `pendingMarkdown`, flush in `didFinish`.
2. **Escaping HTML for `evaluateJavaScript`.** Encode the HTML as a JSON
   string via `JSONSerialization.data(withJSONObject: [html])`, then extract
   the single element's literal form. This guarantees a valid JS string
   with all quotes, backslashes and newlines escaped.
3. **`data-line` on multi-line blocks.** The attribute marks only the first
   line of each block. `mdScrollToLine(n)` finds the largest `data-line <= n`
   via a simple linear scan — 99%+ of documents have few enough top-level
   blocks for this to be instant.
4. **Scroll sync jitter while typing.** 50 ms debounce on active-line
   publishing, plus 100 ms debounce on `mdUpdate`, keeps sync calm.
5. **Multi-line selection for wrap-style formatting.** `MarkdownFormatter`
   wraps the whole selection as a single run. For prefix-style formatting
   (headings, lists, quote), it applies the prefix to every line that the
   selection intersects.
6. **Format toggle.** Wrap-style toggle: if the selection is immediately
   bracketed by matching markers (e.g. `**…**` for `.bold`), strip the
   markers; otherwise wrap. "Immediately bracketed" means the `N` characters
   directly before `selection.location` and the `N` characters directly
   after `selection.location + selection.length` equal the marker string.
   Prefix-style toggle (`heading(level:)`, lists, quote): if every line in
   the selection already starts with the exact prefix, strip it; otherwise
   apply. For `heading`, a line that starts with a different heading level
   (e.g. `## ` when applying `.heading(level: 1)`) is replaced, not toggled.
7. **`pendingFormat` races.** `pendingFormat` is main-thread-only (SwiftUI
   state). No concurrent reads/writes possible.
8. **Selection lost after format.** `MarkdownFormatter` returns an explicit
   new `NSRange`; Coordinator sets it back on the text view.
9. **JS evaluation errors.** Logged, non-fatal. A catastrophic shell load
   failure triggers fallback to `loadHTMLString` via
   `useIncrementalUpdates = false`.
10. **Empty document.** All formatters accept `""` with `NSRange(0,0)` and
    return sensible results (e.g. `.bold` produces `"****"` with the cursor
    between the markers).

## Testing

### Unit tests — `MarkdownFormatterTests`

- `testBoldWrapsSelection`
- `testBoldToggleRemoves`
- `testItalicWrapsSelection`
- `testCodeWrapsSelection`
- `testLinkWrapsSelectionCursorOnURL`
- `testLinkEmptySelectionCursorBetweenBrackets`
- `testHeadingPrefixesCurrentLine`
- `testHeadingOnMultilineSelection`
- `testHeadingToggleRemoves`
- `testHeadingUpgradeReplacesLevel`
- `testUnorderedListMultiline`
- `testUnorderedListToggleRemoves`
- `testOrderedListNumbersLines`
- `testQuoteMultiline`
- `testCodeBlockWrapsInFences`
- `testEmptyStringSafe`
- `testSelectionOutsideBoundsReturnsUnchanged`

### Unit tests — `MarkdownRendererTests`

- `testDataLineOnHeadings`
- `testDataLineOnParagraph`
- `testDataLineOnListIsOnContainer`
- `testDataLineOnFencedCodeBlock`
- `testDataLineOnBlockquote`
- `testDataLineOnTable`
- `testExistingFeaturesStillRender` — smoke parity for a representative
  document (verifies the extraction did not regress headings, inline
  formatting, lists, tables, code blocks).

### Manual smoke checks (not automated)

- Open a longer markdown file, enter split mode, type — no flicker, scroll
  position in preview stays put.
- Move the cursor with arrow keys through different sections — preview
  scrolls to show the block around the cursor.
- Select a word, press ⌘B — wrapped in `**...**`. Press again — unwrapped.
- Select several lines, Shift-⌘-2 — each line prefixed with `## `.
- Switch to preview mode — formatting toolbar disappears, keyboard
  shortcuts are disabled.
- Load a new file — preview shows the file, no flash.
- External file change → reload — preview updates, no flash.

## Implementation order

1. **MarkdownRenderer extraction + `data-line` attributes** (pure refactor,
   fully covered by unit tests). Keep the existing non-incremental preview
   path working.
2. **MarkdownFormatter service + CommandGroup + toolbar** (independent from
   preview changes). Ship-able on its own.
3. **Incremental WebView updates + scroll sync.** Depends on step 1 for
   `data-line` attributes. Replaces `loadHTMLString`-per-change with the
   shell + `evaluateJavaScript` model.

Each step is a self-contained commit / PR with its own tests or manual smoke
check.
