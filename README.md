<p align="center">
  <img src="Resources/AppIcon.png" width="128" height="128" alt="Imperator Menu Bar Folders app icon">
</p>

<h1 align="center">Imperator Menu Bar Folders</h1>

<p align="center">
  Group your apps into folders that live in the macOS menu bar. Each folder is its
  own menu bar icon; click it and a popover drops down with the apps inside.
</p>

## Requirements

Requires macOS 14 or later, Apple silicon. Built and tested on macOS 26 only — older versions are
expected to work but have not been verified.

Install at your own risk. The app is not notarized and carries no Apple Developer signature, so
macOS cannot vouch for it. It is provided as is, with no warranty, under the
[MIT license](LICENSE).

## Install

Download the latest zip from
[Releases](https://github.com/goranimperator/imperator-menu-bar-folders/releases), unzip, and move
`Imperator Menu Bar Folders.app` to `/Applications`.

The app is signed with a self-signed certificate and is not notarized, so Gatekeeper blocks the
first launch. Right-click the app and choose **Open**, or clear the quarantine flag:

```bash
xattr -dr com.apple.quarantine "/Applications/Imperator Menu Bar Folders.app"
```

There is no Dock icon. The app lives in the menu bar. On first launch it has no folders yet, so the
settings window opens on its own.

## Permissions

None. The app requests no Accessibility, Input Monitoring, or Automation grants, and declares no
`NSUsage` keys. It reads `/Applications`, `/System/Applications`, `~/Applications` and
`/Applications/Xcode.app/Contents/Applications` to list what is installed, and launches apps through
`NSWorkspace`.

The one system integration is **Open at Login** in the settings window. It calls
`SMAppService.mainApp.register()`, which adds the app to Login Items in System Settings. Turning the
toggle off unregisters it.

## Use

Each folder you create becomes its own icon in the menu bar. Click an icon and a popover drops down
with that folder's apps; click an app to launch it. The popover footer holds **Settings** and
**Quit**.

The settings window is where folders are built:

| Control | What it does |
|---------|--------------|
| Sidebar `+` | Create a folder |
| Folder icon | Open the icon picker — 138 Lucide icons, searchable, or paste your own SVG |
| Name field | Rename the folder; the name is also the menu bar icon's tooltip |
| Columns stepper | 2 to 6 apps per row in the popover |
| Add Apps | Pick from everything installed; apps marked **Menu bar app** declare `LSUIElement` |
| Double-click an app | Give it a custom label |
| Drag | Reorder folders in the sidebar, or apps within a folder |

The popover sizes itself from the app count and the column setting, so a folder with three apps
does not open a window built for twelve.

Deleting the last folder reopens the settings window — with no folders there are no menu bar icons,
and with no Dock icon there would be no way back in.

Folders are stored as one JSON file:

```
~/Library/Application Support/MenuBarFolders/folders.json
```

## Build from source

```bash
make install
```

Builds release, bundles, codesigns, installs to `/Applications`, and launches. Other targets:

```bash
make run
```

```bash
make clean
```

Signing uses the self-signed `Imperator Dev` identity by default. It has to be a stable identity
rather than ad-hoc: the login item registration is keyed to the bundle's designated requirement, and
ad-hoc signing mints a new hash on every build, so each update would look like a different app and
drop the registration. Override it if you do not care:

```bash
make build CODESIGN_IDENTITY=-
```

## Release

Build a zip without touching git or the remote:

```bash
make dist VERSION=1.0.0
```

Cut a full release — bumps `Info.plist`, commits, tags `v1.0.0`, pushes, and publishes a GitHub
release with the zip attached:

```bash
make release VERSION=1.0.0
```

Requires the [GitHub CLI](https://cli.github.com) (`brew install gh`, then `gh auth login`). The
working tree must be clean. Tags are plain semver (`v1.0.0`); the release title carries the app
name. `CFBundleVersion` is set from `git rev-list --count HEAD` and is never edited by hand.

## Layout

| Path | Role |
|------|------|
| `Sources/MenuBarFolders/main.swift` | Entry point, `.accessory` activation policy, forced dark mode |
| `Sources/MenuBarFolders/AppDelegate.swift` | Lifecycle, settings window, app menu with Cmd+Q |
| `Sources/MenuBarFolders/AppColors.swift` | Brand colour |
| `Sources/MenuBarFolders/Models/` | `MenuBarFolder`, `AppEntry` — both `Codable` |
| `Sources/MenuBarFolders/Services/FolderStore.swift` | `@MainActor ObservableObject`, JSON persistence |
| `Sources/MenuBarFolders/Services/MenuBarManager.swift` | One `NSStatusItem` per folder, popover lifecycle |
| `Sources/MenuBarFolders/Services/AppDiscovery.swift` | Scans the app directories, reads `LSUIElement` |
| `Sources/MenuBarFolders/Services/LucideIcons.swift` | 138 icons as SVG element data, cached as `NSImage` |
| `Sources/MenuBarFolders/Services/SVGRenderer.swift` | SVG elements and path data to `NSBezierPath` |
| `Sources/MenuBarFolders/Views/` | SwiftUI: settings window, pickers, popover |
| `Resources/` | `Info.plist` and app icon |

A SwiftPM executable with no dependencies. `LSUIElement` is true, so there is no Dock icon; the
status items are the entire interface. `MenuBarManager` keys each status item's click back to its
folder UUID with `objc_setAssociatedObject`, because `NSStatusBarButton` carries no user data of its
own.

Because SwiftPM does not compile asset catalogs, menu bar icons cannot ship as image assets. They
are stored as SVG element strings, parsed at runtime, and rendered into template `NSImage`s so macOS
tints them for light and dark menu bars.

`AppDiscovery` lists apps with the string-based `contentsOfDirectory(atPath:)` and then resolves
symlinks, because on macOS Sequoia and later some system apps are Cryptex symlinks that the
URL-based API skips.

## Third-party

Icon path data is derived from [Lucide](https://lucide.dev), used under the ISC license. Portions of
Lucide are held by Cole Bemis 2013-2022 as part of Feather (MIT); all other copyright is held by
Lucide Contributors 2022.

## License

[MIT](LICENSE) &copy; Goran Imperator
