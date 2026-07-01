// swift-tools-version:5.9
// comment-checker-disable-file
import PackageDescription

let package = Package(
    name: "DropboxOpen",
    platforms: [.macOS(.v13)],
    targets: [
        .target(
            name: "DropboxOpenCore",
            path: "Sources/DropboxOpenCore"
        ),
        .executableTarget(
            name: "DropboxOpen",
            dependencies: ["DropboxOpenCore"],
            path: "Sources/DropboxOpen",
            exclude: ["Resources"]
        ),
        .testTarget(
            name: "DropboxOpenCoreTests",
            dependencies: ["DropboxOpenCore"],
            path: "Tests/DropboxOpenCoreTests"
        )
    ]
)
