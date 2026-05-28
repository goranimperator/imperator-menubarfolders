import AppKit
import SwiftUI
import ObjectiveC

private var folderIDKey: UInt8 = 0

@MainActor
class MenuBarManager {
    private var statusItems: [UUID: NSStatusItem] = [:]
    private var popovers: [UUID: NSPopover] = [:]
    private var activePopoverID: UUID?
    private var eventMonitor: Any?
    private let store: FolderStore
    private weak var appDelegate: AppDelegate?

    init(store: FolderStore, appDelegate: AppDelegate) {
        self.store = store
        self.appDelegate = appDelegate
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
        if let svg = folder.customSVG, let img = LucideIcons.statusBarImageFromSVG(svg) {
            return img
        }
        if let img = LucideIcons.statusBarImage(named: folder.iconName) {
            return img
        }
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
            onQuit: {
                NSApplication.shared.terminate(nil)
            }
        )
        let hostingController = NSHostingController(rootView: popoverView)
        let popover = NSPopover()
        popover.contentSize = NSSize(width: totalWidth, height: totalHeight)
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = hostingController

        popovers[folderID] = popover
        activePopoverID = folderID

        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()

        setupEventMonitor(for: folderID)
    }

    private func closePopover(for folderID: UUID) {
        popovers[folderID]?.performClose(nil)
        if activePopoverID == folderID { activePopoverID = nil }
        teardownEventMonitor()
    }

    private func setupEventMonitor(for folderID: UUID) {
        teardownEventMonitor()
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.closePopover(for: folderID)
            }
        }
    }

    private func teardownEventMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
}
