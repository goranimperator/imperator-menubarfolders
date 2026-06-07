import AppKit

struct DiscoveredApp: Identifiable {
    let url: URL
    let name: String
    let bundleIdentifier: String
    let isMenuBarApp: Bool
    let icon: NSImage

    var id: String { bundleIdentifier }
}

enum AppDiscovery {
    static func installedApps() -> [DiscoveredApp] {
        let searchPaths = [
            "/Applications",
            "/System/Applications",
            NSHomeDirectory() + "/Applications",
            "/Applications/Xcode.app/Contents/Applications",
        ]

        var seen = Set<String>()
        var apps: [DiscoveredApp] = []

        let fm = FileManager.default

        for searchPath in searchPaths {
            // Use string-based API to find Cryptex symlinks on macOS Sequoia+ (brand book §22.1)
            guard let entries = try? fm.contentsOfDirectory(atPath: searchPath) else { continue }

            for entry in entries {
                guard entry.hasSuffix(".app") else { continue }
                let fullPath = (searchPath as NSString).appendingPathComponent(entry)

                // Resolve symlinks for correct icons (brand book §22.2)
                let resolved = URL(fileURLWithPath: fullPath).resolvingSymlinksInPath()
                guard let bundle = Bundle(url: resolved),
                      let bundleID = bundle.bundleIdentifier,
                      !seen.contains(bundleID) else { continue }

                seen.insert(bundleID)

                let name = fm.displayName(atPath: fullPath)
                    .replacingOccurrences(of: ".app", with: "")
                let icon = NSWorkspace.shared.icon(forFile: resolved.path)
                icon.size = NSSize(width: 32, height: 32)

                apps.append(DiscoveredApp(
                    url: URL(fileURLWithPath: fullPath),
                    name: name,
                    bundleIdentifier: bundleID,
                    isMenuBarApp: isMenuBarApp(bundle: bundle),
                    icon: icon
                ))
            }
        }

        return apps.sorted { lhs, rhs in
            if lhs.isMenuBarApp != rhs.isMenuBarApp { return lhs.isMenuBarApp }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    static func isMenuBarApp(bundle: Bundle) -> Bool {
        guard let info = bundle.infoDictionary else { return false }
        if let val = info["LSUIElement"] as? Bool { return val }
        if let val = info["LSUIElement"] as? String { return val == "1" || val.uppercased() == "YES" || val.uppercased() == "TRUE" }
        if let val = info["LSUIElement"] as? Int { return val == 1 }
        return false
    }

    static func toAppEntry(_ app: DiscoveredApp) -> AppEntry {
        AppEntry(
            bundleIdentifier: app.bundleIdentifier,
            name: app.name,
            path: app.url.path,
            isMenuBarApp: app.isMenuBarApp
        )
    }
}
