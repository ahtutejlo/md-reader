import Foundation

struct ProjectGroup<Item>: Identifiable {
    let id: String
    let name: String
    var items: [Item]
}

/// A file's project is its enclosing git repository, else its folder.
final class ProjectLocator {
    private var cache: [String: (id: String, name: String)] = [:]

    func project(for path: String) -> (id: String, name: String) {
        let folder = (path as NSString).deletingLastPathComponent
        if let cached = cache[folder] {
            return cached
        }
        let root = Self.repositoryRoot(containing: folder) ?? folder
        let name = root == NSHomeDirectory() ? "Home" : (root as NSString).lastPathComponent
        let project = (id: root, name: name)
        cache[folder] = project
        return project
    }

    func group<Item>(_ items: [Item], path: (Item) -> String) -> [ProjectGroup<Item>] {
        var groups: [ProjectGroup<Item>] = []
        var positions: [String: Int] = [:]
        for item in items {
            let project = project(for: path(item))
            if let index = positions[project.id] {
                groups[index].items.append(item)
            } else {
                positions[project.id] = groups.count
                groups.append(ProjectGroup(id: project.id, name: project.name, items: [item]))
            }
        }
        return groups
    }

    static func repositoryRoot(containing folder: String, fileManager: FileManager = .default) -> String? {
        nearestAncestor(of: folder, containing: ".git", fileManager: fileManager)
    }

    /// The closest folder at or above `folder`, below the home folder, that holds `marker`.
    static func nearestAncestor(of folder: String, containing marker: String, fileManager: FileManager = .default) -> String? {
        var current = folder
        while current != "/" && current != NSHomeDirectory() && !current.isEmpty {
            if fileManager.fileExists(atPath: (current as NSString).appendingPathComponent(marker)) {
                return current
            }
            current = (current as NSString).deletingLastPathComponent
        }
        return nil
    }
}
