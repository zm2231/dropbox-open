// swift-tools-version:5.9
// comment-checker-disable-file
import PackageDescription

let package = Package(
    name: "DropboxOpen",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "DropboxOpen",
            path: "Sources/DropboxOpen"
        )
    ]
)
