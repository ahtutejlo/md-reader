# Architecture

**Analysis Date:** 2026-03-19

## Pattern Overview

**Overall:** Multi-layered SwiftUI desktop application with MVVM (Model-View-ViewModel) pattern and clear separation of concerns.

**Key Characteristics:**
- SwiftUI for declarative UI with split-view navigation
- Observable ViewModel pattern for state management
- Service layer for file operations and persistence
- Two entry points: GUI app and CLI wrapper
- NSViewRepresentable bridges for native macOS components (NSTextView, WKWebView)

## Layers

**Presentation Layer:**
- Purpose: SwiftUI views that display UI and handle user interactions
- Location: `Sources/MDReaderApp/Views/`
- Contains: View structs (ContentView, MarkdownEditorView, SidebarView, MarkdownWebView)
- Depends on: Services, Models
- Used by: App delegate and main entry point

**ViewModel/State Layer:**
- Purpose: Manages application state, file loading, editing, and auto-save logic
- Location: `Sources/MDReaderApp/Services/`
- Contains: EditorViewModel (Observable), FileCache (Observable)
- Depends on: Models, Foundation (file operations)
- Used by: Views

**Model Layer:**
- Purpose: Data structures representing application entities
- Location: `Sources/MDReaderApp/Models/`
- Contains: CachedFile, ViewMode enum
- Depends on: Foundation only
- Used by: Services and Views

**Service Layer:**
- Purpose: Business logic and external integrations (file I/O, caching, syntax highlighting)
- Location: `Sources/MDReaderApp/Services/`
- Contains: FileCache (persistent state), EditorViewModel (editing state), MarkdownSyntaxHighlighter (rendering)
- Depends on: Models, Foundation, AppKit
- Used by: Views and App entry point

**Application Layer:**
- Purpose: App lifecycle, window management, delegation
- Location: `Sources/MDReaderApp/MDReaderApp.swift`
- Contains: MDReaderApp (main App scene), AppDelegate
- Depends on: All layers
- Used by: macOS runtime

**CLI Layer:**
- Purpose: Command-line interface for opening files in GUI
- Location: `Sources/mdreader/main.swift`
- Contains: Argument parsing and xdg-open-like behavior
- Depends on: Foundation
- Used by: Terminal users

## Data Flow

**Opening a File (GUI):**

1. User interacts with UI: drags file, clicks Open button, or uses CLI
2. `MDReaderApp.openMarkdownFile()` receives file URL
3. `FileCache.addFile(url:)` updates cached files list and saves to disk
4. Selected file path binding updated → `task(id: fileURL)` triggers
5. `EditorViewModel.loadFile(url:)` loads content from disk and starts monitoring
6. `ContentView` switches on viewMode and renders appropriate editor/preview
7. Changes flow: user types → `MarkdownEditorView.Coordinator.textDidChange()` → `EditorViewModel.textDidChange()` sets `hasUnsavedChanges` flag

**Saving a File:**

1. Auto-save triggered after 1.5 seconds of inactivity OR user presses Cmd+S
2. `EditorViewModel.save()` writes text to URL with atomic write
3. Monitoring temporarily disabled during write to avoid external change alert
4. `hasUnsavedChanges` flag cleared after successful write

**Detecting External Changes:**

1. `EditorViewModel.startMonitoring()` sets up DispatchSourceFileSystemObject on file descriptor
2. File write or rename triggers handler → `handleExternalChange()`
3. If file has unsaved user changes: show alert with reload/ignore/save options
4. If no unsaved changes: automatically reload from disk

**Switching View Modes:**

1. User clicks segmented picker in toolbar
2. `EditorViewModel.viewMode` updated (editor, split, or preview)
3. `ContentView` re-renders with appropriate view layout
4. Both editor and preview react to `viewModel.text` changes in real-time

**File Cache Persistence:**

1. `FileCache` initialized on app launch with ISO8601 date encoding
2. Cache stored in `~/Library/Application Support/MDReader/cache.json`
3. Each file operation (add, remove, favorite toggle) triggers `save()`
4. Files sorted by `lastOpened` date descending

**State Management:**

- `@Observable` classes allow SwiftUI to track all property changes automatically
- `@State` properties in views for local UI state (search text, hover states, filters)
- `@Binding` properties pass state up/down view hierarchy
- No Redux/Redux-like pattern needed due to native SwiftUI observation

## Key Abstractions

**EditorViewModel:**
- Purpose: Central state container for file editing, loading, and monitoring
- Files: `Sources/MDReaderApp/Services/EditorViewModel.swift`
- Pattern: Observable class with imperative side-effects (file I/O, GCD dispatch)
- Responsibilities: Load/save files, detect external changes, schedule auto-saves, manage unsaved state

**FileCache:**
- Purpose: Persistent list of recently accessed files with metadata
- Files: `Sources/MDReaderApp/Services/FileCache.swift`
- Pattern: Observable singleton-like service with JSON persistence
- Responsibilities: Track files, update last-opened timestamp, manage favorites, serialize/deserialize

**MarkdownSyntaxHighlighter:**
- Purpose: Apply NSAttributedString formatting to raw markdown text
- Files: `Sources/MDReaderApp/Services/MarkdownSyntaxHighlighter.swift`
- Pattern: Enum with static functions and cached regex patterns
- Responsibilities: Tokenize markdown syntax, apply color/font attributes per element type

**CachedFile:**
- Purpose: Value type representing a file in the cache
- Files: `Sources/MDReaderApp/Models/CachedFile.swift`
- Pattern: Codable struct with computed properties
- Responsibilities: Store file path, last-opened date, favorite flag; verify file existence

**ViewMode:**
- Purpose: Enum controlling the main content view layout
- Files: `Sources/MDReaderApp/Models/ViewMode.swift`
- Pattern: CaseIterable enum with associated UI metadata
- Responsibilities: Define editor/split/preview mode with icon and label

## Entry Points

**GUI Application (`MDReaderApp`):**
- Location: `Sources/MDReaderApp/MDReaderApp.swift` (lines 6-123)
- Triggers: User launches app directly (icon or Spotlight)
- Responsibilities:
  - Initialize FileCache and EditorViewModel
  - Set up NavigationSplitView with sidebar and detail
  - Register external URL handler (mdreader://) to accept files from CLI
  - Handle drag-and-drop file drops onto window
  - Manage keyboard shortcuts (Save: Cmd+S, Toggle Favorite: Cmd+Shift+D)
  - Initialize AppDelegate for macOS app setup

**CLI Entry Point (`mdreader`):**
- Location: `Sources/mdreader/main.swift`
- Triggers: User runs `mdreader <path>` in terminal
- Responsibilities:
  - Parse file path from command-line arguments
  - Validate file exists and is markdown (.md or .markdown)
  - URL-encode path and construct mdreader:// URL
  - Invoke `open` command to trigger GUI app's URL handler

**AppDelegate:**
- Location: `Sources/MDReaderApp/MDReaderApp.swift` (lines 109-122)
- Triggers: App finished launching
- Responsibilities:
  - Force app to regular GUI mode (not background)
  - Activate app in foreground
  - Load and set Dock icon from bundled .icns resource

## Error Handling

**Strategy:** Defensive with graceful fallback and user-facing alerts

**Patterns:**

- **File Load Errors:** Caught in `EditorViewModel.loadFile()`, stored in `loadError` state, displayed as `ContentUnavailableView`
- **Save Errors:** Caught in `EditorViewModel.save()`, stored in `saveError` state, shown in alert dialog with user acknowledgment
- **External Change Detection:** Monitored via DispatchSource; user prompted to reload/ignore/save based on unsaved state
- **Missing Files:** `FileCache` tracks file existence via `CachedFile.exists` computed property; UI marks missing files with red icon
- **CLI Validation:** Explicit error messages to stderr for missing files, non-markdown files, app launch failures; exit code 1 on failure

## Cross-Cutting Concerns

**Logging:** No structured logging; errors and state changes visible only through UI and user interactions (no console output during normal operation)

**Validation:**
- CLI validates file extension (.md, .markdown) and existence before invoking app
- `CachedFile` initializer validates file exists via FileManager.attributesOfItem()
- View bindings prevent operations on nil state (disabled Save button, Favorite button when no file selected)

**Authentication:** Not applicable; single-user local application with no network authentication

**Persistence:**
- File content: Direct filesystem writes with atomic flag to prevent corruption
- Cache metadata: JSON serialization with ISO8601 date encoding stored in ~/Library/Application Support
- Auto-save: Dispatch-based 1.5-second debouncing to reduce write frequency

**File Monitoring:**
- Native macOS DispatchSourceFileSystemObject watches file descriptor for write/rename events
- Debounced to avoid recursive reloads when app saves its own changes
- Gracefully handles files moved/deleted by external processes

---

*Architecture analysis: 2026-03-19*
