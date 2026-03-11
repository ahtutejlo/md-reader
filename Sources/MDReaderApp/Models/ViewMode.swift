import Foundation

enum ViewMode: String, CaseIterable {
    case editor
    case split
    case preview

    var icon: String {
        switch self {
        case .editor: "square.and.pencil"
        case .split: "rectangle.split.2x1"
        case .preview: "eye"
        }
    }

    var label: String {
        switch self {
        case .editor: "Editor"
        case .split: "Split"
        case .preview: "Preview"
        }
    }
}
