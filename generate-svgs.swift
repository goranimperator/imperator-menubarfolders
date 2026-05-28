#!/usr/bin/env swift
// Generates SVG files from LucideIcons.swift icon data into Resources/icons/
// Run: swift generate-svgs.swift

import Foundation

let sourcePath = "Sources/MenuBarFolders/Services/LucideIcons.swift"
let outputDir = "Resources/icons"

guard let source = try? String(contentsOfFile: sourcePath, encoding: .utf8) else {
    print("Could not read \(sourcePath)")
    exit(1)
}

try? FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

// Parse icon entries from the Swift source
// Format: "icon-name": [#"<element/>"#, #"<element/>"#],
let pattern = #"\"([a-z0-9-]+)\"\s*:\s*\[((?:#\"[^\"]*\"#(?:,\s*)?)+)\]"#
guard let regex = try? NSRegularExpression(pattern: pattern) else {
    print("Regex failed"); exit(1)
}

let range = NSRange(source.startIndex..., in: source)
let matches = regex.matches(in: source, range: range)

var count = 0
for match in matches {
    guard let nameRange = Range(match.range(at: 1), in: source),
          let elemRange = Range(match.range(at: 2), in: source) else { continue }

    let name = String(source[nameRange])
    let rawElements = String(source[elemRange])

    // Extract individual element strings from #"..."#
    let elemPattern = #"#\"([^\"]+)\"#"#
    guard let elemRegex = try? NSRegularExpression(pattern: elemPattern) else { continue }
    let elemNSRange = NSRange(rawElements.startIndex..., in: rawElements)
    let elemMatches = elemRegex.matches(in: rawElements, range: elemNSRange)

    var elements: [String] = []
    for em in elemMatches {
        guard let r = Range(em.range(at: 1), in: rawElements) else { continue }
        elements.append(String(rawElements[r]))
    }

    let svg = """
    <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
      \(elements.joined(separator: "\n  "))
    </svg>
    """

    let path = "\(outputDir)/\(name).svg"
    try? svg.write(toFile: path, atomically: true, encoding: .utf8)
    count += 1
}

print("Generated \(count) SVG files in \(outputDir)/")
