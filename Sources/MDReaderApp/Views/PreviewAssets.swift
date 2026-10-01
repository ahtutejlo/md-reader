import Foundation

enum PreviewAssets {
    // A literal "</script" would end the inline <script> element early.
    static let highlightScript = load("highlight.min", "js").replacingOccurrences(of: "</script", with: "<\\/script")
    static let lightTheme = load("github.min", "css")
    static let darkTheme = load("github-dark.min", "css")

    private static func load(_ name: String, _ ext: String) -> String {
        guard let url = Bundle.module.url(forResource: name, withExtension: ext, subdirectory: "highlight") else { return "" }
        return (try? String(contentsOf: url, encoding: .utf8)) ?? ""
    }
}
