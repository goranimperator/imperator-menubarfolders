import Foundation

struct MenuBarFolder: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var iconName: String
    var customSVG: String?
    var apps: [AppEntry]
    var order: Int
    var columnsPerRow: Int
    /// How many apps one page of the grid holds. The panel is sized from this
    /// rather than from the app count, so a folder of forty apps opens the same
    /// size as a folder of nine and swipes sideways for the rest.
    var itemsPerPage: Int
    /// Hidden folders keep their apps but get no menu bar icon.
    var isHidden: Bool

    init(name: String, iconName: String = "folder", customSVG: String? = nil, apps: [AppEntry] = [], order: Int = 0, columnsPerRow: Int = 3, itemsPerPage: Int = 9, isHidden: Bool = false) {
        self.id = UUID()
        self.name = name
        self.iconName = iconName
        self.customSVG = customSVG
        self.apps = apps
        self.order = order
        self.columnsPerRow = columnsPerRow
        self.itemsPerPage = itemsPerPage
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
        // Added after 1.1.4. 9 fills a three-column page three rows deep, which is
        // the default column count, so a folder written before this reads as one
        // page of nine rather than changing shape.
        itemsPerPage = try container.decodeIfPresent(Int.self, forKey: .itemsPerPage) ?? 9
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
