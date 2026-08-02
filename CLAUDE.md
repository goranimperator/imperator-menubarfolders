# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build

```bash
make install
```

Builds release with SPM, bundles as .app, codesigns with the self-signed `Imperator Dev` identity,
installs to /Applications, and launches. `make install` already kills the running instance first.
Other targets: `make run`, `make clean`.

Signing must use a stable identity, not ad-hoc. The login item registration is keyed to the bundle's
designated requirement, and ad-hoc signing mints a new cdhash per build, so every update would look
like a different app and drop the registration. Override only for throwaway builds:
`make build CODESIGN_IDENTITY=-`

## Release

```bash
make dist VERSION=1.0.0
```

Builds a zip in `dist/`. Touches nothing in git or on the remote.

```bash
make release VERSION=1.0.0
```

Bumps `Resources/Info.plist`, commits, tags `v1.0.0`, pushes, and publishes a GitHub release with
the zip attached. Needs `gh` and a clean working tree. `CFBundleVersion` comes from
`git rev-list --count HEAD` and is never hand-edited. Full checklist:
`~/.claude/skills/imperator-release/SKILL.md`.

## Architecture

- **SPM** (Package.swift) — Swift 5.9, macOS 14+
- **LSUIElement** — menu bar only, no dock icon
- **MVVM**: FolderStore (ObservableObject) → Views
- **Persistence**: `~/Library/Application Support/MenuBarFolders/folders.json`

### Key patterns

- NSStatusItem + NSPopover (from imperator-menu-bar-pong)
- HSplitView settings window (from imperator-dock-folder)
- Lucide icons as SVG element strings → SVGRenderer → NSImage with isTemplate=true
- AppDiscovery scans /Applications using string-based contentsOfDirectory (Cryptex-safe for macOS Sequoia+)
- MenuBarManager: one NSStatusItem per folder, objc_setAssociatedObject for click routing
- Popover height calculated mathematically per folder (columns × rows), set via popover.contentSize
- Deleting the last folder reopens the settings window — zero status items plus no dock icon would
  otherwise leave the app unreachable

### Data flow

MenuBarManager creates one NSStatusItem per folder → click triggers NSPopover with FolderPopoverView → app click launches via NSWorkspace. FolderStore publishes changes → MenuBarManager.syncStatusItems() rebuilds status bar.

## Structure

```
Sources/MenuBarFolders/
  main.swift              # App bootstrap (.accessory), forced dark mode + red accent
  AppDelegate.swift       # Lifecycle, settings window, app menu with Cmd+Q
  AppColors.swift         # Centralized brand color (AppColors.brand)
  ViewExtensions.swift    # .cursor(.pointingHand)
  Models/                 # MenuBarFolder, AppEntry (Codable)
  Services/               # FolderStore, MenuBarManager, AppDiscovery, LucideIcons, SVGRenderer
  Views/                  # ContentView, FolderList/Detail, AppPicker, IconPicker, Popover, Settings
```

## Brand Book

This app follows the Imperator brand book at `~/Code/imperator/imperator-apps-brandbook/BRANDBOOK.md`.

Key rules:
- **Colors**: Always use `AppColors.brand` — never inline `Color(red: 0xa0/255, ...)` or bare `Color.accentColor`
- **Dark mode**: Forced via `NSApp.appearance = NSAppearance(named: .darkAqua)` in main.swift
- **Accent override**: `UserDefaults.standard.set(0, forKey: "AppleAccentColor")` in main.swift
- **HoverButton**: opacity 0.45→1.0, .easeInOut(0.2) — defined in FolderPopoverView.swift
- **LaunchAtLoginToggle**: brand book §7.2 pattern with hover opacity — defined in SettingsView.swift
- **Popover background**: `.background(Color.black.opacity(0.15))`
- **View extensions**: Use `.cursor(.pointingHand)` on clickable non-button elements
- **Cryptex symlinks**: AppDiscovery uses string-based `contentsOfDirectory(atPath:)` + `resolvingSymlinksInPath()` (§22)
- **SPM note**: Asset catalogs don't compile in SPM, so there is no asset catalog in this repo — the
  red accent comes from the UserDefaults override, and menu bar icons are rendered from SVG data

## Conventions

- @MainActor on store and manager classes
- English only in filenames, comments, UI strings, and file content
- Commit messages in English
- No new libraries/patterns without checking existing codebase first
- Icon path data derives from Lucide (ISC) — keep the attribution header in LucideIcons.swift and
  the Third-party section in README.md
