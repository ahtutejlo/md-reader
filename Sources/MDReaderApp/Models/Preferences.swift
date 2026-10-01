import Foundation

enum Preferences {
    static let zoomKey = "zoom"
    static let showOutlineKey = "showOutline"
    static let groupByProjectKey = "groupByProject"

    static let zoomRange: ClosedRange<Double> = 0.6...2.0
    static let zoomStep = 0.1
}
