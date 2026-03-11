// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MDReader",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "MDReaderApp",
            path: "Sources/MDReaderApp",
            exclude: ["Info.plist"],
            resources: [.copy("Resources/AppIcon.icns")]
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
