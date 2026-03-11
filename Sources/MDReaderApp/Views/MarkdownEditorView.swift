import SwiftUI
import AppKit

struct MarkdownEditorView: NSViewRepresentable {
    @Bindable var viewModel: EditorViewModel

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView

        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.font = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        textView.textColor = .labelColor
        textView.backgroundColor = .textBackgroundColor
        textView.insertionPointColor = .labelColor
        textView.textContainerInset = NSSize(width: 16, height: 16)
        textView.delegate = context.coordinator
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true

        context.coordinator.textView = textView

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let textView = scrollView.documentView as! NSTextView
        // Use version counter to avoid O(n) string comparison on every SwiftUI render.
        // textVersion increments only on external text changes (loadFile, reloadFromDisk, clearFile).
        // User typing updates viewModel.text but not textVersion, so we skip the NSView update —
        // the NSTextView already has the correct content and highlighting is handled by textDidChange.
        guard context.coordinator.lastTextVersion != viewModel.textVersion else { return }
        context.coordinator.lastTextVersion = viewModel.textVersion
        context.coordinator.isUpdating = true
        textView.string = viewModel.text
        context.coordinator.applyHighlighting()
        context.coordinator.isUpdating = false
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var viewModel: EditorViewModel
        weak var textView: NSTextView?
        var isUpdating = false
        var lastTextVersion: Int = -1
        private var highlightWorkItem: DispatchWorkItem?

        init(viewModel: EditorViewModel) {
            self.viewModel = viewModel
        }

        func textDidChange(_ notification: Notification) {
            guard !isUpdating, let textView else { return }
            viewModel.text = textView.string
            viewModel.textDidChange()
            scheduleHighlighting()
        }

        func applyHighlighting() {
            guard let textView, let textStorage = textView.textStorage else { return }
            let highlighted = MarkdownSyntaxHighlighter.highlight(textView.string)
            let selectedRanges = textView.selectedRanges
            textStorage.beginEditing()
            textStorage.setAttributedString(highlighted)
            textStorage.endEditing()
            textView.selectedRanges = selectedRanges
        }

        private func scheduleHighlighting() {
            highlightWorkItem?.cancel()
            let item = DispatchWorkItem { [weak self] in
                self?.applyHighlighting()
            }
            highlightWorkItem = item
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: item)
        }
    }
}
