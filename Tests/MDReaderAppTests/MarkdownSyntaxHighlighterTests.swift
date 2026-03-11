import Testing
import AppKit
@testable import MDReaderApp

@Test func highlightsHeading() {
    let text = "# Hello World"
    let highlighted = MarkdownSyntaxHighlighter.highlight(text)
    let attrs = highlighted.attributes(at: 0, effectiveRange: nil)
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
    let text = "```swift"
    let highlighted = MarkdownSyntaxHighlighter.highlight(text)
    let color = highlighted.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor
    // Fence lines use .secondaryLabelColor, not the default .labelColor
    #expect(color == NSColor.secondaryLabelColor)
}

@Test func plainTextUnchanged() {
    let text = "Just normal text"
    let highlighted = MarkdownSyntaxHighlighter.highlight(text)
    #expect(highlighted.string == text)
}
