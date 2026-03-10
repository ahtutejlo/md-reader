# MDReader

A native macOS markdown reader application built with SwiftUI. MDReader provides a clean, distraction-free way to read markdown files with syntax highlighting, a file sidebar, and a companion CLI tool.

## Features

- **Markdown rendering** with full syntax support — headings, lists, tables, code blocks, blockquotes, inline formatting, and more
- **Code syntax highlighting** powered by highlight.js
- **Dark and light mode** — follows system appearance automatically
- **File sidebar** with search, recent files sorted by last opened, and visual indicators for missing files
- **Multiple ways to open files** — file picker, drag-and-drop, CLI tool, or `mdreader://` URL scheme
- **CLI companion tool** — open markdown files from the terminal with `mdreader <file>`
- **Persistent file cache** — recently opened files are remembered across app launches
- **Zero external dependencies** — built entirely with native Apple frameworks

## Requirements

- macOS 14.0+
- Swift 5.9+

## Building

```bash
# Build both the app and CLI tool
swift build

# Run the app directly
.build/debug/MDReaderApp

# Create a proper .app bundle
./scripts/bundle.sh
open .build/MDReader.app
```

## Installation

```bash
# Install to /usr/local/bin (requires sudo)
sudo make install

# Or install to a custom prefix
make install PREFIX=~/.local
```

To uninstall:

```bash
sudo make uninstall
```

## CLI Usage

The `mdreader` CLI tool opens markdown files in the MDReader app:

```bash
# Open a file by path
mdreader /path/to/file.md
mdreader ./relative/path.markdown
```

Supported extensions: `.md`, `.markdown`

The CLI resolves relative paths, validates the file exists, and launches the app via the `mdreader://` URL scheme.

## Project Structure

```
md-reader/
├── Package.swift
├── Sources/
│   ├── MDReaderApp/
│   │   ├── MDReaderApp.swift          # App entry point, window and navigation setup
│   │   ├── Info.plist                 # Bundle config, URL scheme registration
│   │   ├── AppIconGenerator.swift     # Dock icon generation
│   │   ├── Resources/
│   │   │   └── AppIcon.icns
│   │   ├── Models/
│   │   │   └── CachedFile.swift       # File cache data model
│   │   ├── Services/
│   │   │   └── FileCache.swift        # JSON-backed file cache service
│   │   └── Views/
│   │       ├── ContentView.swift      # File content display
│   │       ├── MarkdownWebView.swift  # WKWebView-based markdown renderer
│   │       └── SidebarView.swift      # Searchable file list sidebar
│   └── mdreader/
│       └── main.swift                 # CLI entry point
└── scripts/
    └── bundle.sh                      # macOS .app bundle creation script
```

## Architecture

- **UI**: SwiftUI `NavigationSplitView` with sidebar and detail panes
- **Markdown rendering**: Custom markdown-to-HTML conversion displayed in a `WKWebView`
- **State management**: Swift Observation framework (`@Observable`)
- **File cache**: JSON persistence in `~/Library/Application Support/MDReader/cache.json`
- **CLI integration**: URL scheme (`mdreader://`) bridges the CLI tool to the GUI app

## License

This project is provided as-is for personal use.
