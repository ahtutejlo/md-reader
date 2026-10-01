import Foundation

/// The `---` YAML block at the top of an Obsidian note. Only the shapes notes use are
/// understood; anything else means the block is not front matter.
struct FrontMatter: Equatable {
    struct Entry: Equatable {
        let key: String
        var value: String

        mutating func append(_ text: String, separator: String = " ") {
            value = value.isEmpty ? text : value + separator + text
        }
    }

    let entries: [Entry]
    /// 0-based index of the closing `---` line.
    let closingLine: Int

    static func parse(lines: [String]) -> FrontMatter? {
        guard lines.first?.trimmed == "---",
              let closing = lines.indices.dropFirst().first(where: { ["---", "..."].contains(lines[$0].trimmed) })
        else { return nil }

        var entries: [Entry] = []
        var parent: String?
        var inBlockScalar = false
        for line in lines[1..<closing] {
            let trimmed = line.trimmed
            let isIndented = line.first == " " || line.first == "\t"
            if inBlockScalar && isIndented && !trimmed.isEmpty {
                entries[entries.count - 1].append(trimmed)
                continue
            }
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
            inBlockScalar = false

            let pair = keyValue(trimmed)
            if trimmed.hasPrefix("- ") || trimmed == "-" {
                guard !entries.isEmpty else { return nil }
                entries[entries.count - 1].append(unquote(String(trimmed.dropFirst())), separator: ", ")
            } else if !isIndented, let (key, value, isBlockScalar) = pair {
                parent = value.isEmpty && !isBlockScalar ? key : nil
                inBlockScalar = isBlockScalar
                entries.append(Entry(key: key, value: value))
            } else if let parent, let (key, value, _) = pair {
                if entries.last == Entry(key: parent, value: "") {
                    entries.removeLast()
                }
                entries.append(Entry(key: "\(parent).\(key)", value: value))
            } else {
                guard isIndented, !entries.isEmpty else { return nil }
                entries[entries.count - 1].append(trimmed)
            }
        }
        return entries.isEmpty ? nil : FrontMatter(entries: entries, closingLine: closing)
    }

    private static let keyPattern = try! NSRegularExpression(pattern: #"^([\p{L}\p{N}_][\p{L}\p{N}_ .-]*):(?:\s+(.*))?$"#)

    private static func keyValue(_ line: String) -> (key: String, value: String, isBlockScalar: Bool)? {
        let range = NSRange(line.startIndex..., in: line)
        guard let match = keyPattern.firstMatch(in: line, range: range),
              let keyRange = Range(match.range(at: 1), in: line) else { return nil }
        let value = Range(match.range(at: 2), in: line).map { String(line[$0]) } ?? ""
        let key = String(line[keyRange])
        if ["|", ">", "|-", ">-", "|+", ">+"].contains(value) {
            return (key, "", true)
        }
        if value.hasPrefix("[") && value.hasSuffix("]") {
            let items = value.dropFirst().dropLast().split(separator: ",").map { unquote(String($0)) }
            return (key, items.filter { !$0.isEmpty }.joined(separator: ", "), false)
        }
        return (key, unquote(value), false)
    }

    private static func unquote(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        for quote in ["\"", "'"] where trimmed.count >= 2 && trimmed.hasPrefix(quote) && trimmed.hasSuffix(quote) {
            return String(trimmed.dropFirst().dropLast())
        }
        return trimmed
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
