import Testing
@testable import MDReaderApp

@Test func dataLineOnHeadings() {
    let md = """
    # First

    ## Second

    ### Third
    """
    let html = MarkdownRenderer.renderHTML(from: md)
    #expect(html.contains("<h1 data-line=\"0\">First</h1>"))
    #expect(html.contains("<h2 data-line=\"2\">Second</h2>"))
    #expect(html.contains("<h3 data-line=\"4\">Third</h3>"))
}

@Test func dataLineOnParagraph() {
    let md = """
    First paragraph.

    Second paragraph
    continues here.
    """
    let html = MarkdownRenderer.renderHTML(from: md)
    #expect(html.contains("<p data-line=\"0\">First paragraph.</p>"))
    #expect(html.contains("<p data-line=\"2\">Second paragraph\ncontinues here.</p>"))
}

@Test func dataLineOnUnorderedList() {
    let md = """
    Intro.

    - one
    - two
    """
    let html = MarkdownRenderer.renderHTML(from: md)
    #expect(html.contains("<ul data-line=\"2\">"))
}

@Test func dataLineOnOrderedList() {
    let md = """
    1. first
    2. second
    """
    let html = MarkdownRenderer.renderHTML(from: md)
    #expect(html.contains("<ol data-line=\"0\">"))
}

@Test func dataLineOnFencedCodeBlock() {
    let md = """
    para

    ```swift
    let x = 1
    ```
    """
    let html = MarkdownRenderer.renderHTML(from: md)
    #expect(html.contains("<pre data-line=\"2\">"))
}

@Test func dataLineOnBlockquote() {
    let md = """
    intro

    > quoted line
    > second line
    """
    let html = MarkdownRenderer.renderHTML(from: md)
    #expect(html.contains("<blockquote data-line=\"2\">"))
}

@Test func dataLineOnTable() {
    let md = """
    before

    | A | B |
    | --- | --- |
    | 1 | 2 |
    """
    let html = MarkdownRenderer.renderHTML(from: md)
    #expect(html.contains("<table data-line=\"2\">"))
}

@Test func dataLineOnHorizontalRule() {
    let md = """
    above

    ---

    below
    """
    let html = MarkdownRenderer.renderHTML(from: md)
    #expect(html.contains("<hr data-line=\"2\">"))
}
