import Foundation

/// Re-reads a file only when its modification date changes.
final class FileContentIndex {
    private var cache: [String: (modified: Date, text: String)] = [:]

    func snippet(in path: String, matching query: String) -> String? {
        guard let text = text(at: path),
              let match = text.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) else { return nil }
        return Self.snippet(of: text, around: match)
    }

    static func snippet(of text: String, around match: Range<String.Index>, context: Int = 30) -> String {
        let line = text.lineRange(for: match)
        let start = text.index(match.lowerBound, offsetBy: -context, limitedBy: line.lowerBound) ?? line.lowerBound
        let snippet = text[start..<line.upperBound].trimmingCharacters(in: .whitespacesAndNewlines)
        return start == line.lowerBound ? snippet : "…" + snippet
    }

    private func text(at path: String) -> String? {
        guard let modified = (try? FileManager.default.attributesOfItem(atPath: path))?[.modificationDate] as? Date else { return nil }
        if let cached = cache[path], cached.modified == modified {
            return cached.text
        }
        guard let text = try? String(contentsOfFile: path, encoding: .utf8) else { return nil }
        cache[path] = (modified, text)
        return text
    }
}
