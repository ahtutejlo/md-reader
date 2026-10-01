import SwiftUI

struct QuickOpenView: View {
    let files: [CachedFile]
    var onOpen: (CachedFile) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [CachedFile] = []
    @State private var selection = 0
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            TextField("Open file by name", text: $query)
                .textFieldStyle(.plain)
                .font(.title3)
                .padding(14)
                .focused($isFocused)
                .onSubmit(openSelection)
                .onKeyPress(.downArrow) { move(1) }
                .onKeyPress(.upArrow) { move(-1) }
                .onExitCommand { dismiss() }
            Divider()
            ScrollViewReader { proxy in
                List(Array(results.enumerated()), id: \.element.id) { index, file in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(file.name)
                        Text(file.displayPath)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .padding(.vertical, 2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .listRowBackground(index == selection ? Color.accentColor.opacity(0.25) : Color.clear)
                    .onTapGesture {
                        selection = index
                        openSelection()
                    }
                }
                .listStyle(.plain)
                .onChange(of: selection) { _, index in
                    if results.indices.contains(index) {
                        proxy.scrollTo(results[index].id)
                    }
                }
            }
        }
        .frame(width: 560, height: 400)
        .onAppear { isFocused = true }
        .onChange(of: query, initial: true) {
            results = Array(QuickOpenMatcher.rank(files, query: query).prefix(50))
            selection = 0
        }
    }

    private func move(_ step: Int) -> KeyPress.Result {
        guard !results.isEmpty else { return .handled }
        selection = min(max(selection + step, 0), results.count - 1)
        return .handled
    }

    private func openSelection() {
        guard results.indices.contains(selection) else { return }
        onOpen(results[selection])
        dismiss()
    }
}
