# MD Editor: View Modes & Editing

## Overview

Add editing capabilities to MDReader with three view modes (like IntelliJ): Editor, Split (Editor + Preview), and Preview (current behavior).

## View Modes

Segmented control in toolbar with three options:

- **Editor** (`square.and.pencil`) — full-screen native text editor with markdown syntax highlighting
- **Split** (`rectangle.split.2x1`) — horizontal split: editor left, WKWebView preview right
- **Preview** (`eye`) — current read-only rendered view

Default mode: **Preview** (preserves current behavior).

## Text Editor

`NSTextView` wrapped in `NSViewRepresentable`:

- Monospace font (SF Mono, 14px)
- Basic syntax highlighting: headings, bold/italic, inline code, code blocks, links
- Free NSTextView features: undo/redo, Cmd+F search

## Saving

- **Auto-save**: debounce 1.5s after last change
- **Manual**: Cmd+S
- Unsaved changes indicator: dot in window title (standard macOS pattern)

## Split Mode Sync

- Preview updates on each text change with ~300ms debounce for performance

## External File Change Detection

- `DispatchSource.makeFileSystemObjectSource` to monitor the open file
- File changed externally + **no unsaved changes** → auto-reload
- File changed externally + **unsaved changes** → Alert: "File changed externally. Reload (lose changes) / Ignore / Save your version"

## Architecture

New files:
- `MarkdownEditorView.swift` — NSViewRepresentable wrapping NSTextView
- `MarkdownSyntaxHighlighter.swift` — syntax highlighting for markdown
- `EditorViewModel.swift` — @Observable model: text content, view mode, save state, debounce logic

Modified files:
- `ContentView.swift` — support three view modes, integrate editor
- `MDReaderApp.swift` — add toolbar segmented control, Cmd+S handler

New types:
- `ViewMode` enum: `.editor`, `.split`, `.preview`

## Out of Scope

- Creating new files
- Markdown toolbar (bold/italic buttons)
- Tab-based multi-file editing
