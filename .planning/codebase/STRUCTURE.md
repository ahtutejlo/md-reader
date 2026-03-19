# Codebase Structure

**Analysis Date:** 2026-03-19

## Directory Layout

```
md-reader/
├── Sources/
│   ├── MDReaderApp/              # Main GUI application target
│   │   ├── Models/               # Data structures
│   │   ├── Services/             # Business logic and state
│   │   ├── Views/                # SwiftUI views
│   │   ├── Resources/            # App icon asset
│   │   ├── MDReaderApp.swift     # Entry point and app delegate
│   │   └── Info.plist            # App metadata
│   └── mdreader/                 # CLI tool target
│       └── main.swift            # Command-line entry point
├── Tests/
│   └── MDReaderAppTests/         # Test target (directory present)
├── docs/
│   ├── plans/                    # Planning documents
│   └── superpowers/              # Feature specifications
├── scripts/                      # Build/utility scripts
├── Package.swift                 # Swift package manifest
├── Makefile                      # Build commands
├── README.md                     # Project overview
└── .planning/                    # GSD planning documents
    └── codebase/                 # Architecture analysis (this directory)
```

## Directory Purposes

**`Sources/MDReaderApp/`:**
- Purpose: Main GUI application—markdown editor with three view modes
- Contains: Swift source files organized by layer (Models, Services, Views)
- Key files: `MDReaderApp.swift` (app entry point), Views (presentation), Services (state/logic)

**`Sources/MDReaderApp/Models/`:**
- Purpose: Value types representing core domain entities
- Contains: Swift structs and enums
- Key files: `CachedFile.swift` (file metadata), `ViewMode.swift` (display mode enum)

**`Sources/MDReaderApp/Services/`:**
- Purpose: State management, business logic, and external integrations
- Contains: Observable classes and utility functions
- Key files: `EditorViewModel.swift` (editing state), `FileCache.swift` (persistence), `MarkdownSyntaxHighlighter.swift` (rendering)

**`Sources/MDReaderApp/Views/`:**
- Purpose: SwiftUI UI components
- Contains: View structs and NSViewRepresentable wrappers
- Key files: `ContentView.swift` (main layout), `MarkdownEditorView.swift` (text editor), `MarkdownWebView.swift` (preview), `SidebarView.swift` (file list)

**`Sources/MDReaderApp/Resources/`:**
- Purpose: Bundled assets
- Contains: AppIcon.icns (macOS app icon)

**`Sources/mdreader/`:**
- Purpose: Command-line tool for opening files in GUI
- Contains: Single entry point script
- Key files: `main.swift` (argument parsing and app invocation)

**`Tests/MDReaderAppTests/`:**
- Purpose: Unit and integration tests
- Contains: Test files (structure present but empty)

**`docs/`:**
- Purpose: Project documentation and specifications
- Contains: Planning documents, feature specs, user guides

**`scripts/`:**
- Purpose: Build automation and utility scripts
- Contains: Shell scripts for packaging, code generation, etc.

## Key File Locations

**Entry Points:**

- `Sources/MDReaderApp/MDReaderApp.swift` (lines 6-86): @main App struct defining window group, navigation, toolbar, and event handlers
- `Sources/mdreader/main.swift`: CLI wrapper that validates arguments and opens mdreader:// URL

**Configuration:**

- `Package.swift`: Swift package manifest with target definitions, dependencies, resources
- `Info.plist`: App metadata (bundle identifier, version, display name)
- Makefile: Common build commands

**Core Logic:**

- `Sources/MDReaderApp/Services/EditorViewModel.swift`: File loading, auto-save, external change detection, state tracking
- `Sources/MDReaderApp/Services/FileCache.swift`: Persistent file history with JSON storage
- `Sources/MDReaderApp/Services/MarkdownSyntaxHighlighter.swift`: Syntax coloring and formatting

**Presentation:**

- `Sources/MDReaderApp/Views/ContentView.swift`: Main view dispatcher based on selection and view mode
- `Sources/MDReaderApp/Views/MarkdownEditorView.swift`: NSTextView wrapper with highlighting coordination
- `Sources/MDReaderApp/Views/MarkdownWebView.swift`: WKWebView markdown-to-HTML renderer
- `Sources/MDReaderApp/Views/SidebarView.swift`: File list with search, favorites, and actions

**Models:**

- `Sources/MDReaderApp/Models/CachedFile.swift`: File metadata (path, last opened, favorite flag)
- `Sources/MDReaderApp/Models/ViewMode.swift`: Editor/split/preview mode enumeration

## Naming Conventions

**Files:**

- PascalCase for view and type names: `ContentView.swift`, `EditorViewModel.swift`
- lowercase for utilities: `main.swift` (CLI entry point)
- Directory grouping by feature/layer: Models/, Views/, Services/

**Directories:**

- PascalCase for app targets: MDReaderApp, MDReaderAppTests
- lowercase for utility directories: scripts/, docs/
- Plural for collections: Views/, Services/, Models/, Resources/

**Swift Identifiers:**

- Classes and structs: PascalCase (EditorViewModel, CachedFile)
- Functions and properties: camelCase (loadFile, textDidChange, hasUnsavedChanges)
- Constants: camelCase (markdownExtensions, fenceColor)
- Enums: PascalCase with lowercase cases (ViewMode.editor, ViewMode.split)

## Where to Add New Code

**New Feature (e.g., Theme Switching):**
- Model: Add to `Sources/MDReaderApp/Models/` if defining data structure
- State: Add Observable class or property to `Sources/MDReaderApp/Services/EditorViewModel.swift` or new service
- View: Add UI component in `Sources/MDReaderApp/Views/`
- Tests: Create corresponding file in `Tests/MDReaderAppTests/`

**New Component/Module:**
- If presentation layer: Create view struct in `Sources/MDReaderApp/Views/ComponentName.swift`
- If business logic: Create service class in `Sources/MDReaderApp/Services/ComponentName.swift`
- If data: Create model struct in `Sources/MDReaderApp/Models/ComponentName.swift`

**Utilities and Helpers:**
- Syntax-specific helpers: Add as extensions on String, NSTextView, etc. in the relevant file
- Shared algorithms: Extract to new file in `Sources/MDReaderApp/Services/` (e.g., MarkdownSyntaxHighlighter is utility-like)
- Constants and formatters: Keep alongside their primary consumer or in Models/ if shared

**Tests:**
- Place in `Tests/MDReaderAppTests/` with same name as target file + "Tests" suffix
- Example: test for `EditorViewModel.swift` goes in `EditorViewModelTests.swift`

## Special Directories

**`Sources/MDReaderApp/Resources/`:**
- Purpose: App bundled resources referenced from code
- Generated: No
- Committed: Yes
- Contains: AppIcon.icns (macOS icon set)
- Copied into app bundle at build time via `resources: [.copy("Resources/AppIcon.icns")]` in Package.swift

**`docs/plans/` and `docs/superpowers/`:**
- Purpose: Design documentation and feature specifications
- Generated: No (hand-authored)
- Committed: Yes
- Used by: Developers planning features

**`.planning/codebase/`:**
- Purpose: Machine-readable architecture analysis for GSD orchestrator
- Generated: Yes (by /gsd:map-codebase)
- Committed: Yes
- Contains: ARCHITECTURE.md, STRUCTURE.md, CONVENTIONS.md, TESTING.md, CONCERNS.md

**`~/Library/Application Support/MDReader/`:**
- Purpose: Runtime file cache storage (not in repo)
- Generated: Yes (by FileCache on first run)
- Committed: No
- Contains: cache.json (recently opened files metadata)

## Relative Import Patterns

**Swift Package Structure:**
- Targets are defined in Package.swift; files within a target automatically see each other
- No explicit import needed between files in same target (e.g., View can use ViewModel without import)
- Cross-target imports require declaring dependencies in Package.swift (mdreader target has no dependencies on MDReaderApp)

**Resource Access:**
- App icon accessed via `Bundle.module.url(forResource:withExtension:)` in AppDelegate (line 117)
- HTML styles and JavaScript CDN URLs hardcoded in `MarkdownWebView.buildHTML()` (lines 26-28)

---

*Structure analysis: 2026-03-19*
