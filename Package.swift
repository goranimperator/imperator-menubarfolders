// swift-tools-version:6.4

import PackageDescription

let package = Package(
    name: "MenuBarFolders",
    // Stays at macOS 14. The repo is public and the README promises 14 or later, so
    // raising this to 27 would lock out every machine below it. SwiftPM stamps
    // LC_BUILD_VERSION's sdk field from this value rather than from the SDK it compiled
    // against, which is what left the binary drawing macOS 14 era controls; the Makefile
    // passes -platform_version to stamp sdk 27.0 while keeping minos 14.0.
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "MenuBarFolders",
            path: "Sources/MenuBarFolders",
            // swift-tools-version 6.4 turns on Swift 6 language mode, which stops on this
            // codebase's pre-concurrency code. That migration is a separate job.
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
