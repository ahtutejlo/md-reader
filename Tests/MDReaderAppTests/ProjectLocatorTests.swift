import Foundation
import Testing
@testable import MDReaderApp

enum GitEntry: CaseIterable {
    case directory, worktreeFile
}

private func makeRepo(at url: URL, git: GitEntry = .directory) throws {
    let marker = url.appendingPathComponent(".git")
    switch git {
    case .directory:
        try FileManager.default.createDirectory(at: marker, withIntermediateDirectories: true)
    case .worktreeFile:
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        try "gitdir: /elsewhere/.git/worktrees/feature".write(to: marker, atomically: true, encoding: .utf8)
    }
}

@Test(arguments: GitEntry.allCases)
func repositoryRootFindsGitEntryAboveFolder(_ git: GitEntry) throws {
    let root = try makeTempDir()
    defer { try? FileManager.default.removeItem(at: root) }
    let repo = root.appendingPathComponent("md-reader")
    try makeRepo(at: repo, git: git)

    #expect(ProjectLocator.repositoryRoot(containing: repo.appendingPathComponent("docs/plans").path) == repo.path)
}

@Test func repositoryRootPicksNearestRepository() throws {
    let root = try makeTempDir()
    defer { try? FileManager.default.removeItem(at: root) }
    let outer = root.appendingPathComponent("outer")
    let inner = outer.appendingPathComponent("vendor/inner")
    try makeRepo(at: outer)
    try makeRepo(at: inner)

    #expect(ProjectLocator.repositoryRoot(containing: inner.appendingPathComponent("docs").path) == inner.path)
    #expect(ProjectLocator.repositoryRoot(containing: outer.appendingPathComponent("docs").path) == outer.path)
}

@Test func repositoryRootIsNilOutsideRepository() throws {
    let root = try makeTempDir()
    defer { try? FileManager.default.removeItem(at: root) }

    #expect(ProjectLocator.repositoryRoot(containing: root.appendingPathComponent("notes/deep").path) == nil)
}

@Test func nearestAncestorFindsCustomMarkerBelowHomeOnly() throws {
    let root = try makeTempDir()
    defer { try? FileManager.default.removeItem(at: root) }
    let project = root.appendingPathComponent("project")
    try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
    try "".write(to: project.appendingPathComponent(".marker"), atomically: true, encoding: .utf8)

    #expect(ProjectLocator.nearestAncestor(of: project.appendingPathComponent("docs/deep").path, containing: ".marker") == project.path)
    // ~/Library always exists, so a walk that passed the home folder would return it.
    #expect(ProjectLocator.nearestAncestor(of: NSHomeDirectory() + "/\(UUID())/notes", containing: "Library") == nil)
}

@Test func projectInHomeFolderIsNamedHome() {
    let project = ProjectLocator().project(for: NSHomeDirectory() + "/notes-\(UUID()).md")
    #expect(project == (id: NSHomeDirectory(), name: "Home"))
}

@Test func groupKeepsRecentOrderInsideAndAcrossProjects() throws {
    let root = try makeTempDir()
    defer { try? FileManager.default.removeItem(at: root) }
    let alpha = root.appendingPathComponent("alpha")
    let beta = root.appendingPathComponent("beta")
    let loose = root.appendingPathComponent("loose")
    try makeRepo(at: alpha)
    try makeRepo(at: beta)
    let paths = [
        alpha.appendingPathComponent("README.md").path,
        loose.appendingPathComponent("todo.md").path,
        alpha.appendingPathComponent("docs/plan.md").path,
        beta.appendingPathComponent("notes.md").path,
        loose.appendingPathComponent("ideas.md").path,
    ]

    let groups = ProjectLocator().group(paths) { $0 }

    #expect(groups.map(\.name) == ["alpha", "loose", "beta"])
    #expect(groups.map(\.id) == [alpha.path, loose.path, beta.path])
    #expect(groups.map(\.items) == [[paths[0], paths[2]], [paths[1], paths[4]], [paths[3]]])
}

@Test func groupSeparatesRepositoriesWithSameFolderName() throws {
    let root = try makeTempDir()
    defer { try? FileManager.default.removeItem(at: root) }
    let work = root.appendingPathComponent("work/app")
    let personal = root.appendingPathComponent("personal/app")
    try makeRepo(at: work)
    try makeRepo(at: personal)
    let paths = [
        work.appendingPathComponent("a.md").path,
        personal.appendingPathComponent("b.md").path,
        work.appendingPathComponent("c.md").path,
    ]

    let groups = ProjectLocator().group(paths) { $0 }

    #expect(groups.map(\.name) == ["app", "app"])
    #expect(groups.map(\.id) == [work.path, personal.path])
    #expect(groups.map(\.items) == [[paths[0], paths[2]], [paths[1]]])
}
