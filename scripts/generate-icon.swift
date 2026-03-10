#!/usr/bin/env swift
import Cocoa

// Generate a simple app icon with "MD" text and a document symbol
let sizes: [(CGFloat, String)] = [
    (16, "icon_16x16"),
    (32, "icon_16x16@2x"),
    (32, "icon_32x32"),
    (64, "icon_32x32@2x"),
    (128, "icon_128x128"),
    (256, "icon_128x128@2x"),
    (256, "icon_256x256"),
    (512, "icon_256x256@2x"),
    (512, "icon_512x512"),
    (1024, "icon_512x512@2x"),
]

func renderIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    let ctx = NSGraphicsContext.current!.cgContext

    // Background rounded rect
    let inset = size * 0.05
    let rect = CGRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
    let cornerRadius = size * 0.2
    let path = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)

    // Gradient background
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let gradient = CGGradient(
        colorsSpace: colorSpace,
        colors: [
            CGColor(red: 0.15, green: 0.35, blue: 0.85, alpha: 1.0),
            CGColor(red: 0.30, green: 0.55, blue: 0.95, alpha: 1.0),
        ] as CFArray,
        locations: [0.0, 1.0]
    )!

    ctx.saveGState()
    ctx.addPath(path)
    ctx.clip()
    ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: size), end: CGPoint(x: size, y: 0), options: [])
    ctx.restoreGState()

    // Draw "MD" text
    let fontSize = size * 0.38
    let font = NSFont.systemFont(ofSize: fontSize, weight: .bold)
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor.white,
    ]
    let text = "MD" as NSString
    let textSize = text.size(withAttributes: attrs)
    let textX = (size - textSize.width) / 2
    let textY = (size - textSize.height) / 2 - size * 0.02
    text.draw(at: NSPoint(x: textX, y: textY), withAttributes: attrs)

    // Draw small document icon above
    let smallSize = size * 0.14
    let docX = (size - smallSize) / 2
    let docY = textY + textSize.height + size * 0.02
    let docRect = CGRect(x: docX, y: docY, width: smallSize, height: smallSize * 1.2)
    let docPath = CGPath(roundedRect: docRect, cornerWidth: size * 0.02, cornerHeight: size * 0.02, transform: nil)
    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.9))
    ctx.addPath(docPath)
    ctx.fillPath()

    image.unlockFocus()
    return image
}

// Create iconset directory
let iconsetPath = "Sources/MDReaderApp/Resources/AppIcon.iconset"
let fm = FileManager.default
try? fm.createDirectory(atPath: iconsetPath, withIntermediateDirectories: true)

for (size, name) in sizes {
    let image = renderIcon(size: size)
    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:]) else {
        fputs("Failed to render \(name)\n", stderr)
        continue
    }
    let path = "\(iconsetPath)/\(name).png"
    try png.write(to: URL(fileURLWithPath: path))
}

print("Generated iconset at \(iconsetPath)")
print("Converting to .icns...")

// Convert iconset to icns
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconsetPath, "-o", "Sources/MDReaderApp/Resources/AppIcon.icns"]
try process.run()
process.waitUntilExit()

if process.terminationStatus == 0 {
    // Clean up iconset
    try? fm.removeItem(atPath: iconsetPath)
    print("Done: Sources/MDReaderApp/Resources/AppIcon.icns")
} else {
    fputs("iconutil failed\n", stderr)
}
