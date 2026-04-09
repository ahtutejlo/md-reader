import SwiftUI
import WebKit

struct MarkdownWebView: NSViewRepresentable {
    let markdown: String

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let html = buildHTML(from: markdown)
        webView.loadHTMLString(html, baseURL: nil)
    }

    private func buildHTML(from source: String) -> String {
        let rendered = markdownToHTML(source)
        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/styles/github.min.css" media="(prefers-color-scheme: light)">
        <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/styles/github-dark.min.css" media="(prefers-color-scheme: dark)">
        <script src="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/highlight.min.js"></script>
        <style>
        :root {
            color-scheme: light dark;
            --text:          light-dark(#1f1b16, #ebe5db);
            --text-muted:    light-dark(#6b6359, #9b928a);
            --text-subtle:   light-dark(#8c8478, #766e66);
            --accent:        light-dark(#9a4a12, #e3995a);
            --accent-soft:   light-dark(#c2784a, #c68860);
            --border:        light-dark(#e8e2d6, #2b2823);
            --border-strong: light-dark(#d2ccbe, #3a3630);
            --surface:       light-dark(#f4efe4, #1c1a16);
            --code-text:     light-dark(#8a3a0c, #f1a775);
            --selection:     light-dark(rgba(154, 74, 18, 0.18), rgba(227, 153, 90, 0.24));
            --font-serif:    ui-serif, "New York", "Charter", "Iowan Old Style", Georgia, serif;
            --font-sans:     -apple-system, BlinkMacSystemFont, "SF Pro Text", "Helvetica Neue", sans-serif;
            --font-mono:     ui-monospace, "SF Mono", "JetBrains Mono", Menlo, Consolas, monospace;
        }

        * { box-sizing: border-box; }

        ::selection { background: var(--selection); }

        html { scroll-behavior: smooth; }

        body {
            font-family: var(--font-sans);
            font-size: 15px;
            line-height: 1.72;
            color: var(--text);
            background: transparent;
            padding: clamp(24px, 3.5vw, 52px) clamp(24px, 4vw, 56px) clamp(48px, 7vw, 88px);
            max-width: 90ch;
            margin: 0 auto;
            -webkit-font-smoothing: antialiased;
            font-feature-settings: "kern", "liga", "calt";
            text-rendering: optimizeLegibility;
        }

        body > *:first-child { margin-top: 0; }
        body > *:last-child { margin-bottom: 0; }

        /* Headings — serif for editorial contrast */
        h1, h2, h3, h4 {
            font-family: var(--font-serif);
            font-weight: 600;
            line-height: 1.18;
            letter-spacing: -0.015em;
            text-wrap: balance;
            color: var(--text);
        }

        h1 {
            font-size: 2.35em;
            font-weight: 700;
            letter-spacing: -0.028em;
            margin: 0 0 0.55em;
            padding-bottom: 0.32em;
            border-bottom: 1px solid var(--border);
        }

        h2 {
            font-size: 1.68em;
            margin: 2em 0 0.5em;
        }

        h3 {
            font-size: 1.32em;
            margin: 1.8em 0 0.4em;
        }

        h4 {
            font-size: 1.1em;
            margin: 1.4em 0 0.3em;
        }

        /* h5/h6 act as subtitles/labels, not headlines */
        h5, h6 {
            font-family: var(--font-sans);
            font-size: 0.82em;
            font-weight: 600;
            text-transform: uppercase;
            letter-spacing: 0.06em;
            color: var(--text-muted);
            margin: 1.4em 0 0.3em;
        }

        h1 + p, h2 + p, h3 + p, h4 + p { margin-top: 0.15em; }

        /* Paragraphs */
        p {
            margin: 0 0 1.05em;
            text-wrap: pretty;
        }

        /* Emphasis */
        strong { font-weight: 600; color: var(--text); }
        em { font-style: italic; }

        /* Links */
        a {
            color: var(--accent);
            text-decoration: none;
            border-bottom: 1px solid color-mix(in oklab, var(--accent) 35%, transparent);
            transition: border-color 160ms ease, color 160ms ease;
        }
        a:hover { border-bottom-color: var(--accent); }
        a:focus-visible {
            outline: 2px solid var(--accent);
            outline-offset: 3px;
            border-radius: 2px;
        }

        /* Inline code */
        code {
            font-family: var(--font-mono);
            font-size: 0.86em;
            background: var(--surface);
            color: var(--code-text);
            padding: 0.12em 0.42em;
            border-radius: 4px;
            border: 1px solid var(--border);
            font-variant-ligatures: none;
        }

        /* Fenced code blocks */
        pre {
            font-family: var(--font-mono);
            background: var(--surface);
            padding: 18px 22px;
            border-radius: 10px;
            overflow-x: auto;
            margin: 1.4em 0;
            border: 1px solid var(--border);
            font-size: 0.87em;
            line-height: 1.62;
        }
        pre code {
            background: none;
            padding: 0;
            border: 0;
            color: var(--text);
            font-size: 1em;
        }

        /* Let the warm pre surface show through highlight.js themes */
        pre code.hljs,
        .hljs {
            background: transparent !important;
            padding: 0 !important;
        }

        /* Blockquote — editorial italic serif */
        blockquote {
            margin: 1.5em 0;
            padding: 0.2em 0 0.2em 1.4em;
            border-left: 2px solid var(--accent-soft);
            font-family: var(--font-serif);
            font-style: italic;
            font-size: 1.06em;
            color: var(--text-muted);
            text-wrap: pretty;
        }
        blockquote p { margin: 0.3em 0; }

        /* Lists */
        ul, ol {
            padding-left: 1.45em;
            margin: 0 0 1.1em;
        }
        li {
            margin: 0.35em 0;
            padding-left: 0.2em;
        }
        li::marker { color: var(--text-subtle); }
        ul ul, ol ol, ul ol, ol ul { margin: 0.25em 0 0.4em; }

        /* Horizontal rule — subtle divider */
        hr {
            border: none;
            height: 1px;
            background: var(--border);
            margin: 2.4em auto;
            width: 42%;
        }

        /* Tables — bordered but quiet, rounded container */
        table {
            width: 100%;
            border-collapse: separate;
            border-spacing: 0;
            margin: 1.4em 0;
            font-size: 0.93em;
            font-variant-numeric: tabular-nums;
            border: 1px solid var(--border);
            border-radius: 8px;
            overflow: hidden;
        }
        thead th {
            font-weight: 600;
            text-align: left;
            padding: 10px 14px;
            background: color-mix(in oklab, var(--surface) 65%, transparent);
            border-bottom: 1px solid var(--border-strong);
            border-right: 1px solid var(--border);
            color: var(--text);
        }
        thead th:last-child { border-right: none; }
        tbody td {
            padding: 10px 14px;
            border-bottom: 1px solid var(--border);
            border-right: 1px solid var(--border);
            color: var(--text);
        }
        tbody td:last-child { border-right: none; }
        tbody tr:last-child td { border-bottom: none; }
        tbody tr { transition: background 140ms ease; }
        tbody tr:hover td {
            background: color-mix(in oklab, var(--surface) 55%, transparent);
        }

        /* Images */
        img {
            max-width: 100%;
            border-radius: 6px;
            margin: 1em 0;
        }

        /* Respect users who prefer reduced motion */
        @media (prefers-reduced-motion: reduce) {
            html { scroll-behavior: auto; }
            a, tbody tr { transition: none; }
        }
        </style>
        </head>
        <body>
        \(rendered)
        <script>hljs.highlightAll();</script>
        </body>
        </html>
        """
    }

    /// Converts markdown source to HTML using line-by-line parsing.
    /// Input is local file content — no untrusted user input.
    func markdownToHTML(_ source: String) -> String {
        let lines = source.components(separatedBy: "\n")
        var html: [String] = []
        var i = 0

        while i < lines.count {
            let line = lines[i]

            // Fenced code block
            if line.hasPrefix("```") {
                let lang = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                var codeLines: [String] = []
                i += 1
                while i < lines.count && !lines[i].hasPrefix("```") {
                    codeLines.append(escapeHTML(lines[i]))
                    i += 1
                }
                let langAttr = lang.isEmpty ? "" : " class=\"language-\(escapeHTML(lang))\""
                html.append("<pre><code\(langAttr)>\(codeLines.joined(separator: "\n"))</code></pre>")
                i += 1
                continue
            }

            // Headings
            if line.hasPrefix("######") {
                html.append("<h6>\(inlineMarkdown(String(line.dropFirst(7))))</h6>")
                i += 1; continue
            }
            if line.hasPrefix("#####") {
                html.append("<h5>\(inlineMarkdown(String(line.dropFirst(6))))</h5>")
                i += 1; continue
            }
            if line.hasPrefix("####") {
                html.append("<h4>\(inlineMarkdown(String(line.dropFirst(5))))</h4>")
                i += 1; continue
            }
            if line.hasPrefix("###") {
                html.append("<h3>\(inlineMarkdown(String(line.dropFirst(4))))</h3>")
                i += 1; continue
            }
            if line.hasPrefix("##") {
                html.append("<h2>\(inlineMarkdown(String(line.dropFirst(3))))</h2>")
                i += 1; continue
            }
            if line.hasPrefix("#") {
                html.append("<h1>\(inlineMarkdown(String(line.dropFirst(2))))</h1>")
                i += 1; continue
            }

            // Horizontal rule
            if line.trimmingCharacters(in: .whitespaces) == "---" ||
               line.trimmingCharacters(in: .whitespaces) == "***" ||
               line.trimmingCharacters(in: .whitespaces) == "___" {
                html.append("<hr>")
                i += 1; continue
            }

            // Blockquote
            if line.hasPrefix(">") {
                var quoteLines: [String] = []
                while i < lines.count && lines[i].hasPrefix(">") {
                    let content = String(lines[i].dropFirst(1)).trimmingCharacters(in: .init(charactersIn: " "))
                    quoteLines.append(inlineMarkdown(content))
                    i += 1
                }
                html.append("<blockquote><p>\(quoteLines.joined(separator: "<br>"))</p></blockquote>")
                continue
            }

            // Unordered list
            if line.hasPrefix("- ") || line.hasPrefix("* ") {
                html.append("<ul>")
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
                html.append("<ol>")
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
                let headers = parseTableRow(line)
                let colCount = headers.count
                let alignments = parseAlignments(lines[i + 1], count: colCount)
                i += 2
                html.append("<table><thead><tr>")
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
            var paraLines: [String] = []
            while i < lines.count &&
                  !lines[i].trimmingCharacters(in: .whitespaces).isEmpty &&
                  !lines[i].hasPrefix("#") &&
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
                html.append("<p>\(paraLines.joined(separator: "\n"))</p>")
            }
        }

        return html.joined(separator: "\n")
    }

    private func isTableStart(lines: [String], at i: Int) -> Bool {
        guard i + 1 < lines.count, lines[i].contains("|") else { return false }
        return lines[i + 1].range(
            of: #"^\|?(\s*:?-{3,}:?\s*\|)+\s*:?-{3,}:?\s*\|?\s*$"#,
            options: .regularExpression
        ) != nil
    }

    private func parseTableRow(_ row: String) -> [String] {
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

    private func normalizeCells(_ cells: [String], count: Int) -> [String] {
        if cells.count >= count { return Array(cells.prefix(count)) }
        return cells + Array(repeating: "", count: count - cells.count)
    }

    private func parseAlignments(_ separator: String, count: Int) -> [String] {
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

    private func escapeHTML(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    /// Handles inline markdown: bold, italic, code, links
    private func inlineMarkdown(_ text: String) -> String {
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
