import AppKit
import SwiftUI

struct SidebarView: View {
    let files: [CachedFile]
    @Binding var selectedFilePath: String?
    var onRemove: (Set<String>) -> Void
    var onToggleFavorite: (String) -> Void

    @State private var selection: Set<String> = []
    @State private var searchText = ""
    @State private var showFavoritesOnly = false
    @State private var contentIndex = FileContentIndex()
    @State private var projectLocator = ProjectLocator()
    @AppStorage(Preferences.groupByProjectKey) private var groupByProject = true

    private var matches: [SidebarMatch] {
        let candidates = showFavoritesOnly ? files.filter(\.isFavorite) : files
        guard !searchText.isEmpty else {
            return candidates.map { SidebarMatch(file: $0, snippet: nil) }
        }
        return candidates.compactMap { file in
            if file.name.localizedCaseInsensitiveContains(searchText) {
                return SidebarMatch(file: file, snippet: nil)
            }
            return contentIndex.snippet(in: file.path, matching: searchText).map { SidebarMatch(file: file, snippet: $0) }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Picker("Filter", selection: $showFavoritesOnly) {
                    Text("All").tag(false)
                    Text("Favorites").tag(true)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                Toggle(isOn: $groupByProject) {
                    Label("Group by Project", systemImage: "rectangle.3.group")
                        .labelStyle(.iconOnly)
                }
                .toggleStyle(.button)
                .help("Group by Project")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            List(selection: listSelection) {
                if groupByProject {
                    ForEach(projectLocator.group(matches, path: \.file.path)) { group in
                        Section(group.name) {
                            ForEach(group.items, content: row)
                        }
                    }
                } else {
                    ForEach(matches, content: row)
                }
            }
            .contextMenu(forSelectionType: String.self) { paths in
                menu(for: paths)
            }
            .onDeleteCommand {
                remove(visibleFiles(in: selection))
            }
        }
        .searchable(text: $searchText, placement: .sidebar, prompt: "Search names and text")
        .navigationSplitViewColumnWidth(min: 200, ideal: 250)
        .onChange(of: selectedFilePath, initial: true) {
            selection = selectedFilePath.map { Set([$0]) } ?? []
        }
    }

    private var listSelection: Binding<Set<String>> {
        Binding(
            get: { selection },
            set: { newSelection in
                selection = newSelection
                if newSelection.count == 1, let path = newSelection.first {
                    selectedFilePath = path
                }
            }
        )
    }

    private func row(_ match: SidebarMatch) -> some View {
        let file = match.file
        return FileRow(file: file, snippet: match.snippet, onToggleFavorite: { onToggleFavorite(file.path) })
            .tag(file.path)
    }

    @ViewBuilder
    private func menu(for paths: Set<String>) -> some View {
        let targets = visibleFiles(in: paths)
        if targets.count == 1, let file = targets.first {
            Button("Reveal in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: file.path)])
            }
            .disabled(!file.exists)
            Button("Copy Path") {
                RichClipboard.copy(text: file.path)
            }
            Divider()
            Button("Remove from List", role: .destructive) {
                remove(targets)
            }
        } else if targets.count > 1 {
            Button("Remove \(targets.count) Files from List", role: .destructive) {
                remove(targets)
            }
        }
    }

    private func visibleFiles(in paths: Set<String>) -> [CachedFile] {
        matches.filter { paths.contains($0.file.path) }.map(\.file)
    }

    private func remove(_ targets: [CachedFile]) {
        let paths = Set(targets.map(\.path))
        onRemove(paths)
        selection.subtract(paths)
    }
}

struct SidebarMatch: Identifiable {
    let file: CachedFile
    let snippet: String?
    var id: String { file.id }
}

struct FileRow: View {
    let file: CachedFile
    var snippet: String?
    var onToggleFavorite: () -> Void

    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Image(systemName: file.exists ? "doc.text" : "doc.text.fill")
                    .foregroundStyle(file.exists ? Color.primary : Color.red)
                Text(file.name)
                    .lineLimit(1)
                Spacer()
                if file.isFavorite || isHovering {
                    Button {
                        onToggleFavorite()
                    } label: {
                        Image(systemName: file.isFavorite ? "star.fill" : "star")
                            .foregroundStyle(file.isFavorite ? .yellow : .secondary)
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                }
            }
            Text("\(file.displayDirectory) · \(file.lastOpened, format: .relative(presentation: .named))")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            if let snippet {
                Text(snippet)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 2)
        .help(file.path)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}
