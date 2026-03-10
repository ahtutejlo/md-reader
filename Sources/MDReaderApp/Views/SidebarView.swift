import SwiftUI

struct SidebarView: View {
    let files: [CachedFile]
    @Binding var selectedFilePath: String?
    var onRemove: (CachedFile) -> Void

    @State private var searchText = ""

    private var filteredFiles: [CachedFile] {
        if searchText.isEmpty { return files }
        return files.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        List(filteredFiles, selection: $selectedFilePath) { file in
            FileRow(file: file)
                .contextMenu {
                    Button("Remove from List", role: .destructive) {
                        onRemove(file)
                    }
                }
        }
        .searchable(text: $searchText, prompt: "Search files")
        .navigationSplitViewColumnWidth(min: 200, ideal: 250)
    }
}

struct FileRow: View {
    let file: CachedFile

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Image(systemName: file.exists ? "doc.text" : "doc.text.fill")
                    .foregroundStyle(file.exists ? Color.primary : Color.red)
                Text(file.name)
                    .lineLimit(1)
            }
            Text(file.lastOpened, style: .relative)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
