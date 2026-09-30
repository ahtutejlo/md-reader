import Foundation
import Markdown

enum MarkdownRenderer {

    /// Converts markdown source to HTML. Block elements carry a 0-based `data-line`
    /// source line so the preview can scroll in sync with the editor. Relative image
    /// paths resolve against `baseDirectory`, the folder of the file being shown.
    static func renderHTML(from source: String, baseDirectory: URL? = nil) -> String {
        let document = Document(parsing: source, options: [.disableSmartOpts])
        var walker = HTMLWalker(sourceLines: source.components(separatedBy: "\n"), baseDirectory: baseDirectory)
        walker.visit(document)
        return walker.result
    }
}

private struct HTMLWalker: MarkupWalker {
    let sourceLines: [String]
    let baseDirectory: URL?
    var result = ""
    var tightLists: [Bool] = []
    var columnAlignments: [Table.ColumnAlignment?] = []
    var inLink = false
    var usedSlugs: Set<String> = []

    mutating func visitHeading(_ heading: Heading) {
        let id = uniqueSlug(for: heading.plainText)
        let idAttr = id.isEmpty ? "" : " id=\"\(escapeHTML(id))\""
        wrap(heading, "<h\(heading.level)\(idAttr)\(lineAttr(heading))>", "</h\(heading.level)>\n")
    }

    mutating func visitParagraph(_ paragraph: Paragraph) {
        if paragraph.parent is ListItem, tightLists.last == true {
            descendInto(paragraph)
            if paragraph.indexInParent < (paragraph.parent?.childCount ?? 0) - 1 {
                result += "\n"
            }
            return
        }
        wrap(paragraph, "<p\(lineAttr(paragraph))>", "</p>\n")
    }

    mutating func visitBlockQuote(_ blockQuote: BlockQuote) {
        wrap(blockQuote, "<blockquote\(lineAttr(blockQuote))>\n", "</blockquote>\n")
    }

    mutating func visitCodeBlock(_ codeBlock: CodeBlock) {
        let language = codeBlock.language?.split(separator: " ").first.map(String.init) ?? ""
        let langAttr = language.isEmpty ? "" : " class=\"language-\(escapeHTML(language))\""
        var code = codeBlock.code
        if code.hasSuffix("\n") { code.removeLast() }
        result += "<pre\(lineAttr(codeBlock))><code\(langAttr)>\(escapeHTML(code))</code></pre>\n"
    }

    mutating func visitThematicBreak(_ thematicBreak: ThematicBreak) {
        result += "<hr\(lineAttr(thematicBreak))>\n"
    }

    mutating func visitHTMLBlock(_ html: HTMLBlock) {
        var raw = html.rawHTML
        if raw.hasSuffix("\n") { raw.removeLast() }
        result += "<p\(lineAttr(html))>\(escapeHTML(raw))</p>\n"
    }

    mutating func visitUnorderedList(_ list: UnorderedList) {
        let hasTasks = list.listItems.contains { taskCheckbox($0) != nil }
        renderList(list, tag: "ul", attrs: hasTasks ? " class=\"contains-task-list\"" : "")
    }

    mutating func visitOrderedList(_ list: OrderedList) {
        renderList(list, tag: "ol", attrs: list.startIndex == 1 ? "" : " start=\"\(list.startIndex)\"")
    }

    mutating func visitListItem(_ item: ListItem) {
        guard let checkbox = taskCheckbox(item) else {
            wrap(item, "<li>", "</li>\n")
            return
        }
        let checked = checkbox == .checked
        result += "<li class=\"task-list-item\(checked ? " checked" : "")\"\(lineAttr(item, name: "data-md-line"))>"
        result += "<input type=\"checkbox\" disabled\(checked ? " checked" : "")>"
        if item.checkbox != nil {
            descendInto(item)
        }
        result += "</li>\n"
    }

    mutating func visitTable(_ table: Table) {
        columnAlignments = table.columnAlignments
        wrap(table, "<table\(lineAttr(table))>", "</table>\n")
    }

    mutating func visitTableHead(_ head: Table.Head) {
        wrap(head, "<thead><tr>\n", "</tr></thead>")
    }

    mutating func visitTableBody(_ body: Table.Body) {
        wrap(body, "<tbody>\n", "</tbody>")
    }

    mutating func visitTableRow(_ row: Table.Row) {
        wrap(row, "<tr>\n", "</tr>\n")
    }

    mutating func visitTableCell(_ cell: Table.Cell) {
        let tag = cell.parent is Table.Head ? "th" : "td"
        let column = cell.indexInParent
        let alignment = columnAlignments.indices.contains(column) ? columnAlignments[column] : nil
        let style = alignment.map { " style=\"text-align:\(cssAlignment($0))\"" } ?? ""
        wrap(cell, "<\(tag)\(style)>", "</\(tag)>\n")
    }

    mutating func visitText(_ text: Text) {
        result += inLink ? escapeHTML(text.string) : autolinked(text.string)
    }

    mutating func visitInlineCode(_ code: InlineCode) {
        result += "<code>\(escapeHTML(code.code))</code>"
    }

    mutating func visitEmphasis(_ emphasis: Emphasis) {
        wrap(emphasis, "<em>", "</em>")
    }

    mutating func visitStrong(_ strong: Strong) {
        wrap(strong, "<strong>", "</strong>")
    }

    /// cmark-gfm also strikes through `~single~` tildes, which turns "~25M … ~7M"
    /// into struck text; only `~~double~~` counts here.
    mutating func visitStrikethrough(_ strikethrough: Strikethrough) {
        let (open, close) = opensWithDoubleTilde(strikethrough) ? ("<del>", "</del>") : ("~", "~")
        wrap(strikethrough, open, close)
    }

    mutating func visitLink(_ link: Link) {
        let destination = link.destination ?? ""
        let open = isScriptURL(destination) ? "<a>" : "<a href=\"\(escapeHTML(destination))\">"
        inLink = true
        wrap(link, open, "</a>")
        inLink = false
    }

    mutating func visitImage(_ image: Image) {
        let source = image.source ?? ""
        let resolved = LinkRouter.fileURL(for: source, relativeTo: baseDirectory)
            .flatMap(LocalAssetSchemeHandler.url(for:))?.absoluteString ?? source
        result += "<img src=\"\(escapeHTML(resolved))\" alt=\"\(escapeHTML(image.plainText))\">"
    }

    mutating func visitInlineHTML(_ html: InlineHTML) {
        result += escapeHTML(html.rawHTML)
    }

    mutating func visitSoftBreak(_ softBreak: SoftBreak) {
        result += "\n"
    }

    mutating func visitLineBreak(_ lineBreak: LineBreak) {
        result += "<br>\n"
    }

    private mutating func wrap(_ markup: Markup, _ open: String, _ close: String) {
        result += open
        descendInto(markup)
        result += close
    }

    private mutating func renderList(_ list: Markup, tag: String, attrs: String) {
        tightLists.append(isTight(list))
        wrap(list, "<\(tag)\(attrs)\(lineAttr(list))>\n", "</\(tag)>\n")
        tightLists.removeLast()
    }

    /// cmark-gfm needs text after the marker; a bare `- [ ]` still renders as an
    /// empty task so a freshly typed item shows its checkbox.
    private func taskCheckbox(_ item: ListItem) -> Checkbox? {
        if let checkbox = item.checkbox { return checkbox }
        guard item.childCount == 1,
              let start = (item.child(at: 0) as? Paragraph)?.range?.lowerBound,
              sourceLines.indices.contains(start.line - 1) else { return nil }
        let rest = String(decoding: sourceLines[start.line - 1].utf8.dropFirst(start.column - 1), as: UTF8.self)
        switch rest.trimmingCharacters(in: .whitespaces) {
        case "[ ]": return .unchecked
        case "[x]", "[X]": return .checked
        default: return nil
        }
    }

    /// GitHub-style heading anchor: lowercase, spaces become hyphens, punctuation is
    /// dropped, letters of any script are kept; repeats get `-1`, `-2`, ...
    private mutating func uniqueSlug(for text: String) -> String {
        var slug = ""
        for scalar in text.lowercased().unicodeScalars {
            if scalar == " " {
                slug += "-"
            } else if CharacterSet.alphanumerics.contains(scalar) || scalar == "-" || scalar == "_" {
                slug.unicodeScalars.append(scalar)
            }
        }
        guard slug.unicodeScalars.contains(where: CharacterSet.alphanumerics.contains) else { return "" }
        var unique = slug
        var suffix = 0
        while !usedSlugs.insert(unique).inserted {
            suffix += 1
            unique = "\(slug)-\(suffix)"
        }
        return unique
    }

    private static let ignoredInScheme = CharacterSet.whitespacesAndNewlines.union(.controlCharacters)

    private func isScriptURL(_ destination: String) -> Bool {
        let compact = destination.components(separatedBy: Self.ignoredInScheme).joined().lowercased()
        return ["javascript:", "vbscript:", "data:"].contains { compact.hasPrefix($0) }
    }

    private func lineAttr(_ markup: Markup, name: String = "data-line") -> String {
        guard let line = markup.range?.lowerBound.line else { return "" }
        return " \(name)=\"\(line - 1)\""
    }

    /// swift-markdown does not expose list tightness, so it is derived from the
    /// source: a blank line between items, or between blocks of one item, makes
    /// the list loose.
    private func isTight(_ list: Markup) -> Bool {
        !list.children.dropFirst().contains(where: hasBlankLineBefore)
            && !list.children.contains { $0.children.dropFirst().contains(where: hasBlankLineBefore) }
    }

    private func hasBlankLineBefore(_ markup: Markup) -> Bool {
        guard let line = markup.range?.lowerBound.line else { return false }
        let index = line - 2
        return sourceLines.indices.contains(index)
            && sourceLines[index].trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// Compares the marker's start with its content's start rather than reading
    /// source bytes: on lazy continuation lines cmark reports columns relative to
    /// the enclosing list item or quote.
    private func opensWithDoubleTilde(_ strikethrough: Strikethrough) -> Bool {
        guard let start = strikethrough.range?.lowerBound,
              let contentStart = strikethrough.child(at: 0)?.range?.lowerBound,
              contentStart.line == start.line else { return false }
        return contentStart.column - start.column == 2
    }

    private func cssAlignment(_ alignment: Table.ColumnAlignment) -> String {
        switch alignment {
        case .left: "left"
        case .center: "center"
        case .right: "right"
        }
    }

    private static let urlPattern = try! NSRegularExpression(pattern: #"https?://[^\s<>"'`]+"#)

    private func autolinked(_ raw: String) -> String {
        let ns = raw as NSString
        var output = ""
        var cursor = 0
        for match in Self.urlPattern.matches(in: raw, range: NSRange(location: 0, length: ns.length)) {
            var url = ns.substring(with: match.range)
            while let last = url.last, ".,;:!?)]".contains(last) {
                if last == ")", url.filter({ $0 == "(" }).count >= url.filter({ $0 == ")" }).count { break }
                url.removeLast()
            }
            output += escapeHTML(ns.substring(with: NSRange(location: cursor, length: match.range.location - cursor)))
            output += "<a href=\"\(escapeHTML(url))\">\(escapeHTML(url))</a>"
            cursor = match.range.location + (url as NSString).length
        }
        output += escapeHTML(ns.substring(from: cursor))
        return output
    }

    private func escapeHTML(_ text: String) -> String {
        guard text.utf8.contains(where: { "&<>\"".utf8.contains($0) }) else { return text }
        var escaped = ""
        escaped.reserveCapacity(text.utf8.count + 16)
        for scalar in text.unicodeScalars {
            switch scalar {
            case "&": escaped += "&amp;"
            case "<": escaped += "&lt;"
            case ">": escaped += "&gt;"
            case "\"": escaped += "&quot;"
            default: escaped.unicodeScalars.append(scalar)
            }
        }
        return escaped
    }
}
