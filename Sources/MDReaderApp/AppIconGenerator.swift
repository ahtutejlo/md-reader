import AppKit

enum AppIconGenerator {
    static func generate(size: CGFloat = 512) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()

        guard let ctx = NSGraphicsContext.current?.cgContext else {
            image.unlockFocus()
            return image
        }

        // Rounded rect background
        let inset = size * 0.05
        let rect = CGRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
        let cornerRadius = size * 0.2
        let path = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)

        // Blue gradient
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        if let gradient = CGGradient(
            colorsSpace: colorSpace,
            colors: [
                CGColor(red: 0.15, green: 0.35, blue: 0.85, alpha: 1.0),
                CGColor(red: 0.30, green: 0.55, blue: 0.95, alpha: 1.0),
            ] as CFArray,
            locations: [0.0, 1.0]
        ) {
            ctx.saveGState()
            ctx.addPath(path)
            ctx.clip()
            ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: size), end: CGPoint(x: size, y: 0), options: [])
            ctx.restoreGState()
        }

        // "MD" text
        let fontSize = size * 0.38
        let font = NSFont.systemFont(ofSize: fontSize, weight: .bold)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white,
        ]
        let text = "MD" as NSString
        let textSize = text.size(withAttributes: attrs)
        let textX = (size - textSize.width) / 2
        let textY = (size - textSize.height) / 2
        text.draw(at: NSPoint(x: textX, y: textY), withAttributes: attrs)

        image.unlockFocus()
        return image
    }
}
