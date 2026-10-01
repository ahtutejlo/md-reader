import SwiftUI
import UniformTypeIdentifiers

@main
struct MDReaderApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
    @State private var fileCache = FileCache()
    @State private var selectedFilePath: String?
    @State private var viewModel = EditorViewModel()
    @State private var showQuickOpen = false
    @AppStorage(Preferences.zoomKey) private var zoom = 1.0
    @AppStorage(Preferences.showOutlineKey) private var showOutline = true
    @AppStorage(Preferences.groupByProjectKey) private var groupByProject = true

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
                    viewModel: viewModel,
                    hooks: PreviewHooks(
                        openMarkdown: openMarkdownFile,
                        savedLine: { fileCache.lastLine(for: $0.path) },
                        saveLine: { fileCache.setLastLine($1, for: $0.path) }
                    )
                )
            }
            .background {
                Button("Zoom In") { setZoom(zoom + Preferences.zoomStep) }
                    .keyboardShortcut("=", modifiers: [.command, .shift])
                    .opacity(0)
                    .accessibilityHidden(true)
            }
            .sheet(isPresented: $showQuickOpen) {
                QuickOpenView(files: fileCache.files) { openMarkdownFile(URL(fileURLWithPath: $0.path)) }
            }
            .onOpenURL { url in
                let fileURL = URL(fileURLWithPath: url.path)
                openMarkdownFile(fileURL)
            }
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                fileCache.pruneMissingFiles(keeping: selectedFilePath)
            }
            .onChange(of: selectedFilePath) {
                fileCache.pruneMissingFiles(keeping: selectedFilePath)
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
                ToolbarItem {
                    Toggle(isOn: $showOutline) {
                        Label("Outline", systemImage: "list.bullet.indent")
                            .labelStyle(.iconOnly)
                    }
                    .help("Show Outline (⌥⌘0)")
                    .disabled(selectedFilePath == nil)
                }
            }
            .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                for provider in providers {
                    _ = provider.loadObject(ofClass: URL.self) { url, _ in
                        if let url, LinkRouter.markdownExtensions.contains(url.pathExtension) {
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
            CommandGroup(after: .newItem) {
                Button("Open Quickly…") { showQuickOpen = true }
                    .keyboardShortcut("p", modifiers: .command)
            }
            CommandGroup(replacing: .saveItem) {
                Button("Close") { closeFileOrWindow() }
                    .keyboardShortcut("w", modifiers: .command)
                Button("Save") {
                    viewModel.save()
                }
                .keyboardShortcut("s", modifiers: .command)
                .disabled(!viewModel.hasUnsavedChanges)
            }
            CommandGroup(after: .pasteboard) {
                Divider()
                Button("Copy Document") { RichClipboard.copy(markdown: viewModel.text) }
                    .keyboardShortcut("c", modifiers: [.command, .option])
                    .disabled(selectedFilePath == nil)
                Button("Find…") { showFind() }
                    .keyboardShortcut("f", modifiers: .command)
                    .disabled(selectedFilePath == nil)
            }
            CommandGroup(after: .textFormatting) {
                let formattingDisabled = selectedFilePath == nil || viewModel.viewMode == .preview
                Button("Bold") { viewModel.pendingFormat = .bold }
                    .keyboardShortcut("b", modifiers: .command)
                    .disabled(formattingDisabled)
                Button("Italic") { viewModel.pendingFormat = .italic }
                    .keyboardShortcut("i", modifiers: .command)
                    .disabled(formattingDisabled)
                Button("Link") { viewModel.pendingFormat = .link }
                    .keyboardShortcut("k", modifiers: .command)
                    .disabled(formattingDisabled)
                Button("Inline Code") { viewModel.pendingFormat = .code }
                    .keyboardShortcut("e", modifiers: .command)
                    .disabled(formattingDisabled)
                Divider()
                Button("Heading 1") { viewModel.pendingFormat = .heading(level: 1) }
                    .keyboardShortcut("1", modifiers: [.command, .shift])
                    .disabled(formattingDisabled)
                Button("Heading 2") { viewModel.pendingFormat = .heading(level: 2) }
                    .keyboardShortcut("2", modifiers: [.command, .shift])
                    .disabled(formattingDisabled)
                Button("Heading 3") { viewModel.pendingFormat = .heading(level: 3) }
                    .keyboardShortcut("3", modifiers: [.command, .shift])
                    .disabled(formattingDisabled)
                Divider()
                Button("Bulleted List") { viewModel.pendingFormat = .unorderedList }
                    .keyboardShortcut("8", modifiers: [.command, .shift])
                    .disabled(formattingDisabled)
                Button("Numbered List") { viewModel.pendingFormat = .orderedList }
                    .keyboardShortcut("7", modifiers: [.command, .shift])
                    .disabled(formattingDisabled)
                Button("Quote") { viewModel.pendingFormat = .quote }
                    .keyboardShortcut("'", modifiers: [.command, .shift])
                    .disabled(formattingDisabled)
            }
            CommandGroup(after: .sidebar) {
                Button("Toggle Favorite") {
                    if let path = selectedFilePath {
                        fileCache.toggleFavorite(path: path)
                    }
                }
                .keyboardShortcut("d", modifiers: [.command, .shift])
                .disabled(selectedFilePath == nil)
                Toggle("Show Outline", isOn: $showOutline)
                    .keyboardShortcut("0", modifiers: [.command, .option])
                Toggle("Group by Project", isOn: $groupByProject)
                Divider()
                Button("Zoom In") { setZoom(zoom + Preferences.zoomStep) }
                    .keyboardShortcut("=", modifiers: .command)
                Button("Zoom Out") { setZoom(zoom - Preferences.zoomStep) }
                    .keyboardShortcut("-", modifiers: .command)
                Button("Actual Size") { setZoom(1) }
                    .keyboardShortcut("0", modifiers: .command)
                    .disabled(zoom == 1)
            }
        }
    }

    private func closeFileOrWindow() {
        if selectedFilePath != nil {
            selectedFilePath = nil
        } else {
            NSApp.keyWindow?.performClose(nil)
        }
    }

    private func showFind() {
        if let textView = NSApp.keyWindow?.firstResponder as? NSTextView, textView.isEditable, !textView.isFieldEditor {
            let item = NSMenuItem()
            item.tag = NSTextFinder.Action.showFindInterface.rawValue
            textView.performFindPanelAction(item)
        } else if viewModel.viewMode != .editor {
            viewModel.isFindVisible = true
        }
    }

    private func setZoom(_ value: Double) {
        zoom = (min(max(value, Preferences.zoomRange.lowerBound), Preferences.zoomRange.upperBound) * 10).rounded() / 10
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
        panel.allowedContentTypes = LinkRouter.markdownExtensions.compactMap { UTType(filenameExtension: $0) }
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
