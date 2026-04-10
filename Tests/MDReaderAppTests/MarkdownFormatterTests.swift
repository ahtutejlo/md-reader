import Testing
import Foundation
@testable import MDReaderApp

// MARK: - Bold (Task 2.2)

@Test func boldWrapsSelection() {
    let input = "hello world"
    let selection = NSRange(location: 6, length: 5)  // "world"
    let result = MarkdownFormatter.apply(.bold, to: input, selection: selection)
    #expect(result.text == "hello **world**")
    #expect(result.selection == NSRange(location: 8, length: 5))
}

@Test func boldToggleRemoves() {
    let input = "hello **world**"
    let selection = NSRange(location: 8, length: 5)  // "world"
    let result = MarkdownFormatter.apply(.bold, to: input, selection: selection)
    #expect(result.text == "hello world")
    #expect(result.selection == NSRange(location: 6, length: 5))
}

@Test func boldOnEmptyString() {
    let result = MarkdownFormatter.apply(.bold, to: "", selection: NSRange(location: 0, length: 0))
    #expect(result.text == "****")
    #expect(result.selection == NSRange(location: 2, length: 0))
}

// MARK: - Inline (Task 2.3)

@Test func italicWrapsSelection() {
    let result = MarkdownFormatter.apply(
        .italic,
        to: "an apple",
        selection: NSRange(location: 3, length: 5)
    )
    #expect(result.text == "an *apple*")
    #expect(result.selection == NSRange(location: 4, length: 5))
}

@Test func codeWrapsSelection() {
    let result = MarkdownFormatter.apply(
        .code,
        to: "call foo now",
        selection: NSRange(location: 5, length: 3)
    )
    #expect(result.text == "call `foo` now")
    #expect(result.selection == NSRange(location: 6, length: 3))
}

@Test func strikethroughWrapsSelection() {
    let result = MarkdownFormatter.apply(
        .strikethrough,
        to: "old value",
        selection: NSRange(location: 0, length: 3)
    )
    #expect(result.text == "~~old~~ value")
    #expect(result.selection == NSRange(location: 2, length: 3))
}

// MARK: - Link (Task 2.4)

@Test func linkWrapsSelectionCursorOnURL() {
    let result = MarkdownFormatter.apply(
        .link,
        to: "click here to learn",
        selection: NSRange(location: 0, length: 10)  // "click here"
    )
    #expect(result.text == "[click here](url) to learn")
    #expect(result.selection == NSRange(location: 13, length: 3))  // "url"
}

@Test func linkEmptySelectionCursorBetweenBrackets() {
    let result = MarkdownFormatter.apply(
        .link,
        to: "hello",
        selection: NSRange(location: 5, length: 0)
    )
    #expect(result.text == "hello[](url)")
    #expect(result.selection == NSRange(location: 6, length: 0))
}

// MARK: - Heading (Task 2.5)

@Test func headingPrefixesCurrentLine() {
    let result = MarkdownFormatter.apply(
        .heading(level: 1),
        to: "title\nbody",
        selection: NSRange(location: 2, length: 0)  // cursor inside "title"
    )
    #expect(result.text == "# title\nbody")
    #expect(result.selection == NSRange(location: 4, length: 0))
}

@Test func headingOnMultilineSelection() {
    let result = MarkdownFormatter.apply(
        .heading(level: 2),
        to: "one\ntwo\nthree",
        selection: NSRange(location: 0, length: 7)  // "one\ntwo"
    )
    #expect(result.text == "## one\n## two\nthree")
}

@Test func headingToggleRemoves() {
    let result = MarkdownFormatter.apply(
        .heading(level: 1),
        to: "# title",
        selection: NSRange(location: 3, length: 0)  // cursor inside "title"
    )
    #expect(result.text == "title")
}

@Test func headingUpgradeReplacesLevel() {
    let result = MarkdownFormatter.apply(
        .heading(level: 2),
        to: "# title",
        selection: NSRange(location: 3, length: 0)
    )
    #expect(result.text == "## title")
}

// MARK: - Lists and Quote (Task 2.6)

@Test func unorderedListMultiline() {
    let result = MarkdownFormatter.apply(
        .unorderedList,
        to: "one\ntwo\nthree",
        selection: NSRange(location: 0, length: 13)
    )
    #expect(result.text == "- one\n- two\n- three")
}

@Test func unorderedListToggleRemoves() {
    let result = MarkdownFormatter.apply(
        .unorderedList,
        to: "- one\n- two",
        selection: NSRange(location: 0, length: 11)
    )
    #expect(result.text == "one\ntwo")
}

@Test func orderedListNumbersLines() {
    let result = MarkdownFormatter.apply(
        .orderedList,
        to: "apple\nbanana\ncherry",
        selection: NSRange(location: 0, length: 19)
    )
    #expect(result.text == "1. apple\n2. banana\n3. cherry")
}

@Test func orderedListToggleRemoves() {
    let result = MarkdownFormatter.apply(
        .orderedList,
        to: "1. apple\n2. banana",
        selection: NSRange(location: 0, length: 18)
    )
    #expect(result.text == "apple\nbanana")
}

@Test func orderedListPreservesCursorOnFirstLine() {
    // Cursor is mid-line on "apple" at position 2 (the "p" between "a" and "p").
    // After numbering, the line becomes "1. apple" so the cursor should shift
    // to position 5 (still on the same character).
    let result = MarkdownFormatter.apply(
        .orderedList,
        to: "apple\nbanana",
        selection: NSRange(location: 2, length: 0)
    )
    #expect(result.text == "1. apple\nbanana")
    #expect(result.selection == NSRange(location: 5, length: 0))
}

@Test func quoteMultiline() {
    let result = MarkdownFormatter.apply(
        .quote,
        to: "line a\nline b",
        selection: NSRange(location: 0, length: 13)
    )
    #expect(result.text == "> line a\n> line b")
}

// MARK: - Code Block (Task 2.7)

@Test func codeBlockWrapsSelection() {
    let result = MarkdownFormatter.apply(
        .codeBlock,
        to: "before\nlet x = 1\nafter",
        selection: NSRange(location: 7, length: 9)  // "let x = 1"
    )
    #expect(result.text == "before\n```\nlet x = 1\n```\nafter")
}

// MARK: - Edge cases (Task 2.8)

@Test func selectionOutOfBoundsReturnsUnchanged() {
    let result = MarkdownFormatter.apply(
        .bold,
        to: "hi",
        selection: NSRange(location: 0, length: 99)
    )
    #expect(result.text == "hi")
    #expect(result.selection == NSRange(location: 0, length: 99))
}

@Test func emptyDocumentHeading() {
    let result = MarkdownFormatter.apply(
        .heading(level: 1),
        to: "",
        selection: NSRange(location: 0, length: 0)
    )
    #expect(result.text == "# ")
}
