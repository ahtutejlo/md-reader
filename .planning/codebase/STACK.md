# Technology Stack

**Analysis Date:** 2026-03-19

## Languages

**Primary:**
- Swift 5.9+ - Native macOS application and CLI tool

**Secondary:**
- HTML/CSS - Generated markup for markdown rendering in WKWebView
- JavaScript - highlight.js library for code syntax highlighting (loaded from CDN)

## Runtime

**Environment:**
- macOS 14.0 or later (Sonoma and newer)
- Apple Silicon and Intel x86_64 support (native compilation via Swift)

**Package Manager:**
- Swift Package Manager (SPM) - Native to Swift ecosystem
- Lockfile: `Package.swift` (deterministic versioning)

## Frameworks

**Core UI:**
- SwiftUI - Modern declarative UI framework for app interface
- Combine (implicit via SwiftUI) - Reactive programming for state management
- AppKit - macOS system integrations (NSApplication, NSOpenPanel, etc.)

**Web Rendering:**
- WebKit (`WKWebView`) - Native macOS web view for markdown rendering

**State Management:**
- Swift Observation framework (`@Observable` macro) - Built-in observable pattern for reactive state

**Testing:**
- Swift Testing (Testing framework) - Modern native testing framework introduced in Swift 5.9
  - Uses `@Test` macro-based syntax instead of XCTest
  - Config: Tests located in `/Tests/MDReaderAppTests/`

**Build/Dev:**
- Swift compiler (native toolchain)
- Makefile - Build and installation automation at `Makefile`

## Key Dependencies

**Critical:**
- highlight.js 11.9.0 - Code syntax highlighting
  - Loaded via CDN: `https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/`
  - CSS themes for light and dark modes included
  - No local package dependency (loaded at runtime in WKWebView HTML)

**Core:**
- Foundation - Standard library utilities (FileManager, URL handling, JSON encoding)
- Combine - Event handling and observation (implicit, built-in)
- UniformTypeIdentifiers - File type handling and validation

**Infrastructure:**
- None - Zero external package dependencies (stated in README as a design goal)

## Configuration

**Environment:**
- No environment variables required
- Application defaults provided via code

**Build:**
- `swift-tools-version: 5.9` in `Package.swift`
- Two executable targets defined:
  - `MDReaderApp` - Main GUI application with SwiftUI
  - `mdreader` - Companion CLI tool for opening files

**macOS Bundle Config:**
- `Info.plist` at `Sources/MDReaderApp/Info.plist`
- Defines URL scheme registration for `mdreader://` protocol
- Bundle icon configuration for dock appearance
- CFBundleIconFile: `AppIcon.icns`

## Platform Requirements

**Development:**
- macOS 14.0+ with Xcode 15+ or Swift 5.9+ command-line tools
- Unix-like environment (bash/zsh shell for build scripts)
- Makefile support (standard on macOS)

**Production:**
- Native macOS application (`.app` bundle)
- Deployment via:
  - Direct app bundle execution
  - CLI tool installation to `/usr/local/bin` or custom prefix via `make install`
  - URL scheme handler registration in macOS

**Deployment Target:**
- macOS 14.0 (minimum version specified in `Package.swift`)
- Self-contained executable (no runtime dependencies)

## File Persistence

**Local Storage:**
- Application Support directory: `~/Library/Application Support/MDReader/`
- Cache file: `cache.json` (JSON format with ISO8601 date encoding)
- File system access via FileManager (native macOS APIs)

## Notable Design Decisions

**Zero External Dependencies:**
- No third-party package dependencies beyond Swift stdlib and macOS frameworks
- Custom markdown-to-HTML parser implemented in `MarkdownWebView.swift` (lines 88-206)
- Markdown rendering: custom line-by-line parser with regex support
- Syntax highlighting delegated to highlight.js via CDN (no local package)

**Web-Based Rendering:**
- Markdown rendered to HTML and displayed in WKWebView
- Allows CSS styling with native macOS appearance support
- Supports dark mode via CSS media queries

**URL Scheme Integration:**
- CLI tool bridges to GUI via `mdreader://` protocol handler
- Enables seamless terminal-to-app workflow

---

*Stack analysis: 2026-03-19*
