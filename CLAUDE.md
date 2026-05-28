# Imperator Menu Bar Folders

macOS menu bar app for grouping apps into expandable folders.

## Build

```bash
./build.sh
```

Builds with SPM, bundles as .app, ad-hoc codesigns, installs to /Applications.

## Architecture

- **SPM** (Package.swift) — Swift 5.9, macOS 14+
- **LSUIElement** — menu bar only, no dock icon
- **MVVM**: FolderStore (ObservableObject) → Views
- **Persistence**: `~/Library/Application Support/MenuBarFolders/folders.json`

### Key patterns

- NSStatusItem + NSPopover (from imperator-menubar-pong)
- HSplitView settings window (from imperator-dock-folder)
- Lucide icons as SVG strings → NSImage(data:) with isTemplate=true
- AppDiscovery scans /Applications + checks LSUIElement for menu bar app detection
- MenuBarManager: one NSStatusItem per folder, objc_setAssociatedObject for click routing

## Structure

```
Sources/MenuBarFolders/
  main.swift              # App bootstrap (.accessory)
  AppDelegate.swift       # Lifecycle, settings window
  Models/                 # MenuBarFolder, AppEntry (Codable)
  Services/               # FolderStore, MenuBarManager, AppDiscovery, LucideIcons
  Views/                  # ContentView, FolderList/Detail, AppPicker, IconPicker, Popover
```

## Conventions

- Accent color: `Color(red: 0xa0/255, green: 0x18/255, blue: 0x18/255)`
- @MainActor on store and manager classes
- Ad-hoc codesign in build.sh (`codesign --sign - --force --deep`)
