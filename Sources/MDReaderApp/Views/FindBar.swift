import AppKit
import SwiftUI

struct FindBar: View {
    @Bindable var viewModel: EditorViewModel
    @State private var query = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Find in document", text: $query)
                .textFieldStyle(.plain)
                .focused($isFocused)
                .onSubmit { search(backwards: NSEvent.modifierFlags.contains(.shift)) }
                .onExitCommand(perform: close)
            if !query.isEmpty && !viewModel.findMatched {
                Text("Not found")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Button { search(backwards: true) } label: { Image(systemName: "chevron.up") }
                .help("Previous match (⇧↩)")
            Button { search(backwards: false) } label: { Image(systemName: "chevron.down") }
                .help("Next match (↩)")
            Button("Done", action: close)
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: 440)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.separator))
        .padding(12)
        .onAppear { isFocused = true }
        .onChange(of: query) { search(backwards: false, restart: true) }
    }

    private func search(backwards: Bool, restart: Bool = false) {
        viewModel.preview?.find(query, backwards: backwards, restart: restart)
    }

    private func close() {
        if !query.isEmpty {
            viewModel.preview?.find("", backwards: false, restart: false)
        }
        viewModel.isFindVisible = false
    }
}
