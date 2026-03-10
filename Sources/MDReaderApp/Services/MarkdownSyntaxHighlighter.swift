import AppKit

enum MarkdownSyntaxHighlighter {
    private static let monoFont = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
    private static let boldMonoFont = NSFont.monospacedSystemFont(ofSize: 14, weight: .bold)

    private static var headingFont: NSFont {
        NSFont.monospacedSystemFont(ofSize: 18, weight: .bold)
    }

    private static var subheadingFont: NSFont {
        NSFont.monospacedSystemFont(ofSize: 16, weight: .bold)
    }

    private static var fenceColor: NSColor {
        .secondaryLabelColor
    }

    private static var inlineCodeColor: NSColor {
        NSColor(red: 0.78, green: 0.24, blue: 0.24, alpha: 1.0)
    }

    private static var headingColor: NSColor {
        NSColor(red: 0.0, green: 0.35, blue: 0.85, alpha: 1.0)
    }

    private static var boldColor: NSColor {
        .labelColor
    }

    private static var linkColor: NSColor {
        NSColor(red: 0.0, green: 0.44, blue: 0.88, alpha: 1.0)
    }

    static func highlight(_ text: String) -> NSMutableAttributedString {
        let result = NSMutableAttributedString(
            string: text,
            attributes: [
                .font: monoFont,
                .foregroundColor: NSColor.labelColor
            ]
        )

        let fullRange = NSRange(location: 0, length: result.length)
        let nsString = text as NSString

        // Code blocks (fenced)
        applyPattern(#"^```.*$"#, to: result, in: fullRange, nsString: nsString, attrs: [
            .foregroundColor: fenceColor,
            .font: monoFont
        ])

        // Headings
        applyPattern(#"^#{1,6}\s+.*$"#, to: result, in: fullRange, nsString: nsString, attrs: [
            .foregroundColor: headingColor,
            .font: boldMonoFont
        ])

        // Bold **text**
        applyPattern(#"\*\*[^*]+\*\*"#, to: result, in: fullRange, nsString: nsString, attrs: [
            .font: boldMonoFont
        ])

        // Italic *text*
        applyPattern(#"(?<!\*)\*(?!\*)[^*]+\*(?!\*)"#, to: result, in: fullRange, nsString: nsString, attrs: [
            .font: NSFontManager.shared.convert(monoFont, toHaveTrait: .italicFontMask)
        ])

        // Inline code `text`
        applyPattern(#"`[^`]+`"#, to: result, in: fullRange, nsString: nsString, attrs: [
            .foregroundColor: inlineCodeColor,
            .font: monoFont
        ])

        // Links [text](url)
        applyPattern(#"\[[^\]]+\]\([^)]+\)"#, to: result, in: fullRange, nsString: nsString, attrs: [
            .foregroundColor: linkColor
        ])

        // Blockquote lines
        applyPattern(#"^>.*$"#, to: result, in: fullRange, nsString: nsString, attrs: [
            .foregroundColor: NSColor.secondaryLabelColor
        ])

        return result
    }

    private static func applyPattern(
        _ pattern: String,
        to attrString: NSMutableAttributedString,
        in range: NSRange,
        nsString: NSString,
        attrs: [NSAttributedString.Key: Any]
    ) {
        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: [.anchorsMatchLines]
        ) else { return }

        let matches = regex.matches(in: nsString as String, range: range)
        for match in matches {
            attrString.addAttributes(attrs, range: match.range)
        }
    }
}
