import SwiftUI

struct ContentView: View {
    let fileURL: URL?
    @Bindable var viewModel: EditorViewModel

    var body: some View {
        Group {
            if let _ = fileURL {
                switch viewModel.viewMode {
                case .editor:
                    MarkdownEditorView(viewModel: viewModel)

                case .split:
                    HSplitView {
                        MarkdownEditorView(viewModel: viewModel)
                            .frame(minWidth: 200)
                        MarkdownWebView(markdown: viewModel.text)
                            .frame(minWidth: 200)
                    }

                case .preview:
                    MarkdownWebView(markdown: viewModel.text)
                }
            } else {
                ContentUnavailableView(
                    "No File Selected",
                    systemImage: "doc.text",
                    description: Text("Select a file from the sidebar or open one via terminal:\nmdreader <path>")
                )
            }
        }
        .onChange(of: fileURL) { _, newURL in
            if let url = newURL {
                viewModel.loadFile(url: url)
            }
        }
        .task(id: fileURL) {
            if let url = fileURL {
                viewModel.loadFile(url: url)
            }
        }
        .alert("File Changed Externally", isPresented: $viewModel.showExternalChangeAlert) {
            Button("Reload", role: .destructive) {
                viewModel.reloadFromDisk()
            }
            Button("Ignore") {
                viewModel.dismissExternalChange()
            }
            Button("Save My Version") {
                viewModel.save()
                viewModel.dismissExternalChange()
            }
        } message: {
            Text("The file has been modified by another application. What would you like to do?")
        }
    }
}
