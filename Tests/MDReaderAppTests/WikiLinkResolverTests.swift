import Foundation
import Testing
@testable import MDReaderApp

private func makeVault() throws -> URL {
    let vault = try makeTempDir()
    try FileManager.default.createDirectory(at: vault.appendingPathComponent(".obsidian"), withIntermediateDirectories: true)
    return vault
}

@discardableResult
private func write(_ path: String, in root: URL, _ text: String = "# Note") throws -> URL {
    let url = root.appendingPathComponent(path)
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try text.write(to: url, atomically: true, encoding: .utf8)
    return url
}

private func standardPath(_ url: URL?) -> String? {
    url?.standardizedFileURL.path
}

private func resolved(_ link: String, from note: URL) -> String? {
    standardPath(WikiLinkResolver.resolve(link, from: note.deletingLastPathComponent()))
}

private final class MarkerFileManager: FileManager {
    private let existing: Set<String>

    init(existing: Set<String>) {
        self.existing = existing
        super.init()
    }

    override func fileExists(atPath path: String) -> Bool {
        existing.contains(path)
    }
}

private let sameFolderNotes = ["Project Plan.md", "guide.md", "spec.markdown", "1.0 release.md"]

@Test(arguments: zip(["project plan", "Guide.md", "spec.markdown", "1.0 Release"], sameFolderNotes))
func resolvesNoteInSameFolderIgnoringCase(_ link: String, _ file: String) throws {
    let folder = try makeTempDir()
    defer { try? FileManager.default.removeItem(at: folder) }
    let today = try write("today.md", in: folder)
    for name in sameFolderNotes {
        try write(name, in: folder)
    }

    #expect(resolved(link, from: today) == standardPath(folder.appendingPathComponent(file)))
}

@Test func sameFolderNoteWinsOverShorterVaultPath() throws {
    let vault = try makeVault()
    defer { try? FileManager.default.removeItem(at: vault) }
    try write("target.md", in: vault)
    let local = try write("projects/q3/target.md", in: vault)

    #expect(resolved("target", from: local) == standardPath(local))
}

@Test func resolvesNoteAnywhereInVaultPreferringShortestPath() throws {
    let vault = try makeVault()
    defer { try? FileManager.default.removeItem(at: vault) }
    let today = try write("daily/today.md", in: vault)
    try write("archive/2023/target.md", in: vault)
    let nearest = try write("projects/Target.md", in: vault)

    #expect(resolved("target", from: today) == standardPath(nearest))
}

@Test func equallyDeepVaultMatchesResolveToFirstPathInSortOrder() throws {
    let vault = try makeVault()
    defer { try? FileManager.default.removeItem(at: vault) }
    let today = try write("daily/today.md", in: vault)
    try write("beta/target.md", in: vault)
    let first = try write("alpha/target.md", in: vault)

    #expect(resolved("target", from: today) == standardPath(first))
}

@Test func vaultSearchSkipsHiddenFolders() throws {
    let vault = try makeVault()
    defer { try? FileManager.default.removeItem(at: vault) }
    let today = try write("daily/today.md", in: vault)
    try write(".trash/target.md", in: vault)
    try write(".obsidian/target.md", in: vault)

    #expect(resolved("target", from: today) == nil)
}

@Test func sameNameOutsideVaultIsNotFound() throws {
    let root = try makeTempDir()
    defer { try? FileManager.default.removeItem(at: root) }
    let today = try write("a/today.md", in: root)
    try write("b/target.md", in: root)
    try write("target.md", in: root)

    #expect(resolved("target", from: today) == nil)
    #expect(resolved("b/target", from: today) == nil)
}

@Test(arguments: [
    ("Feedback-Open-Markdown-Via-MDReader", "feedback_open_markdown_via_mdreader.md"),
    ("project start", "2024-01-01 kickoff.md"),
    ("SOLO NOTE", "solo.md"),
    ("bar baz", "inline.md"),
    ("crlf name", "crlf.md"),
])
func resolvesNoteByFrontMatterNameOrAlias(_ link: String, _ file: String) throws {
    let folder = try makeTempDir()
    defer { try? FileManager.default.removeItem(at: folder) }
    let today = try write("today.md", in: folder)
    try write("0-other-keys.md", in: folder, "---\ntitle: Project Start\nsummary: SOLO NOTE, Feedback-Open-Markdown-Via-MDReader\n---\n")
    try write("feedback_open_markdown_via_mdreader.md", in: folder, """
    ---
    name: feedback-open-markdown-via-mdreader
    description: "When the user wants to READ a markdown file"
    metadata:
      node_type: memory
      type: feedback
    ---
    """)
    try write("2024-01-01 kickoff.md", in: folder, "---\naliases:\n  - Kickoff\n  - Project Start\n---\n# Kickoff")
    try write("solo.md", in: folder, "---\nalias: Solo Note\n---\n")
    try write("inline.md", in: folder, "---\naliases: [Foo, \"Bar Baz\", 'Q']\n---\n")
    try write("crlf.md", in: folder, "---\r\nname: CRLF Name\r\n---\r\n# CRLF")

    #expect(resolved(link, from: today) == standardPath(folder.appendingPathComponent(file)))
}

@Test func fileNameMatchInVaultWinsOverLocalAlias() throws {
    let vault = try makeVault()
    defer { try? FileManager.default.removeItem(at: vault) }
    let holder = try write("daily/holder.md", in: vault, "---\naliases:\n  - target\n---\n")
    let target = try write("projects/target.md", in: vault)

    #expect(resolved("target", from: holder) == standardPath(target))
}

@Test func aliasInAnotherFolderIsNotUsed() throws {
    let vault = try makeVault()
    defer { try? FileManager.default.removeItem(at: vault) }
    let today = try write("daily/today.md", in: vault)
    try write("people/ann.md", in: vault, "---\nname: target\naliases:\n  - target\n---\n")

    #expect(resolved("target", from: today) == nil)
}

@Test(arguments: [
    ("plans/q3", "daily/plans/q3.md"),
    ("notes/x", "daily/notes/x.md"),
    ("projects/roadmap", "projects/roadmap.md"),
    ("projects/roadmap.md", "projects/roadmap.md"),
    ("../people/ann", "people/ann.md"),
])
func pathLinkResolvesFromFolderThenVaultRoot(_ link: String, _ file: String) throws {
    let vault = try makeVault()
    defer { try? FileManager.default.removeItem(at: vault) }
    let today = try write("daily/today.md", in: vault)
    for note in ["daily/plans/q3.md", "daily/notes/x.md", "notes/x.md", "projects/roadmap.md", "people/ann.md"] {
        try write(note, in: vault)
    }

    #expect(resolved(link, from: today) == standardPath(vault.appendingPathComponent(file)))
}

@Test(arguments: ["missing/target", "nobody"])
func unresolvableLinkIsNil(_ link: String) throws {
    let vault = try makeVault()
    defer { try? FileManager.default.removeItem(at: vault) }
    let today = try write("daily/today.md", in: vault)
    try write("daily/target.md", in: vault)
    try write("projects/plan.md", in: vault)

    #expect(resolved(link, from: today) == nil)
}

@Test func vaultRootIsNearestObsidianFolder() throws {
    let vault = try makeVault()
    defer { try? FileManager.default.removeItem(at: vault) }
    let team = vault.appendingPathComponent("team")
    try FileManager.default.createDirectory(at: team.appendingPathComponent(".obsidian"), withIntermediateDirectories: true)

    #expect(standardPath(WikiLinkResolver.vaultRoot(containing: team.appendingPathComponent("notes/deep"))) == standardPath(team))
    #expect(standardPath(WikiLinkResolver.vaultRoot(containing: vault.appendingPathComponent("personal"))) == standardPath(vault))
}

@Test func vaultRootIsNilOutsideVault() throws {
    let root = try makeTempDir()
    defer { try? FileManager.default.removeItem(at: root) }

    #expect(WikiLinkResolver.vaultRoot(containing: root.appendingPathComponent("notes/deep")) == nil)
}

@Test func vaultRootSearchStopsAtHomeFolder() {
    let home = NSHomeDirectory()
    let notes = URL(fileURLWithPath: home).appendingPathComponent("Documents/notes")
    let markersAtAndAboveHome = MarkerFileManager(existing: [home + "/.obsidian", (home as NSString).deletingLastPathComponent + "/.obsidian"])
    let markerInDocuments = MarkerFileManager(existing: [home + "/Documents/.obsidian"])

    #expect(WikiLinkResolver.vaultRoot(containing: notes, fileManager: markersAtAndAboveHome) == nil)
    #expect(WikiLinkResolver.vaultRoot(containing: notes, fileManager: markerInDocuments)?.path == home + "/Documents")
}

@Test func aliasLookupIgnoresNoteNotStartingWithFrontMatter() throws {
    let folder = try makeTempDir()
    defer { try? FileManager.default.removeItem(at: folder) }
    let today = try write("today.md", in: folder)
    try write("late.md", in: folder, "\n---\nname: target\n---\n")

    #expect(resolved("target", from: today) == nil)
}

@Test func aliasLookupMatchesWhenReadLimitSplitsMultiByteCharacter() throws {
    let folder = try makeTempDir()
    defer { try? FileManager.default.removeItem(at: folder) }
    let today = try write("today.md", in: folder)
    let header = "---\nname: target\n---\n"
    let note = try write("journal.md", in: folder, header + String(repeating: "x", count: 4095 - header.utf8.count) + "журнал")

    #expect(resolved("target", from: today) == standardPath(note))
}
