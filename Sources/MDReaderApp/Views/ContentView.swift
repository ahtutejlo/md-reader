import SwiftUI

struct ContentView: View {
    let fileURL: URL?

    @State private var markdownText: String?
    @State private var loadError = false

    var body: some View {
        Group {
            if let _ = fileURL {
                if let text = markdownText {
                    MarkdownWebView(markdown: text)
                } else if loadError {
                    ContentUnavailableView(
                        "Cannot Read File",
                        systemImage: "exclamationmark.triangle",
                        description: Text(fileURL?.path ?? "")
                    )
                }
            } else {
                ContentUnavailableView(
                    "No File Selected",
                    systemImage: "doc.text",
                    description: Text("Select a file from the sidebar or open one via terminal:\nmdreader <path>")
                )
            }
        }
        .task(id: fileURL) {
            guard let url = fileURL else {
                markdownText = nil
                loadError = false
                return
            }
            if let content = try? String(contentsOf: url, encoding: .utf8) {
                markdownText = content
                loadError = false
            } else {
                markdownText = nil
                loadError = true
            }
        }
    }
}
