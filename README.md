# Imperator Menu Bar Folders

macOS menu bar app som grupperar appar i expanderbara mappar. Varje mapp visas som en ikon i menu bar — klicka for att visa en popover med apparna i mappen.

## Funktioner

- **Skapa mappar** i macOS menu bar med valfri Lucide-ikon
- **Klistra in custom SVG** direkt fran [lucide.dev/icons](https://lucide.dev/icons/)
- **Lagg till appar** fran alla installerade applikationer
- **Menu bar app-detektering** — appar med LSUIElement markeras automatiskt
- **Custom labels** — byt visningsnamn per app med dubbelklick
- **Kolumner per rad** — konfigurera 2–6 kolumner per mapp
- **Drag-to-reorder** — sortera mappar och appar med drag & drop
- **Dynamisk popover** — hoejd och bredd anpassas efter innehall
- **Persistens** — all data sparas som JSON lokalt
- **Launch at login** — via SMAppService

## Krav

- macOS 14 (Sonoma) eller nyare
- Swift 5.9+

## Bygga

```bash
./build.sh
```

Bygger med Swift Package Manager, skapar .app-bundle, kodsignerar (ad-hoc) och installerar till `/Applications`.

Koer manuellt:

```bash
open '/Applications/Imperator Menu Bar Folders.app'
```

## Arkitektur

```
Sources/MenuBarFolders/
  main.swift                  # App bootstrap (NSApplication .accessory)
  AppDelegate.swift           # Livscykel, settings-foenster, Edit-meny

  Models/
    MenuBarFolder.swift       # Folder-modell (namn, ikon, appar, kolumner)
    AppEntry.swift            # App-referens (bundleId, namn, custom label)

  Services/
    FolderStore.swift         # @MainActor ObservableObject, JSON-persistens
    MenuBarManager.swift      # Hanterar N st NSStatusItem + NSPopover
    AppDiscovery.swift        # Skannar /Applications, LSUIElement-check
    LucideIcons.swift         # 138 ikoner som SVG-element → NSImage
    SVGRenderer.swift         # SVG path/circle/rect/line → NSBezierPath

  Views/
    ContentView.swift         # HSplitView (sidebar + detail)
    FolderListView.swift      # Sidebar med mapplista
    FolderDetailView.swift    # Redigera mapp: namn, ikon, kolumner, appar
    AppPickerView.swift       # Vaelj appar att laegga till
    IconPickerView.swift      # Rutnaet med Lucide-ikoner + paste SVG
    FolderPopoverView.swift   # Dropdown-innehall vid klick i menu bar
    SettingsView.swift        # Open at login
```

## Tekniska beslut

| Beslut | Motivering |
|--------|-----------|
| SPM + build.sh | Inget Xcode-projekt behoevs, enkelt och reproducerbart |
| JSON-persistens | En fil, enklare aen symlinks eller CoreData |
| NSPopover | Standard macOS-beteende, automatisk positionering |
| SVG → NSBezierPath | Template images kraever programmatisk rendering |
| objc_setAssociatedObject | Mappar NSStatusBarButton-klick till raett folder UUID |
| Edit-meny i AppDelegate | LSUIElement-appar saknar standardmeny, behoevs foer Cmd+V |

## Datalagring

Mappar sparas i:

```
~/Library/Application Support/MenuBarFolders/folders.json
```

## Licens

Privat projekt — Goran Imperator.
