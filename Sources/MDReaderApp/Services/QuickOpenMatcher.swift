import Foundation

/// Query letters must appear in the file name in order ("rdme" finds README.md);
/// path-only matches rank after every name match.
enum QuickOpenMatcher {
    static func rank(_ files: [CachedFile], query: String) -> [CachedFile] {
        let query = query.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return files }
        let scored = files.enumerated().compactMap { offset, file -> (file: CachedFile, score: Int, offset: Int)? in
            if let score = subsequenceScore(of: query, in: file.name) {
                return (file, 1000 + score, offset)
            }
            if file.displayPath.localizedCaseInsensitiveContains(query) {
                return (file, 0, offset)
            }
            return nil
        }
        return scored
            .sorted { $0.score != $1.score ? $0.score > $1.score : $0.offset < $1.offset }
            .map(\.file)
    }

    static func subsequenceScore(of query: String, in candidate: String) -> Int? {
        let haystack = Array(candidate.lowercased())
        var score = 0
        var searchFrom = 0
        var previous = -2
        for character in query.lowercased() {
            guard let index = haystack[searchFrom...].firstIndex(of: character) else { return nil }
            score += index == previous + 1 ? 5 : 1
            if index == 0 {
                score += 10
            }
            previous = index
            searchFrom = index + 1
        }
        return score
    }
}
