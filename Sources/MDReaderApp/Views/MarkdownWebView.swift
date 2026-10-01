import SwiftUI
import WebKit
import os

struct PreviewHooks {
    var openMarkdown: (URL) -> Void
    var savedLine: (URL) -> Int?
    var saveLine: (URL, Int) -> Void
}

struct MarkdownWebView: NSViewRepresentable {
    @Bindable var viewModel: EditorViewModel
    var hooks: PreviewHooks
    @AppStorage(Preferences.zoomKey) private var zoom = 1.0

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.userContentController.add(context.coordinator, name: "mdToggleTask")
        config.userContentController.add(context.coordinator, name: "mdCopyCode")
        config.userContentController.add(context.coordinator, name: "mdOpenLink")
        config.userContentController.add(context.coordinator, name: "mdScrollState")
        config.userContentController.add(context.coordinator, name: "mdCopySection")
        config.setURLSchemeHandler(LocalAssetSchemeHandler(), forURLScheme: LocalAssetSchemeHandler.scheme)
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        webView.navigationDelegate = context.coordinator
        webView.pageZoom = zoom
        context.coordinator.webView = webView
        context.coordinator.viewModel = viewModel
        context.coordinator.hooks = hooks
        viewModel.preview = context.coordinator
        webView.loadHTMLString(Self.shellHTML, baseURL: nil)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let coordinator = context.coordinator
        coordinator.viewModel = viewModel
        coordinator.hooks = hooks
        viewModel.preview = coordinator
        if webView.pageZoom != zoom {
            webView.pageZoom = zoom
        }
        coordinator.onUpdate(markdown: viewModel.text, activeLine: viewModel.activeLine)
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler, PreviewController {
        weak var webView: WKWebView?
        weak var viewModel: EditorViewModel?
        var hooks: PreviewHooks?
        var isLoaded = false
        private var renderedFileURL: URL?
        var lastMarkdownHash: Int = 0
        var lastActiveLine: Int?
        var pendingMarkdown: String?
        var pendingActiveLine: Int?
        private var updateWorkItem: DispatchWorkItem?
        private let log = Logger(subsystem: "dev.mdreader", category: "MarkdownWebView")

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isLoaded = true
            let md = pendingMarkdown
            let line = pendingActiveLine
            pendingMarkdown = nil
            pendingActiveLine = nil
            if let md {
                pushUpdate(markdown: md, thenScrollTo: line)
            } else if let line {
                pushScroll(line: line)
            }
        }

        /// Links are handled by the click listener; the shell page itself never navigates away.
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void) {
            decisionHandler(isLoaded ? .cancel : .allow)
        }

        private var documentDirectory: URL? {
            viewModel?.fileURL?.deletingLastPathComponent()
        }

        func onUpdate(markdown: String, activeLine: Int) {
            guard isLoaded else {
                pendingMarkdown = markdown
                pendingActiveLine = activeLine
                return
            }
            var hasher = Hasher()
            hasher.combine(markdown)
            hasher.combine(viewModel?.fileURL)
            let hash = hasher.finalize()
            let markdownChanged = (hash != lastMarkdownHash)
            let lineChanged = (activeLine != lastActiveLine)
            if markdownChanged {
                lastMarkdownHash = hash
                scheduleUpdate(markdown: markdown, thenScrollTo: lineChanged ? activeLine : nil)
            } else if lineChanged {
                pushScroll(line: activeLine)
            }
        }

        private func scheduleUpdate(markdown: String, thenScrollTo scrollLine: Int?) {
            updateWorkItem?.cancel()
            let item = DispatchWorkItem { [weak self] in
                self?.pushUpdate(markdown: markdown, thenScrollTo: scrollLine)
            }
            updateWorkItem = item
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: item)
        }

        private func pushUpdate(markdown: String, thenScrollTo scrollLine: Int?) {
            guard let webView else { return }
            let fileURL = viewModel?.fileURL
            let rendered = MarkdownRenderer.render(markdown, baseDirectory: documentDirectory)
            if viewModel?.outline != rendered.outline {
                viewModel?.outline = rendered.outline
            }
            let isNewDocument = fileURL != renderedFileURL
            renderedFileURL = fileURL
            var options: [String: Any] = ["doc": fileURL?.path ?? ""]
            if isNewDocument {
                options["restoreLine"] = fileURL.flatMap { hooks?.savedLine($0) } ?? 0
                if let scrollLine { lastActiveLine = scrollLine }
            }
            guard let html = jsonLiteral(rendered.html), let optionsLiteral = jsonLiteral(options) else {
                log.error("Failed to encode HTML for JS")
                return
            }
            webView.evaluateJavaScript("window.mdUpdate(\(html), \(optionsLiteral));") { [weak self] _, error in
                if let error {
                    self?.log.error("mdUpdate failed: \(error.localizedDescription)")
                }
                if !isNewDocument, let line = scrollLine {
                    self?.pushScroll(line: line)
                }
            }
        }

        func scrollToAnchor(_ id: String) {
            guard let literal = jsonLiteral(id) else { return }
            webView?.evaluateJavaScript("window.mdScrollToAnchor(\(literal));")
        }

        func find(_ text: String, backwards: Bool, restart: Bool) {
            guard let webView else { return }
            guard !text.isEmpty else {
                // WebKit keeps the yellow match marker until the DOM it points at is replaced.
                viewModel?.findMatched = true
                if let markdown = viewModel?.text {
                    pushUpdate(markdown: markdown, thenScrollTo: nil)
                }
                return
            }
            let configuration = WKFindConfiguration()
            configuration.backwards = backwards
            configuration.caseSensitive = false
            configuration.wraps = true
            let prepare = restart ? "window.getSelection().rangeCount && window.getSelection().collapseToStart();" : ""
            webView.evaluateJavaScript(prepare) { [weak self] _, _ in
                webView.find(text, configuration: configuration) { result in
                    self?.viewModel?.findMatched = result.matchFound
                }
            }
        }

        private func pushScroll(line: Int) {
            guard let webView else { return }
            webView.evaluateJavaScript("window.mdScrollToLine(\(line));") { [weak self] _, error in
                if let error {
                    self?.log.error("mdScrollToLine failed: \(error.localizedDescription)")
                }
            }
            lastActiveLine = line
        }

        // MARK: - WKScriptMessageHandler

        func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
            switch message.name {
            case "mdToggleTask":
                guard let body = message.body as? [String: Any],
                      let line = body["line"] as? Int else { return }
                viewModel?.toggleTaskAt(line: line)
            case "mdCopyCode":
                guard let text = message.body as? String else { return }
                RichClipboard.copy(text: text)
            case "mdOpenLink":
                guard let href = message.body as? String else { return }
                openLink(href)
            case "mdScrollState":
                guard let body = message.body as? [String: Any],
                      let doc = body["doc"] as? String,
                      let fileURL = viewModel?.fileURL, doc == fileURL.path else { return }
                if let line = body["line"] as? Int {
                    hooks?.saveLine(fileURL, line)
                }
                let heading = body["heading"] as? String
                if viewModel?.currentHeadingID != heading {
                    viewModel?.currentHeadingID = heading
                }
            case "mdCopySection":
                guard let start = message.body as? Int, let viewModel else { return }
                let end = viewModel.outline.sectionEnd(startingAt: start)
                RichClipboard.copy(markdown: RichClipboard.section(of: viewModel.text, from: start, to: end))
            default:
                break
            }
        }

        private func openLink(_ href: String) {
            switch LinkRouter.target(for: href, relativeTo: documentDirectory) {
            case .external(let url):
                NSWorkspace.shared.open(url)
            case .markdown(let url) where FileManager.default.fileExists(atPath: url.path):
                hooks?.openMarkdown(url)
            case .localFile(let url) where FileManager.default.fileExists(atPath: url.path):
                NSWorkspace.shared.activateFileViewerSelecting([url])
            case .wikilink(let name):
                guard let directory = documentDirectory else { return NSSound.beep() }
                DispatchQueue.global(qos: .userInitiated).async {
                    let url = WikiLinkResolver.resolve(name, from: directory)
                    DispatchQueue.main.async { [weak self] in
                        if let url {
                            self?.hooks?.openMarkdown(url)
                        } else {
                            NSSound.beep()
                        }
                    }
                }
            default:
                NSSound.beep()
            }
        }

        private func jsonLiteral(_ value: Any) -> String? {
            guard let data = try? JSONSerialization.data(withJSONObject: value, options: .fragmentsAllowed) else { return nil }
            return String(decoding: data, as: UTF8.self)
        }
    }

    static let shellHTML: String = """
    <!DOCTYPE html>
    <html>
    <head>
    <meta charset="utf-8">
    <style media="(prefers-color-scheme: light)">\(PreviewAssets.lightTheme)</style>
    <style media="(prefers-color-scheme: dark)">\(PreviewAssets.darkTheme)</style>
    <script>\(PreviewAssets.highlightScript)</script>
    <style>
    \(Self.previewCSS)
    </style>
    </head>
    <body>
    <div id="content"></div>
    <script>
    const headingSelector = ":is(h1, h2, h3, h4, h5, h6)[id]";
    window.mdUpdate = function(html, options) {
        const target = document.getElementById("content");
        const scrollY = document.documentElement.scrollTop;
        // Parse off-screen, then swap in a single rAF to batch into one paint.
        const parsed = new DOMParser().parseFromString(html, "text/html");
        const nodes = Array.from(parsed.body.childNodes);
        requestAnimationFrame(function() {
            target.replaceChildren.apply(target, nodes);
            if (window.hljs) {
                target.querySelectorAll("pre code").forEach(function(el) {
                    hljs.highlightElement(el);
                });
            }
            target.querySelectorAll("pre > code").forEach(addCodeCopyButton);
            target.querySelectorAll("li.task-list-item > input[type='checkbox']").forEach(function(input) {
                input.removeAttribute("disabled");
                input.tabIndex = -1;
                input.addEventListener("click", onTaskCheckboxClick);
            });
            target.querySelectorAll(":scope > " + headingSelector).forEach(function(heading) {
                heading.append(makeCopyButton("copy-section", "Copy section", function() {
                    post("mdCopySection", lineOf(heading));
                }));
            });
            window.mdDocument = options.doc;
            if (options.restoreLine != null) {
                scrollLineToTop(options.restoreLine);
            } else {
                window.scrollTo({ top: scrollY, behavior: "instant" });
            }
            reportScrollState();
        });
    };
    function post(name, body) {
        const handlers = window.webkit && window.webkit.messageHandlers;
        if (handlers && handlers[name]) handlers[name].postMessage(body);
    }
    function lineOf(element) {
        return parseInt(element.getAttribute("data-line"), 10);
    }
    function blockAtLine(blocks, line) {
        let match = null;
        for (const block of blocks) {
            if (lineOf(block) <= line) match = block; else break;
        }
        return match;
    }
    function makeCopyButton(className, label, onCopy) {
        const button = document.createElement("button");
        button.type = "button";
        button.className = className;
        button.textContent = "Copy";
        button.setAttribute("aria-label", label);
        button.addEventListener("click", function() {
            onCopy();
            button.textContent = "Copied";
            button.classList.add("copied");
            clearTimeout(button.resetTimer);
            button.resetTimer = setTimeout(function() {
                button.textContent = "Copy";
                button.classList.remove("copied");
            }, 1500);
        });
        return button;
    }
    function addCodeCopyButton(code) {
        const pre = code.parentElement;
        const wrapper = document.createElement("div");
        wrapper.className = "code-block";
        pre.before(wrapper);
        wrapper.append(pre, makeCopyButton("copy-code", "Copy code", function() {
            post("mdCopyCode", code.textContent);
        }));
    }
    function topLevelBlocks() {
        return document.querySelectorAll("#content > [data-line], #content > .code-block > [data-line]");
    }
    function scrollLineToTop(line) {
        const block = line > 0 ? blockAtLine(topLevelBlocks(), line) : null;
        const top = block ? block.getBoundingClientRect().top + window.scrollY - 12 : 0;
        window.scrollTo({ top: top, behavior: "instant" });
    }
    function topVisibleLine() {
        for (const block of topLevelBlocks()) {
            if (block.getBoundingClientRect().bottom > 1) return lineOf(block);
        }
        return 0;
    }
    function currentHeadingId() {
        const headings = document.querySelectorAll("#content " + headingSelector);
        let current = headings.length ? headings[0].id : null;
        for (const heading of headings) {
            if (heading.getBoundingClientRect().top <= 80) current = heading.id; else break;
        }
        return current;
    }
    let reportTimer;
    function reportScrollState() {
        clearTimeout(reportTimer);
        reportTimer = setTimeout(function() {
            if (!window.mdDocument) return;
            post("mdScrollState", { doc: window.mdDocument, line: topVisibleLine(), heading: currentHeadingId() });
        }, 150);
    }
    window.addEventListener("scroll", reportScrollState, { passive: true });
    function onTaskCheckboxClick(e) {
        const input = e.currentTarget;
        const li = input.closest("li.task-list-item");
        if (!li) return;
        const lineAttr = li.getAttribute("data-md-line");
        if (lineAttr == null) return;
        // Optimistic visual update; the markdown re-render will confirm it.
        li.classList.toggle("checked", input.checked);
        post("mdToggleTask", { line: parseInt(lineAttr, 10) });
    }
    window.mdScrollToAnchor = function(id) {
        document.getElementById(id)?.scrollIntoView({ block: "start" });
    };
    document.addEventListener("click", function(e) {
        const link = e.target.closest("a[href]");
        if (!link) return;
        e.preventDefault();
        const href = link.getAttribute("href");
        if (href.startsWith("#")) {
            let id = href.slice(1);
            try { id = decodeURIComponent(id); } catch (_) {}
            window.mdScrollToAnchor(id);
            return;
        }
        post("mdOpenLink", href);
    });
    window.mdScrollToLine = function(line) {
        const blocks = document.querySelectorAll("[data-line]");
        const match = blockAtLine(blocks, line) || blocks[0];
        if (match) match.scrollIntoView({ block: "center", behavior: "smooth" });
    };
    </script>
    </body>
    </html>
    """

    private static let previewCSS: String = """
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

    #content > *:first-child { margin-top: 0; }
    #content > *:last-child { margin-bottom: 0; }

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
    a[href] {
        color: var(--accent);
        text-decoration: none;
        border-bottom: 1px solid color-mix(in oklab, var(--accent) 35%, transparent);
        transition: border-color 160ms ease, color 160ms ease;
    }
    a[href]:hover { border-bottom-color: var(--accent); }
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
    .code-block {
        position: relative;
        margin: 1.4em 0;
    }
    .code-block > pre { margin: 0; }
    .copy-code, .copy-section {
        position: absolute;
        top: 8px;
        right: 8px;
        font-family: var(--font-sans);
        font-size: 11.5px;
        font-weight: 500;
        line-height: 1;
        padding: 5px 9px;
        color: var(--text-muted);
        background: var(--surface);
        border: 1px solid var(--border-strong);
        border-radius: 6px;
        cursor: pointer;
        user-select: none;
        -webkit-user-select: none;
        opacity: 0;
        transition: opacity 140ms ease, color 140ms ease, border-color 140ms ease;
    }
    .copy-section {
        position: static;
        margin-left: 0.6em;
        vertical-align: middle;
        letter-spacing: normal;
    }
    .code-block:hover .copy-code,
    :is(h1, h2, h3, h4, h5, h6):hover > .copy-section,
    :is(.copy-code, .copy-section):focus-visible,
    :is(.copy-code, .copy-section).copied { opacity: 1; }
    :is(.copy-code, .copy-section):hover { color: var(--text); border-color: var(--accent-soft); }
    :is(.copy-code, .copy-section):focus-visible { outline: 2px solid var(--accent); outline-offset: 2px; }
    :is(.copy-code, .copy-section).copied { color: var(--accent); border-color: var(--accent-soft); }
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
    li > p { margin: 0 0 0.35em; }
    li > p:last-child { margin-bottom: 0; }
    li::marker { color: var(--text-subtle); }
    ul ul, ol ol, ul ol, ol ul { margin: 0.25em 0 0.4em; }

    /* GFM task lists */
    ul.contains-task-list { padding-left: 0.4em; }
    ul.contains-task-list ul { padding-left: 1.45em; }
    ul.contains-task-list > li:not(.task-list-item) { margin-left: 1.05em; }
    li.task-list-item {
        list-style: none;
        padding-left: 0;
        display: flex;
        flex-wrap: wrap;
        align-items: baseline;
        gap: 0 0.55em;
    }
    li.task-list-item > :not(input):not(p:first-of-type) {
        flex-basis: 100%;
        padding-left: 1.5em;
    }
    li.task-list-item > input[type="checkbox"] {
        appearance: none;
        -webkit-appearance: none;
        flex: 0 0 auto;
        width: 0.95em;
        height: 0.95em;
        margin: 0;
        border: 1.5px solid var(--border-strong);
        border-radius: 3px;
        background: transparent;
        cursor: pointer;
        transition: background 120ms ease, border-color 120ms ease;
    }
    li.task-list-item > input[type="checkbox"]:hover {
        border-color: var(--accent);
    }
    li.task-list-item.checked > input[type="checkbox"] {
        background: var(--accent);
        border-color: var(--accent);
        background-image: url("data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 16 16'><path fill='none' stroke='white' stroke-width='2.2' stroke-linecap='round' stroke-linejoin='round' d='M3.5 8.4l3 3 6-6.4'/></svg>");
        background-size: 100% 100%;
        background-repeat: no-repeat;
    }
    li.task-list-item.checked {
        color: var(--text-muted);
        text-decoration: line-through;
        text-decoration-color: color-mix(in oklab, var(--text-muted) 55%, transparent);
    }

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

    /* Front matter (Obsidian properties) */
    .frontmatter {
        margin: 0 0 1.8em;
        padding: 0.55em 0.9em;
        border: 1px solid var(--border);
        border-radius: 8px;
        background: color-mix(in oklab, var(--surface) 55%, transparent);
        font-size: 0.86em;
    }
    .frontmatter summary {
        cursor: pointer;
        color: var(--text-muted);
        font-weight: 600;
        user-select: none;
        -webkit-user-select: none;
    }
    .frontmatter table { margin: 0.5em 0 0.1em; font-size: 1em; }
    .frontmatter tbody th {
        width: 28%;
        padding: 4px 12px 4px 0;
        text-align: left;
        vertical-align: top;
        font-weight: 500;
        color: var(--text-muted);
        border: none;
    }
    .frontmatter tbody td { padding: 4px 0; border: none; word-break: break-word; }
    .frontmatter tbody tr:hover td { background: none; }

    /* Images */
    img {
        max-width: 100%;
        border-radius: 6px;
        margin: 1em 0;
    }

    /* Respect users who prefer reduced motion */
    @media (prefers-reduced-motion: reduce) {
        html { scroll-behavior: auto; }
        a, tbody tr, .copy-code, .copy-section { transition: none; }
    }
    """
}
