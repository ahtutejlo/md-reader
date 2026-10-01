import Foundation
import Testing
@testable import MDReaderApp

private let recentPaths = [
    "/work/rdme-archive/index.md",
    "/work/notes/draft.md",
    "/work/a/x-r-d-m-e.md",
    "/work/b/README.md",
    "/work/a/old-readme.md",
    "/work/a/README.md",
]

private func recentFile(_ path: String) throws -> CachedFile {
    let json = try JSONSerialization.data(withJSONObject: ["path": path, "lastOpened": 0])
    return try JSONDecoder().decode(CachedFile.self, from: json)
}

@Test(arguments: ["rdme", "  RdMe "])
func rankOrdersNameMatchesByScoreThenPathMatches(_ query: String) throws {
    let ranked = QuickOpenMatcher.rank(try recentPaths.map(recentFile), query: query)
    #expect(ranked.map(\.path) == [
        "/work/b/README.md",
        "/work/a/README.md",
        "/work/a/old-readme.md",
        "/work/a/x-r-d-m-e.md",
        "/work/rdme-archive/index.md",
    ])
}

@Test func rankMatchesLettersInOrderWithinFileName() throws {
    let files = try [
        "/work/fix-shared.md",
        "/work/shared/fix/notes.md",
        "/work/2026-09-29-shared-line-fix-for-shay.md",
    ].map(recentFile)
    #expect(QuickOpenMatcher.rank(files, query: "shrdfix").map(\.path) == ["/work/2026-09-29-shared-line-fix-for-shay.md"])
}

@Test(arguments: ["", "   "])
func rankKeepsRecentOrderForBlankQuery(_ query: String) throws {
    #expect(QuickOpenMatcher.rank(try recentPaths.map(recentFile), query: query).map(\.path) == recentPaths)
}

@Test(arguments: [
    ("/work/old-readme.md", "/work/old-r-d-m-e.md"),
    ("/work/readme-old.md", "/work/old-readme.md"),
])
func rankPutsCloserNameMatchFirst(_ closer: String, _ looser: String) throws {
    let ranked = QuickOpenMatcher.rank(try [looser, closer].map(recentFile), query: "rdme")
    #expect(ranked.map(\.path) == [closer, looser])
}

@Test(arguments: ["emdr", "ddd"])
func rankExcludesOutOfOrderOrMissingLetters(_ query: String) throws {
    #expect(QuickOpenMatcher.rank([try recentFile("/work/README.md")], query: query).isEmpty)
}
