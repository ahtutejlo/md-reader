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

        // Consume any pending format command from the toolbar/menu before
        // checking the textVersion path. This runs whenever SwiftUI re-invokes
        // updateNSView and the view model has a queued action.
        if let action = viewModel.pendingFormat {
            let result = MarkdownFormatter.apply(
                action,
                to: textView.string,
                selection: textView.selectedRange()
            )
            context.coordinator.isUpdating = true
            textView.string = result.text
            textView.selectedRange = result.selection
            context.coordinator.applyHighlighting()
            context.coordinator.isUpdating = false
            viewModel.text = result.text
            viewModel.textDidChange()
            viewModel.pendingFormat = nil
            // Fall through to check textVersion in case an external reload happened simultaneously.
        }

        // Existing external-text update path. Skip O(n) string comparison via the version counter:
        // textVersion increments only on external text changes (loadFile, reloadFromDisk, clearFile).
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
        private var activeLineWorkItem: DispatchWorkItem?

        init(viewModel: EditorViewModel) {
            self.viewModel = viewModel
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard !isUpdating, let textView else { return }
            let location = textView.selectedRange().location
            let ns = textView.string as NSString
            let clamped = min(location, ns.length)
            let lineRange = ns.lineRange(for: NSRange(location: clamped, length: 0))
            // Count newlines before the start of the current line to get the 0-based line number.
            let prefix = ns.substring(with: NSRange(location: 0, length: lineRange.location))
            let count = prefix.components(separatedBy: "\n").count - 1
            activeLineWorkItem?.cancel()
            let item = DispatchWorkItem { [weak self] in
                self?.viewModel.activeLine = count
            }
            activeLineWorkItem = item
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: item)
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
