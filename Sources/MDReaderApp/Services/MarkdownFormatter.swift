import Foundation

enum MarkdownFormatAction: Equatable {
    case bold
    case italic
    case code
    case strikethrough
    case link
    case heading(level: Int)
    case unorderedList
    case orderedList
    case quote
    case codeBlock
}

struct FormattedResult: Equatable {
    let text: String
    let selection: NSRange
}

enum MarkdownFormatter {
    static func apply(_ action: MarkdownFormatAction,
                      to text: String,
                      selection: NSRange) -> FormattedResult {
        let ns = text as NSString
        guard selection.location >= 0,
              selection.location + selection.length <= ns.length else {
            return FormattedResult(text: text, selection: selection)
        }

        switch action {
        case .bold:
            return wrap(text, selection: selection, marker: "**")
        case .italic:
            return wrap(text, selection: selection, marker: "*")
        case .code:
            return wrap(text, selection: selection, marker: "`")
        case .strikethrough:
            return wrap(text, selection: selection, marker: "~~")
        case .link:
            return insertLink(text, selection: selection)
        case .heading(let level):
            return applyLinePrefix(
                text,
                selection: selection,
                prefix: String(repeating: "#", count: level) + " ",
                matchAny: { line in
                    guard let match = line.range(of: #"^#{1,6} "#, options: .regularExpression) else { return nil }
                    return (line as NSString).substring(with: NSRange(match, in: line))
                }
            )
        case .unorderedList:
            return applyLinePrefix(
                text,
                selection: selection,
                prefix: "- ",
                matchAny: { _ in nil }
            )
        case .quote:
            return applyLinePrefix(
                text,
                selection: selection,
                prefix: "> ",
                matchAny: { _ in nil }
            )
        case .orderedList:
            return applyOrderedList(text, selection: selection)
        case .codeBlock:
            return wrapCodeBlock(text, selection: selection)
        }
    }

    // MARK: - Wrap helpers

    private static func wrap(_ text: String, selection: NSRange, marker: String) -> FormattedResult {
        let ns = text as NSString
        if isWrapped(ns, selection: selection, marker: marker) {
            let markerLen = (marker as NSString).length
            let newText = ns.replacingCharacters(
                in: NSRange(location: selection.location - markerLen,
                            length: selection.length + 2 * markerLen),
                with: ns.substring(with: selection)
            )
            return FormattedResult(
                text: newText,
                selection: NSRange(location: selection.location - markerLen, length: selection.length)
            )
        }
        let selected = ns.substring(with: selection)
        let replacement = "\(marker)\(selected)\(marker)"
        let newText = ns.replacingCharacters(in: selection, with: replacement)
        let markerLen = (marker as NSString).length
        return FormattedResult(
            text: newText,
            selection: NSRange(location: selection.location + markerLen, length: selection.length)
        )
    }

    private static func isWrapped(_ ns: NSString, selection: NSRange, marker: String) -> Bool {
        let markerLen = (marker as NSString).length
        guard selection.location >= markerLen,
              selection.location + selection.length + markerLen <= ns.length else {
            return false
        }
        let before = ns.substring(with: NSRange(location: selection.location - markerLen, length: markerLen))
        let after = ns.substring(with: NSRange(location: selection.location + selection.length, length: markerLen))
        return before == marker && after == marker
    }

    // MARK: - Link helper

    private static func insertLink(_ text: String, selection: NSRange) -> FormattedResult {
        let ns = text as NSString
        let selected = ns.substring(with: selection)
        if selected.isEmpty {
            let replacement = "[](url)"
            let newText = ns.replacingCharacters(in: selection, with: replacement)
            return FormattedResult(
                text: newText,
                selection: NSRange(location: selection.location + 1, length: 0)
            )
        }
        let replacement = "[\(selected)](url)"
        let newText = ns.replacingCharacters(in: selection, with: replacement)
        let urlStart = selection.location + 1 + (selected as NSString).length + 2  // "[" + text + "]("
        return FormattedResult(
            text: newText,
            selection: NSRange(location: urlStart, length: 3)  // "url"
        )
    }

    // MARK: - Line prefix helper

    /// Applies a line prefix to every line that the selection intersects.
    /// Behavior rules:
    ///   • If every selected line already starts with `prefix` → remove it (toggle off).
    ///   • Else if `matchAny` returns a different existing prefix for a line → replace it.
    ///   • Else → prepend `prefix` to the line.
    private static func applyLinePrefix(
        _ text: String,
        selection: NSRange,
        prefix: String,
        matchAny: (String) -> String?
    ) -> FormattedResult {
        let ns = text as NSString
        let lineRange = ns.lineRange(for: selection)
        let block = ns.substring(with: lineRange)
        let hadTrailingNewline = block.hasSuffix("\n")
        let body = hadTrailingNewline ? String(block.dropLast()) : block
        let lines = body.components(separatedBy: "\n")

        let allHavePrefix = !lines.isEmpty && lines.allSatisfy { $0.hasPrefix(prefix) }

        let newLines: [String]
        if allHavePrefix {
            newLines = lines.map { String($0.dropFirst(prefix.count)) }
        } else {
            newLines = lines.map { line -> String in
                if let existing = matchAny(line) {
                    return prefix + String(line.dropFirst(existing.count))
                }
                return prefix + line
            }
        }

        let joined = newLines.joined(separator: "\n") + (hadTrailingNewline ? "\n" : "")
        let newText = ns.replacingCharacters(in: lineRange, with: joined)

        // Cursor math: the cursor sits inside the first selected line, so shift its
        // location by the delta applied to that first line. Any extra delta on
        // following lines lands in the trailing length.
        let firstLineDelta = (newLines.first.map { ($0 as NSString).length } ?? 0)
                           - (lines.first.map { ($0 as NSString).length } ?? 0)
        let totalDelta = (joined as NSString).length - (block as NSString).length
        let newLocation = max(0, selection.location + firstLineDelta)
        let newLength = max(0, selection.length + (totalDelta - firstLineDelta))

        return FormattedResult(
            text: newText,
            selection: NSRange(location: newLocation, length: newLength)
        )
    }

    // MARK: - Ordered list helper

    private static func applyOrderedList(_ text: String, selection: NSRange) -> FormattedResult {
        let ns = text as NSString
        let lineRange = ns.lineRange(for: selection)
        let block = ns.substring(with: lineRange)
        let hasTrailingNewline = block.hasSuffix("\n")
        let rawLines = hasTrailingNewline
            ? Array(block.split(separator: "\n", omittingEmptySubsequences: false).dropLast())
            : block.split(separator: "\n", omittingEmptySubsequences: false).map { $0 }
        let lines = rawLines.map(String.init)

        // Toggle off if every line starts with "<n>. "
        let numberedRE = #"^\d+\. "#
        let allNumbered = !lines.isEmpty && lines.allSatisfy {
            $0.range(of: numberedRE, options: .regularExpression) != nil
        }

        let newLines: [String]
        if allNumbered {
            newLines = lines.map { line in
                guard let range = line.range(of: numberedRE, options: .regularExpression) else { return line }
                return String(line[range.upperBound...])
            }
        } else {
            newLines = lines.enumerated().map { idx, line in "\(idx + 1). \(line)" }
        }

        let joined = newLines.joined(separator: "\n") + (hasTrailingNewline ? "\n" : "")
        let newText = ns.replacingCharacters(in: lineRange, with: joined)
        let delta = (joined as NSString).length - (block as NSString).length
        return FormattedResult(
            text: newText,
            selection: NSRange(location: selection.location, length: max(0, selection.length + delta))
        )
    }

    // MARK: - Code block helper

    private static func wrapCodeBlock(_ text: String, selection: NSRange) -> FormattedResult {
        // codeBlock intentionally does not toggle — a second apply produces nested fences.
        let ns = text as NSString
        let lineRange = ns.lineRange(for: selection)
        var block = ns.substring(with: lineRange)
        let hadTrailingNewline = block.hasSuffix("\n")
        if hadTrailingNewline { block = String(block.dropLast()) }
        let replacement = "```\n\(block)\n```" + (hadTrailingNewline ? "\n" : "")
        let newText = ns.replacingCharacters(in: lineRange, with: replacement)
        return FormattedResult(
            text: newText,
            selection: NSRange(location: selection.location + 4, length: selection.length)  // past "```\n"
        )
    }
}
