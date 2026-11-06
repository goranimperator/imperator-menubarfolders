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
            // The Xcode 27 template defaults: everything is @MainActor unless it says
            // otherwise, and the compiler rejects data races rather than warning. What
            // runs off the main actor says so with `nonisolated`, and each one is there
            // because a detached task calls it.
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .defaultIsolation(MainActor.self),
                .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
            ]
        )
    ]
)
