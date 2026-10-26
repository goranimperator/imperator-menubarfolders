import AppKit

struct DiscoveredApp: Identifiable {
    let url: URL
    let name: String
    let bundleIdentifier: String
    let isMenuBarApp: Bool
    let icon: NSImage

    var id: String { bundleIdentifier }
}

/// Whether mounted external drives are scanned for apps, and which ones are left out.
///
/// Exclusions are keyed by volume name rather than mount path. The path is only
/// `/Volumes/<name>`, the name is what Finder shows, and keying on the name means the
/// choice survives unplugging the disk, which is the one moment its row disappears from
/// the settings window.
enum VolumeScanSettings {
    static let scanEnabledKey = "scanExternalDrives"
    static let excludedVolumesKey = "excludedVolumeNames"

    /// Defaults to on: an app on a drive is otherwise unreachable without the file
    /// dialog, and the scan is depth-capped. Read through `object(forKey:)` because
    /// `bool(forKey:)` returns false for "never set" and so cannot express the default.
    static var scanExternalDrives: Bool {
        get { UserDefaults.standard.object(forKey: scanEnabledKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: scanEnabledKey) }
    }

    static var excludedVolumeNames: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: excludedVolumesKey) ?? []) }
        set { UserDefaults.standard.set(newValue.sorted(), forKey: excludedVolumesKey) }
    }
}

enum AppDiscovery {
    /// The four paths every Mac keeps its apps in. Scanned at `fixedPathScanDepth`.
    private static let fixedSearchPaths = [
        "/Applications",
        "/System/Applications",
        NSHomeDirectory() + "/Applications",
        "/Applications/Xcode.app/Contents/Applications",
    ]

    /// `nil` is an unbounded walk. These paths are small and known, and a bundle is never
    /// descended into, so the cost is the handful of folders Apple and installers put
    /// there: `/System/Applications/Utilities` and the likes of `/Applications/Adobe`.
    private static let fixedPathScanDepth: Int? = nil

    /// A mounted volume is a whole filesystem, so it gets a cap. Three levels reach an app
    /// on the disk itself, in a folder on it, and one below that:
    ///
    ///     /Volumes/SSD/Game.app              found
    ///     /Volumes/SSD/Games/Game.app        found
    ///     /Volumes/SSD/Games/Steam/Game.app  found
    ///     /Volumes/SSD/a/b/c/Game.app        not found, use the file dialog
    private static let volumeScanDepth: Int? = 3

    /// A Time Machine store holds every app of every backed-up Mac, which would both bury
    /// the disk's own apps and make the scan as slow as the backup is large. Hidden
    /// entries are skipped by the walk itself, so the other metadata stores need no entry.
    private static let skippedDirectoryNames: Set<String> = ["Backups.backupdb"]

    static func installedApps() -> [DiscoveredApp] {
        var urls: [URL] = []

        for searchPath in fixedSearchPaths {
            collectApps(in: searchPath, into: &urls, depthRemaining: fixedPathScanDepth)
        }

        if VolumeScanSettings.scanExternalDrives {
            for volume in scannableVolumes() {
                collectApps(in: volume.path, into: &urls, depthRemaining: volumeScanDepth)
            }
        }

        var seen = Set<String>()
        var apps: [DiscoveredApp] = []

        for url in urls {
            guard let app = discoveredApp(at: url), !seen.contains(app.bundleIdentifier) else { continue }
            seen.insert(app.bundleIdentifier)
            apps.append(app)
        }

        return apps.sorted { lhs, rhs in
            if lhs.isMenuBarApp != rhs.isMenuBarApp { return lhs.isMenuBarApp }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    /// Walks `dir` for `.app` bundles. `depthRemaining` is the number of directory levels
    /// still allowed, `nil` for no limit; a bundle sitting at the limit is still collected
    /// because the descent guard comes after the `.app` check.
    private static func collectApps(in dir: String, into urls: inout [URL], depthRemaining: Int?) {
        let fm = FileManager.default

        // String-based API, so Cryptex symlinks on macOS Sequoia+ are seen (brand book §22.1)
        guard let entries = try? fm.contentsOfDirectory(atPath: dir) else { return }

        for entry in entries {
            guard !entry.hasPrefix(".") else { continue }
            let fullPath = (dir as NSString).appendingPathComponent(entry)

            if entry.hasSuffix(".app") {
                urls.append(URL(fileURLWithPath: fullPath))
                continue
            }

            if skippedDirectoryNames.contains(entry) { continue }
            if let depthRemaining, depthRemaining <= 1 { continue }

            var isDirectory: ObjCBool = false
            guard fm.fileExists(atPath: fullPath, isDirectory: &isDirectory), isDirectory.boolValue else { continue }

            collectApps(in: fullPath, into: &urls, depthRemaining: depthRemaining.map { $0 - 1 })
        }
    }

    /// Reads one `.app` bundle. Also the path the file dialog takes, so an app chosen by
    /// hand is built exactly like a scanned one.
    static func discoveredApp(at url: URL) -> DiscoveredApp? {
        // Resolve symlinks for correct icons (brand book §22.2)
        let resolved = url.resolvingSymlinksInPath()
        guard let bundle = Bundle(url: resolved),
              let bundleID = bundle.bundleIdentifier else { return nil }

        let name = FileManager.default.displayName(atPath: url.path)
            .replacingOccurrences(of: ".app", with: "")
        let icon = NSWorkspace.shared.icon(forFile: resolved.path)
        icon.size = NSSize(width: 32, height: 32)

        return DiscoveredApp(
            url: url,
            name: name,
            bundleIdentifier: bundleID,
            isMenuBarApp: isMenuBarApp(bundle: bundle),
            icon: icon
        )
    }

    /// Every mounted drive the settings window offers a row for, excluded ones included.
    ///
    /// - root filesystem: already covered by `fixedSearchPaths`.
    /// - not browsable: Recovery and its like are not disks anyone mounted to use.
    /// - not local: `contentsOfDirectory` on a network share blocks for as long as the
    ///   server takes to answer, which is unbounded.
    /// - internal: "external drive" is what the setting promises. A second internal disk
    ///   is reached through the file dialog instead.
    static func externalVolumes() -> [URL] {
        let keys: [URLResourceKey] = [
            .volumeNameKey,
            .volumeIsInternalKey,
            .volumeIsBrowsableKey,
            .volumeIsLocalKey,
            .volumeIsRootFileSystemKey,
        ]

        guard let volumes = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: keys,
            options: [.skipHiddenVolumes]
        ) else { return [] }

        return volumes.filter { url in
            guard let values = try? url.resourceValues(forKeys: Set(keys)) else { return false }
            guard values.volumeIsRootFileSystem != true,
                  values.volumeIsBrowsable == true,
                  values.volumeIsLocal == true,
                  values.volumeIsInternal != true else { return false }
            return values.volumeName != nil
        }
    }

    static func volumeName(of url: URL) -> String {
        (try? url.resourceValues(forKeys: [.volumeNameKey]))?.volumeName
            ?? url.lastPathComponent
    }

    private static func scannableVolumes() -> [URL] {
        let excluded = VolumeScanSettings.excludedVolumeNames
        return externalVolumes().filter { !excluded.contains(volumeName(of: $0)) }
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
