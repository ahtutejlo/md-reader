import Foundation

enum LinkTarget: Equatable {
    case external(URL)
    case markdown(URL)
    case localFile(URL)
    case ignored
}

enum LinkRouter {
    private static let externalSchemes: Set<String> = ["http", "https", "mailto"]
    static let markdownExtensions: Set<String> = ["md", "markdown"]

    static func target(for href: String, relativeTo directory: URL?) -> LinkTarget {
        let trimmed = href.trimmingCharacters(in: .whitespaces)
        if let url = URL(string: trimmed), let scheme = url.scheme?.lowercased(), externalSchemes.contains(scheme) {
            return .external(url)
        }
        guard let fileURL = fileURL(for: trimmed, relativeTo: directory) else { return .ignored }
        return markdownExtensions.contains(fileURL.pathExtension.lowercased()) ? .markdown(fileURL) : .localFile(fileURL)
    }

    /// Resolves a link or image reference to a local file: `file:` URLs, absolute
    /// and `~/` paths, and paths relative to `directory`. Any other scheme is nil.
    static func fileURL(for reference: String, relativeTo directory: URL?) -> URL? {
        let trimmed = reference.trimmingCharacters(in: .whitespaces)
        if let url = URL(string: trimmed), let scheme = url.scheme {
            return scheme.lowercased() == "file" ? url.standardizedFileURL : nil
        }
        let withoutFragment = String(trimmed.prefix { $0 != "#" })
        let path = ((withoutFragment.removingPercentEncoding ?? withoutFragment) as NSString).expandingTildeInPath
        guard !path.isEmpty else { return nil }
        if path.hasPrefix("/") {
            return URL(fileURLWithPath: path).standardizedFileURL
        }
        return directory.map { $0.appendingPathComponent(path).standardizedFileURL }
    }
}
