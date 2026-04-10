import SwiftUI
import UniformTypeIdentifiers

private let markdownExtensions: Set<String> = ["md", "markdown"]

@main
struct MDReaderApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
    @State private var fileCache = FileCache()
    @State private var selectedFilePath: String?
    @State private var viewModel = EditorViewModel()

    var body: some Scene {
        WindowGroup {
            NavigationSplitView {
                SidebarView(
                    files: fileCache.files,
                    selectedFilePath: $selectedFilePath,
                    onRemove: { fileCache.removeFile($0) },
                    onToggleFavorite: { fileCache.toggleFavorite(path: $0) }
                )
            } detail: {
                ContentView(
                    fileURL: selectedFilePath.map { URL(fileURLWithPath: $0) },
                    viewModel: viewModel
                )
            }
            .onOpenURL { url in
                let fileURL = URL(fileURLWithPath: url.path)
                openMarkdownFile(fileURL)
            }
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    if selectedFilePath != nil && viewModel.viewMode != .preview {
                        MarkdownFormattingToolbar(viewModel: viewModel)
                    }
                }
                ToolbarItem {
                    Picker("View Mode", selection: $viewModel.viewMode) {
                        ForEach(ViewMode.allCases, id: \.self) { mode in
                            Image(systemName: mode.icon)
                                .help(mode.label)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 120)
                }
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
            .navigationTitle(windowTitle)
            .handlesExternalEvents(preferring: ["*"], allowing: ["*"])
        }
        .handlesExternalEvents(matching: ["*"])
        .commands {
            CommandGroup(replacing: .saveItem) {
                Button("Save") {
                    viewModel.save()
                }
                .keyboardShortcut("s", modifiers: .command)
                .disabled(!viewModel.hasUnsavedChanges)
            }
            CommandGroup(after: .textFormatting) {
                Button("Bold") { viewModel.pendingFormat = .bold }
                    .keyboardShortcut("b", modifiers: .command)
                    .disabled(selectedFilePath == nil || viewModel.viewMode == .preview)
                Button("Italic") { viewModel.pendingFormat = .italic }
                    .keyboardShortcut("i", modifiers: .command)
                    .disabled(selectedFilePath == nil || viewModel.viewMode == .preview)
                Button("Link") { viewModel.pendingFormat = .link }
                    .keyboardShortcut("k", modifiers: .command)
                    .disabled(selectedFilePath == nil || viewModel.viewMode == .preview)
                Button("Inline Code") { viewModel.pendingFormat = .code }
                    .keyboardShortcut("e", modifiers: .command)
                    .disabled(selectedFilePath == nil || viewModel.viewMode == .preview)
                Divider()
                Button("Heading 1") { viewModel.pendingFormat = .heading(level: 1) }
                    .keyboardShortcut("1", modifiers: [.command, .shift])
                    .disabled(selectedFilePath == nil || viewModel.viewMode == .preview)
                Button("Heading 2") { viewModel.pendingFormat = .heading(level: 2) }
                    .keyboardShortcut("2", modifiers: [.command, .shift])
                    .disabled(selectedFilePath == nil || viewModel.viewMode == .preview)
                Button("Heading 3") { viewModel.pendingFormat = .heading(level: 3) }
                    .keyboardShortcut("3", modifiers: [.command, .shift])
                    .disabled(selectedFilePath == nil || viewModel.viewMode == .preview)
                Divider()
                Button("Bulleted List") { viewModel.pendingFormat = .unorderedList }
                    .keyboardShortcut("8", modifiers: [.command, .shift])
                    .disabled(selectedFilePath == nil || viewModel.viewMode == .preview)
                Button("Numbered List") { viewModel.pendingFormat = .orderedList }
                    .keyboardShortcut("7", modifiers: [.command, .shift])
                    .disabled(selectedFilePath == nil || viewModel.viewMode == .preview)
                Button("Quote") { viewModel.pendingFormat = .quote }
                    .keyboardShortcut("'", modifiers: [.command, .shift])
                    .disabled(selectedFilePath == nil || viewModel.viewMode == .preview)
            }
            CommandGroup(after: .sidebar) {
                Button("Toggle Favorite") {
                    if let path = selectedFilePath {
                        fileCache.toggleFavorite(path: path)
                    }
                }
                .keyboardShortcut("d", modifiers: [.command, .shift])
                .disabled(selectedFilePath == nil)
            }
        }
    }

    private var windowTitle: String {
        guard let path = selectedFilePath else { return "MDReader" }
        let name = URL(fileURLWithPath: path).lastPathComponent
        return viewModel.hasUnsavedChanges ? "\(name) — Edited" : name
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
