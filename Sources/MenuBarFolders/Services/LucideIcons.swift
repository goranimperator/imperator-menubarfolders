import AppKit

enum LucideIcons {
    private static var cache: [String: NSImage] = [:]

    static var allIconNames: [String] {
        icons.keys.sorted()
    }

    static func statusBarImage(named name: String, size: CGFloat = 18) -> NSImage? {
        let key = "\(name)-status-\(size)"
        if let cached = cache[key] { return cached }

        guard let elements = parsedElements(for: name) else { return nil }
        let image = SVGRenderer.render(elements: elements, size: size, strokeWidth: 1.5 * (size / 24.0))
        image.isTemplate = true
        cache[key] = image
        return image
    }

    static func previewImage(named name: String, size: CGFloat = 24, color: NSColor = .white) -> NSImage? {
        let key = "\(name)-preview-\(size)"
        if let cached = cache[key] { return cached }

        guard let elements = parsedElements(for: name) else { return nil }
        let image = SVGRenderer.render(elements: elements, size: size, strokeWidth: 2.0 * (size / 24.0), color: color)
        cache[key] = image
        return image
    }

    static func statusBarImageFromSVG(_ svg: String, size: CGFloat = 18) -> NSImage? {
        guard let elements = parseSVGString(svg) else { return nil }
        let image = SVGRenderer.render(elements: elements, size: size, strokeWidth: 1.5 * (size / 24.0))
        image.isTemplate = true
        return image
    }

    static func previewImageFromSVG(_ svg: String, size: CGFloat = 24, color: NSColor = .white) -> NSImage? {
        guard let elements = parseSVGString(svg) else { return nil }
        return SVGRenderer.render(elements: elements, size: size, strokeWidth: 2.0 * (size / 24.0), color: color)
    }

    static func parseSVGString(_ svg: String) -> [SVGRenderer.Element]? {
        let tags = extractSVGElements(from: svg)
        let elements = tags.compactMap { SVGRenderer.parseElement($0) }
        return elements.isEmpty ? nil : elements
    }

    private static func extractSVGElements(from svg: String) -> [String] {
        var results: [String] = []
        let tags = ["path", "circle", "rect", "line", "polyline", "polygon", "ellipse"]
        for tag in tags {
            var searchRange = svg.startIndex..<svg.endIndex
            while let start = svg.range(of: "<\(tag) ", range: searchRange) {
                if let end = svg.range(of: "/>", range: start.lowerBound..<svg.endIndex) {
                    results.append(String(svg[start.lowerBound...end.upperBound]))
                    searchRange = end.upperBound..<svg.endIndex
                } else if let end = svg.range(of: "</\(tag)>", range: start.lowerBound..<svg.endIndex) {
                    results.append(String(svg[start.lowerBound...end.upperBound]))
                    searchRange = end.upperBound..<svg.endIndex
                } else {
                    break
                }
            }
        }
        return results
    }

    private static func parsedElements(for name: String) -> [SVGRenderer.Element]? {
        guard let svgStrings = icons[name] else { return nil }
        let elements = svgStrings.compactMap { SVGRenderer.parseElement($0) }
        return elements.isEmpty ? nil : elements
    }
}

func folderPreviewIcon(_ folder: MenuBarFolder, size: CGFloat = 24) -> NSImage? {
    if let svg = folder.customSVG, let img = LucideIcons.previewImageFromSVG(svg, size: size) {
        return img
    }
    return LucideIcons.previewImage(named: folder.iconName, size: size)
        ?? LucideIcons.previewImage(named: "folder", size: size)
}

extension LucideIcons {
    // Each icon is an array of SVG elements (path, circle, rect, line, polyline, polygon)
    static let icons: [String: [String]] = [
        // --- Folders & Files ---
        "folder": [#"<path d="M20 20a2 2 0 0 0 2-2V8a2 2 0 0 0-2-2h-7.9a2 2 0 0 1-1.69-.9L9.6 3.9A2 2 0 0 0 7.93 3H4a2 2 0 0 0-2 2v13a2 2 0 0 0 2 2Z"/>"#],
        "folder-open": [#"<path d="m6 14 1.5-2.9A2 2 0 0 1 9.24 10H20a2 2 0 0 1 1.94 2.5l-1.54 6a2 2 0 0 1-1.95 1.5H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h3.9a2 2 0 0 1 1.69.9l.81 1.2a2 2 0 0 0 1.67.9H18a2 2 0 0 1 2 2v2"/>"#],
        "file": [#"<path d="M15 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7Z"/>"#, #"<path d="M14 2v4a2 2 0 0 0 2 2h4"/>"#],
        "file-text": [#"<path d="M15 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7Z"/>"#, #"<path d="M14 2v4a2 2 0 0 0 2 2h4"/>"#, #"<line x1="16" x2="8" y1="13" y2="13"/>"#, #"<line x1="16" x2="8" y1="17" y2="17"/>"#, #"<line x1="10" x2="8" y1="9" y2="9"/>"#],

        // --- Communication ---
        "mail": [#"<rect width="20" height="16" x="2" y="4" rx="2"/>"#, #"<path d="m22 7-8.97 5.7a1.94 1.94 0 0 1-2.06 0L2 7"/>"#],
        "message-circle": [#"<path d="M7.9 20A9 9 0 1 0 4 16.1L2 22Z"/>"#],
        "message-square": [#"<path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/>"#],
        "phone": [#"<path d="M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07 19.5 19.5 0 0 1-6-6 19.79 19.79 0 0 1-3.07-8.67A2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72 12.84 12.84 0 0 0 .7 2.81 2 2 0 0 1-.45 2.11L8.09 9.91a16 16 0 0 0 6 6l1.27-1.27a2 2 0 0 1 2.11-.45 12.84 12.84 0 0 0 2.81.7A2 2 0 0 1 22 16.92z"/>"#],
        "bell": [#"<path d="M6 8a6 6 0 0 1 12 0c0 7 3 9 3 9H3s3-2 3-9"/>"#, #"<path d="M10.3 21a1.94 1.94 0 0 0 3.4 0"/>"#],

        // --- Media ---
        "music": [#"<path d="M9 18V5l12-2v13"/>"#, #"<circle cx="6" cy="18" r="3"/>"#, #"<circle cx="18" cy="16" r="3"/>"#],
        "headphones": [#"<path d="M3 14h3a2 2 0 0 1 2 2v3a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-7a9 9 0 0 1 18 0v7a2 2 0 0 1-2 2h-1a2 2 0 0 1-2-2v-3a2 2 0 0 1 2-2h3"/>"#],
        "camera": [#"<path d="M14.5 4h-5L7 7H4a2 2 0 0 0-2 2v9a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2V9a2 2 0 0 0-2-2h-3l-2.5-3z"/>"#, #"<circle cx="12" cy="13" r="3"/>"#],
        "video": [#"<path d="m16 13 5.223 3.482a.5.5 0 0 0 .777-.416V7.87a.5.5 0 0 0-.752-.432L16 10.5"/>"#, #"<rect x="2" y="6" width="14" height="12" rx="2"/>"#],
        "image": [#"<rect width="18" height="18" x="3" y="3" rx="2" ry="2"/>"#, #"<circle cx="9" cy="9" r="2"/>"#, #"<path d="m21 15-3.086-3.086a2 2 0 0 0-2.828 0L6 21"/>"#],
        "play": [#"<polygon points="6 3 20 12 6 21 6 3"/>"#],
        "mic": [#"<path d="M12 2a3 3 0 0 0-3 3v7a3 3 0 0 0 6 0V5a3 3 0 0 0-3-3Z"/>"#, #"<path d="M19 10v2a7 7 0 0 1-14 0v-2"/>"#, #"<line x1="12" x2="12" y1="19" y2="22"/>"#],

        // --- Development ---
        "code": [#"<polyline points="16 18 22 12 16 6"/>"#, #"<polyline points="8 6 2 12 8 18"/>"#],
        "terminal": [#"<polyline points="4 17 10 11 4 5"/>"#, #"<line x1="12" x2="20" y1="19" y2="19"/>"#],
        "git-branch": [#"<line x1="6" x2="6" y1="3" y2="15"/>"#, #"<circle cx="18" cy="6" r="3"/>"#, #"<circle cx="6" cy="18" r="3"/>"#, #"<path d="M18 9a9 9 0 0 1-9 9"/>"#],
        "bug": [#"<path d="m8 2 1.88 1.88"/>"#, #"<path d="M14.12 3.88 16 2"/>"#, #"<path d="M9 7.13v-1a3.003 3.003 0 1 1 6 0v1"/>"#, #"<path d="M12 20c-3.3 0-6-2.7-6-6v-3a4 4 0 0 1 4-4h4a4 4 0 0 1 4 4v3c0 3.3-2.7 6-6 6"/>"#, #"<path d="M12 20v-9"/>"#, #"<path d="M6.53 9C4.6 8.8 3 7.1 3 5"/>"#, #"<path d="M6 13H2"/>"#, #"<path d="M3 21c0-2.1 1.7-3.9 3.8-4"/>"#, #"<path d="M20.97 5c0 2.1-1.6 3.8-3.5 4"/>"#, #"<path d="M22 13h-4"/>"#, #"<path d="M17.2 17c2.1.1 3.8 1.9 3.8 4"/>"#],
        "database": [#"<ellipse cx="12" cy="5" rx="9" ry="3"/>"#, #"<path d="M3 5V19A9 3 0 0 0 21 19V5"/>"#, #"<path d="M3 12A9 3 0 0 0 21 12"/>"#],

        // --- System & Tools ---
        "settings": [#"<path d="M12.22 2h-.44a2 2 0 0 0-2 2v.18a2 2 0 0 1-1 1.73l-.43.25a2 2 0 0 1-2 0l-.15-.08a2 2 0 0 0-2.73.73l-.22.38a2 2 0 0 0 .73 2.73l.15.1a2 2 0 0 1 1 1.72v.51a2 2 0 0 1-1 1.74l-.15.09a2 2 0 0 0-.73 2.73l.22.38a2 2 0 0 0 2.73.73l.15-.08a2 2 0 0 1 2 0l.43.25a2 2 0 0 1 1 1.73V20a2 2 0 0 0 2 2h.44a2 2 0 0 0 2-2v-.18a2 2 0 0 1 1-1.73l.43-.25a2 2 0 0 1 2 0l.15.08a2 2 0 0 0 2.73-.73l.22-.39a2 2 0 0 0-.73-2.73l-.15-.08a2 2 0 0 1-1-1.74v-.5a2 2 0 0 1 1-1.74l.15-.09a2 2 0 0 0 .73-2.73l-.22-.38a2 2 0 0 0-2.73-.73l-.15.08a2 2 0 0 1-2 0l-.43-.25a2 2 0 0 1-1-1.73V4a2 2 0 0 0-2-2z"/>"#, #"<circle cx="12" cy="12" r="3"/>"#],
        "wrench": [#"<path d="M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.77-3.77a6 6 0 0 1-7.94 7.94l-6.91 6.91a2.12 2.12 0 0 1-3-3l6.91-6.91a6 6 0 0 1 7.94-7.94l-3.76 3.76z"/>"#],
        "shield": [#"<path d="M20 13c0 5-3.5 7.5-7.66 8.95a1 1 0 0 1-.67-.01C7.5 20.5 4 18 4 13V6a1 1 0 0 1 1-1c2 0 4.5-1.2 6.24-2.72a1.17 1.17 0 0 1 1.52 0C14.51 3.81 17 5 19 5a1 1 0 0 1 1 1z"/>"#],
        "lock": [#"<rect width="18" height="11" x="3" y="11" rx="2" ry="2"/>"#, #"<path d="M7 11V7a5 5 0 0 1 10 0v4"/>"#],
        "key": [#"<path d="m15.5 7.5 2.3 2.3a1 1 0 0 0 1.4 0l2.1-2.1a1 1 0 0 0 0-1.4L19 4"/>"#, #"<path d="m21 2-9.6 9.6"/>"#, #"<circle cx="7.5" cy="15.5" r="5.5"/>"#],
        "zap": [#"<path d="M4 14a1 1 0 0 1-.78-1.63l9.9-10.2a.5.5 0 0 1 .86.46l-1.92 6.02A1 1 0 0 0 13 10h7a1 1 0 0 1 .78 1.63l-9.9 10.2a.5.5 0 0 1-.86-.46l1.92-6.02A1 1 0 0 0 11 14z"/>"#],
        "cpu": [#"<rect x="4" y="4" width="16" height="16" rx="2"/>"#, #"<rect x="9" y="9" width="6" height="6"/>"#, #"<path d="M15 2v2"/>"#, #"<path d="M15 20v2"/>"#, #"<path d="M2 15h2"/>"#, #"<path d="M2 9h2"/>"#, #"<path d="M20 15h2"/>"#, #"<path d="M20 9h2"/>"#, #"<path d="M9 2v2"/>"#, #"<path d="M9 20v2"/>"#],
        "hard-drive": [#"<line x1="22" x2="2" y1="12" y2="12"/>"#, #"<path d="M5.45 5.11 2 12v6a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2v-6l-3.45-6.89A2 2 0 0 0 16.76 4H7.24a2 2 0 0 0-1.79 1.11z"/>"#, #"<line x1="6" x2="6.01" y1="16" y2="16"/>"#, #"<line x1="10" x2="10.01" y1="16" y2="16"/>"#],

        // --- Navigation & UI ---
        "home": [#"<path d="M15 21v-8a1 1 0 0 0-1-1h-4a1 1 0 0 0-1 1v8"/>"#, #"<path d="M3 10a2 2 0 0 1 .709-1.528l7-5.999a2 2 0 0 1 2.582 0l7 5.999A2 2 0 0 1 21 10v9a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/>"#],
        "search": [#"<circle cx="11" cy="11" r="8"/>"#, #"<path d="m21 21-4.3-4.3"/>"#],
        "menu": [#"<line x1="4" x2="20" y1="12" y2="12"/>"#, #"<line x1="4" x2="20" y1="6" y2="6"/>"#, #"<line x1="4" x2="20" y1="18" y2="18"/>"#],
        "layout-grid": [#"<rect width="7" height="7" x="3" y="3" rx="1"/>"#, #"<rect width="7" height="7" x="14" y="3" rx="1"/>"#, #"<rect width="7" height="7" x="14" y="14" rx="1"/>"#, #"<rect width="7" height="7" x="3" y="14" rx="1"/>"#],
        "layers": [#"<path d="m12.83 2.18a2 2 0 0 0-1.66 0L2.6 6.08a1 1 0 0 0 0 1.83l8.58 3.91a2 2 0 0 0 1.66 0l8.58-3.9a1 1 0 0 0 0-1.83Z"/>"#, #"<path d="m22 17.65-9.17 4.16a2 2 0 0 1-1.66 0L2 17.65"/>"#, #"<path d="m22 12.65-9.17 4.16a2 2 0 0 1-1.66 0L2 12.65"/>"#],
        "box": [#"<path d="M21 8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16Z"/>"#, #"<path d="m3.3 7 8.7 5 8.7-5"/>"#, #"<path d="M12 22V12"/>"#],
        "package": [#"<path d="m16.5 9.4-9-5.19"/>"#, #"<path d="M21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16z"/>"#, #"<polyline points="3.27 6.96 12 12.01 20.73 6.96"/>"#, #"<line x1="12" x2="12" y1="22.08" y2="12"/>"#],

        // --- Shapes & Symbols ---
        "star": [#"<polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"/>"#],
        "heart": [#"<path d="M19 14c1.49-1.46 3-3.21 3-5.5A5.5 5.5 0 0 0 16.5 3c-1.76 0-3 .5-4.5 2-1.5-1.5-2.74-2-4.5-2A5.5 5.5 0 0 0 2 8.5c0 2.3 1.5 4.05 3 5.5l7 7Z"/>"#],
        "circle": [#"<circle cx="12" cy="12" r="10"/>"#],
        "square": [#"<rect width="18" height="18" x="3" y="3" rx="2"/>"#],
        "triangle": [#"<path d="m21.73 18-8-14a2 2 0 0 0-3.48 0l-8 14A2 2 0 0 0 4 21h16a2 2 0 0 0 1.73-3"/>"#],
        "hexagon": [#"<path d="M21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16z"/>"#],
        "diamond": [#"<path d="M2.7 10.3a2.41 2.41 0 0 0 0 3.41l7.59 7.59a2.41 2.41 0 0 0 3.41 0l7.59-7.59a2.41 2.41 0 0 0 0-3.41l-7.59-7.59a2.41 2.41 0 0 0-3.41 0Z"/>"#],
        "crown": [#"<path d="M11.562 3.266a.5.5 0 0 1 .876 0L15.39 8.87a1 1 0 0 0 1.516.294L20.183 6.5a.5.5 0 0 1 .798.519l-2.834 10.246a1 1 0 0 1-.956.734H6.81a1 1 0 0 1-.957-.734L3.02 7.02a.5.5 0 0 1 .798-.519l3.276 2.664a1 1 0 0 0 1.516-.294z"/>"#, #"<path d="M5 21h14"/>"#],

        // --- Weather & Nature ---
        "sun": [#"<circle cx="12" cy="12" r="4"/>"#, #"<path d="M12 2v2"/>"#, #"<path d="M12 20v2"/>"#, #"<path d="m4.93 4.93 1.41 1.41"/>"#, #"<path d="m17.66 17.66 1.41 1.41"/>"#, #"<path d="M2 12h2"/>"#, #"<path d="M20 12h2"/>"#, #"<path d="m6.34 17.66-1.41 1.41"/>"#, #"<path d="m19.07 4.93-1.41 1.41"/>"#],
        "moon": [#"<path d="M12 3a6 6 0 0 0 9 9 9 9 0 1 1-9-9Z"/>"#],
        "cloud": [#"<path d="M17.5 19H9a7 7 0 1 1 6.71-9h1.79a4.5 4.5 0 1 1 0 9Z"/>"#],
        "flame": [#"<path d="M8.5 14.5A2.5 2.5 0 0 0 11 12c0-1.38-.5-2-1-3-1.072-2.143-.224-4.054 2-6 .5 2.5 2 4.9 4 6.5 2 1.6 3 3.5 3 5.5a7 7 0 1 1-14 0c0-1.153.433-2.294 1-3a2.5 2.5 0 0 0 2.5 2.5z"/>"#],
        "snowflake": [#"<line x1="2" x2="22" y1="12" y2="12"/>"#, #"<line x1="12" x2="12" y1="2" y2="22"/>"#, #"<path d="m20 16-4-4 4-4"/>"#, #"<path d="m4 8 4 4-4 4"/>"#, #"<path d="m16 4-4 4-4-4"/>"#, #"<path d="m8 20 4-4 4 4"/>"#],
        "tree-pine": [#"<path d="m17 14 3 3.3a1 1 0 0 1-.7 1.7H4.7a1 1 0 0 1-.7-1.7L7 14l-3-3.3a1 1 0 0 1 .7-1.7h4.6L7 6.3a1 1 0 0 1 .7-1.7h8.6a1 1 0 0 1 .7 1.7L15 9h4.6a1 1 0 0 1 .7 1.7z"/>"#, #"<path d="M12 22v-3"/>"#],

        // --- Arrows ---
        "arrow-right": [#"<path d="M5 12h14"/>"#, #"<path d="m12 5 7 7-7 7"/>"#],
        "arrow-left": [#"<path d="m12 19-7-7 7-7"/>"#, #"<path d="M19 12H5"/>"#],
        "arrow-up": [#"<path d="m5 12 7-7 7 7"/>"#, #"<path d="M12 19V5"/>"#],
        "arrow-down": [#"<path d="M12 5v14"/>"#, #"<path d="m19 12-7 7-7-7"/>"#],
        "move": [#"<polyline points="5 9 2 12 5 15"/>"#, #"<polyline points="9 5 12 2 15 5"/>"#, #"<polyline points="15 19 12 22 9 19"/>"#, #"<polyline points="19 9 22 12 19 15"/>"#, #"<line x1="2" x2="22" y1="12" y2="12"/>"#, #"<line x1="12" x2="12" y1="2" y2="22"/>"#],
        "external-link": [#"<path d="M15 3h6v6"/>"#, #"<path d="M10 14 21 3"/>"#, #"<path d="M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6"/>"#],
        "download": [#"<path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/>"#, #"<polyline points="7 10 12 15 17 10"/>"#, #"<line x1="12" x2="12" y1="15" y2="3"/>"#],
        "upload": [#"<path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/>"#, #"<polyline points="17 8 12 3 7 8"/>"#, #"<line x1="12" x2="12" y1="3" y2="15"/>"#],

        // --- People & Social ---
        "user": [#"<path d="M19 21v-2a4 4 0 0 0-4-4H9a4 4 0 0 0-4 4v2"/>"#, #"<circle cx="12" cy="7" r="4"/>"#],
        "users": [#"<path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/>"#, #"<circle cx="9" cy="7" r="4"/>"#, #"<path d="M22 21v-2a4 4 0 0 0-3-3.87"/>"#, #"<path d="M16 3.13a4 4 0 0 1 0 7.75"/>"#],
        "globe": [#"<circle cx="12" cy="12" r="10"/>"#, #"<path d="M12 2a14.5 14.5 0 0 0 0 20 14.5 14.5 0 0 0 0-20"/>"#, #"<path d="M2 12h20"/>"#],
        "share": [#"<circle cx="18" cy="5" r="3"/>"#, #"<circle cx="6" cy="12" r="3"/>"#, #"<circle cx="18" cy="19" r="3"/>"#, #"<line x1="8.59" x2="15.42" y1="13.51" y2="17.49"/>"#, #"<line x1="15.41" x2="8.59" y1="6.51" y2="10.49"/>"#],

        // --- Business ---
        "briefcase": [#"<path d="M16 20V4a2 2 0 0 0-2-2h-4a2 2 0 0 0-2 2v16"/>"#, #"<rect width="20" height="14" x="2" y="6" rx="2"/>"#],
        "calendar": [#"<path d="M8 2v4"/>"#, #"<path d="M16 2v4"/>"#, #"<rect width="18" height="18" x="3" y="4" rx="2"/>"#, #"<path d="M3 10h18"/>"#],
        "clock": [#"<circle cx="12" cy="12" r="10"/>"#, #"<polyline points="12 6 12 12 16 14"/>"#],
        "credit-card": [#"<rect width="20" height="14" x="2" y="5" rx="2"/>"#, #"<line x1="2" x2="22" y1="10" y2="10"/>"#],
        "bar-chart": [#"<line x1="12" x2="12" y1="20" y2="10"/>"#, #"<line x1="18" x2="18" y1="20" y2="4"/>"#, #"<line x1="6" x2="6" y1="20" y2="16"/>"#],
        "pie-chart": [#"<path d="M21.21 15.89A10 10 0 1 1 8 2.83"/>"#, #"<path d="M22 12A10 10 0 0 0 12 2v10z"/>"#],
        "trending-up": [#"<polyline points="22 7 13.5 15.5 8.5 10.5 2 17"/>"#, #"<polyline points="16 7 22 7 22 13"/>"#],

        // --- Technology ---
        "monitor": [#"<rect width="20" height="14" x="2" y="3" rx="2"/>"#, #"<line x1="8" x2="16" y1="21" y2="21"/>"#, #"<line x1="12" x2="12" y1="17" y2="21"/>"#],
        "laptop": [#"<path d="M20 16V7a2 2 0 0 0-2-2H6a2 2 0 0 0-2 2v9m16 0H4m16 0 1.28 2.55a1 1 0 0 1-.9 1.45H3.62a1 1 0 0 1-.9-1.45L4 16"/>"#],
        "smartphone": [#"<rect width="14" height="20" x="5" y="2" rx="2" ry="2"/>"#, #"<path d="M12 18h.01"/>"#],
        "tablet": [#"<rect width="16" height="20" x="4" y="2" rx="2" ry="2"/>"#, #"<line x1="12" x2="12.01" y1="18" y2="18"/>"#],
        "wifi": [#"<path d="M12 20h.01"/>"#, #"<path d="M2 8.82a15 15 0 0 1 20 0"/>"#, #"<path d="M5 12.859a10 10 0 0 1 14 0"/>"#, #"<path d="M8.5 16.429a5 5 0 0 1 7 0"/>"#],
        "bluetooth": [#"<path d="m7 7 10 10-5 5V2l5 5L7 17"/>"#],
        "battery": [#"<rect width="16" height="10" x="2" y="7" rx="2" ry="2"/>"#, #"<line x1="22" x2="22" y1="11" y2="13"/>"#],
        "power": [#"<path d="M12 2v10"/>"#, #"<path d="M18.4 6.6a9 9 0 1 1-12.77.04"/>"#],

        // --- Creative ---
        "palette": [#"<circle cx="13.5" cy="6.5" r=".5" fill="currentColor"/>"#, #"<circle cx="17.5" cy="10.5" r=".5" fill="currentColor"/>"#, #"<circle cx="8.5" cy="7.5" r=".5" fill="currentColor"/>"#, #"<circle cx="6.5" cy="12.5" r=".5" fill="currentColor"/>"#, #"<path d="M12 2C6.5 2 2 6.5 2 12s4.5 10 10 10c.926 0 1.648-.746 1.648-1.688 0-.437-.18-.835-.437-1.125-.29-.289-.438-.652-.438-1.125a1.64 1.64 0 0 1 1.668-1.668h1.996c3.051 0 5.555-2.503 5.555-5.554C21.965 6.012 17.461 2 12 2z"/>"#],
        "pen-tool": [#"<path d="M15.707 21.293a1 1 0 0 1-1.414 0l-1.586-1.586a1 1 0 0 1 0-1.414l5.586-5.586a1 1 0 0 1 1.414 0l1.586 1.586a1 1 0 0 1 0 1.414z"/>"#, #"<path d="m18 13-1.375-6.874a1 1 0 0 0-.746-.776L3.235 2.028a1 1 0 0 0-1.207 1.207L5.35 15.879a1 1 0 0 0 .776.746L13 18"/>"#, #"<path d="m2.3 2.3 7.286 7.286"/>"#, #"<circle cx="11" cy="11" r="2"/>"#],
        "brush": [#"<path d="m9.06 11.9 8.07-8.06a2.85 2.85 0 1 1 4.03 4.03l-8.06 8.08"/>"#, #"<path d="M7.07 14.94c-1.66 0-3 1.35-3 3.02 0 1.33-2.5 1.52-2 2.02 1.08 1.1 2.49 2.02 4 2.02 2.2 0 4-1.8 4-4.04a3.01 3.01 0 0 0-3-3.02z"/>"#],
        "scissors": [#"<circle cx="6" cy="6" r="3"/>"#, #"<path d="M8.12 8.12 12 12"/>"#, #"<path d="M20 4 8.12 15.88"/>"#, #"<circle cx="6" cy="18" r="3"/>"#, #"<path d="M14.8 14.8 20 20"/>"#],
        "type": [#"<polyline points="4 7 4 4 20 4 20 7"/>"#, #"<line x1="9" x2="15" y1="20" y2="20"/>"#, #"<line x1="12" x2="12" y1="4" y2="20"/>"#],
        "figma": [#"<path d="M5 5.5A3.5 3.5 0 0 1 8.5 2H12v7H8.5A3.5 3.5 0 0 1 5 5.5z"/>"#, #"<path d="M12 2h3.5a3.5 3.5 0 1 1 0 7H12V2z"/>"#, #"<path d="M12 12.5a3.5 3.5 0 1 1 7 0 3.5 3.5 0 1 1-7 0z"/>"#, #"<path d="M5 19.5A3.5 3.5 0 0 1 8.5 16H12v3.5a3.5 3.5 0 1 1-7 0z"/>"#, #"<path d="M5 12.5A3.5 3.5 0 0 1 8.5 9H12v7H8.5A3.5 3.5 0 0 1 5 12.5z"/>"#],

        // --- Science & Education ---
        "book": [#"<path d="M4 19.5v-15A2.5 2.5 0 0 1 6.5 2H19a1 1 0 0 1 1 1v18a1 1 0 0 1-1 1H6.5a1 1 0 0 1 0-5H20"/>"#],
        "book-open": [#"<path d="M12 7v14"/>"#, #"<path d="M3 18a1 1 0 0 1-1-1V4a1 1 0 0 1 1-1h5a4 4 0 0 1 4 4 4 4 0 0 1 4-4h5a1 1 0 0 1 1 1v13a1 1 0 0 1-1 1h-6a3 3 0 0 0-3 3 3 3 0 0 0-3-3z"/>"#],
        "graduation-cap": [#"<path d="M21.42 10.922a1 1 0 0 0-.019-1.838L12.83 5.18a2 2 0 0 0-1.66 0L2.6 9.08a1 1 0 0 0 0 1.832l8.57 3.908a2 2 0 0 0 1.66 0z"/>"#, #"<path d="M22 10v6"/>"#, #"<path d="M6 12.5V16a6 3 0 0 0 12 0v-3.5"/>"#],
        "atom": [#"<circle cx="12" cy="12" r="1"/>"#, #"<path d="M20.2 20.2c2.04-2.03.02-7.36-4.5-11.9-4.54-4.52-9.87-6.54-11.9-4.5-2.04 2.03-.02 7.36 4.5 11.9 4.54 4.52 9.87 6.54 11.9 4.5Z"/>"#, #"<path d="M15.7 15.7c4.52-4.54 6.54-9.87 4.5-11.9-2.03-2.04-7.36-.02-11.9 4.5-4.52 4.54-6.54 9.87-4.5 11.9 2.03 2.04 7.36.02 11.9-4.5Z"/>"#],
        "flask-conical": [#"<path d="M10 2v7.527a2 2 0 0 1-.211.896L4.72 20.55a1 1 0 0 0 .9 1.45h12.76a1 1 0 0 0 .9-1.45l-5.069-10.127A2 2 0 0 1 14 9.527V2"/>"#, #"<path d="M8.5 2h7"/>"#, #"<path d="M7 16.5h10"/>"#],

        // --- Travel & Places ---
        "map": [#"<path d="M14.106 5.553a2 2 0 0 0 1.788 0l3.659-1.83A1 1 0 0 1 21 4.619v12.764a1 1 0 0 1-.553.894l-4.553 2.277a2 2 0 0 1-1.788 0l-4.212-2.106a2 2 0 0 0-1.788 0l-3.659 1.83A1 1 0 0 1 3 19.381V6.618a1 1 0 0 1 .553-.894l4.553-2.277a2 2 0 0 1 1.788 0z"/>"#, #"<path d="M15 5.764v15"/>"#, #"<path d="M9 3.236v15"/>"#],
        "map-pin": [#"<path d="M20 10c0 4.993-5.539 10.193-7.399 11.799a1 1 0 0 1-1.202 0C9.539 20.193 4 14.993 4 10a8 8 0 0 1 16 0"/>"#, #"<circle cx="12" cy="10" r="3"/>"#],
        "compass": [#"<circle cx="12" cy="12" r="10"/>"#, #"<polygon points="16.24 7.76 14.12 14.12 7.76 16.24 9.88 9.88 16.24 7.76"/>"#],
        "plane": [#"<path d="M17.8 19.2 16 11l3.5-3.5C21 6 21.5 4 21 3c-1-.5-3 0-4.5 1.5L13 8 4.8 6.2c-.5-.1-.9.1-1.1.5l-.3.5c-.2.5-.1 1 .3 1.3L9 12l-2 3H4l-1 1 3 2 2 3 1-1v-3l3-2 3.5 5.3c.3.4.8.5 1.3.3l.5-.2c.4-.3.6-.7.5-1.2z"/>"#],
        "train": [#"<path d="M8 3.1V7a4 4 0 0 0 8 0V3.1"/>"#, #"<path d="m9 15-1-1"/>"#, #"<path d="m15 15 1-1"/>"#, #"<path d="M9 19c-2.8 0-5-2.2-5-5v-4a8 8 0 0 1 16 0v4c0 2.8-2.2 5-5 5Z"/>"#, #"<path d="m8 19-2 3"/>"#, #"<path d="m16 19 2 3"/>"#],

        // --- Commerce ---
        "shopping-cart": [#"<circle cx="8" cy="21" r="1"/>"#, #"<circle cx="19" cy="21" r="1"/>"#, #"<path d="M2.05 2.05h2l2.66 12.42a2 2 0 0 0 2 1.58h9.78a2 2 0 0 0 1.95-1.57l1.65-7.43H5.12"/>"#],
        "shopping-bag": [#"<path d="M6 2 3 6v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V6l-3-4Z"/>"#, #"<path d="M3 6h18"/>"#, #"<path d="M16 10a4 4 0 0 1-8 0"/>"#],
        "tag": [#"<path d="M12.586 2.586A2 2 0 0 0 11.172 2H4a2 2 0 0 0-2 2v7.172a2 2 0 0 0 .586 1.414l8.704 8.704a2.426 2.426 0 0 0 3.42 0l6.58-6.58a2.426 2.426 0 0 0 0-3.42z"/>"#, #"<circle cx="7.5" cy="7.5" r=".5" fill="currentColor"/>"#],
        "gift": [#"<rect x="3" y="8" width="18" height="4" rx="1"/>"#, #"<path d="M12 8v13"/>"#, #"<path d="M19 12v7a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2v-7"/>"#, #"<path d="M7.5 8a2.5 2.5 0 0 1 0-5A4.8 8 0 0 1 12 8a4.8 8 0 0 1 4.5-5 2.5 2.5 0 0 1 0 5"/>"#],
        "store": [#"<path d="m2 7 4.41-4.41A2 2 0 0 1 7.83 2h8.34a2 2 0 0 1 1.42.59L22 7"/>"#, #"<path d="M4 12v8a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-8"/>"#, #"<path d="M15 22v-4a2 2 0 0 0-2-2h-2a2 2 0 0 0-2 2v4"/>"#, #"<path d="M2 7h20"/>"#, #"<path d="M22 7v3a2 2 0 0 1-2 2a2.7 2.7 0 0 1-1.59-.63.7.7 0 0 0-.82 0A2.7 2.7 0 0 1 16 12a2.7 2.7 0 0 1-1.59-.63.7.7 0 0 0-.82 0A2.7 2.7 0 0 1 12 12a2.7 2.7 0 0 1-1.59-.63.7.7 0 0 0-.82 0A2.7 2.7 0 0 1 8 12a2.7 2.7 0 0 1-1.59-.63.7.7 0 0 0-.82 0A2.7 2.7 0 0 1 4 12a2 2 0 0 1-2-2V7"/>"#],

        // --- Health ---
        "activity": [#"<path d="M22 12h-2.48a2 2 0 0 0-1.93 1.46l-2.35 8.36a.25.25 0 0 1-.48 0L9.24 2.18a.25.25 0 0 0-.48 0l-2.35 8.36A2 2 0 0 1 4.49 12H2"/>"#],
        "heart-pulse": [#"<path d="M19 14c1.49-1.46 3-3.21 3-5.5A5.5 5.5 0 0 0 16.5 3c-1.76 0-3 .5-4.5 2-1.5-1.5-2.74-2-4.5-2A5.5 5.5 0 0 0 2 8.5c0 2.3 1.5 4.05 3 5.5l7 7Z"/>"#, #"<path d="M3.22 12H9.5l.5-1 2 4.5 2-7 1.5 3.5h5.27"/>"#],
        "stethoscope": [#"<path d="M11 2v2"/>"#, #"<path d="M5 2v2"/>"#, #"<path d="M5 3H4a2 2 0 0 0-2 2v4a6 6 0 0 0 12 0V5a2 2 0 0 0-2-2h-1"/>"#, #"<path d="M8 15a6 6 0 0 0 12 0v-3"/>"#, #"<circle cx="20" cy="10" r="2"/>"#],

        // --- Misc ---
        "rocket": [#"<path d="M4.5 16.5c-1.5 1.26-2 5-2 5s3.74-.5 5-2c.71-.84.7-2.13-.09-2.91a2.18 2.18 0 0 0-2.91-.09z"/>"#, #"<path d="m12 15-3-3a22 22 0 0 1 2-3.95A12.88 12.88 0 0 1 22 2c0 2.72-.78 7.5-6 11a22.35 22.35 0 0 1-4 2z"/>"#, #"<path d="M9 12H4s.55-3.03 2-4c1.62-1.08 5 0 5 0"/>"#, #"<path d="M12 15v5s3.03-.55 4-2c1.08-1.62 0-5 0-5"/>"#],
        "trophy": [#"<path d="M6 9H4.5a2.5 2.5 0 0 1 0-5H6"/>"#, #"<path d="M18 9h1.5a2.5 2.5 0 0 0 0-5H18"/>"#, #"<path d="M4 22h16"/>"#, #"<path d="M10 14.66V17c0 .55-.47.98-.97 1.21C7.85 18.75 7 20.24 7 22"/>"#, #"<path d="M14 14.66V17c0 .55.47.98.97 1.21C16.15 18.75 17 20.24 17 22"/>"#, #"<path d="M18 2H6v7a6 6 0 0 0 12 0V2Z"/>"#],
        "anchor": [#"<path d="M12 22V8"/>"#, #"<path d="M5 12H2a10 10 0 0 0 20 0h-3"/>"#, #"<circle cx="12" cy="5" r="3"/>"#],
        "coffee": [#"<path d="M10 2v2"/>"#, #"<path d="M14 2v2"/>"#, #"<path d="M16 8a1 1 0 0 1 1 1v3a4 4 0 0 1-4 4H7a4 4 0 0 1-4-4V9a1 1 0 0 1 1-1h14a2 2 0 0 1 2 2v1a2 2 0 0 1-2 2h-1"/>"#, #"<path d="M6 2v2"/>"#, #"<path d="M3 18h18"/>"#],
        "pizza": [#"<path d="M15 11h.01"/>"#, #"<path d="M11 15h.01"/>"#, #"<path d="M16 16h.01"/>"#, #"<path d="m2 16 20 6-6-20A20 20 0 0 0 2 16"/>"#, #"<path d="M5.71 17.11a17.04 17.04 0 0 1 11.4-11.4"/>"#],
        "gamepad-2": [#"<line x1="6" x2="10" y1="11" y2="11"/>"#, #"<line x1="8" x2="8" y1="9" y2="13"/>"#, #"<line x1="15" x2="15.01" y1="12" y2="12"/>"#, #"<line x1="18" x2="18.01" y1="10" y2="10"/>"#, #"<path d="M17.32 5H6.68a4 4 0 0 0-3.978 3.59c-.006.052-.01.101-.017.152C2.604 9.416 2 14.456 2 16a3 3 0 0 0 3 3c1 0 1.5-.5 2-1l1.414-1.414A2 2 0 0 1 9.828 16h4.344a2 2 0 0 1 1.414.586L17 18c.5.5 1 1 2 1a3 3 0 0 0 3-3c0-1.545-.604-6.584-.685-7.258-.007-.05-.011-.1-.017-.151A4 4 0 0 0 17.32 5z"/>"#],
        "sparkles": [#"<path d="M9.937 15.5A2 2 0 0 0 8.5 14.063l-6.135-1.582a.5.5 0 0 1 0-.962L8.5 9.936A2 2 0 0 0 9.937 8.5l1.582-6.135a.5.5 0 0 1 .963 0L14.063 8.5A2 2 0 0 0 15.5 9.937l6.135 1.581a.5.5 0 0 1 0 .964L15.5 14.063a2 2 0 0 0-1.437 1.437l-1.582 6.135a.5.5 0 0 1-.963 0z"/>"#, #"<path d="M20 3v4"/>"#, #"<path d="M22 5h-4"/>"#, #"<path d="M4 17v2"/>"#, #"<path d="M5 18H3"/>"#],
        "wand": [#"<path d="M15 4V2"/>"#, #"<path d="M15 16v-2"/>"#, #"<path d="M8 9h2"/>"#, #"<path d="M20 9h2"/>"#, #"<path d="M17.8 11.8 19 13"/>"#, #"<path d="M15 9h.01"/>"#, #"<path d="M17.8 6.2 19 5"/>"#, #"<path d="m3 21 9-9"/>"#, #"<path d="M12.2 6.2 11 5"/>"#],
        "target": [#"<circle cx="12" cy="12" r="10"/>"#, #"<circle cx="12" cy="12" r="6"/>"#, #"<circle cx="12" cy="12" r="2"/>"#],
        "flag": [#"<path d="M4 15s1-1 4-1 5 2 8 2 4-1 4-1V3s-1 1-4 1-5-2-8-2-4 1-4 1z"/>"#, #"<line x1="4" x2="4" y1="22" y2="15"/>"#],
        "bookmark": [#"<path d="m19 21-7-4-7 4V5a2 2 0 0 1 2-2h10a2 2 0 0 1 2 2v16z"/>"#],
        "link": [#"<path d="M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71"/>"#, #"<path d="M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71"/>"#],
        "paperclip": [#"<path d="m21.44 11.05-9.19 9.19a6 6 0 0 1-8.49-8.49l8.57-8.57A4 4 0 1 1 18 8.84l-8.59 8.57a2 2 0 0 1-2.83-2.83l8.49-8.48"/>"#],
        "trash": [#"<path d="M3 6h18"/>"#, #"<path d="M19 6v14c0 1-1 2-2 2H7c-1 0-2-1-2-2V6"/>"#, #"<path d="M8 6V4c0-1 1-2 2-2h4c1 0 2 1 2 2v2"/>"#],
        "eye": [#"<path d="M2.062 12.348a1 1 0 0 1 0-.696 10.75 10.75 0 0 1 19.876 0 1 1 0 0 1 0 .696 10.75 10.75 0 0 1-19.876 0"/>"#, #"<circle cx="12" cy="12" r="3"/>"#],
        "check": [#"<path d="M20 6 9 17l-5-5"/>"#],
        "x": [#"<path d="M18 6 6 18"/>"#, #"<path d="m6 6 12 12"/>"#],
        "plus": [#"<path d="M5 12h14"/>"#, #"<path d="M12 5v14"/>"#],
        "minus": [#"<path d="M5 12h14"/>"#],
        "info": [#"<circle cx="12" cy="12" r="10"/>"#, #"<path d="M12 16v-4"/>"#, #"<path d="M12 8h.01"/>"#],
        "alert-triangle": [#"<path d="m21.73 18-8-14a2 2 0 0 0-3.48 0l-8 14A2 2 0 0 0 4 21h16a2 2 0 0 0 1.73-3"/>"#, #"<path d="M12 9v4"/>"#, #"<path d="M12 17h.01"/>"#],
        "help-circle": [#"<circle cx="12" cy="12" r="10"/>"#, #"<path d="M9.09 9a3 3 0 0 1 5.83 1c0 2-3 3-3 3"/>"#, #"<path d="M12 17h.01"/>"#],
        "refresh-cw": [#"<path d="M3 12a9 9 0 0 1 9-9 9.75 9.75 0 0 1 6.74 2.74L21 8"/>"#, #"<path d="M21 3v5h-5"/>"#, #"<path d="M21 12a9 9 0 0 1-9 9 9.75 9.75 0 0 1-6.74-2.74L3 16"/>"#, #"<path d="M8 16H3v5"/>"#],
        "sliders": [#"<line x1="4" x2="4" y1="21" y2="14"/>"#, #"<line x1="4" x2="4" y1="10" y2="3"/>"#, #"<line x1="12" x2="12" y1="21" y2="12"/>"#, #"<line x1="12" x2="12" y1="8" y2="3"/>"#, #"<line x1="20" x2="20" y1="21" y2="16"/>"#, #"<line x1="20" x2="20" y1="12" y2="3"/>"#, #"<line x1="2" x2="6" y1="14" y2="14"/>"#, #"<line x1="10" x2="14" y1="8" y2="8"/>"#, #"<line x1="18" x2="22" y1="16" y2="16"/>"#],
        "filter": [#"<polygon points="22 3 2 3 10 12.46 10 19 14 21 14 12.46 22 3"/>"#],
        "maximize": [#"<path d="M8 3H5a2 2 0 0 0-2 2v3"/>"#, #"<path d="M21 8V5a2 2 0 0 0-2-2h-3"/>"#, #"<path d="M3 16v3a2 2 0 0 0 2 2h3"/>"#, #"<path d="M16 21h3a2 2 0 0 0 2-2v-3"/>"#],
        "minimize": [#"<path d="M8 3v3a2 2 0 0 1-2 2H3"/>"#, #"<path d="M21 8h-3a2 2 0 0 1-2-2V3"/>"#, #"<path d="M3 16h3a2 2 0 0 1 2 2v3"/>"#, #"<path d="M16 21v-3a2 2 0 0 1 2-2h3"/>"#],
        "grid": [#"<rect width="18" height="18" x="3" y="3" rx="2"/>"#, #"<path d="M3 9h18"/>"#, #"<path d="M3 15h18"/>"#, #"<path d="M9 3v18"/>"#, #"<path d="M15 3v18"/>"#],
        "list": [#"<line x1="8" x2="21" y1="6" y2="6"/>"#, #"<line x1="8" x2="21" y1="12" y2="12"/>"#, #"<line x1="8" x2="21" y1="18" y2="18"/>"#, #"<line x1="3" x2="3.01" y1="6" y2="6"/>"#, #"<line x1="3" x2="3.01" y1="12" y2="12"/>"#, #"<line x1="3" x2="3.01" y1="18" y2="18"/>"#],
        "command": [#"<path d="M15 6v12a3 3 0 1 0 3-3H6a3 3 0 1 0 3 3V6a3 3 0 1 0-3 3h12a3 3 0 1 0-3-3"/>"#],
        "hash": [#"<line x1="4" x2="20" y1="9" y2="9"/>"#, #"<line x1="4" x2="20" y1="15" y2="15"/>"#, #"<line x1="10" x2="8" y1="3" y2="21"/>"#, #"<line x1="16" x2="14" y1="3" y2="21"/>"#],
        "at-sign": [#"<circle cx="12" cy="12" r="4"/>"#, #"<path d="M16 8v5a3 3 0 0 0 6 0v-1a10 10 0 1 0-4 8"/>"#],
        "send": [#"<path d="M14.536 21.686a.5.5 0 0 0 .937-.024l6.5-19a.496.496 0 0 0-.635-.635l-19 6.5a.5.5 0 0 0-.024.937l7.93 3.18a2 2 0 0 1 1.112 1.11z"/>"#, #"<path d="m21.854 2.147-10.94 10.939"/>"#],
        "inbox": [#"<polyline points="22 12 16 12 14 15 10 15 8 12 2 12"/>"#, #"<path d="M5.45 5.11 2 12v6a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2v-6l-3.45-6.89A2 2 0 0 0 16.76 4H7.24a2 2 0 0 0-1.79 1.11z"/>"#],
        "clipboard": [#"<rect width="8" height="4" x="8" y="2" rx="1" ry="1"/>"#, #"<path d="M16 4h2a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2h2"/>"#],
        "save": [#"<path d="M15.2 3a2 2 0 0 1 1.4.6l3.8 3.8a2 2 0 0 1 .6 1.4V19a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2z"/>"#, #"<path d="M17 21v-7a1 1 0 0 0-1-1H8a1 1 0 0 0-1 1v7"/>"#, #"<path d="M7 3v4a1 1 0 0 0 1 1h7"/>"#],
        "printer": [#"<path d="M6 18H4a2 2 0 0 1-2-2v-5a2 2 0 0 1 2-2h16a2 2 0 0 1 2 2v5a2 2 0 0 1-2 2h-2"/>"#, #"<path d="M6 9V3a1 1 0 0 1 1-1h10a1 1 0 0 1 1 1v6"/>"#, #"<rect x="6" y="14" width="12" height="8" rx="1"/>"#],
    ]
}

extension NSColor {
    var hexString: String {
        guard let rgb = usingColorSpace(.sRGB) else { return "000000" }
        return String(format: "%02X%02X%02X",
                      Int(rgb.redComponent * 255),
                      Int(rgb.greenComponent * 255),
                      Int(rgb.blueComponent * 255))
    }
}
