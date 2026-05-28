import Foundation

struct MenuBarFolder: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var iconName: String
    var customSVG: String?
    var apps: [AppEntry]
    var order: Int

    init(name: String, iconName: String = "folder", customSVG: String? = nil, apps: [AppEntry] = [], order: Int = 0) {
        self.id = UUID()
        self.name = name
        self.iconName = iconName
        self.customSVG = customSVG
        self.apps = apps
        self.order = order
    }

    static func == (lhs: MenuBarFolder, rhs: MenuBarFolder) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
