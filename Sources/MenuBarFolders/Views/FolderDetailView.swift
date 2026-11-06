import SwiftUI

struct FolderDetailView: View {
    @Binding var folder: MenuBarFolder
    @Environment(FolderStore.self) private var store
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

    /// Display order as bundle ids. Follows the folder, except while a row is
    /// lifted, when it is the live order the other rows slide into.
    @State private var appOrder: [String] = []
    @State private var lifted: LiftedRow?
    /// Height of one app row. Measured off a rendered row; the starting value is
    /// the 40pt icon plus the padding above and below it.
    @State private var rowPitch: CGFloat = 64

    private struct LiftedRow {
        let id: String
        /// Pointer position in the list's coordinate space.
        var pointerY: CGFloat
        /// Pointer minus row centre when lifted, so the row stays where it was
        /// grabbed instead of jumping to centre on the pointer.
        let grab: CGFloat
        let startOrder: [String]
    }

    private static let space = "appList"
    /// The same settle the sidebar uses, so both lists reorder alike.
    private static let settle = Animation.spring(response: 0.32, dampingFraction: 0.8)

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
            // Positioned rows rather than a List, the same as the sidebar: a List
            // reorders through a system drag session, where a translucent
            // snapshot follows the pointer and the rows stay put until the drop.
            // Here the row lifts and the others slide out of its way.
            //
            // The List's own 8pt leading inset is gone with it, so the rows carry
            // the full paneInset themselves and the separators are drawn here
            // instead of by listRowSeparator.
            GeometryReader { geo in
                ScrollView {
                    ZStack(alignment: .topLeading) {
                        ForEach(orderedApps) { app in
                            appRow(app, isLast: app.id == appOrder.last)
                                .frame(width: geo.size.width)
                                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
                                    if height > 0 && abs(height - rowPitch) > 0.5 { rowPitch = height }
                                }
                                .scaleEffect(lifted?.id == app.id ? 1.03 : 1)
                                .shadow(
                                    color: .black.opacity(lifted?.id == app.id ? 0.45 : 0),
                                    radius: lifted?.id == app.id ? 12 : 0,
                                    y: lifted?.id == app.id ? 6 : 0
                                )
                                .position(x: geo.size.width / 2, y: centerY(of: app))
                                .zIndex(lifted?.id == app.id ? 1 : 0)
                                .animation(Self.settle, value: lifted?.id == app.id)
                                // minimumDistance 3, so a click that does not move
                                // still reaches the rename double-tap and the
                                // pencil and remove buttons. A row with its label
                                // field open passes the drag to the field instead
                                // of lifting.
                                .simultaneousGesture(
                                    DragGesture(minimumDistance: 3, coordinateSpace: .named(Self.space))
                                        .onChanged { value in drag(app, value) }
                                        .onEnded { _ in drop() },
                                    including: editingAppId == app.id ? .subviews : .all
                                )
                                .accessibilityAction(named: "Move Up") { move(app, by: -1) }
                                .accessibilityAction(named: "Move Down") { move(app, by: 1) }
                                .transition(.opacity)
                        }
                    }
                    .frame(width: geo.size.width,
                           height: CGFloat(orderedApps.count) * rowPitch)
                    .coordinateSpace(name: Self.space)
                }
            }
            .onAppear { appOrder = folder.apps.map(\.id) }
            .onChange(of: folder.apps.map(\.id)) { _, ids in
                guard lifted == nil, ids != appOrder else { return }
                withAnimation(Self.settle) { appOrder = ids }
            }
        }
    }

    private var orderedApps: [AppEntry] {
        let byId = Dictionary(folder.apps.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var seen = Set<String>()
        var result: [AppEntry] = []
        for id in appOrder {
            if let app = byId[id], seen.insert(id).inserted { result.append(app) }
        }
        for app in folder.apps where seen.insert(app.id).inserted { result.append(app) }
        return result
    }

    private func centerY(of app: AppEntry) -> CGFloat {
        if let lifted, lifted.id == app.id {
            return lifted.pointerY - lifted.grab
        }
        let index = appOrder.firstIndex(of: app.id) ?? appOrder.count
        return (CGFloat(index) + 0.5) * rowPitch
    }

    private func drag(_ app: AppEntry, _ value: DragGesture.Value) {
        if lifted == nil {
            lifted = LiftedRow(
                id: app.id,
                pointerY: value.startLocation.y,
                grab: value.startLocation.y - centerY(of: app),
                startOrder: appOrder
            )
            NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
        }
        guard var current = lifted, current.id == app.id else { return }
        current.pointerY = value.location.y
        lifted = current

        let rowCenter = current.pointerY - current.grab
        let target = min(max(Int((rowCenter / rowPitch).rounded(.down)), 0), appOrder.count - 1)
        if let from = appOrder.firstIndex(of: app.id), from != target {
            withAnimation(Self.settle) {
                appOrder.remove(at: from)
                appOrder.insert(app.id, at: target)
            }
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        }
    }

    private func drop() {
        guard let current = lifted else { return }
        withAnimation(Self.settle) { lifted = nil }
        if appOrder != current.startOrder { commitOrder() }
    }

    /// Keyboard and VoiceOver path: the List this replaced had none either, but a
    /// row that only a pointer can move is a control half finished.
    private func move(_ app: AppEntry, by step: Int) {
        guard let from = appOrder.firstIndex(of: app.id) else { return }
        let to = min(max(from + step, 0), appOrder.count - 1)
        guard to != from else { return }
        withAnimation(Self.settle) {
            appOrder.remove(at: from)
            appOrder.insert(app.id, at: to)
        }
        commitOrder()
    }

    private func commitOrder() {
        let byId = Dictionary(folder.apps.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        store.reorderApps(in: folder, to: appOrder.compactMap { byId[$0] })
    }

    @ViewBuilder
    private func appRow(_ app: AppEntry, isLast: Bool) -> some View {
        HStack(alignment: .center, spacing: 10) {
            // The rows reorder by drag, which nothing in the row said. The grip is
            // the affordance.
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
        .padding(.horizontal, Self.paneInset)
        .padding(.vertical, Self.paneInset)
        .frame(maxWidth: .infinity, alignment: .leading)
        // Drawn here rather than by the List that used to supply it, inset to
        // paneInset on both sides so it lines up with the header and the rows.
        // The lifted row carries none: a line travelling with a floating row
        // reads as a row that has not left its slot.
        .overlay(alignment: .bottom) {
            if !isLast && lifted?.id != app.id {
                Divider().padding(.horizontal, Self.paneInset)
            }
        }
        .contentShape(Rectangle())
        .onHover { h in
            withAnimation(.easeInOut(duration: 0.1)) {
                hoveredApp = h ? app.bundleIdentifier : nil
            }
        }
    }
}
