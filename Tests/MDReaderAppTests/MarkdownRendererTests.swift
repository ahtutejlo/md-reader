import Foundation
import Testing
@testable import MDReaderApp

@Test func dataLineOnHeadings() {
    let md = """
    # H1

    ## H2

    ### H3

    #### H4

    ##### H5

    ###### H6
    """
    let html = MarkdownRenderer.renderHTML(from: md)
    #expect(html.contains("<h1 id=\"h1\" data-line=\"0\">H1</h1>"))
    #expect(html.contains("<h2 id=\"h2\" data-line=\"2\">H2</h2>"))
    #expect(html.contains("<h3 id=\"h3\" data-line=\"4\">H3</h3>"))
    #expect(html.contains("<h4 id=\"h4\" data-line=\"6\">H4</h4>"))
    #expect(html.contains("<h5 id=\"h5\" data-line=\"8\">H5</h5>"))
    #expect(html.contains("<h6 id=\"h6\" data-line=\"10\">H6</h6>"))
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

@Test func taskListUnchecked() {
    let md = "- [ ] todo item"
    let html = MarkdownRenderer.renderHTML(from: md)
    #expect(html.contains("<ul class=\"contains-task-list\""))
    #expect(html.contains("<li class=\"task-list-item\" data-md-line=\"0\"><input type=\"checkbox\" disabled>todo item</li>"))
}

@Test func taskListChecked() {
    let md = "- [x] done item"
    let html = MarkdownRenderer.renderHTML(from: md)
    #expect(html.contains("<li class=\"task-list-item checked\" data-md-line=\"0\"><input type=\"checkbox\" disabled checked>done item</li>"))
}

@Test func taskListCheckedCapital() {
    let md = "- [X] done item"
    let html = MarkdownRenderer.renderHTML(from: md)
    #expect(html.contains("<input type=\"checkbox\" disabled checked>done item"))
}

@Test func taskListMixed() {
    let md = """
    - [ ] one
    - [x] two
    - three
    """
    let html = MarkdownRenderer.renderHTML(from: md)
    #expect(html.contains("<ul class=\"contains-task-list\""))
    #expect(html.contains("<li class=\"task-list-item\" data-md-line=\"0\"><input type=\"checkbox\" disabled>one</li>"))
    #expect(html.contains("<li class=\"task-list-item checked\" data-md-line=\"1\"><input type=\"checkbox\" disabled checked>two</li>"))
    #expect(html.contains("<li>three</li>"))
}

@Test func taskListRespectsInlineMarkdown() {
    let md = "- [x] **bold** task"
    let html = MarkdownRenderer.renderHTML(from: md)
    #expect(html.contains("<strong>bold</strong> task</li>"))
}

@Test func plainBracketIsNotTaskList() {
    let md = "- [link](https://example.com)"
    let html = MarkdownRenderer.renderHTML(from: md)
    #expect(!html.contains("contains-task-list"))
    #expect(html.contains("<a href=\"https://example.com\">link</a>"))
}

@Test func taskListWithAsteriskBullet() {
    let md = "* [x] starred task"
    let html = MarkdownRenderer.renderHTML(from: md)
    #expect(html.contains("<ul class=\"contains-task-list\""))
    #expect(html.contains("<li class=\"task-list-item checked\" data-md-line=\"0\"><input type=\"checkbox\" disabled checked>starred task</li>"))
}

@Test func taskListAcceptsTabAfterMarker() {
    let md = "- [x]\tafter tab"
    let html = MarkdownRenderer.renderHTML(from: md)
    #expect(html.contains("<li class=\"task-list-item checked\" data-md-line=\"0\"><input type=\"checkbox\" disabled checked>"))
}

@Test func taskListWithoutTrailingText() {
    let md = "- [ ]"
    let html = MarkdownRenderer.renderHTML(from: md)
    #expect(html.contains("<li class=\"task-list-item\" data-md-line=\"0\"><input type=\"checkbox\" disabled></li>"))
}

@Test func dataLineOnHorizontalRule() {
    let md = """
    above

    ---

    middle

    ***

    between

    ___

    below
    """
    let html = MarkdownRenderer.renderHTML(from: md)
    #expect(html.contains("<hr data-line=\"2\">"))
    #expect(html.contains("<hr data-line=\"6\">"))
    #expect(html.contains("<hr data-line=\"10\">"))
}

@Test func nestedBulletListInsideParentItem() {
    let md = """
    - a
      - b
      - c
    - d
    """
    let html = MarkdownRenderer.renderHTML(from: md)
    #expect(html.contains("<li>a\n<ul data-line=\"1\">\n<li>b</li>\n<li>c</li>\n</ul>\n</li>\n<li>d</li>\n</ul>"))
    #expect(occurrences(of: "<ul", in: html) == 2)
    #expect(!html.contains("<p "))
    #expect(!html.contains("- b"))
}

@Test func orderedListKeepsNumberingAfterNestedBullets() {
    let md = """
    1. one
       - sub
    2. two
    3. three
    """
    let html = MarkdownRenderer.renderHTML(from: md)
    #expect(html.contains("<ol data-line=\"0\">\n<li>one\n<ul data-line=\"1\">\n<li>sub</li>\n</ul>\n</li>\n<li>two</li>\n<li>three</li>\n</ol>"))
    #expect(occurrences(of: "<ol", in: html) == 1)
    #expect(!html.contains("start="))
}

@Test func orderedListNestedInsideBulletItem() {
    let md = """
    - a
      1. x
      2. y
    - b
    """
    let html = MarkdownRenderer.renderHTML(from: md)
    #expect(html.contains("<ul data-line=\"0\">\n<li>a\n<ol data-line=\"1\">\n<li>x</li>\n<li>y</li>\n</ol>\n</li>\n<li>b</li>\n</ul>"))
}

@Test func blankLineBetweenItemsMakesListLoose() {
    let md = """
    * a
    * b

    * c
    """
    let html = MarkdownRenderer.renderHTML(from: md)
    #expect(html.contains("<li><p data-line=\"0\">a</p>\n</li>\n<li><p data-line=\"1\">b</p>\n</li>\n<li><p data-line=\"3\">c</p>\n</li>"))
    #expect(occurrences(of: "<ul", in: html) == 1)
}

@Test func continuationParagraphInsideListItem() {
    let md = """
    - a

      more para
    - b
    """
    let html = MarkdownRenderer.renderHTML(from: md)
    #expect(html.contains("<ul data-line=\"0\">\n<li><p data-line=\"0\">a</p>\n<p data-line=\"2\">more para</p>\n</li>\n<li><p data-line=\"3\">b</p>\n</li>\n</ul>"))
    #expect(occurrences(of: "<ul", in: html) == 1)
}

@Test func blankLinesNotBetweenItemsKeepListTight() {
    let nested = MarkdownRenderer.renderHTML(from: "- a\n  - b\n\n  - c\n- d")
    #expect(nested.contains("<ul data-line=\"0\">\n<li>a\n<ul data-line=\"1\">\n<li><p data-line=\"1\">b</p>\n</li>\n<li><p data-line=\"3\">c</p>\n</li>\n</ul>\n</li>\n<li>d</li>"))

    let code = MarkdownRenderer.renderHTML(from: "- a\n  ```\n  x\n\n  y\n  ```\n- b")
    #expect(code.contains("<li>a\n<pre data-line=\"1\"><code>x\n\ny</code></pre>\n</li>\n<li>b</li>"))
    #expect(!code.contains("<p "))

    let trailing = MarkdownRenderer.renderHTML(from: "- a\n- b\n\nafter para")
    #expect(trailing.contains("<li>a</li>\n<li>b</li>\n</ul>\n<p data-line=\"3\">after para</p>"))
}

@Test func strikethroughNeedsDoubleTilde() {
    let double = MarkdownRenderer.renderHTML(from: "a ~~x~~ b ~y~ c")
    #expect(double.contains("<p data-line=\"0\">a <del>x</del> b ~y~ c</p>"))
    #expect(occurrences(of: "<del>", in: double) == 1)

    let approx = MarkdownRenderer.renderHTML(from: "51M→~25M, prometheus 15M→~7M")
    #expect(approx.contains("<p data-line=\"0\">51M→~25M, prometheus 15M→~7M</p>"))
    #expect(!approx.contains("<del>"))
}

@Test(arguments: [
    ("- ~~a~~ and ~b~", "<li><del>a</del> and ~b~</li>"),
    ("> ~~a~~ and ~b~", "<p data-line=\"0\"><del>a</del> and ~b~</p>"),
    ("→→ ~~struck~~ and ~approx~", "<p data-line=\"0\">→→ <del>struck</del> and ~approx~</p>"),
])
func strikethroughAfterListOrQuotePrefix(_ md: String, _ expected: String) {
    #expect(MarkdownRenderer.renderHTML(from: md).contains(expected))
}

@Test func strikethroughOnLazyContinuationLine() {
    let list = MarkdownRenderer.renderHTML(from: "- foo\n~~bar~~")
    #expect(list.contains("<li>foo\n<del>bar</del></li>"))

    let quote = MarkdownRenderer.renderHTML(from: "> foo\n~~bar~~")
    #expect(quote.contains("<p data-line=\"0\">foo\n<del>bar</del></p>"))
}

@Test func bareUrlBecomesLink() {
    let html = MarkdownRenderer.renderHTML(from: "visit http://a.com, then https://b.org/x?q=1&r=2!")
    #expect(html.contains("<p data-line=\"0\">visit <a href=\"http://a.com\">http://a.com</a>, then <a href=\"https://b.org/x?q=1&amp;r=2\">https://b.org/x?q=1&amp;r=2</a>!</p>"))
}

@Test(arguments: [".", ",", ";", ":", "!", "?", ")", "]"])
func bareUrlExcludesTrailingPunctuation(_ mark: String) {
    let html = MarkdownRenderer.renderHTML(from: "go https://example.com/a\(mark) now")
    #expect(html.contains("go <a href=\"https://example.com/a\">https://example.com/a</a>\(mark) now"))
}

@Test func bareUrlKeepsBalancedParentheses() {
    let url = "https://en.wikipedia.org/wiki/Swift_(programming_language)"
    let html = MarkdownRenderer.renderHTML(from: url)
    #expect(html.contains("<a href=\"\(url)\">\(url)</a></p>"))
}

@Test(arguments: [
    ("[go to https://x.com now](https://y.com)", "<p data-line=\"0\"><a href=\"https://y.com\">go to https://x.com now</a></p>", 1),
    ("<https://example.com>", "<p data-line=\"0\"><a href=\"https://example.com\">https://example.com</a></p>", 1),
    ("`https://example.com`", "<p data-line=\"0\"><code>https://example.com</code></p>", 0),
])
func autolinkSkipsExistingLinksAndCode(_ md: String, _ expected: String, _ linkCount: Int) {
    let html = MarkdownRenderer.renderHTML(from: md)
    #expect(html.contains(expected))
    #expect(occurrences(of: "<a ", in: html) == linkCount)
}

@Test func rawHtmlIsEscaped() {
    let block = MarkdownRenderer.renderHTML(from: "<script>alert(1)</script>")
    #expect(block.contains("<p data-line=\"0\">&lt;script&gt;alert(1)&lt;/script&gt;</p>"))
    #expect(!block.contains("<script"))

    let inline = MarkdownRenderer.renderHTML(from: "text <b>bold</b> <img src=x onerror=alert(1)>")
    #expect(inline.contains("<p data-line=\"0\">text &lt;b&gt;bold&lt;/b&gt; &lt;img src=x onerror=alert(1)&gt;</p>"))
    #expect(!inline.contains("<b>"))
    #expect(!inline.contains("<img"))
}

@Test func bareTaskMarkersRenderAsEmptyTasks() {
    let md = """
    - [ ]
    - [x]
    """
    let html = MarkdownRenderer.renderHTML(from: md)
    #expect(html.contains("<ul class=\"contains-task-list\" data-line=\"0\">"))
    #expect(html.contains("<li class=\"task-list-item\" data-md-line=\"0\"><input type=\"checkbox\" disabled></li>"))
    #expect(html.contains("<li class=\"task-list-item checked\" data-md-line=\"1\"><input type=\"checkbox\" disabled checked></li>"))
    #expect(!html.contains("[ ]"))
    #expect(!html.contains("[x]"))
}

@Test func escapedTaskBracketsStayLiteral() {
    let html = MarkdownRenderer.renderHTML(from: "- \\[ \\]")
    #expect(html.contains("<li>[ ]</li>"))
    #expect(!html.contains("task-list-item"))
    #expect(!html.contains("<input"))
}

@Test func taskItemsInOrderedList() {
    let md = """
    1. [ ] first
    2. [x] second
    """
    let html = MarkdownRenderer.renderHTML(from: md)
    #expect(html.contains("<ol data-line=\"0\">\n<li class=\"task-list-item\" data-md-line=\"0\"><input type=\"checkbox\" disabled>first</li>\n<li class=\"task-list-item checked\" data-md-line=\"1\"><input type=\"checkbox\" disabled checked>second</li>\n</ol>"))
    #expect(!html.contains("[ ]"))
    #expect(!html.contains("[x]"))
}

@Test func nestedTaskItemPointsToOwnLine() {
    let md = """
    Tasks:

    1. plan
       - [ ] draft
       - [x] review
    2. ship
    """
    let html = MarkdownRenderer.renderHTML(from: md)
    #expect(html.contains("<ol data-line=\"2\">\n<li>plan\n<ul class=\"contains-task-list\" data-line=\"3\">"))
    #expect(html.contains("<li class=\"task-list-item\" data-md-line=\"3\"><input type=\"checkbox\" disabled>draft</li>"))
    #expect(html.contains("<li class=\"task-list-item checked\" data-md-line=\"4\"><input type=\"checkbox\" disabled checked>review</li>"))
    #expect(html.contains("</ul>\n</li>\n<li>ship</li>\n</ol>"))
}

@Test func looseTaskItemKeepsCheckboxFirst() {
    let md = """
    - [x] task

      paragraph in task
    """
    let html = MarkdownRenderer.renderHTML(from: md)
    #expect(html.contains("<li class=\"task-list-item checked\" data-md-line=\"0\"><input type=\"checkbox\" disabled checked><p data-line=\"0\">task</p>\n<p data-line=\"2\">paragraph in task</p>\n</li>"))
}

@Test func dataLineOnNestedBlocks() {
    let md = """
    intro

    - item
      > quoted
    - next
      ```
      code
      ```
    """
    let html = MarkdownRenderer.renderHTML(from: md)
    #expect(html.contains("<li>item\n<blockquote data-line=\"3\">\n<p data-line=\"3\">quoted</p>\n</blockquote>\n</li>"))
    #expect(html.contains("<li>next\n<pre data-line=\"5\"><code>code</code></pre>\n</li>"))
}

@Test(arguments: [
    ("![alt text](img.png)", "<p data-line=\"0\"><img src=\"img.png\" alt=\"alt text\"></p>"),
    ("![say \"hi\"](a.png)", "<p data-line=\"0\"><img src=\"a.png\" alt=\"say &quot;hi&quot;\"></p>"),
])
func imageRendersAsImgTag(_ md: String, _ expected: String) {
    #expect(MarkdownRenderer.renderHTML(from: md).contains(expected))
}

@Test func punctuationStaysAsTyped() {
    let html = MarkdownRenderer.renderHTML(from: "a -- b --- \"dq\" 'sq' ...")
    #expect(html.contains("<p data-line=\"0\">a -- b --- &quot;dq&quot; 'sq' ...</p>"))
    for smart in ["–", "—", "“", "”", "‘", "’", "…"] {
        #expect(!html.contains(smart))
    }
}

@Test(arguments: [
    ("## Частина 1", "<h2 id=\"частина-1\" data-line=\"0\">Частина 1</h2>"),
    ("## snake_case & kebab-case", "<h2 id=\"snake_case--kebab-case\" data-line=\"0\">snake_case &amp; kebab-case</h2>"),
    ("## !!!", "<h2 data-line=\"0\">!!!</h2>"),
])
func headingGetsGitHubStyleAnchor(_ md: String, _ expected: String) {
    #expect(MarkdownRenderer.renderHTML(from: md).contains(expected))
}

@Test func repeatedHeadingsGetNumberedAnchors() {
    let html = MarkdownRenderer.renderHTML(from: "## Setup\n\n## Setup\n\n## SETUP")
    #expect(html.contains("<h2 id=\"setup\" data-line=\"0\">Setup</h2>"))
    #expect(html.contains("<h2 id=\"setup-1\" data-line=\"2\">Setup</h2>"))
    #expect(html.contains("<h2 id=\"setup-2\" data-line=\"4\">SETUP</h2>"))
}

@Test func numberedAnchorDoesNotCollideWithLiteralHeading() {
    let html = MarkdownRenderer.renderHTML(from: "## Example\n\n## Example\n\n## Example 1")
    #expect(html.contains("<h2 id=\"example\" data-line=\"0\">Example</h2>"))
    #expect(html.contains("<h2 id=\"example-1\" data-line=\"2\">Example</h2>"))
    #expect(html.contains("<h2 id=\"example-1-1\" data-line=\"4\">Example 1</h2>"))
}

@Test func headingWithoutLettersOrDigitsHasNoAnchor() {
    let html = MarkdownRenderer.renderHTML(from: "## 🚀 ✨")
    #expect(html.contains("<h2 data-line=\"0\">🚀 ✨</h2>"))
}

@Test(arguments: [
    ("[x](JavaScript:alert(1))", "<a>x</a>"),
    ("[x](vbscript:msgbox(1))", "<a>x</a>"),
    ("[x](data:text/html;base64,PHNjcmlwdD4=)", "<a>x</a>"),
    ("[x](java&#9;script:alert(1))", "<a>x</a>"),
    ("[x](<\u{1}javascript:alert(1)>)", "<a>x</a>"),
    ("<javascript:alert(1)>", "<a>javascript:alert(1)</a>"),
])
func scriptLinkRendersWithoutHref(_ md: String, _ expected: String) {
    let html = MarkdownRenderer.renderHTML(from: md)
    #expect(html.contains(expected))
    #expect(!html.contains("href"))
}

@Test func ordinaryLinksKeepHref() {
    let html = MarkdownRenderer.renderHTML(from: "[a](javascript-notes.md) [b](data/report.md) [c](#part-1)")
    #expect(html.contains("<a href=\"javascript-notes.md\">a</a> <a href=\"data/report.md\">b</a> <a href=\"#part-1\">c</a>"))
}

@Test(arguments: [
    ("![a](pic.png)", "md-asset://local/docs/notes/pic.png"),
    ("![a](<фото 1.png>)", "md-asset://local/docs/notes/%D1%84%D0%BE%D1%82%D0%BE%201.png"),
    ("![a](https://example.com/pic.png)", "https://example.com/pic.png"),
    ("![a](data:image/png;base64,iVBORw0KGgo=)", "data:image/png;base64,iVBORw0KGgo="),
])
func imageSourceResolvesAgainstDocumentFolder(_ md: String, _ src: String) {
    let html = MarkdownRenderer.renderHTML(from: md, baseDirectory: URL(fileURLWithPath: "/docs/notes", isDirectory: true))
    #expect(html.contains("<img src=\"\(src)\" alt=\"a\">"))
}

@Test func absoluteImageLoadsWithoutDocumentFolder() {
    let html = MarkdownRenderer.renderHTML(from: "![a](/shared/pic.png)")
    #expect(html.contains("<img src=\"md-asset://local/shared/pic.png\" alt=\"a\">"))
}

private func occurrences(of needle: String, in html: String) -> Int {
    html.components(separatedBy: needle).count - 1
}

private func expectOutline(_ md: String, _ expected: [OutlineItem], sourceLocation: SourceLocation = #_sourceLocation) {
    let rendered = MarkdownRenderer.render(md)
    #expect(rendered.outline == expected, sourceLocation: sourceLocation)
    for item in expected {
        let heading = "<h\(item.level) id=\"\(item.id)\" data-line=\"\(item.line)\">"
        #expect(rendered.html.contains(heading), "heading anchor must equal outline id \(item.id)", sourceLocation: sourceLocation)
    }
}

@Test func outlineListsHeadingsWithAnchorsAndLines() {
    let md = """
    # Guide

    Intro text.

    ## Install

    ### From source

    ## 🚀 ✨

    ## Usage
    """
    expectOutline(md, [
        OutlineItem(id: "guide", level: 1, title: "Guide", line: 0),
        OutlineItem(id: "install", level: 2, title: "Install", line: 4),
        OutlineItem(id: "from-source", level: 3, title: "From source", line: 6),
        OutlineItem(id: "usage", level: 2, title: "Usage", line: 10),
    ])
}

@Test func outlineTitleDropsEmphasisAndLinks() {
    expectOutline("## **Read** the *latest* [docs](https://example.com)", [
        OutlineItem(id: "read-the-latest-docs", level: 2, title: "Read the latest docs", line: 0),
    ])
}

@Test func outlineTitleDropsInlineCodeBackticks() {
    expectOutline("## Hello *world* `x`", [
        OutlineItem(id: "hello-world-x", level: 2, title: "Hello world x", line: 0),
    ])
}

@Test func outlineNumbersRepeatedHeadingsLikeAnchors() {
    expectOutline("## Example\n\n## Example\n\n## Example 1", [
        OutlineItem(id: "example", level: 2, title: "Example", line: 0),
        OutlineItem(id: "example-1", level: 2, title: "Example", line: 2),
        OutlineItem(id: "example-1-1", level: 2, title: "Example 1", line: 4),
    ])
}

@Test func outlineLeavesOutHeadingsWithoutAnchor() {
    #expect(MarkdownRenderer.render("## 🚀 ✨\n\n## !!!\n\nplain text").outline.isEmpty)
}

@Test func outlineIgnoresHashLinesInsideCodeBlock() {
    expectOutline("```bash\n# install deps\nnpm i\n```\n\n## Run", [
        OutlineItem(id: "run", level: 2, title: "Run", line: 5),
    ])
}

@Test func outlineIncludesUnderlinedHeadings() {
    expectOutline("Guide\n=====\n\nSetup\n-----", [
        OutlineItem(id: "guide", level: 1, title: "Guide", line: 0),
        OutlineItem(id: "setup", level: 2, title: "Setup", line: 3),
    ])
}
