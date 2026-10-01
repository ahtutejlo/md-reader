import SwiftUI

struct OutlineView: View {
    @Bindable var viewModel: EditorViewModel

    var body: some View {
        if viewModel.outline.isEmpty {
            ContentUnavailableView("No Headings", systemImage: "list.bullet.indent")
        } else {
            let topLevel = viewModel.outline.map(\.level).min() ?? 1
            ScrollViewReader { proxy in
                List(viewModel.outline) { item in
                    let isCurrent = item.id == viewModel.currentHeadingID
                    Button {
                        viewModel.preview?.scrollToAnchor(item.id)
                    } label: {
                        Text(item.title)
                            .lineLimit(2)
                            .fontWeight(item.level == topLevel || isCurrent ? .semibold : .regular)
                            .foregroundStyle(isCurrent ? Color.accentColor : item.level <= topLevel + 1 ? .primary : .secondary)
                            .padding(.leading, CGFloat(item.level - topLevel) * 12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .listRowSeparator(.hidden)
                    .help(item.title)
                }
                .onChange(of: viewModel.currentHeadingID) { _, id in
                    if let id {
                        proxy.scrollTo(id)
                    }
                }
            }
        }
    }
}
