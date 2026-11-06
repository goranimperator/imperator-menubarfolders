import Foundation
import Observation
import SwiftUI

/// `@Observable` rather than `ObservableObject`: an `objectWillChange` send
/// re-renders every view observing the store, so hiding one folder redrew the whole
/// settings window. Observation tracks the properties a view actually read, which is
/// what keeps the reordering rows from being redrawn by changes they do not use.
@MainActor
@Observable
final class FolderStore {
    var folders: [MenuBarFolder] = []

    private let storageURL: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("MenuBarFolders")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        storageURL = dir.appendingPathComponent("folders.json")
        load()
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: storageURL.path) else { return }
        guard let data = try? Data(contentsOf: storageURL),
              let decoded = try? JSONDecoder().decode([MenuBarFolder].self, from: data) else { return }
        folders = decoded.sorted { $0.order < $1.order }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(folders) else { return }
        try? data.write(to: storageURL, options: .atomic)
    }

    func createFolder(name: String, iconName: String = "folder") {
        let folder = MenuBarFolder(name: name, iconName: iconName, order: folders.count)
        folders.append(folder)
        save()
        syncMenuBar()
    }

    func deleteFolder(_ folder: MenuBarFolder) {
        folders.removeAll { $0.id == folder.id }
        reindex()
        save()
        syncMenuBar()
        // With no folders there are no status items, and an LSUIElement app has no
        // Dock icon -- closing the settings window would leave no way back in.
        if folders.isEmpty {
            AppDelegate.shared?.showSettingsWindow()
        }
    }

    func renameFolder(_ folder: MenuBarFolder, to name: String) {
        guard let idx = folders.firstIndex(where: { $0.id == folder.id }) else { return }
        folders[idx].name = name
        save()
        syncMenuBar()
    }

    func updateIcon(for folder: MenuBarFolder, iconName: String, customSVG: String? = nil) {
        guard let idx = folders.firstIndex(where: { $0.id == folder.id }) else { return }
        folders[idx].iconName = iconName
        folders[idx].customSVG = customSVG
        save()
        syncMenuBar()
    }

    func addApp(to folder: MenuBarFolder, app: AppEntry) {
        guard let idx = folders.firstIndex(where: { $0.id == folder.id }) else { return }
        guard !folders[idx].apps.contains(where: { $0.bundleIdentifier == app.bundleIdentifier }) else { return }
        folders[idx].apps.append(app)
        save()
    }

    func removeApp(from folder: MenuBarFolder, app: AppEntry) {
        guard let idx = folders.firstIndex(where: { $0.id == folder.id }) else { return }
        folders[idx].apps.removeAll { $0.bundleIdentifier == app.bundleIdentifier }
        save()
    }

    func renameApp(in folder: MenuBarFolder, app: AppEntry, to newName: String) {
        guard let fIdx = folders.firstIndex(where: { $0.id == folder.id }),
              let aIdx = folders[fIdx].apps.firstIndex(where: { $0.bundleIdentifier == app.bundleIdentifier }) else { return }
        folders[fIdx].apps[aIdx].customName = newName.isEmpty ? nil : newName
        save()
    }

    func updateColumns(for folder: MenuBarFolder, columns: Int) {
        guard let idx = folders.firstIndex(where: { $0.id == folder.id }) else { return }
        folders[idx].columnsPerRow = max(2, min(columns, 6))
        save()
    }

    func toggleHidden(for folder: MenuBarFolder) {
        guard let idx = folders.firstIndex(where: { $0.id == folder.id }) else { return }
        folders[idx].isHidden.toggle()
        save()
        syncMenuBar()
        // Hiding the last visible folder leaves no status items, and an
        // LSUIElement app has no Dock icon, so closing the settings window would
        // leave no way back in. Same trap as deleting the last folder.
        if folders.allSatisfy({ $0.isHidden }) {
            AppDelegate.shared?.showSettingsWindow()
        }
    }

    /// Takes the whole order rather than a move, because the rows reorder by hand
    /// now: the list has already settled into this arrangement by the time the
    /// drag ends, and this is the one write that drop makes.
    func reorderFolders(to ordered: [MenuBarFolder]) {
        guard ordered.count == folders.count else { return }
        folders = ordered
        reindex()
        save()
        syncMenuBar()
    }

    func reorderApps(in folder: MenuBarFolder, to ordered: [AppEntry]) {
        guard let idx = folders.firstIndex(where: { $0.id == folder.id }),
              ordered.count == folders[idx].apps.count else { return }
        folders[idx].apps = ordered
        save()
    }

    private func reindex() {
        for i in folders.indices {
            folders[i].order = i
        }
    }

    private func syncMenuBar() {
        AppDelegate.shared?.menuBarManager.syncStatusItems()
    }
}
