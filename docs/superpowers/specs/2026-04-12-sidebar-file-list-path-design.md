# Sidebar File List: Path Disambiguation & Reveal in Finder

**Date:** 2026-04-12
**Status:** Approved

## Problem

Sidebar shows only the filename, so files with identical names (e.g. `README.md` from different projects) are indistinguishable. There is also no quick way to locate a file on disk.

## Scope

Two focused changes to `SidebarView.swift` and `CachedFile.swift`:

1. Add a third line to each row showing the file path (home directory collapsed to `~`, middle-truncated).
2. Add "Reveal in Finder" to the row context menu.

Out of scope: sorting, grouping, file size, content preview, missing-file badges.

## Design

### `CachedFile.swift`

Add a computed property:

```swift
var displayPath: String {
    let home = NSHomeDirectory()
    if path.hasPrefix(home) {
        return "~" + path.dropFirst(home.count)
    }
    return path
}
```

The model owns the `~` substitution so the view stays declarative.

### `SidebarView.swift` — `FileRow`

Current layout: `VStack` with two rows (name, relative date).

New layout: three rows.

1. Name row (unchanged): icon + name + favorite star.
2. Path row (new):
   - `Text(file.displayPath)`
   - `.font(.caption2)`
   - `.foregroundStyle(.secondary)`
   - `.lineLimit(1)`
   - `.truncationMode(.middle)`
3. Date row (unchanged): `Text(file.lastOpened, style: .relative)` with `.caption` / secondary.

Attach `.help(file.path)` to the row so the full absolute path appears as a tooltip on hover (useful when truncation hides the middle).

### Context menu

Current menu has one item: `Remove from List`. New order:

1. `Button("Reveal in Finder") { NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: file.path)]) }`
2. `Divider()`
3. `Button("Remove from List", role: .destructive) { onRemove(file) }`

`NSWorkspace` is already available via `AppKit`, which SwiftUI brings in transitively; add `import AppKit` to `SidebarView.swift` if not present.

## Non-goals / things we explicitly do not change

- Filtering, search, favorites logic — untouched.
- Row height is not set explicitly; SwiftUI adapts to the extra caption line.
- No new dependencies.
- No changes to `ContentView.swift` or the sidebar's public surface.

## Testing

Manual verification after the change:

- Two files with the same name from different directories show distinct paths.
- Very long paths truncate in the middle and the full path appears in the tooltip.
- "Reveal in Finder" opens Finder with the file selected.
- "Remove from List" still works and is visually separated from the new action.
