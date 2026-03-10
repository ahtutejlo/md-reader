import AppKit

enum MarkdownSyntaxHighlighter {
    private static let monoFont = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
    private static let boldMonoFont = NSFont.monospacedSystemFont(ofSize: 14, weight: .bold)

    private static var fenceColor: NSColor {
        .secondaryLabelColor
    }

    private static var inlineCodeColor: NSColor {
        NSColor(red: 0.78, green: 0.24, blue: 0.24, alpha: 1.0)
    }

    private static var headingColor: NSColor {
        NSColor(red: 0.0, green: 0.35, blue: 0.85, alpha: 1.0)
    }

    private static var linkColor: NSColor {
        NSColor(red: 0.0, green: 0.44, blue: 0.88, alpha: 1.0)
    }

    // MARK: - Cached Regex Patterns

    private static let fenceRegex = try! NSRegularExpression(pattern: #"^```.*$"#, options: [.anchorsMatchLines])
    private static let headingRegex = try! NSRegularExpression(pattern: #"^#{1,6}\s+.*$"#, options: [.anchorsMatchLines])
    private static let boldRegex = try! NSRegularExpression(pattern: #"\*\*[^*]+\*\*"#, options: [.anchorsMatchLines])
    private static let italicRegex = try! NSRegularExpression(pattern: #"(?<!\*)\*(?!\*)[^*]+\*(?!\*)"#, options: [.anchorsMatchLines])
    private static let inlineCodeRegex = try! NSRegularExpression(pattern: #"`[^`]+`"#, options: [.anchorsMatchLines])
    private static let linkRegex = try! NSRegularExpression(pattern: #"\[[^\]]+\]\([^)]+\)"#, options: [.anchorsMatchLines])
    private static let blockquoteRegex = try! NSRegularExpression(pattern: #"^>.*$"#, options: [.anchorsMatchLines])

    static func highlight(_ text: String) -> NSMutableAttributedString {
        let result = NSMutableAttributedString(
            string: text,
            attributes: [
                .font: monoFont,
                .foregroundColor: NSColor.labelColor
            ]
        )

        let fullRange = NSRange(location: 0, length: result.length)

        // Code blocks (fenced)
        applyRegex(fenceRegex, to: result, in: fullRange, text: text, attrs: [
            .foregroundColor: fenceColor,
            .font: monoFont
        ])

        // Headings
        applyRegex(headingRegex, to: result, in: fullRange, text: text, attrs: [
            .foregroundColor: headingColor,
            .font: boldMonoFont
        ])

        // Bold **text**
        applyRegex(boldRegex, to: result, in: fullRange, text: text, attrs: [
            .font: boldMonoFont
        ])

        // Italic *text*
        applyRegex(italicRegex, to: result, in: fullRange, text: text, attrs: [
            .font: NSFontManager.shared.convert(monoFont, toHaveTrait: .italicFontMask)
        ])

        // Inline code `text`
        applyRegex(inlineCodeRegex, to: result, in: fullRange, text: text, attrs: [
            .foregroundColor: inlineCodeColor,
            .font: monoFont
        ])

        // Links [text](url)
        applyRegex(linkRegex, to: result, in: fullRange, text: text, attrs: [
            .foregroundColor: linkColor
        ])

        // Blockquote lines
        applyRegex(blockquoteRegex, to: result, in: fullRange, text: text, attrs: [
            .foregroundColor: NSColor.secondaryLabelColor
        ])

        return result
    }

    private static func applyRegex(
        _ regex: NSRegularExpression,
        to attrString: NSMutableAttributedString,
        in range: NSRange,
        text: String,
        attrs: [NSAttributedString.Key: Any]
    ) {
        let matches = regex.matches(in: text, range: range)
        for match in matches {
            attrString.addAttributes(attrs, range: match.range)
        }
    }
}
