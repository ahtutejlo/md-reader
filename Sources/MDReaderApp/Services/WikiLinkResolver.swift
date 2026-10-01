import Foundation

/// Resolves `[[name]]`: a same-named note in the open note's folder, then anywhere in
/// its Obsidian vault, then a note in that folder whose `name:`/`aliases:` matches.
enum WikiLinkResolver {
    private static let maxVaultFiles = 20_000
    private static let frontMatterBytes = 4096

    static func resolve(_ name: String, from directory: URL) -> URL? {
        let wanted = (LinkRouter.markdownExtensions.contains((name as NSString).pathExtension.lowercased()) ? name : name + ".md").lowercased()
        let vault = vaultRoot(containing: directory)
        if name.contains("/") {
            return [directory, vault].compactMap { $0 }
                .map { $0.appendingPathComponent(wanted).standardizedFileURL }
                .first { FileManager.default.fileExists(atPath: $0.path) }
        }
        let siblings = markdownFiles(in: directory)
        if let match = siblings.first(where: { $0.lastPathComponent.lowercased() == wanted }) {
            return match
        }
        if let vault, let match = vaultFile(named: wanted, in: vault) {
            return match
        }
        return siblings.first { frontMatterNames(of: $0).contains { $0.caseInsensitiveCompare(name) == .orderedSame } }
    }

    static func vaultRoot(containing directory: URL, fileManager: FileManager = .default) -> URL? {
        ProjectLocator.nearestAncestor(of: directory.standardizedFileURL.path, containing: ".obsidian", fileManager: fileManager)
            .map { URL(fileURLWithPath: $0, isDirectory: true) }
    }

    private static func markdownFiles(in directory: URL) -> [URL] {
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)) ?? []
        return files
            .filter { LinkRouter.markdownExtensions.contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    private static func vaultFile(named wanted: String, in vault: URL) -> URL? {
        guard let enumerator = FileManager.default.enumerator(at: vault, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles, .skipsPackageDescendants]) else { return nil }
        return enumerator.prefix(maxVaultFiles)
            .compactMap { $0 as? URL }
            .filter { $0.lastPathComponent.lowercased() == wanted }
            .min { ($0.pathComponents.count, $0.path) < ($1.pathComponents.count, $1.path) }
    }

    private static func frontMatterNames(of file: URL) -> [String] {
        guard let handle = try? FileHandle(forReadingFrom: file) else { return [] }
        defer { try? handle.close() }
        guard let head = try? handle.read(upToCount: frontMatterBytes) else { return [] }
        let text = String(decoding: head, as: UTF8.self)
        guard text.hasPrefix("---"), let frontMatter = FrontMatter.parse(lines: text.components(separatedBy: "\n")) else { return [] }
        return frontMatter.entries
            .filter { ["name", "aliases", "alias"].contains($0.key) }
            .flatMap { $0.value.components(separatedBy: ", ") }
    }
}
