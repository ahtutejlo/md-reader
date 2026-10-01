import Testing
@testable import MDReaderApp

private let document = "# Title\nintro\n\n## Setup\ninstall\n\n## Usage\nrun it\n"

@Test(arguments: [
    (3, 6, "## Setup\ninstall"),
    (6, nil, "## Usage\nrun it"),
    (2, 5, "## Setup\ninstall"),
    (3, nil, "## Setup\ninstall\n\n## Usage\nrun it"),
    (6, 100, "## Usage\nrun it"),
    (6, 3, ""),
    (9, nil, ""),
    (-1, 3, ""),
] as [(Int, Int?, String)])
func sectionCopiesSourceLines(_ start: Int, _ end: Int?, _ expected: String) {
    #expect(RichClipboard.section(of: document, from: start, to: end) == expected)
}
