import AppKit

/// Markdown goes on the clipboard as HTML for apps that paste formatting and as the
/// source for plain-text targets.
enum RichClipboard {
    static func copy(text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    static func copy(markdown: String) {
        let html = "<meta charset=\"utf-8\">" + MarkdownRenderer.renderHTML(from: markdown)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(html, forType: .html)
        pasteboard.setString(markdown, forType: .string)
    }

    static func section(of text: String, from start: Int, to end: Int?) -> String {
        let lines = text.components(separatedBy: "\n")
        guard lines.indices.contains(start) else { return "" }
        let stop = min(max(end ?? lines.count, start), lines.count)
        return lines[start..<stop].joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
