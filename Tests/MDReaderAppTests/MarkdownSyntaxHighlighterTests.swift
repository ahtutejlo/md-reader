import Testing
import AppKit
@testable import MDReaderApp

@Test func highlightsHeading() {
    let text = "# Hello World"
    let highlighted = MarkdownSyntaxHighlighter.highlight(text)
    var attrs = highlighted.attributes(at: 0, effectiveRange: nil)
    let font = attrs[.font] as! NSFont
    #expect(font.fontDescriptor.symbolicTraits.contains(.bold))
}

@Test func highlightsInlineCode() {
    let text = "Use `code` here"
    let highlighted = MarkdownSyntaxHighlighter.highlight(text)
    let attrs = highlighted.attributes(at: 5, effectiveRange: nil)
    let font = attrs[.font] as! NSFont
    #expect(font.isFixedPitch)
}

@Test func highlightsCodeBlock() {
    let text = "```swift\nlet x = 1\n```"
    let highlighted = MarkdownSyntaxHighlighter.highlight(text)
    let attrs = highlighted.attributes(at: 0, effectiveRange: nil)
    #expect(attrs[.foregroundColor] != nil)
}

@Test func plainTextUnchanged() {
    let text = "Just normal text"
    let highlighted = MarkdownSyntaxHighlighter.highlight(text)
    #expect(highlighted.string == text)
}
