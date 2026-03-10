import SwiftUI
import UniformTypeIdentifiers

private let markdownExtensions: Set<String> = ["md", "markdown"]

@main
struct MDReaderApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
    @State private var fileCache = FileCache()
    @State private var selectedFilePath: String?

    var body: some Scene {
        WindowGroup {
            NavigationSplitView {
                SidebarView(
                    files: fileCache.files,
                    selectedFilePath: $selectedFilePath,
                    onRemove: { fileCache.removeFile($0) }
                )
            } detail: {
                ContentView(fileURL: selectedFilePath.map { URL(fileURLWithPath: $0) })
            }
            .onOpenURL { url in
                let fileURL = URL(fileURLWithPath: url.path)
                openMarkdownFile(fileURL)
            }
            .toolbar {
                ToolbarItem {
                    Button {
                        openFilePanel()
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                for provider in providers {
                    _ = provider.loadObject(ofClass: URL.self) { url, _ in
                        if let url, markdownExtensions.contains(url.pathExtension) {
                            DispatchQueue.main.async {
                                openMarkdownFile(url)
                            }
                        }
                    }
                }
                return true
            }
            .frame(minWidth: 700, minHeight: 500)
        }
    }

    private func openMarkdownFile(_ url: URL) {
        fileCache.addFile(url: url)
        selectedFilePath = url.path
    }

    private func openFilePanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = markdownExtensions.compactMap { UTType(filenameExtension: $0) }
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            openMarkdownFile(url)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // When running as a bare executable (not a .app bundle), macOS may not
        // activate the app automatically. Force it to become a regular GUI app.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        // Set the Dock icon from the bundled .icns resource
        if let iconURL = Bundle.module.url(forResource: "AppIcon", withExtension: "icns"),
           let icon = NSImage(contentsOf: iconURL) {
            NSApp.applicationIconImage = icon
        }
    }
}
