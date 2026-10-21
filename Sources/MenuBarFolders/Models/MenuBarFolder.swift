import Foundation

struct MenuBarFolder: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var iconName: String
    var customSVG: String?
    var apps: [AppEntry]
    var order: Int
    var columnsPerRow: Int
    /// Hidden folders keep their apps but get no menu bar icon.
    var isHidden: Bool

    init(name: String, iconName: String = "folder", customSVG: String? = nil, apps: [AppEntry] = [], order: Int = 0, columnsPerRow: Int = 3, isHidden: Bool = false) {
        self.id = UUID()
        self.name = name
        self.iconName = iconName
        self.customSVG = customSVG
        self.apps = apps
        self.order = order
        self.columnsPerRow = columnsPerRow
        self.isHidden = isHidden
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        iconName = try container.decode(String.self, forKey: .iconName)
        customSVG = try container.decodeIfPresent(String.self, forKey: .customSVG)
        apps = try container.decode([AppEntry].self, forKey: .apps)
        order = try container.decode(Int.self, forKey: .order)
        columnsPerRow = try container.decodeIfPresent(Int.self, forKey: .columnsPerRow) ?? 3
        // Added after 1.1.1, so folders.json written before it has no key here.
        isHidden = try container.decodeIfPresent(Bool.self, forKey: .isHidden) ?? false
    }

    static func == (lhs: MenuBarFolder, rhs: MenuBarFolder) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
