import Foundation
import Testing
@testable import MDReaderApp

private let notes = URL(fileURLWithPath: "/docs/notes", isDirectory: true)
private let home = FileManager.default.homeDirectoryForCurrentUser.path

private enum Route: Equatable {
    case external(String)
    case markdown(String)
    case localFile(String)
    case wikilink(String)
    case ignored
}

private func route(_ href: String, from directory: URL? = notes) -> Route {
    switch LinkRouter.target(for: href, relativeTo: directory) {
    case .external(let url): .external(url.absoluteString)
    case .markdown(let url): .markdown(url.path)
    case .localFile(let url): .localFile(url.path)
    case .wikilink(let name): .wikilink(name)
    case .ignored: .ignored
    }
}

@Test(arguments: [
    ("../other/readme.markdown", "/docs/other/readme.markdown"),
    ("guide.md#setup", "/docs/notes/guide.md"),
    ("C%23%20tips.md#intro", "/docs/notes/C# tips.md"),
    ("/shared/spec.md", "/shared/spec.md"),
    ("~/notes/todo.md", home + "/notes/todo.md"),
    ("file:///shared/My%20Spec.md#part", "/shared/My Spec.md"),
])
func markdownLinkOpensInApp(_ href: String, _ path: String) {
    #expect(route(href) == .markdown(path))
}

@Test(arguments: ["https://example.com/docs/guide.md", "mailto:team@example.com"])
func webAndMailLinksOpenExternally(_ href: String) {
    #expect(route(href) == .external(href))
}

@Test func otherLocalFileIsRevealedInFinder() {
    #expect(route("../assets/report.pdf") == .localFile("/docs/assets/report.pdf"))
    #expect(route("notes.md.bak") == .localFile("/docs/notes/notes.md.bak"))
}

@Test(arguments: [
    ("wikilink:My%20Note", "My Note"),
    ("wikilink:%D0%9D%D0%BE%D1%82%D0%B0%D1%82%D0%BA%D0%B0", "Нотатка"),
])
func wikilinkHrefNamesTheNote(_ href: String, _ name: String) {
    #expect(route(href) == .wikilink(name))
}

@Test(arguments: ["javascript:alert(1)", "vscode://file/docs/notes/guide.md", "", "#setup"])
func unsupportedLinkIsIgnored(_ href: String) {
    #expect(route(href) == .ignored)
}

@Test func unsavedDocumentFollowsOnlyAbsoluteLinks() {
    #expect(route("guide.md", from: nil) == .ignored)
    #expect(route("/shared/spec.md", from: nil) == .markdown("/shared/spec.md"))
}
