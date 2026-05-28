import AppKit

struct AppEntry: Identifiable, Codable, Hashable {
    let bundleIdentifier: String
    let name: String
    let path: String
    let isMenuBarApp: Bool

    var id: String { bundleIdentifier }
    var url: URL { URL(fileURLWithPath: path) }
    var exists: Bool { FileManager.default.fileExists(atPath: path) }

    private static var iconCache: [String: NSImage] = [:]

    var icon: NSImage {
        if let cached = Self.iconCache[path] { return cached }
        let img = NSWorkspace.shared.icon(forFile: path)
        img.size = NSSize(width: 32, height: 32)
        Self.iconCache[path] = img
        return img
    }

    enum CodingKeys: String, CodingKey {
        case bundleIdentifier, name, path, isMenuBarApp
    }

    static func == (lhs: AppEntry, rhs: AppEntry) -> Bool {
        lhs.bundleIdentifier == rhs.bundleIdentifier
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(bundleIdentifier)
    }
}
