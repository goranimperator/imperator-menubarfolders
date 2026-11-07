import SwiftUI

struct FolderDetailView: View {
    @Binding var folder: MenuBarFolder
    @Environment(FolderStore.self) private var store
    @State private var editingName: String = ""
    @State private var isEditingName = false
    @State private var showAppPicker = false
    @State private var showIconPicker = false
    @FocusState private var nameFieldFocused: Bool
    @State private var iconButtonHovered = false
    @State private var isArranging = false

    /// Brand book: the same hover fill the rows in Imperator DefaultBrowser use,
    /// so a hoverable surface reads the same across the apps.
    private static let hoverFill = AppColors.brand.opacity(0.1)

    /// The one horizontal inset for every row in this pane: the header, the grid
    /// bar and the grid. Left to each view's own default they drifted a few
    /// points apart and nothing lined up down the left edge.
    static let paneInset: CGFloat = 12

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            gridSettingsBar
            Divider()
            grid
        }
        .onChange(of: folder.id) { _, _ in isArranging = false }
        .onChange(of: folder.apps.isEmpty) { _, empty in
            if empty { isArranging = false }
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

    // MARK: - Header

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

            if !folder.apps.isEmpty {
                if isArranging {
                    // The one filled control on screen while arranging, so the
                    // way out is never in doubt.
                    Button(action: { withAnimation(.easeOut(duration: 0.2)) { isArranging = false } }) {
                        Text("Done")
                            .fontWeight(.semibold)
                            .frame(minWidth: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppColors.brand)
                    .help("Stop arranging (Esc)")
                } else {
                    Button(action: { withAnimation(.easeOut(duration: 0.2)) { isArranging = true } }) {
                        Label("Arrange", systemImage: "square.grid.3x3")
                    }
                    // main.swift forces the system accent to the brand red, so
                    // every stock control inherits it. An explicit tint puts this
                    // one back on the neutral the rest of the header uses.
                    .tint(.primary)
                    .help("Move and remove apps. You can also hold an app to start.")
                }
            }

            // The stock macOS button, no style, same as imperator-dock-folder.
            // Bordered prominent in brand red made this the loudest thing here.
            Button(action: { showAppPicker = true }) {
                Label("Add Apps", systemImage: "plus.app")
            }
            .tint(.primary)
        }
        // Even on all four sides. Split horizontal and vertical, the right gap
        // came out larger than the left: the icon and Add Apps are buttons and carry
        // their own chrome, which eats into the leading inset but not the
        // trailing one.
        .padding(Self.paneInset)
    }

    // MARK: - Grid settings

    private static let columnOptions = [2, 3, 4, 5, 6]
    /// 20 fills a four-column page five rows deep.
    private static let pageOptions = [4, 6, 8, 9, 12, 16, 20]

    @ViewBuilder
    private var gridSettingsBar: some View {
        HStack(spacing: 20) {
            labelledPicker(
                "Per row",
                help: "How many apps the panel shows per row",
                options: Self.columnOptions,
                selection: Binding(
                    get: { folder.columnsPerRow },
                    set: { store.updateColumns(for: folder, columns: $0) }
                )
            )

            labelledPicker(
                "Per page",
                help: "How many apps one page holds before the grid swipes sideways",
                options: Self.pageOptions,
                selection: Binding(
                    get: { folder.itemsPerPage },
                    set: { store.updateItemsPerPage(for: folder, itemsPerPage: $0) }
                )
            )

            Spacer()

            gridPreview
        }
        .padding(.horizontal, Self.paneInset)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func labelledPicker(_ title: String, help: String, options: [Int],
                                selection: Binding<Int>) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                // Without this the label wrapped to one character per line when
                // the window sat at its minimum width.
                .fixedSize()
            Picker("", selection: selection) {
                ForEach(options, id: \.self) { n in
                    Text("\(n)").tag(n)
                }
            }
            .frame(width: 60)
            // Same reason as the header buttons: the forced accent would make
            // the number red.
            .tint(.primary)
        }
        .help(help)
    }

    /// The page shape at a glance: filled cells are the slots one page holds,
    /// empty ones the rest of the last row.
    private var gridPreview: some View {
        let cols = folder.columnsPerRow
        let rows = Int(ceil(Double(folder.itemsPerPage) / Double(cols)))
        return VStack(spacing: 1.5) {
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: 1.5) {
                    ForEach(0..<cols, id: \.self) { col in
                        let index = row * cols + col
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(index < folder.itemsPerPage
                                  ? AppColors.brand.opacity(0.5)
                                  : Color.secondary.opacity(0.15))
                            .frame(width: 8, height: 8)
                    }
                }
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
        )
        .help("\(folder.itemsPerPage) apps per page, \(folder.columnsPerRow) per row")
    }

    // MARK: - Grid

    @ViewBuilder
    private var grid: some View {
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
                    .tint(.primary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            AppGridCarousel(
                apps: folder.apps,
                columns: folder.columnsPerRow,
                itemsPerPage: folder.itemsPerPage,
                isArranging: $isArranging,
                onRemove: { app in store.removeApp(from: folder, app: app) },
                onReorder: { newOrder in store.reorderApps(in: folder, to: newOrder) },
                onSetLabel: { app, label in
                    store.renameApp(in: folder, app: app, to: label ?? "")
                }
            )
            // One carousel per folder, so switching folders starts on page one
            // instead of animating the last folder's icons into this one's.
            .id(folder.id)
        }
    }
}
