import SwiftUI
import WebKit

struct MarkdownWebView: NSViewRepresentable {
    @Bindable var viewModel: EditorViewModel

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let html = buildHTML(from: viewModel.text)
        webView.loadHTMLString(html, baseURL: nil)
    }

    private func buildHTML(from source: String) -> String {
        let rendered = MarkdownRenderer.renderHTML(from: source)
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

}
