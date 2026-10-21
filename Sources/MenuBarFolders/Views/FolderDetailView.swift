import SwiftUI

struct FolderDetailView: View {
    @Binding var folder: MenuBarFolder
    @EnvironmentObject var store: FolderStore
    @State private var editingName: String = ""
    @State private var isEditingName = false
    @State private var showAppPicker = false
    @State private var showIconPicker = false
    @State private var hoveredApp: String?
    @State private var editingAppId: String?
    @State private var editingAppName: String = ""
    @FocusState private var nameFieldFocused: Bool
    @FocusState private var appNameFieldFocused: Bool
    @State private var iconButtonHovered = false

    /// Brand book: the same hover fill the rows in Imperator DefaultBrowser use,
    /// so a hoverable surface reads the same across the apps.
    private static let hoverFill = AppColors.brand.opacity(0.1)

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            appList
        }
        .sheet(isPresented: $showAppPicker) {
            AppPickerView(folder: folder)
        }
        .sheet(isPresented: $showIconPicker) {
            IconPickerView(
                selectedIconName: Binding(
                    get: { folder.iconName },
                    set: { newIcon in store.updateIcon(for: folder, iconName: newIcon) }
                ),
                onPasteSVG: { svg in
                    store.updateIcon(for: folder, iconName: "custom", customSVG: svg)
                }
            )
        }
    }

    @ViewBuilder
    private var header: some View {
        HStack(spacing: 12) {
            // The icon is the control that opens the picker, but at rest it looks
            // like a label. The hover fill is what says it can be clicked.
            Button(action: { showIconPicker = true }) {
                if let img = folderPreviewIcon(folder, size: 28) {
                    Image(nsImage: img)
                        .frame(width: 44, height: 44)
                        .background(iconButtonHovered ? Self.hoverFill : Color.primary.opacity(0.05))
                        .cornerRadius(10)
                }
            }
            .buttonStyle(.borderless)
            .onHover { iconButtonHovered = $0 }
            .help("Change icon")

            if isEditingName {
                TextField("Name", text: $editingName, onCommit: {
                    if !editingName.isEmpty {
                        store.renameFolder(folder, to: editingName)
                    }
                    isEditingName = false
                })
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 18, weight: .semibold))
                .focused($nameFieldFocused)
                .onAppear {
                    editingName = folder.name
                    nameFieldFocused = true
                }
            } else {
                Text(folder.name)
                    .font(.system(size: 18, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .onTapGesture {
                        editingName = folder.name
                        isEditingName = true
                    }
            }

            Spacer()

            HStack(spacing: 6) {
                Text("Per row")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    // Without this the label wrapped to one character per line
                    // when the window sat at its minimum width.
                    .fixedSize()
                Picker("", selection: Binding(
                    get: { folder.columnsPerRow },
                    set: { store.updateColumns(for: folder, columns: $0) }
                )) {
                    ForEach(Self.columnOptions, id: \.self) { n in
                        Text("\(n)").tag(n)
                    }
                }
                .frame(width: 60)
                // main.swift forces the system accent to the brand red, so every
                // stock control inherits it and the number came out red. An
                // explicit tint puts this one back on the neutral the rest of
                // the header uses.
                .tint(.primary)
            }
            .help("How many apps the panel shows per row")

            // The stock macOS button, no style and no tint, same as
            // imperator-dock-folder. Bordered prominent in brand red made this
            // the loudest thing in the header.
            Button(action: { showAppPicker = true }) {
                Label("Apps", systemImage: "plus.app")
            }
            // Same reason as the Per page picker: the forced accent would make
            // this label and its glyph red.
            .tint(.primary)
        }
        // Even on all four sides. Split horizontal and vertical, the right gap
        // came out larger than the left: the icon and Add Apps are buttons and
        // carry their own chrome, which eats into the leading inset but not the
        // trailing one.
        .padding(Self.paneInset)
    }

    private static let columnOptions = [2, 3, 4, 5, 6]

    /// The one horizontal inset for every row in this pane: the header, the grid
    /// bar and the app rows. Left to each view's own default they drifted a few
    /// points apart and nothing lined up down the left edge.
    static let paneInset: CGFloat = 12

    @ViewBuilder
    private var appList: some View {
        if folder.apps.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "app.dashed")
                    .font(.system(size: 36))
                    .foregroundStyle(.tertiary)
                Text("No apps in this folder")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                Button("Add Apps") { showAppPicker = true }
                    .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                ForEach(folder.apps) { app in
                    appRow(app)
                }
                .onMove { source, destination in
                    store.reorderApps(in: folder, from: source, to: destination)
                }
            }
            // .plain, not .inset: the inset style adds a margin of its own, which
            // pushed the app rows about 17pt further in than the header above
            // them. A plain list keeps only the 8pt the row insets below top up
            // to paneInset.
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }

    @ViewBuilder
    private func appRow(_ app: AppEntry) -> some View {
        HStack(alignment: .center, spacing: 10) {
            // The rows reorder by drag, which nothing in the row said. The grip is
            // the affordance; the drag itself is still the List's own .onMove.
            DragGrip()
                .help("Drag to reorder")
                .foregroundStyle(.tertiary)

            Image(nsImage: app.icon)
                .resizable()
                .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 2) {
                if editingAppId == app.bundleIdentifier {
                    TextField("Label", text: $editingAppName, onCommit: {
                        store.renameApp(in: folder, app: app, to: editingAppName)
                        editingAppId = nil
                    })
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13))
                    .focused($appNameFieldFocused)
                    .onAppear {
                        appNameFieldFocused = true
                    }
                } else {
                    HStack(spacing: 4) {
                        Text(app.displayName)
                            .font(.system(size: 13))
                        if app.customName != nil {
                            Text(app.name)
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .onTapGesture(count: 2) {
                        editingAppName = app.displayName
                        editingAppId = app.bundleIdentifier
                    }
                }
                if app.isMenuBarApp {
                    Text("Menu bar app")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Color.secondary.opacity(0.15)))
                }
            }

            Spacer()

            if !app.exists {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.system(size: 12))
                    .help("App not found at \(app.path)")
            }

            if hoveredApp == app.bundleIdentifier {
                Button(action: {
                    editingAppName = app.displayName
                    editingAppId = app.bundleIdentifier
                }) {
                    Image(systemName: "pencil")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
                .buttonStyle(.borderless)
                .help("Rename")

                Button(action: {
                    store.removeApp(from: folder, app: app)
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.vertical, Self.paneInset)
        // A plain List keeps 8pt of its own leading inset even when these are
        // set, so this is what is left to reach paneInset and line the grips up
        // with the header icon.
        .listRowInsets(EdgeInsets(top: 0, leading: Self.paneInset - 8,
                                  bottom: 0, trailing: Self.paneInset - 8))
        // Left alone the separator starts under the app name and runs to the
        // window edge. These pin it to the row's own edges, so it ends up the
        // same 12pt in on both sides as everything else in the pane.
        .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
        .alignmentGuide(.listRowSeparatorTrailing) { $0.width }
        .onHover { h in
            withAnimation(.easeInOut(duration: 0.1)) {
                hoveredApp = h ? app.bundleIdentifier : nil
            }
        }
    }
}
