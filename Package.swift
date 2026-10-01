// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MDReader",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-markdown.git", .upToNextMinor(from: "0.9.0"))
    ],
    targets: [
        .executableTarget(
            name: "MDReaderApp",
            dependencies: [.product(name: "Markdown", package: "swift-markdown")],
            path: "Sources/MDReaderApp",
            exclude: ["Info.plist"],
            resources: [.copy("Resources/AppIcon.icns"), .copy("Resources/highlight")]
        ),
        .executableTarget(
            name: "mdreader",
            path: "Sources/mdreader"
        ),
        .testTarget(
            name: "MDReaderAppTests",
            dependencies: ["MDReaderApp"],
            path: "Tests/MDReaderAppTests"
        )
    ]
)
