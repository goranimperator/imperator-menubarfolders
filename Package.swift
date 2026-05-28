// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "MenuBarFolders",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "MenuBarFolders",
            path: "Sources/MenuBarFolders"
        )
    ]
)
