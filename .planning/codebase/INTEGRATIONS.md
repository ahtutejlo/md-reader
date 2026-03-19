# External Integrations

**Analysis Date:** 2026-03-19

## APIs & External Services

**Code Syntax Highlighting:**
- highlight.js 11.9.0 - Syntax highlighting for code blocks in rendered markdown
  - CDN URLs:
    - Light theme: `https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/styles/github.min.css`
    - Dark theme: `https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/styles/github-dark.min.css`
    - JavaScript: `https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/highlight.min.js`
  - Implementation: `MarkdownWebView.swift` (lines 26-28)
  - Initialization: `hljs.highlightAll()` called in generated HTML (line 80)
  - No API key required - public CDN access

## Data Storage

**File Cache:**
- Type: Local JSON file storage
- Location: `~/Library/Application Support/MDReader/cache.json`
- Format: JSON with ISO8601 date encoding
- Data model: `CachedFile` struct containing path, lastOpened timestamp, isFavorite boolean flag
- Implementation: `FileCache.swift` handles reading/writing cache.json
- Persistence: JSON serialization via JSONEncoder/JSONDecoder with custom ISO8601 strategy

**Markdown Files:**
- Storage: User filesystem (local .md and .markdown files)
- Access: Via FileManager APIs with read-only display (except when using editor view mode)
- Supported extensions: `.md`, `.markdown`

**File Cache Details:**
- Format: Pretty-printed JSON
- Encoding: `.iso8601` date strategy for `lastOpened` field
- Backward compatibility: `isFavorite` field defaults to false if missing (line 33 in CachedFile.swift)
- Location handling: Absolute file paths stored with symlink support

## Caching

**highlight.js CDN Caching:**
- Browser-level caching via HTTP headers from CDN
- No local caching mechanism implemented
- Requires internet connectivity for initial load (highlight.js CSS and JS)

**Application-Level Caching:**
- File metadata cache: `cache.json` keeps track of recently opened files
- No network caching layer

## Authentication & Identity

**Auth Provider:**
- None - Not applicable
- Application uses local file system access only
- No user authentication or identity management
- No cloud sync or multi-user features

**File Access:**
- Local file system permissions via native macOS Finder integration
- File picker uses NSOpenPanel (native system dialog)
- Drag-and-drop from Finder supported
- CLI tool validates file existence before opening

## URL Scheme & Protocol Handling

**Custom Protocol:**
- Scheme: `mdreader://`
- Purpose: Bridge between CLI tool and GUI application
- Registration: Defined in `Info.plist` under `CFBundleURLSchemes`
- Handler: `MDReaderApp.swift` lines 28-31 (`onOpenURL` handler)
- Example: `mdreader:///path/to/file.md` (absolute path URL-encoded)

**URL Encoding:**
- CLI tool encodes file paths with `.urlPathAllowed` character set (main.swift line 22)
- App decodes and opens files via standard macOS file APIs

## Monitoring & Observability

**Error Tracking:**
- None implemented - Not applicable for local desktop application

**Logging:**
- Basic error output to stderr via `fputs()` in CLI tool
- No structured logging framework
- No analytics or telemetry

**Debug Output:**
- Error messages printed to standard error stream for CLI diagnostics

## CI/CD & Deployment

**Hosting:**
- None - Standalone native macOS application
- No cloud hosting or distribution infrastructure

**Build Pipeline:**
- Local `swift build` compilation
- Makefile automation for release builds and installation (Makefile)
- Bundle creation script: `scripts/bundle.sh` (creates .app bundle)
- Release build: `swift build -c release`

**Installation Methods:**
1. **CLI Tool Installation:**
   - Target location: `/usr/local/bin/mdreader` (default) or custom PREFIX
   - Method: `make install` (uses Makefile)
   - Uninstall: `make uninstall`

2. **App Bundle:**
   - Created via `./scripts/bundle.sh`
   - Location: `.build/MDReader.app`
   - No signing or notarization (local development)

## File Operations

**Input:**
- Markdown files from user filesystem
- File picker via NSOpenPanel
- Drag-and-drop from Finder
- CLI arguments (mdreader tool)

**Output:**
- Cached file metadata to `cache.json`
- Temporary file writes during app initialization (app support directory creation)
- No exported file formats

## Webhooks & Callbacks

**Incoming:**
- URL scheme callbacks: `mdreader://` protocol handler
- File system monitoring: None (no file watchers implemented)

**Outgoing:**
- None - Application is read-only for markdown content

**Event Handling:**
- `onOpenURL` handler in SwiftUI (MDReaderApp.swift)
- `onDrop` handler for drag-and-drop support
- No network-based callbacks or webhooks

## Network Configuration

**Internet Requirements:**
- Required: For initial load of highlight.js assets from CDN (one-time per session)
- Fallback: App functions without syntax highlighting if CDN unreachable (graceful degradation)

**External Domains:**
- `cdnjs.cloudflare.com` - Cloudflare CDN for highlight.js library

## Environment Configuration

**Required Environment Variables:**
- None - Application uses no environment configuration

**Defaults:**
- App Support directory created automatically at runtime
- Cache file location fixed: `~/Library/Application Support/MDReader/cache.json`
- No configuration files or preferences system

**Secrets:**
- None - No credentials, API keys, or sensitive data
- No .env file or secret management needed

---

*Integration audit: 2026-03-19*
