import Testing
@testable import MDReaderApp

private let view = MarkdownWebView(markdown: "")

@Test func basicTable() {
    let md = """
    | Name | Age |
    | --- | --- |
    | Alice | 30 |
    | Bob | 25 |
    """
    let html = view.markdownToHTML(md)
    #expect(html.contains("<table>"))
    #expect(html.contains("<thead>"))
    #expect(html.contains("<th>Name</th>"))
    #expect(html.contains("<th>Age</th>"))
    #expect(html.contains("<td>Alice</td>"))
    #expect(html.contains("<td>30</td>"))
    #expect(html.contains("<td>Bob</td>"))
    #expect(html.contains("</tbody></table>"))
}

@Test func tableAlignment() {
    let md = """
    | Left | Center | Right |
    | :--- | :---: | ---: |
    | a | b | c |
    """
    let html = view.markdownToHTML(md)
    #expect(html.contains("<th style=\"text-align:left\">Left</th>"))
    #expect(html.contains("<th style=\"text-align:center\">Center</th>"))
    #expect(html.contains("<th style=\"text-align:right\">Right</th>"))
    #expect(html.contains("<td style=\"text-align:left\">a</td>"))
    #expect(html.contains("<td style=\"text-align:center\">b</td>"))
    #expect(html.contains("<td style=\"text-align:right\">c</td>"))
}

@Test func escapedPipeInCell() {
    let md = """
    | Expression | Result |
    | --- | --- |
    | a \\| b | yes |
    """
    let html = view.markdownToHTML(md)
    #expect(html.contains("<td>a | b</td>"))
    #expect(html.contains("<td>yes</td>"))
}

@Test func columnNormalization() {
    let md = """
    | A | B | C |
    | --- | --- | --- |
    | 1 |
    | 1 | 2 | 3 | 4 |
    """
    let html = view.markdownToHTML(md)
    // Row with fewer cells should be padded
    #expect(html.contains("<td>1</td>\n<td></td>\n<td></td>"))
    // Row with extra cells should be trimmed — no "4" in output
    #expect(!html.contains("<td>4</td>"))
}

@Test func noFalsePositiveOnPipeInText() {
    let md = "this | is not | a table"
    let html = view.markdownToHTML(md)
    #expect(!html.contains("<table>"))
    #expect(html.contains("<p>"))
}

@Test func inlineMarkdownInCells() {
    let md = """
    | Feature | Status |
    | --- | --- |
    | **bold** | `done` |
    """
    let html = view.markdownToHTML(md)
    #expect(html.contains("<td><strong>bold</strong></td>"))
    #expect(html.contains("<td><code>done</code></td>"))
}

@Test func tableAfterParagraph() {
    let md = """
    Some text here.

    | H1 | H2 |
    | --- | --- |
    | a | b |
    """
    let html = view.markdownToHTML(md)
    #expect(html.contains("<p>Some text here.</p>"))
    #expect(html.contains("<table>"))
    #expect(html.contains("<td>a</td>"))
}

@Test func tableWithoutLeadingPipes() {
    let md = """
    H1 | H2
    --- | ---
    a | b
    """
    let html = view.markdownToHTML(md)
    #expect(html.contains("<table>"))
    #expect(html.contains("<th>H1</th>"))
    #expect(html.contains("<td>a</td>"))
}
