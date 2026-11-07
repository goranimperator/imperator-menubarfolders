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

- **SPM** (Package.swift): swift-tools-version 6.4 with `swiftLanguageMode(.v6)`,
  `defaultIsolation(MainActor.self)` and `NonisolatedNonsendingByDefault`, deployment target macOS 14.
  Everything is `@MainActor` unless it says `nonisolated`, and the compiler rejects data races rather
  than warning about them
- **LSUIElement**: menu bar only, no dock icon
- **MVVM**: FolderStore (`@Observable`) → Views, read with `@Environment(FolderStore.self)`
- **Persistence**: `~/Library/Application Support/MenuBarFolders/folders.json`

### Key patterns

- NSStatusItem + MenuBarPanel, the app's own `NSPanel`, not `NSPopover`
- HSplitView settings window (from imperator-dock-folder)
- Lucide icons as SVG element strings → SVGRenderer → NSImage with isTemplate=true
- AppDiscovery scans with string-based contentsOfDirectory (Cryptex-safe for macOS Sequoia+) and
  carries a depth budget: `nil` for the four standard directories, `3` for a mounted external drive.
  The descent guard sits after the `.app` check, so a bundle at the limit is still collected.
  `Backups.backupdb` is never descended into: a Time Machine store holds every app of every
  backed-up Mac. `VolumeScanSettings` lives in the same file and keys exclusions by volume name, not
  mount path, so the choice survives unplugging the disk. Anything the scan cannot reach is added
  with the `NSOpenPanel` behind **Choose App…** in the picker
- **Reordering**: the sidebar folder rows position themselves by hand inside a `ScrollView` and
  reorder with a plain `DragGesture`, ported from imperator-dock-folder 1.0.8. A `List` with
  `.onMove` runs a system drag session on macOS: a translucent snapshot follows the pointer and an
  insertion line marks the target while the rows stay put until the drop. Here the row lifts and the
  others slide. This departs from brand book 7.18 on purpose. An `order` array of ids gives each row
  its slot, a `lifted` struct holds the pointer position and the grab offset, `rowPitch` is measured
  off a rendered row with `onGeometryChange`, `spring(response: 0.32, dampingFraction: 0.8)` is the
  settle, `.levelChange` haptics fire on lift and `.alignment` on each slot change, and the drop
  writes once through `reorderFolders(to:)`. `minimumDistance: 3` on a `simultaneousGesture` keeps
  taps and the row buttons working. No auto-scroll past the visible rows
- **App grid**: the detail pane is `AppGridCarousel`, a paged grid ported from the same release.
  Hold an app for 380ms, or press **Arrange**, and the grid starts arranging: the icons wiggle,
  remove badges appear, the held icon lifts and the others slide out of its way, and resting it
  within 36pt of a side edge for 550ms turns the page and keeps turning. **Done**, Escape or a click
  on empty grid space ends it. The wiggle is a `TimelineView`, never `repeatForever`: a repeating
  animation leaks into every change in the same transaction and sets the slide into slot wobbling.
  `GridPaging.swift` holds the parts with no view in them, `GridMetrics`, `pageCount` and
  `PageSwipeAccumulator`, so the arithmetic can be compiled and exercised on its own
- **Sideways swipe**: three ways in, because a panel has to answer a trackpad, a mouse wheel and a
  click-drag. A trackpad reports a gesture, so a page turn is a horizontal swipe, one per gesture,
  with the momentum tail ignored and vertical scrolling left alone. A plain wheel reports no phase,
  no momentum and usually no horizontal axis at all, so held to the trackpad rules it could never
  turn a page and the accumulator would never reset; `PageSwipeAccumulator` splits on
  `hasPreciseScrollingDeltas` plus the phase fields and gives the wheel its own path: whichever axis
  moves, two detents, reset after a 0.25s pause. Click-drag is a `DragGesture(minimumDistance: 0)`
  on the cells and on the grid behind them, which turns into a swipe past 6pt of travel. The cells
  are deliberately not `Button`s: a button fires on mouse-up wherever the pointer has been, so a
  swipe begun on an icon launched that app when it was released
- **Where the scroll comes from**: two routes, because event delivery differs. The settings window
  uses `ScrollWheelOverlay`, an `NSViewRepresentable` whose view installs a local `.scrollWheel`
  monitor and only asks whether the pointer is over its own bounds; it returns nil from `hitTest` so
  it never takes a click. Overriding `scrollWheel(with:)` behind the grid instead only ever saw
  scrolls in the gaps between icons. The menu bar panel cannot use a monitor at all: it is a
  `.nonactivatingPanel`, so the app is not frontmost while it is open. It overrides
  `scrollWheel(with:)` on the window and feeds `PanelScrollRelay`
- **Per page**: `MenuBarFolder.itemsPerPage`, default 9, `decodeIfPresent` so folders.json written
  before 1.1.4 still reads. The panel's height comes from `min(appCount, itemsPerPage)` rows, not
  from the app count, so a folder of forty apps opens the same size as one of nine. There is no
  grid height cap and no scroll view inside a page: a page is exactly its slots, so a cap would hide
  rows with no way to reach them, and a scroll view would swallow the vertical half of every
  gesture. `MenuBarPanel.show` clamps the finished panel to what is below the menu bar instead
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
  Services/               # FolderStore, MenuBarManager, MenuBarPanel, AppDiscovery, GridPaging, LucideIcons, SVGRenderer
  Views/                  # ContentView, FolderList/Detail, AppGridCarousel, AppPicker, IconPicker, Popover, Settings, AboutPanel
```

## Brand Book

This app follows the Imperator brand book at `~/Code/imperator/imperator-apps-brandbook/BRANDBOOK.md`.

Key rules:
- **Colors**: Always use `AppColors.brand`, never inline `Color(red: 0xa0/255, ...)` or bare `Color.accentColor`
- **Dark mode**: Forced via `NSApp.appearance = NSAppearance(named: .darkAqua)` in main.swift
- **Accent override**: `UserDefaults.standard.set(0, forKey: "AppleAccentColor")` in main.swift
- **HoverButton**: opacity 0.45 to 1.0, .easeInOut(0.2), defined in FolderPopoverView.swift
- **Hover fill**: a hoverable surface that is not a HoverButton fills with
  `AppColors.brand.opacity(0.1)` behind its own resting background, `.easeInOut(0.2)`, the same
  value the rows in imperator-menu-bar-default-browser use
- **Drag grip**: `DragGrip.swift`, two columns of three dots at the left of a reorderable row, shared
  by the sidebar and the app list. It carries no colour of its own; the caller sets
  `foregroundStyle`. The sizes are half-points on purpose: see `DRAG-GRIP.md`, written to be handed
  to the other Imperator apps
- **Sidebar rows**: ported from imperator-dock-folder. The brand fill rides on the padded content
  through `.background(RoundedRectangle(cornerRadius: 6))`. There is no `List` any more, so there is
  no row box either: the outer padding is the plain `gap` on both sides and `boxInsetLeading` /
  `boxInsetTrailing` are gone with it. The folder name sits above the app count in one
  `VStack(alignment: .leading, spacing: 2)`. The trailing `HStack` takes `spacing: isHovered ?
  itemGap : 0`, so at rest the eye is the last thing in the row and lands on the margin instead of
  holding open the gap where the hidden trash would be
- **Detail pane**: two rows of chrome over the grid, the shape imperator-dock-folder uses. The
  header carries the folder icon button, the name, then Arrange (or Done) and Add Apps; the bar under it
  carries Per row, Per page and the dot-matrix page preview. One constant,
  `FolderDetailView.paneInset`, insets both, so everything lines up down each edge
- **External drives**: `ExternalDrivesView` sits under the Add Folder row and above Open at Login,
  with the other controls that put apps into a folder. The master switch is **Scan drives for
  apps**, pulled right by `switchSideBearing` because the macOS 27 switch claims 54pt in layout and
  `scaleEffect(0.55)` paints 29.7 of them, so the drawn edge would otherwise sit 12pt inside the
  margin; one row per mounted drive follows,
  indented 12pt, and the list refreshes on `NSWorkspace.didMountNotification` and
  `didUnmountNotification`. The per-drive switch reads as "scan this drive", so it is the inverse of
  the stored exclusion. Every switch repeats LaunchAtLoginToggle's shape: `.switch`,
  `scaleEffect(0.55)`, `.tint(AppColors.brand)`, no frame and no cursor modifier
- **Hidden folders**: `MenuBarFolder.isHidden`. `syncStatusItems` filters on it, so a hidden folder
  keeps its apps and its settings row but owns no status item. Hiding the last visible folder
  reopens the settings window, the same guard deleting the last folder uses
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

- `defaultIsolation(MainActor.self)` makes @MainActor the default; only `nonisolated` is worth
  writing. `AppDiscovery`, `VolumeScanSettings` and `DiscoveredApp` are `nonisolated` because the
  picker scans in a detached task, and `MenuBarPanel.stopMonitoring()` is, because `deinit` is
- English only in filenames, comments, UI strings, and file content
- Commit messages in English
- No new libraries/patterns without checking existing codebase first
- Icon path data derives from Lucide (ISC): keep the attribution header in LucideIcons.swift and
  the Third-party section in README.md
