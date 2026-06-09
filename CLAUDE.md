# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build

```bash
./build.sh
```

Builds with SPM, bundles as .app, ad-hoc codesigns, installs to /Applications.
Restart after install: `pkill -x MenuBarFolders; sleep 0.5; open '/Applications/Imperator Menu Bar Folders.app'`

## Architecture

- **SPM** (Package.swift) — Swift 5.9, macOS 14+
- **LSUIElement** — menu bar only, no dock icon
- **MVVM**: FolderStore (ObservableObject) → Views
- **Persistence**: `~/Library/Application Support/MenuBarFolders/folders.json`

### Key patterns

- NSStatusItem + NSPopover (from imperator-menubar-pong)
- HSplitView settings window (from imperator-dock-folder)
- Lucide icons as SVG strings → NSImage(data:) with isTemplate=true
- AppDiscovery scans /Applications using string-based contentsOfDirectory (Cryptex-safe for macOS Sequoia+)
- MenuBarManager: one NSStatusItem per folder, objc_setAssociatedObject for click routing
- Popover height calculated mathematically per folder (columns × rows), set via popover.contentSize

### Data flow

MenuBarManager creates one NSStatusItem per folder → click triggers NSPopover with FolderPopoverView → app click launches via NSWorkspace. FolderStore publishes changes → MenuBarManager.syncStatusItems() rebuilds status bar.

## Structure

```
Sources/MenuBarFolders/
  main.swift              # App bootstrap (.accessory), forced dark mode + red accent
  AppDelegate.swift       # Lifecycle, settings window, app menu with Cmd+Q
  AppColors.swift         # Centralized brand colors (AppColors.brand, .brandNS, etc.)
  ViewExtensions.swift    # .cursor(.pointingHand), .expandTapTarget()
  Models/                 # MenuBarFolder, AppEntry (Codable)
  Services/               # FolderStore, MenuBarManager, AppDiscovery, LucideIcons
  Views/                  # ContentView, FolderList/Detail, AppPicker, IconPicker, Popover
```

## Brand Book

This app follows the Imperator brand book at `~/Code/imperator-mac-apps-brandbook/BRANDBOOK.md`.

Key rules:
- **Colors**: Always use `AppColors.brand` — never inline `Color(red: 0xa0/255, ...)` or bare `Color.accentColor`
- **Dark mode**: Forced via `NSApp.appearance = NSAppearance(named: .darkAqua)` in main.swift
- **Accent override**: `UserDefaults.standard.set(0, forKey: "AppleAccentColor")` in main.swift
- **HoverButton**: opacity 0.45→1.0, .easeInOut(0.2) — defined in FolderPopoverView.swift
- **LaunchAtLoginToggle**: brand book §7.2 pattern with hover opacity — defined in SettingsView.swift
- **Popover background**: `.background(Color.black.opacity(0.15))`
- **View extensions**: Use `.cursor(.pointingHand)` on clickable non-button elements, `.expandTapTarget()` on tappable containers
- **Cryptex symlinks**: AppDiscovery uses string-based `contentsOfDirectory(atPath:)` + `resolvingSymlinksInPath()` (§22)
- **SPM note**: Asset catalogs don't compile in SPM — AccentColor.colorset is non-functional, rely on UserDefaults method only

## Conventions

- @MainActor on store and manager classes
- Ad-hoc codesign in build.sh (`codesign --sign - --force --deep`)
- Commit messages in English
- No new libraries/patterns without checking existing codebase first
