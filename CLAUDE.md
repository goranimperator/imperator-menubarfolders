# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build

```bash
make install
```

Builds release with SPM, bundles as .app, codesigns with the self-signed `Imperator Dev` identity,
installs to /Applications, and launches. `make install` already kills the running instance first.
Other targets: `make run`, `make clean`.

The build passes `-platform_version macos 14.0 $(SDK_VERSION)` to the linker. AppKit picks the
generation of a control from the `sdk` field in `LC_BUILD_VERSION`, and SwiftPM stamps that from
`platforms:` rather than the SDK it built against, so without the flag the binary reports `sdk 14.0`
and draws macOS 14 era switches. Never raise `platforms:` to fix this: that makes the new value the
minimum and the repo is public with a macOS 14 promise. Verify with:
`otool -l "build/Imperator MenuBarFolders.app/Contents/MacOS/MenuBarFolders" | awk '/LC_BUILD_VERSION/,/^$/'`

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

- **SPM** (Package.swift): swift-tools-version 6.4 with `swiftLanguageMode(.v5)`, deployment target macOS 14
- **LSUIElement**: menu bar only, no dock icon
- **MVVM**: FolderStore (ObservableObject) → Views
- **Persistence**: `~/Library/Application Support/MenuBarFolders/folders.json`

### Key patterns

- NSStatusItem + MenuBarPanel, the app's own `NSPanel`, not `NSPopover`
- HSplitView settings window (from imperator-dock-folder)
- Lucide icons as SVG element strings → SVGRenderer → NSImage with isTemplate=true
- AppDiscovery scans /Applications using string-based contentsOfDirectory (Cryptex-safe for macOS Sequoia+)
- MenuBarManager: one NSStatusItem per folder, objc_setAssociatedObject for click routing
- Panel height calculated mathematically per folder (columns × rows) and handed to the panel through
  `contentHeight`, because a SwiftUI fitting size a point short opens the panel clipped
- Never go back to `NSPopover`. It draws neither the shape nor the corner macOS puts on a menu bar
  panel, and exposes no radius to set. `MenuBarPanel.swift` carries the measurements and the reason
  its constant sits higher than the corner it draws; read them there rather than restating them
- `MenuBarPanel` owns dismissal: its own global mouse-down monitor and a local keyDown monitor for
  Escape, plus `onClose` so the owner can clear `activePopoverID`. MenuBarManager no longer writes
  any of that by hand, and `setupEventMonitors` is left empty on purpose
- Outside is decided from `NSEvent.mouseLocation`, never from the monitor having fired. A global
  monitor is documented to see only other apps' events, but the first click into an inactive
  `.accessory` app reaches it too, so closing on every event shut the panel before the click landed
  on the control under the cursor. The status item's own window is excluded as well, or the panel
  closes a moment before `statusItemClicked` runs and the toggle reopens it
- No arrow and no open or close animation. macOS 27's own menu bar panels have neither
- Deleting the last folder reopens the settings window, because zero status items plus no dock icon would
  otherwise leave the app unreachable

### Data flow

MenuBarManager creates one NSStatusItem per folder → click shows a MenuBarPanel hosting FolderPopoverView → app click launches via NSWorkspace. FolderStore publishes changes → MenuBarManager.syncStatusItems() rebuilds status bar.

## Structure

```
Sources/MenuBarFolders/
  main.swift              # App bootstrap (.accessory), forced dark mode + red accent
  AppDelegate.swift       # Lifecycle, settings window, app menu with Cmd+Q
  AppColors.swift         # Centralized brand color (AppColors.brand)
  Models/                 # MenuBarFolder, AppEntry (Codable)
  Services/               # FolderStore, MenuBarManager, MenuBarPanel, AppDiscovery, LucideIcons, SVGRenderer
  Views/                  # ContentView, FolderList/Detail, AppPicker, IconPicker, Popover, Settings, AboutPanel
```

## Brand Book

This app follows the Imperator brand book at `~/Code/imperator/imperator-apps-brandbook/BRANDBOOK.md`.

Key rules:
- **Colors**: Always use `AppColors.brand`, never inline `Color(red: 0xa0/255, ...)` or bare `Color.accentColor`
- **Dark mode**: Forced via `NSApp.appearance = NSAppearance(named: .darkAqua)` in main.swift
- **Accent override**: `UserDefaults.standard.set(0, forKey: "AppleAccentColor")` in main.swift
- **HoverButton**: opacity 0.45 to 1.0, .easeInOut(0.2), defined in FolderPopoverView.swift
- **LaunchAtLoginToggle**: brand book §7.2 pattern with hover opacity, defined in SettingsView.swift.
  The switch carries no fixed frame and no cursor modifier: on macOS 27 it claims 54x24pt in layout
  and `scaleEffect` shrinks only the drawing, so a frame clips the hit area without setting the size
- **Panel header**: the folder's own menu bar glyph at 16pt via `folderStatusIcon`, rendered as a
  template so it takes `.primary`, then the folder name in `.headline`, `spacing: 8`, H16 V12. Same
  shape as imperator-widget-clock's header. Do not use `folderPreviewIcon` here: it bakes in white
- **Panel footer**: `HStack(spacing: 12)`. About closes the panel before opening the About window
- **Panel width**: floored at the brand book's 340, which every other Imperator menu bar panel uses.
  At 300 the footer truncated "Open at Login"
- **Panel surface**: `MenuBarPanel` lays down `NSVisualEffectView` with `.popover` material and
  rounds itself; the SwiftUI content paints `AppColors.popoverBackground`, brand book 6.1's
  `.black.opacity(0.15)`, over it. Nothing in the content clips or rounds a second time
- **About panel**: brand book §10, `NSPanel` 300x260pt, computed `© 1986-<year>` line, in
  AboutPanel.swift. No `backgroundColor`, only `darkAqua`, same as imperator-widget-clock.
  `hidesOnDeactivate = false` is required: an NSPanel hides itself when the app deactivates, and an
  .accessory app deactivates on the first click anywhere else
- **Main-actor**: AppDelegate is `@MainActor`; main.swift builds it with `MainActor.assumeIsolated`
- **Hover cursor**: never change it. Clickable non-button elements keep the macOS default arrow, the same as the rest of the system
- **Cryptex symlinks**: AppDiscovery uses string-based `contentsOfDirectory(atPath:)` + `resolvingSymlinksInPath()` (§22)
- **SPM note**: Asset catalogs don't compile in SPM, so there is no asset catalog in this repo. The
  red accent comes from the UserDefaults override, and menu bar icons are rendered from SVG data

## Conventions

- @MainActor on store and manager classes
- English only in filenames, comments, UI strings, and file content
- Commit messages in English
- No new libraries/patterns without checking existing codebase first
- Icon path data derives from Lucide (ISC): keep the attribution header in LucideIcons.swift and
  the Third-party section in README.md
