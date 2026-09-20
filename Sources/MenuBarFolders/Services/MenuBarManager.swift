import AppKit
import SwiftUI
import ObjectiveC

private var folderIDKey: UInt8 = 0

@MainActor
class MenuBarManager: NSObject {
    private var statusItems: [UUID: NSStatusItem] = [:]
    private var popovers: [UUID: MenuBarPanel] = [:]
    private var activePopoverID: UUID?
    private var eventMonitor: Any?
    private var localMonitor: Any?
    private let store: FolderStore
    private weak var appDelegate: AppDelegate?

    init(store: FolderStore, appDelegate: AppDelegate) {
        self.store = store
        self.appDelegate = appDelegate
        super.init()
    }

    func syncStatusItems() {
        let currentIDs = Set(statusItems.keys)
        let folderIDs = Set(store.folders.map { $0.id })

        for id in currentIDs.subtracting(folderIDs) {
            removeStatusItem(for: id)
        }

        for folder in store.folders {
            if statusItems[folder.id] != nil {
                updateStatusItem(for: folder)
            } else {
                createStatusItem(for: folder)
            }
        }
    }

    private func createStatusItem(for folder: MenuBarFolder) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        guard let button = item.button else { return }

        button.image = statusBarIcon(for: folder)
        button.toolTip = folder.name

        objc_setAssociatedObject(button, &folderIDKey, folder.id.uuidString, .OBJC_ASSOCIATION_RETAIN)
        button.target = self
        button.action = #selector(statusItemClicked(_:))

        statusItems[folder.id] = item
    }

    private func updateStatusItem(for folder: MenuBarFolder) {
        guard let item = statusItems[folder.id], let button = item.button else { return }
        button.image = statusBarIcon(for: folder)
        button.toolTip = folder.name
    }

    private func statusBarIcon(for folder: MenuBarFolder) -> NSImage {
        if let img = folderStatusIcon(folder, size: 18) { return img }
        let fallback = NSImage(systemSymbolName: "folder", accessibilityDescription: folder.name)!
        fallback.isTemplate = true
        return fallback
    }

    private func removeStatusItem(for id: UUID) {
        if let item = statusItems[id] {
            NSStatusBar.system.removeStatusItem(item)
        }
        statusItems.removeValue(forKey: id)
        popovers.removeValue(forKey: id)
        if activePopoverID == id { activePopoverID = nil }
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        guard let idString = objc_getAssociatedObject(sender, &folderIDKey) as? String,
              let folderID = UUID(uuidString: idString) else { return }

        if activePopoverID == folderID, let popover = popovers[folderID], popover.isShown {
            closePopover(for: folderID)
            return
        }

        if let activeID = activePopoverID {
            closePopover(for: activeID)
        }

        showPopover(for: folderID, relativeTo: sender)
    }

    private func showPopover(for folderID: UUID, relativeTo button: NSStatusBarButton) {
        guard let folder = store.folders.first(where: { $0.id == folderID }) else { return }

        let cols = folder.columnsPerRow
        let gridHeight = FolderPopoverView.calculateGridHeight(appCount: folder.apps.count, columns: cols)
        let totalHeight = FolderPopoverView.calculateTotalHeight(appCount: folder.apps.count, columns: cols)
        let totalWidth = FolderPopoverView.calculateWidth(columns: cols)

        let popoverView = FolderPopoverView(
            folder: folder,
            gridHeight: gridHeight,
            onOpenApp: { [weak self] app in
                self?.closePopover(for: folderID)
                NSWorkspace.shared.open(app.url)
            },
            onOpenSettings: { [weak self] in
                self?.closePopover(for: folderID)
                self?.appDelegate?.showSettingsWindow()
            },
            onShowAbout: { [weak self] in
                self?.closePopover(for: folderID)
                AboutPanel.show()
            },
            onQuit: {
                NSApplication.shared.terminate(nil)
            }
        )
        // A MenuBarPanel rather than an NSPopover. macOS 27 draws its own menu
        // bar panels as plain rounded rectangles: a 17.50 pt corner, no arrow
        // and no animation, measured off Control Centre's Wi-Fi panel. An
        // NSPopover draws none of that and exposes none of it for adjustment.
        //
        // It also brings the dismissal this app used to hand-write: the panel's
        // own monitor leaves the status item's click to the button's action, so
        // the toggle no longer races a panel that closed itself first.
        let panel = MenuBarPanel(content: popoverView, width: totalWidth)
        // The grid's height is calculated, not measured: the rows are laid out
        // by hand and a fitting size a point short opens the panel clipped.
        panel.contentHeight = { totalHeight }
        panel.onClose = { [weak self] in
            guard let self else { return }
            if self.activePopoverID == folderID { self.activePopoverID = nil }
        }

        popovers[folderID] = panel
        activePopoverID = folderID

        panel.show(from: button)
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKey()
    }

    private func closePopover(for folderID: UUID) {
        popovers[folderID]?.close()
        if activePopoverID == folderID { activePopoverID = nil }
        teardownEventMonitors()
    }

    private func setupEventMonitors(for folderID: UUID) {
        // Click-outside dismissal and Escape both live in MenuBarPanel now. It
        // owns the same global monitor, with the same two exceptions this app
        // had to write by hand: the pointer inside the panel, and the status
        // item's own click, which the button's action already toggles.
    }

    private func teardownEventMonitors() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }
}


