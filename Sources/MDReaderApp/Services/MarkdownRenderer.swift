import Foundation

enum MarkdownRenderer {

    /// Converts markdown source to HTML using line-by-line parsing.
    /// Input is local file content — no untrusted user input.
    static func renderHTML(from source: String) -> String {
        let lines = source.components(separatedBy: "\n")
        var html: [String] = []
        var i = 0

        while i < lines.count {
            let line = lines[i]

            // Fenced code block
            if line.hasPrefix("```") {
                let blockStart = i
                let lang = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                var codeLines: [String] = []
                i += 1
                while i < lines.count && !lines[i].hasPrefix("```") {
                    codeLines.append(escapeHTML(lines[i]))
                    i += 1
                }
                let langAttr = lang.isEmpty ? "" : " class=\"language-\(escapeHTML(lang))\""
                html.append("<pre data-line=\"\(blockStart)\"><code\(langAttr)>\(codeLines.joined(separator: "\n"))</code></pre>")
                i += 1
                continue
            }

            // Headings (CommonMark requires a space after the hashes)
            if line.hasPrefix("###### ") {
                html.append("<h6 data-line=\"\(i)\">\(inlineMarkdown(String(line.dropFirst(7))))</h6>")
                i += 1; continue
            }
            if line.hasPrefix("##### ") {
                html.append("<h5 data-line=\"\(i)\">\(inlineMarkdown(String(line.dropFirst(6))))</h5>")
                i += 1; continue
            }
            if line.hasPrefix("#### ") {
                html.append("<h4 data-line=\"\(i)\">\(inlineMarkdown(String(line.dropFirst(5))))</h4>")
                i += 1; continue
            }
            if line.hasPrefix("### ") {
                html.append("<h3 data-line=\"\(i)\">\(inlineMarkdown(String(line.dropFirst(4))))</h3>")
                i += 1; continue
            }
            if line.hasPrefix("## ") {
                html.append("<h2 data-line=\"\(i)\">\(inlineMarkdown(String(line.dropFirst(3))))</h2>")
                i += 1; continue
            }
            if line.hasPrefix("# ") {
                html.append("<h1 data-line=\"\(i)\">\(inlineMarkdown(String(line.dropFirst(2))))</h1>")
                i += 1; continue
            }

            // Horizontal rule
            if line.trimmingCharacters(in: .whitespaces) == "---" ||
               line.trimmingCharacters(in: .whitespaces) == "***" ||
               line.trimmingCharacters(in: .whitespaces) == "___" {
                html.append("<hr data-line=\"\(i)\">")
                i += 1; continue
            }

            // Blockquote
            if line.hasPrefix(">") {
                let blockStart = i
                var quoteLines: [String] = []
                while i < lines.count && lines[i].hasPrefix(">") {
                    let content = String(lines[i].dropFirst(1)).trimmingCharacters(in: .init(charactersIn: " "))
                    quoteLines.append(inlineMarkdown(content))
                    i += 1
                }
                html.append("<blockquote data-line=\"\(blockStart)\"><p>\(quoteLines.joined(separator: "<br>"))</p></blockquote>")
                continue
            }

            // Unordered list
            if line.hasPrefix("- ") || line.hasPrefix("* ") {
                let blockStart = i
                html.append("<ul data-line=\"\(blockStart)\">")
                while i < lines.count && (lines[i].hasPrefix("- ") || lines[i].hasPrefix("* ")) {
                    let content = String(lines[i].dropFirst(2))
                    html.append("<li>\(inlineMarkdown(content))</li>")
                    i += 1
                }
                html.append("</ul>")
                continue
            }

            // Ordered list
            if let _ = line.range(of: #"^\d+\. "#, options: .regularExpression) {
                let blockStart = i
                html.append("<ol data-line=\"\(blockStart)\">")
                while i < lines.count, let range = lines[i].range(of: #"^\d+\. "#, options: .regularExpression) {
                    let content = String(lines[i][range.upperBound...])
                    html.append("<li>\(inlineMarkdown(content))</li>")
                    i += 1
                }
                html.append("</ol>")
                continue
            }

            // Table
            if isTableStart(lines: lines, at: i) {
                let blockStart = i
                let headers = parseTableRow(line)
                let colCount = headers.count
                let alignments = parseAlignments(lines[i + 1], count: colCount)
                i += 2
                html.append("<table data-line=\"\(blockStart)\"><thead><tr>")
                for (j, h) in headers.enumerated() {
                    let style = alignments[j].isEmpty ? "" : " style=\"text-align:\(alignments[j])\""
                    html.append("<th\(style)>\(inlineMarkdown(h))</th>")
                }
                html.append("</tr></thead><tbody>")
                while i < lines.count && lines[i].contains("|") {
                    let raw = parseTableRow(lines[i])
                    let cells = normalizeCells(raw, count: colCount)
                    html.append("<tr>")
                    for (j, c) in cells.enumerated() {
                        let style = alignments[j].isEmpty ? "" : " style=\"text-align:\(alignments[j])\""
                        html.append("<td\(style)>\(inlineMarkdown(c))</td>")
                    }
                    html.append("</tr>")
                    i += 1
                }
                html.append("</tbody></table>")
                continue
            }

            // Empty line
            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                i += 1; continue
            }

            // Paragraph
            let paraStart = i
            var paraLines: [String] = []
            while i < lines.count &&
                  !lines[i].trimmingCharacters(in: .whitespaces).isEmpty &&
                  lines[i].range(of: #"^#{1,6} "#, options: .regularExpression) == nil &&
                  !lines[i].hasPrefix("```") &&
                  !lines[i].hasPrefix(">") &&
                  !lines[i].hasPrefix("- ") &&
                  !lines[i].hasPrefix("* ") &&
                  lines[i].range(of: #"^\d+\. "#, options: .regularExpression) == nil &&
                  lines[i].trimmingCharacters(in: .whitespaces) != "---" &&
                  !isTableStart(lines: lines, at: i) {
                paraLines.append(inlineMarkdown(lines[i]))
                i += 1
            }
            if !paraLines.isEmpty {
                html.append("<p data-line=\"\(paraStart)\">\(paraLines.joined(separator: "\n"))</p>")
            }
        }

        return html.joined(separator: "\n")
    }

    private static func isTableStart(lines: [String], at i: Int) -> Bool {
        guard i + 1 < lines.count, lines[i].contains("|") else { return false }
        return lines[i + 1].range(
            of: #"^\|?(\s*:?-{3,}:?\s*\|)+\s*:?-{3,}:?\s*\|?\s*$"#,
            options: .regularExpression
        ) != nil
    }

    private static func parseTableRow(_ row: String) -> [String] {
        var trimmed = row.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("|") { trimmed = String(trimmed.dropFirst()) }
        if trimmed.hasSuffix("|") { trimmed = String(trimmed.dropLast()) }
        // Split by unescaped pipes
        var cells: [String] = []
        var current = ""
        var escaped = false
        for ch in trimmed {
            if escaped {
                if ch == "|" { current.append(ch) } else { current.append("\\"); current.append(ch) }
                escaped = false
            } else if ch == "\\" {
                escaped = true
            } else if ch == "|" {
                cells.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
            } else {
                current.append(ch)
            }
        }
        if escaped { current.append("\\") }
        cells.append(current.trimmingCharacters(in: .whitespaces))
        return cells
    }

    private static func normalizeCells(_ cells: [String], count: Int) -> [String] {
        if cells.count >= count { return Array(cells.prefix(count)) }
        return cells + Array(repeating: "", count: count - cells.count)
    }

    private static func parseAlignments(_ separator: String, count: Int) -> [String] {
        let parts = separator.trimmingCharacters(in: .whitespaces)
            .trimmingCharacters(in: .init(charactersIn: "|"))
            .components(separatedBy: "|")
            .map { $0.trimmingCharacters(in: .whitespaces) }
        var alignments: [String] = []
        for part in parts {
            let left = part.hasPrefix(":")
            let right = part.hasSuffix(":")
            if left && right { alignments.append("center") }
            else if right { alignments.append("right") }
            else if left { alignments.append("left") }
            else { alignments.append("") }
        }
        return normalizeCells(alignments, count: count)
    }

    private static func escapeHTML(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    /// Handles inline markdown: bold, italic, code, links
    private static func inlineMarkdown(_ text: String) -> String {
        var result = escapeHTML(text)

        // Inline code (before other transforms to avoid conflicts)
        result = result.replacingOccurrences(
            of: #"`([^`]+)`"#, with: "<code>$1</code>",
            options: .regularExpression)

        // Bold + italic
        result = result.replacingOccurrences(
            of: #"\*\*\*(.+?)\*\*\*"#, with: "<strong><em>$1</em></strong>",
            options: .regularExpression)

        // Bold
        result = result.replacingOccurrences(
            of: #"\*\*(.+?)\*\*"#, with: "<strong>$1</strong>",
            options: .regularExpression)

        // Italic
        result = result.replacingOccurrences(
            of: #"\*(.+?)\*"#, with: "<em>$1</em>",
            options: .regularExpression)

        // Links [text](url)
        result = result.replacingOccurrences(
            of: #"\[([^\]]+)\]\(([^)]+)\)"#, with: #"<a href="$2">$1</a>"#,
            options: .regularExpression)

        return result
    }
}
