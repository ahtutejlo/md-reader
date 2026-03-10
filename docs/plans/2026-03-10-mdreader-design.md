# MDReader — Design Document

## Overview

Native macOS markdown file reader built with SwiftUI. Provides a single place to read and manage all markdown files. Files can be opened via terminal CLI command, and the app caches links to previously opened files with metadata.

## Architecture

Pure SwiftUI app using `AttributedString(markdown:)` for rendering. No external dependencies.

## Components

- **MDReaderApp** — entry point, registers `mdreader://` URL scheme for receiving files from CLI
- **FileCache** — `ObservableObject`, persists file list as JSON in `~/Library/Application Support/MDReader/cache.json`
- **CachedFile** — model: `path`, `name`, `lastOpened`, `fileSize`, `exists`
- **SidebarView** — list of cached files, sorted by last opened date, with search and remove from cache
- **ContentView** — renders markdown via `AttributedString(markdown:)` in a `Text` view
- **CLI utility** (`mdreader`) — separate Swift executable, opens file via `open mdreader://path`

## Data Flow

```
CLI: mdreader file.md
  -> resolves to absolute path
  -> open "mdreader:///absolute/path/to/file.md"
    -> macOS opens MDReader.app (or activates if running)
      -> App parses URL, adds file to cache, displays content
```

## Cache Format (cache.json)

```json
[
  {
    "path": "/Users/user/docs/README.md",
    "name": "README.md",
    "lastOpened": "2026-03-10T12:00:00Z",
    "fileSize": 4096
  }
]
```

## CLI Utility

Simple Swift executable:
- Accepts `mdreader <path>`
- Resolves relative path to absolute
- Calls `open "mdreader:///absolute/path"`

## UI Layout

`NavigationSplitView` — sidebar with cached file list on the left, markdown content on the right.

## Project Structure

```
MDReader/
├── Package.swift
├── MDReaderApp/
│   ├── MDReaderApp.swift
│   ├── Models/
│   │   └── CachedFile.swift
│   ├── Services/
│   │   └── FileCache.swift
│   └── Views/
│       ├── SidebarView.swift
│       └── ContentView.swift
└── mdreader-cli/
    └── main.swift
```

## Decisions

- **AttributedString** over WKWebView — simpler, no dependencies, covers 90% of markdown features
- **JSON file cache** over CoreData/SQLite — lightweight, sufficient for file path + metadata storage
- **URL scheme** for CLI-to-app communication — standard macOS mechanism, works whether app is running or not
