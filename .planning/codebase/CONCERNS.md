# Codebase Concerns

**Analysis Date:** 2026-03-19

## Tech Debt

**Markdown Parsing Implementation:**
- Issue: Custom line-by-line markdown-to-HTML parser implemented from scratch in `MarkdownWebView.swift`. This is fragile and doesn't handle CommonMark spec properly.
- Files: `Sources/MDReaderApp/Views/MarkdownWebView.swift` (lines 88-206)
- Impact: Edge cases in markdown rendering will break silently (nested lists, indented code blocks, complex blockquotes). Parser doesn't support many markdown features (tables partially, nested formatting conflicts, strikethrough, footnotes, etc.).
- Fix approach: Replace with a proven markdown library (e.g., `CommonMark` via Swift bindings, or use JavaScript-based rendering with `highlight.js` which is already loaded).

**Regex Pattern Compilation at Runtime:**
- Issue: Regex patterns in `MarkdownSyntaxHighlighter.swift` are compiled with `try!` at property initialization time. Patterns are recreated on every use despite being static.
- Files: `Sources/MDReaderApp/Services/MarkdownSyntaxHighlighter.swift` (lines 38-44)
- Impact: Forces unwrapping makes invalid patterns crash at startup rather than compile-time. No performance optimization from pattern reuse.
- Fix approach: Keep patterns as static computed properties but add validation tests to catch regex errors.

**No Error Propagation in File Cache:**
- Issue: `FileCache.save()` and `FileCache.load()` silently catch and ignore all errors with `try?` and bare `return` statements.
- Files: `Sources/MDReaderApp/Services/FileCache.swift` (lines 38-48)
- Impact: File cache corruption or disk space issues go undetected. User loses access to recent files list without knowing why. No logging or recovery mechanism.
- Fix approach: Implement proper error logging. Add recovery strategies (e.g., backup cache location). Consider exposing critical errors to UI.

**Weak Self Pattern without Null Check:**
- Issue: `EditorViewModel` uses `[weak self]` in closures but doesn't always null-check before accessing.
- Files: `Sources/MDReaderApp/Services/EditorViewModel.swift` (lines 95-96)
- Impact: If `self` is deallocated during auto-save, the closure silently fails to save. No indication to user that save didn't happen.
- Fix approach: Add null checks or use `[weak self] guard let self else { return }` pattern consistently.

## Known Bugs

**Auto-save Race Condition:**
- Symptoms: Rapid text changes may trigger concurrent saves or skip saves if timing overlaps with manual save.
- Files: `Sources/MDReaderApp/Services/EditorViewModel.swift` (lines 93-99, 53-65)
- Trigger: Edit file rapidly while manual save is in progress, or kill app during auto-save delay.
- Workaround: Use manual save (Cmd+S) to ensure writes complete.

**Markdown Link Regex Failure on Special URLs:**
- Symptoms: Links with parentheses in URL fragments fail to render (e.g., `[text](url#foo(bar))`).
- Files: `Sources/MDReaderApp/Views/MarkdownWebView.swift` (line 240-242)
- Trigger: Click or create link with nested parentheses.
- Workaround: URL-encode parentheses in link URLs.

**File Cache Entry Removal Doesn't Delete Cached Entry:**
- Symptoms: Removing a file from sidebar and re-adding the same file may not restore its favorite status if cache save fails in between.
- Files: `Sources/MDReaderApp/Services/FileCache.swift` (lines 27-30)
- Trigger: Remove file, crash/restart app before next save completes, re-add same file.
- Workaround: Manually toggle favorite status after re-adding.

**File Descriptor Leak on Monitor Creation Failure:**
- Symptoms: If `DispatchSourceFileSystemObject` creation fails, the file descriptor opened by `open()` may not be closed properly.
- Files: `Sources/MDReaderApp/Services/EditorViewModel.swift` (lines 104-122)
- Trigger: Open file when system file descriptor limit is reached.
- Workaround: Restart app to free descriptors.

## Security Considerations

**HTML Injection in Markdown Rendering:**
- Risk: While local files reduce risk, custom markdown parser might not properly escape all edge cases. User could accidentally open malicious markdown files.
- Files: `Sources/MDReaderApp/Views/MarkdownWebView.swift` (lines 208-245)
- Current mitigation: `escapeHTML()` function exists (lines 208-213). However, regex replacements in `inlineMarkdown()` operate on already-escaped strings, which is correct.
- Recommendations: Add test suite for injection edge cases (e.g., markdown with HTML entities, script tags in code blocks). Consider running markdown through a sanitizer.

**Command-Line Argument Validation:**
- Risk: CLI tool passes file path to URL scheme with percent encoding. Malformed input could cause issues.
- Files: `Sources/mdreader/main.swift` (lines 1-35)
- Current mitigation: Validates file exists and has `.md`/`.markdown` extension before passing to URL scheme.
- Recommendations: Validate URL encoding doesn't exceed safe limits. Add tests for path traversal attempts.

**No Sandboxing:**
- Risk: App has unrestricted file system access. Malicious code could read entire file system or modify app bundle.
- Files: All
- Current mitigation: None — app runs with user permissions.
- Recommendations: If distributed, consider App Store submission for code signing and sandboxing enforcement.

## Performance Bottlenecks

**Markdown Rendering on Every Text Change:**
- Problem: `MarkdownWebView.buildHTML()` is called on every keystroke in split/preview modes, parsing entire document from scratch.
- Files: `Sources/MDReaderApp/Views/MarkdownWebView.swift` (lines 14-16)
- Cause: SwiftUI re-renders `updateNSView()` whenever `markdown` binding changes, with no debouncing at this layer.
- Improvement path: Add debouncing or incremental parsing. Cache rendered HTML between identical inputs. Use diffing algorithm to update only changed portions of DOM.

**Regex Matching on Full Text:**
- Problem: `MarkdownSyntaxHighlighter.highlight()` runs all regex matches over entire document text for every keystroke in editor mode.
- Files: `Sources/MDReaderApp/Services/MarkdownSyntaxHighlighter.swift` (lines 46-110)
- Cause: No document diffing; always re-highlights from scratch. 0.15s debounce helps but large files will lag.
- Improvement path: Implement incremental highlighting. Only re-highlight changed lines. Cache highlighting results.

**Linear String Search in Sidebar Filter:**
- Problem: Sidebar filter creates new filtered array on every text change, scanning all cached files.
- Files: `Sources/MDReaderApp/Views/SidebarView.swift` (lines 12-21)
- Cause: No indexing or caching of search results.
- Improvement path: For typical use cases (< 100 files), this is negligible. If scale increases, add full-text index or lazy filtering.

**NSTextView Full String Update:**
- Problem: `updateNSView()` replaces entire `textStorage` via `setAttributedString()`, even when only one character changed.
- Files: `Sources/MDReaderApp/Views/MarkdownEditorView.swift` (lines 36-48, 68-76)
- Cause: Optimization using `textVersion` prevents this on user typing, but external changes replace entire view.
- Improvement path: Implement incremental text updates when external changes detected. Use diff algorithm to identify changed ranges.

## Fragile Areas

**EditorViewModel File Monitoring:**
- Files: `Sources/MDReaderApp/Services/EditorViewModel.swift` (lines 104-127)
- Why fragile: Low-level file descriptor and DispatchSource management. No recovery if monitor fails silently. If file is moved/deleted while monitoring, behavior is undefined.
- Safe modification: Test all file move/delete/chmod scenarios. Add logging for monitor state transitions. Consider wrapping in higher-level FileWatcher abstraction.
- Test coverage: Tests for external changes exist (lines 53-83 in `EditorViewModelTests.swift`), but no tests for monitor failure modes, file deletion during monitoring, or concurrent monitoring of multiple files.

**Markdown Parser Edge Cases:**
- Files: `Sources/MDReaderApp/Views/MarkdownWebView.swift` (lines 88-206)
- Why fragile: Parser is sequential state machine with many string prefix checks. Easy to add features but easy to break existing parsing. No unit tests for parser logic.
- Safe modification: Add comprehensive test suite before modifying parser. Test each markdown feature independently. Test interaction between features (bold inside lists, code blocks with special chars, etc.).
- Test coverage: No parser tests exist. Only high-level rendering tests via `MarkdownSyntaxHighlighterTests.swift`.

**NSTextViewDelegate Coordination:**
- Files: `Sources/MDReaderApp/Views/MarkdownEditorView.swift` (lines 50-86)
- Why fragile: Coordinator must synchronize three states: `textView.string`, `viewModel.text`, and highlight timing. `isUpdating` flag is only synchronization mechanism.
- Safe modification: Any change to text flow must account for update flag. Test sequence: load external file → edit → external change while editing → reload. Document state machine in comments.
- Test coverage: Basic load/save tested, but no tests for concurrent edit+external change scenarios or highlight scheduling races.

**File Cache JSON Persistence:**
- Files: `Sources/MDReaderApp/Services/FileCache.swift` (lines 6-49)
- Why fragile: No schema versioning. Adding fields to `CachedFile` requires manual migration. Corrupted cache.json silently fails to load.
- Safe modification: Add version field to cache format. Implement migration logic before adding breaking changes. Add validation before accepting deserialized data.
- Test coverage: Tests exist for basic operations but no schema migration tests or corruption recovery tests.

## Scaling Limits

**File Cache Memory:**
- Current capacity: Limited by available RAM (entire cache loaded into memory).
- Limit: With 10,000+ cached files, JSON parsing/serialization will become slow.
- Scaling path: Implement pagination or lazy loading. Use SQLite for cache instead of JSON for better indexing and filtering. Stream large cache files rather than loading entirely.

**Markdown Rendering Performance:**
- Current capacity: Smooth rendering up to ~50KB markdown files (typical).
- Limit: Files > 500KB will have noticeable lag during editing and preview mode.
- Scaling path: Implement windowing (only render visible portion). Use virtualization in preview mode. Lazy-load sections of large documents.

**File Descriptor Limit:**
- Current capacity: System limit (typically 256 or 1024 per process on macOS).
- Limit: If monitoring many files simultaneously, system file descriptor limit will be hit.
- Scaling path: Only monitor currently-open file. Close/open monitor as user switches files. Implement resource pooling.

## Dependencies at Risk

**Highlight.js CDN Dependency:**
- Risk: Code syntax highlighting relies on CDN-hosted highlight.js. If CDN is down, code blocks won't highlight. Works offline but without CDN styles.
- Impact: Users on slow/flaky internet see unstyled code. Completely offline rendering falls back to unstyled code.
- Migration plan: Bundle highlight.js locally instead of loading from CDN. Use local CSS files for themes. Test offline rendering.

**No Package Dependencies:**
- Risk: While great for shipping, any security vulnerabilities in custom code cannot be fixed by updating dependencies.
- Impact: Markdown parser vulnerabilities persist until manual fix and recompile.
- Mitigation: Security audit of custom parsing code. Consider using CommonMark Swift library if officially available.

## Missing Critical Features

**No Markdown Syntax Validation:**
- Problem: User can write invalid markdown without feedback. Parser silently skips invalid syntax.
- Blocks: No linting, validation, or error messages during editing.

**No Multi-Tab Support:**
- Problem: Can only edit one file at a time. Must switch via sidebar to edit another file, losing editor scroll/cursor position.
- Blocks: Power users cannot compare/edit multiple files simultaneously.

**No File Encoding Support:**
- Problem: Assumes UTF-8. Files with other encodings (Latin-1, UTF-16) will display as garbage.
- Blocks: Users with legacy files cannot open them.

**No Undo/Redo History Persistence:**
- Problem: Closing file loses undo history. Text view's undo stack is local and not saved.
- Blocks: Recovery from accidental changes across sessions is impossible.

**No File Diff View:**
- Problem: No easy way to see what changed when file was modified externally. Dialog only offers "Reload"/"Ignore"/"Save".
- Blocks: Users cannot merge external changes with local edits manually.

## Test Coverage Gaps

**Markdown Parser:**
- What's not tested: Parser edge cases (nested formatting, special characters in links, tables, complex lists, mixed block types).
- Files: `Sources/MDReaderApp/Views/MarkdownWebView.swift`
- Risk: Parser regressions in markdown rendering will not be caught. Users discover bugs when opening real files.
- Priority: High — critical path for feature.

**File System Operations:**
- What's not tested: File permissions errors, symlinks, case-sensitive file systems, files deleted during app runtime, disk full during save.
- Files: `Sources/MDReaderApp/Services/FileCache.swift`, `Sources/MDReaderApp/Services/EditorViewModel.swift`
- Risk: App crashes or silently loses data in edge cases. Error handling is minimal.
- Priority: High — data loss risk.

**AppDelegate Lifecycle:**
- What's not tested: App activation, window management, multiple window scenarios, app termination with unsaved changes.
- Files: `Sources/MDReaderApp/MDReaderApp.swift` (lines 109-122)
- Risk: App state corruption if multiple windows open, unsaved changes lost on crash.
- Priority: Medium — affects UX stability.

**CLI Tool:**
- What's not tested: Relative path resolution, symlinks, permission errors, nonexistent files, invalid markdown extensions, URL scheme invocation failures.
- Files: `Sources/mdreader/main.swift`
- Risk: CLI silently fails without clear error messages to user. App may not launch as expected.
- Priority: Medium — affects discoverability.

---

*Concerns audit: 2026-03-19*
