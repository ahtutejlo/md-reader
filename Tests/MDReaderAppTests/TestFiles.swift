import Foundation

func writeTempNote(_ text: String = "# Note") throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("note-\(UUID()).md")
    try text.write(to: url, atomically: true, encoding: .utf8)
    return url
}

func setModificationDate(of url: URL, to date: Date) throws {
    try FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: url.path)
}

func modificationDate(of url: URL) throws -> Date? {
    try FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate] as? Date
}
