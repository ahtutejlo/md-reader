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
        :root { color-scheme: light dark; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Helvetica Neue", sans-serif;
            font-size: 14px;
            line-height: 1.6;
            color: light-dark(#1d1d1f, #f5f5f7);
            background: transparent;
            padding: 16px 24px;
            max-width: 800px;
        }
        h1 { font-size: 2em; font-weight: 700; margin: 0.8em 0 0.4em; border-bottom: 1px solid light-dark(#d2d2d7, #424245); padding-bottom: 0.3em; }
        h2 { font-size: 1.5em; font-weight: 600; margin: 0.8em 0 0.4em; }
        h3 { font-size: 1.25em; font-weight: 600; margin: 0.8em 0 0.4em; }
        h4, h5, h6 { font-size: 1em; font-weight: 600; margin: 0.6em 0 0.3em; }
        p { margin: 0.6em 0; }
        code {
            font-family: "SF Mono", Menlo, monospace;
            font-size: 0.9em;
            background: light-dark(#f5f5f7, #2a2a2c);
            padding: 0.15em 0.4em;
            border-radius: 4px;
        }
        pre {
            background: light-dark(#f5f5f7, #1c1c1e);
            padding: 12px 16px;
            border-radius: 8px;
            overflow-x: auto;
            margin: 0.8em 0;
        }
        pre code { background: none; padding: 0; }
        blockquote {
            border-left: 3px solid light-dark(#0071e3, #2997ff);
            margin: 0.6em 0;
            padding: 0.2em 0 0.2em 16px;
            color: light-dark(#6e6e73, #a1a1a6);
        }
        a { color: light-dark(#0071e3, #2997ff); text-decoration: none; }
        a:hover { text-decoration: underline; }
        ul, ol { padding-left: 1.5em; margin: 0.4em 0; }
        li { margin: 0.2em 0; }
        hr { border: none; border-top: 1px solid light-dark(#d2d2d7, #424245); margin: 1.5em 0; }
        table { border-collapse: collapse; margin: 0.8em 0; }
        th, td { border: 1px solid light-dark(#d2d2d7, #424245); padding: 6px 12px; text-align: left; }
        th { background: light-dark(#f5f5f7, #2a2a2c); font-weight: 600; }
        strong { font-weight: 600; }
        img { max-width: 100%; }
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
    private func markdownToHTML(_ source: String) -> String {
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
                  lines[i].trimmingCharacters(in: .whitespaces) != "---" {
                paraLines.append(inlineMarkdown(lines[i]))
                i += 1
            }
            if !paraLines.isEmpty {
                html.append("<p>\(paraLines.joined(separator: "\n"))</p>")
            }
        }

        return html.joined(separator: "\n")
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
