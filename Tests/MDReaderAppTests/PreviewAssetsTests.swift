import Foundation
import Testing
@testable import MDReaderApp

private let shell = MarkdownWebView.shellHTML

private func firstElement(_ tag: String, opening open: String) -> String? {
    guard let start = shell.range(of: open),
          let end = shell.range(of: "</\(tag)", options: .caseInsensitive, range: start.upperBound..<shell.endIndex)
    else { return nil }
    return String(shell[start.upperBound..<end.lowerBound])
}

@Test func previewShellLoadsNothingFromNetwork() {
    let networkReference = #/(?:\b(?:src|href)\s*=\s*|url\(\s*|@import\s+)["']?\s*(?:https?:)?//|<link\b/#.ignoresCase()
    #expect(shell.matches(of: networkReference).map { String($0.output) } == [])
}

@Test func previewShellInlinesBundledHighlighter() throws {
    let script = try #require(firstElement("script", opening: "<script>"))
    #expect(script.contains("var hljs=function()"))
    #expect(script == PreviewAssets.highlightScript, "a </script inside highlight.js would cut the inline script short")
}

@Test(arguments: [
    ("light", ".hljs{color:#24292e;background:#fff}", "#0d1117"),
    ("dark", ".hljs{color:#c9d1d9;background:#0d1117}", "background:#fff}"),
])
func previewShellPicksThemeByColorScheme(_ scheme: String, _ themeRule: String, _ otherThemeBackground: String) throws {
    let style = try #require(firstElement("style", opening: "<style media=\"(prefers-color-scheme: \(scheme))\">"))
    #expect(style.contains(themeRule))
    #expect(!style.contains(otherThemeBackground))
}
