import Foundation

guard CommandLine.arguments.count > 1 else {
    fputs("Usage: mdreader <path-to-markdown-file>\n", stderr)
    exit(1)
}

let inputPath = CommandLine.arguments[1]
let fileURL = URL(fileURLWithPath: inputPath, relativeTo: URL(fileURLWithPath: FileManager.default.currentDirectoryPath))
let absolutePath = fileURL.standardized.path

guard FileManager.default.fileExists(atPath: absolutePath) else {
    fputs("Error: file not found: \(absolutePath)\n", stderr)
    exit(1)
}

guard absolutePath.hasSuffix(".md") || absolutePath.hasSuffix(".markdown") else {
    fputs("Error: not a markdown file: \(absolutePath)\n", stderr)
    exit(1)
}

let encoded = absolutePath.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? absolutePath
let urlString = "mdreader://\(encoded)"

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
process.arguments = [urlString]

do {
    try process.run()
    process.waitUntilExit()
} catch {
    fputs("Error: could not open MDReader app: \(error.localizedDescription)\n", stderr)
    exit(1)
}
