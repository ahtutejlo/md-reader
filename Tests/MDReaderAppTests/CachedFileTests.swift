import XCTest
@testable import MDReaderApp

final class CachedFileTests: XCTestCase {
    private func makeFile(path: String) -> CachedFile {
        // Bypass the throwing init(url:) which hits the filesystem — decode from JSON instead.
        let json = """
        {"path":"\(path)","lastOpened":0,"isFavorite":false}
        """.data(using: .utf8)!
        return try! JSONDecoder().decode(CachedFile.self, from: json)
    }

    func test_displayPath_collapsesHomeDirectoryToTilde() {
        let home = NSHomeDirectory()
        let file = makeFile(path: "\(home)/projects/md-reader/README.md")
        XCTAssertEqual(file.displayPath, "~/projects/md-reader/README.md")
    }

    func test_displayPath_leavesNonHomePathsUntouched() {
        let file = makeFile(path: "/tmp/scratch/notes.md")
        XCTAssertEqual(file.displayPath, "/tmp/scratch/notes.md")
    }

    func test_displayPath_doesNotCollapsePathsThatMerelyStartWithHomePrefix() {
        let home = NSHomeDirectory()
        let sibling = home + "-backup/foo.md"
        let file = makeFile(path: sibling)
        XCTAssertEqual(file.displayPath, sibling)
    }
}
