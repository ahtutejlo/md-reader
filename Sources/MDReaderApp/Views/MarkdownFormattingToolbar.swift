import SwiftUI

struct MarkdownFormattingToolbar: View {
    @Bindable var viewModel: EditorViewModel

    var body: some View {
        HStack(spacing: 2) {
            Button {
                viewModel.pendingFormat = .bold
            } label: {
                Image(systemName: "bold")
            }
            .help("Bold (⌘B)")

            Button {
                viewModel.pendingFormat = .italic
            } label: {
                Image(systemName: "italic")
            }
            .help("Italic (⌘I)")

            Button {
                viewModel.pendingFormat = .link
            } label: {
                Image(systemName: "link")
            }
            .help("Link (⌘K)")

            Button {
                viewModel.pendingFormat = .code
            } label: {
                Image(systemName: "chevron.left.forwardslash.chevron.right")
            }
            .help("Inline code (⌘E)")

            Divider().frame(height: 16)

            Menu {
                Button("Heading 1") { viewModel.pendingFormat = .heading(level: 1) }
                Button("Heading 2") { viewModel.pendingFormat = .heading(level: 2) }
                Button("Heading 3") { viewModel.pendingFormat = .heading(level: 3) }
            } label: {
                Image(systemName: "textformat.size")
            }
            .help("Heading")

            Button {
                viewModel.pendingFormat = .unorderedList
            } label: {
                Image(systemName: "list.bullet")
            }
            .help("Bulleted list")

            Button {
                viewModel.pendingFormat = .orderedList
            } label: {
                Image(systemName: "list.number")
            }
            .help("Numbered list")

            Button {
                viewModel.pendingFormat = .quote
            } label: {
                Image(systemName: "text.quote")
            }
            .help("Quote")
        }
    }
}
