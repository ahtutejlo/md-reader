import SwiftUI

struct SidebarView: View {
    let files: [CachedFile]
    @Binding var selectedFilePath: String?
    var onRemove: (CachedFile) -> Void
    var onToggleFavorite: (String) -> Void

    @State private var searchText = ""
    @State private var showFavoritesOnly = false

    private var filteredFiles: [CachedFile] {
        var result = files
        if showFavoritesOnly {
            result = result.filter { $0.isFavorite }
        }
        if !searchText.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        return result
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Filter", selection: $showFavoritesOnly) {
                Text("All").tag(false)
                Text("Favorites").tag(true)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            List(filteredFiles, selection: $selectedFilePath) { file in
                FileRow(file: file, onToggleFavorite: { onToggleFavorite(file.path) })
                    .contextMenu {
                        Button("Remove from List", role: .destructive) {
                            onRemove(file)
                        }
                    }
            }
        }
        .searchable(text: $searchText, prompt: "Search files")
        .navigationSplitViewColumnWidth(min: 200, ideal: 250)
    }
}

struct FileRow: View {
    let file: CachedFile
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
            Text(file.lastOpened, style: .relative)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}
