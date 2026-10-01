import Foundation
import Testing
@testable import MDReaderApp

private func paragraph(_ inner: String) -> String {
    "<p data-line=\"0\">\(inner)</p>\n"
}

private func wikilink(_ href: String, _ label: String) -> String {
    "<a class=\"wikilink\" href=\"\(href)\">\(label)</a>"
}

@Test(arguments: [
    ("[[note]]", wikilink("wikilink:note", "note")),
    ("[[note|Label]]", wikilink("wikilink:note", "Label")),
    ("[[note#Part 1]]", wikilink("wikilink:note", "note › Part 1")),
    ("[[note#Part 1|Back]]", wikilink("wikilink:note", "Back")),
    ("[[My Note]]", wikilink("wikilink:My%20Note", "My Note")),
    ("[[Нотатка]]", wikilink("wikilink:%D0%9D%D0%BE%D1%82%D0%B0%D1%82%D0%BA%D0%B0", "Нотатка")),
    ("[[#Part 1]]", wikilink("#part-1", "Part 1")),
    ("[[a]] and [[b|B]]", wikilink("wikilink:a", "a") + " and " + wikilink("wikilink:b", "B")),
])
func wikilinkRendersAsLink(_ markdown: String, _ anchor: String) {
    #expect(MarkdownRenderer.renderHTML(from: "See \(markdown) now") == paragraph("See \(anchor) now"))
}

@Test(arguments: ["My Note", "Нотатка про QA", "100% done", "Q&A", "Why? FAQ", "projects/Plan"])
func wikilinkHrefRoutesBackToNoteName(_ name: String) throws {
    let html = MarkdownRenderer.renderHTML(from: "[[\(name)]]")
    let match = try #require(html.firstMatch(of: #/href="([^"]*)"/#))
    let href = String(match.1).replacingOccurrences(of: "&amp;", with: "&")
    #expect(LinkRouter.target(for: href, relativeTo: nil) == .wikilink(name))
}

@Test func headingWikilinkTargetsHeadingId() {
    let html = MarkdownRenderer.renderHTML(from: "## Огляд, проєкту!\n\nBack to [[#Огляд, проєкту!]]")
    #expect(html == """
    <h2 id="огляд-проєкту" data-line="0">Огляд, проєкту!</h2>
    <p data-line="2">Back to <a class="wikilink" href="#огляд-проєкту">Огляд, проєкту!</a></p>

    """)
}

@Test(arguments: ["[[]]", "[[ ]]", "[[#]]"])
func emptyWikilinkStaysLiteral(_ markdown: String) {
    #expect(MarkdownRenderer.renderHTML(from: "a \(markdown) b") == paragraph("a \(markdown) b"))
}

@Test func wikilinkSyntaxInCodeStaysLiteral() {
    let inline = MarkdownRenderer.renderHTML(from: "Run `[[ -f x ]]` before [[note]]")
    #expect(inline == paragraph("Run <code>[[ -f x ]]</code> before \(wikilink("wikilink:note", "note"))"))

    let fenced = MarkdownRenderer.renderHTML(from: "```bash\nif [[ -f x ]]; then open [[note]]; fi\n```")
    #expect(fenced == "<pre data-line=\"0\"><code class=\"language-bash\">if [[ -f x ]]; then open [[note]]; fi</code></pre>\n")
}

@Test func wikilinkInsideLinkTextStaysLiteral() {
    let html = MarkdownRenderer.renderHTML(from: "[docs [[note]]](https://example.com/docs)")
    #expect(html == paragraph("<a href=\"https://example.com/docs\">docs [[note]]</a>"))
}

@Test func bareUrlNextToWikilinkStillAutolinks() {
    let html = MarkdownRenderer.renderHTML(from: "See [[note]], then https://example.com/docs.")
    #expect(html == paragraph("See \(wikilink("wikilink:note", "note")), then <a href=\"https://example.com/docs\">https://example.com/docs</a>."))
}

@Test func wikilinkNameAndLabelAreEscaped() {
    #expect(MarkdownRenderer.renderHTML(from: "[[a\" onmouseover=\"alert(1)]]")
        == paragraph(wikilink("wikilink:a%22%20onmouseover=%22alert(1)", "a&quot; onmouseover=&quot;alert(1)")))
    #expect(MarkdownRenderer.renderHTML(from: "[[Q&A]]") == paragraph(wikilink("wikilink:Q&amp;A", "Q&amp;A")))
}
