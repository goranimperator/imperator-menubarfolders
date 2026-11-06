import SwiftUI

struct FolderListView: View {
    @Binding var selectedFolder: MenuBarFolder?
    @Environment(FolderStore.self) private var store
    @State private var hoveredFolder: UUID?
    @State private var showDeleteAlert = false
    @State private var folderToDelete: MenuBarFolder?

    /// Display order as folder ids. Follows the store, except while a row is
    /// lifted, when it is the live order the other rows slide into.
    @State private var order: [UUID] = []
    @State private var lifted: LiftedRow?
    /// Height of one row including its gaps. Measured off a rendered row; the
    /// starting value is that measurement on macOS 27.
    @State private var rowPitch: CGFloat = 63

    private struct LiftedRow {
        let id: UUID
        /// Pointer position in the list's coordinate space.
        var pointerY: CGFloat
        /// Pointer minus row centre when lifted, so the row stays where it was
        /// grabbed instead of jumping to centre on the pointer.
        let grab: CGFloat
        let startOrder: [UUID]
    }

    private static let space = "folderList"
    /// The same settle imperator-dock-folder uses, so both apps reorder alike.
    private static let settle = Animation.spring(response: 0.32, dampingFraction: 0.8)

    /// Whitespace around a row's fill: at the sidebar edges and between rows.
    private static let gap: CGFloat = 8
    /// Where the row's content sits, matching the rows below the list.
    private static let contentMargin: CGFloat = 20
    /// Vertical padding inside the fill. 12, not dock-folder's 6: this sidebar is
    /// taller and the rows would otherwise crowd the controls under them.
    private static let contentPaddingY: CGFloat = 12
    /// Grip to glyph to name on the left, and eye to trash on the right while the
    /// trash is showing.
    private static let itemGap: CGFloat = 10

    var body: some View {
        // Positioned rows in a scroll view rather than a List. A List reorders
        // through a system drag session: a translucent snapshot follows the
        // pointer and an insertion line shows the target, while the rows stay put
        // until the drop. Here the row itself lifts and the others slide out of
        // its way. This departs from brand book 7.18 (.onMove) on purpose, and
        // matches imperator-dock-folder 1.0.8.
        //
        // The row box a List drew is gone with it, so boxInsetLeading and
        // boxInsetTrailing are gone too: the outer padding is now the plain gap
        // on both sides.
        GeometryReader { geo in
            ScrollView {
                ZStack(alignment: .topLeading) {
                    ForEach(orderedFolders) { folder in
                        folderRow(folder)
                            .frame(width: geo.size.width)
                            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
                                if height > 0 && abs(height - rowPitch) > 0.5 { rowPitch = height }
                            }
                            .scaleEffect(lifted?.id == folder.id ? 1.03 : 1)
                            .shadow(
                                color: .black.opacity(lifted?.id == folder.id ? 0.45 : 0),
                                radius: lifted?.id == folder.id ? 12 : 0,
                                y: lifted?.id == folder.id ? 6 : 0
                            )
                            .position(x: geo.size.width / 2, y: centerY(of: folder))
                            .zIndex(lifted?.id == folder.id ? 1 : 0)
                            // Animates the lift and, on release, the glide into
                            // the slot. While held the row tracks the pointer.
                            .animation(Self.settle, value: lifted?.id == folder.id)
                            // minimumDistance 3, so a click that does not move
                            // still reaches the row's own tap gesture and the
                            // eye and trash buttons inside it.
                            .simultaneousGesture(
                                DragGesture(minimumDistance: 3, coordinateSpace: .named(Self.space))
                                    .onChanged { value in drag(folder, value) }
                                    .onEnded { _ in drop() }
                            )
                            .accessibilityAction(named: "Move Up") { move(folder, by: -1) }
                            .accessibilityAction(named: "Move Down") { move(folder, by: 1) }
                            .transition(.opacity)
                    }
                }
                .frame(width: geo.size.width,
                       height: CGFloat(orderedFolders.count) * rowPitch + Self.gap)
                .coordinateSpace(name: Self.space)
            }
        }
        .frame(minWidth: 200)
        .onAppear { order = store.folders.map(\.id) }
        .onChange(of: store.folders.map(\.id)) { _, ids in
            // Adding, deleting, hiding and a committed reorder all land here.
            guard lifted == nil, ids != order else { return }
            withAnimation(Self.settle) { order = ids }
        }
        .alert("Delete folder?", isPresented: $showDeleteAlert, presenting: folderToDelete) { folder in
            Button("Delete", role: .destructive) {
                store.deleteFolder(folder)
                if selectedFolder?.id == folder.id {
                    selectedFolder = store.folders.first
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: { folder in
            Text("Are you sure you want to delete \"\(folder.name)\"?")
        }
    }

    @ViewBuilder
    private func folderRow(_ folder: MenuBarFolder) -> some View {
        // Everything in a selected row goes white: the brand red fill is dark
        // enough that .secondary and .tertiary disappear into it.
        let isSelected = selectedFolder?.id == folder.id
        let isHovered = hoveredFolder == folder.id

        HStack(spacing: Self.itemGap) {
            DragGrip()
                .help("Drag to reorder")
                .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(Color.gray))

            // The folder's own menu bar glyph, so a pasted custom SVG shows here
            // too. Template rendering lets it take the row's foreground, and the
            // grip's height keeps both row glyphs on one line.
            Group {
                if let img = folderStatusIcon(folder, size: DragGrip.height) {
                    Image(nsImage: img)
                        .renderingMode(.template)
                } else {
                    Image(systemName: "folder")
                }
            }
            .frame(width: DragGrip.height, height: DragGrip.height)
            .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(.secondary))

            VStack(alignment: .leading, spacing: 2) {
                Text(folder.name)
                    .font(.system(size: 14))
                    .lineLimit(1)
                    .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(.secondary))

                Text("\(folder.apps.count) apps")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
            }

            Spacer()

            // Spacing collapses with the trash, so at rest the eye is the last
            // thing in the row and sits on the margin. Left at a constant it
            // held open the gap where the hidden trash would be.
            HStack(spacing: isHovered ? Self.itemGap : 0) {
                Button(action: { store.toggleHidden(for: folder) }) {
                    Image(systemName: folder.isHidden ? "eye.slash" : "eye")
                        .font(.system(size: 13))
                        .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(.secondary))
                }
                .buttonStyle(.plain)
                .help(folder.isHidden ? "Show in the menu bar" : "Hide from the menu bar")

                Button(action: {
                    folderToDelete = folder
                    showDeleteAlert = true
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 13))
                        .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(.secondary))
                }
                // .plain, not .borderless: borderless tints the label with the
                // accent colour, so the trash came out a different colour from
                // the eye beside it.
                .buttonStyle(.plain)
                .help("Delete")
                .frame(width: isHovered ? nil : 0)
                .opacity(isHovered ? 1 : 0)
                .clipped()
            }
            .animation(.easeInOut(duration: 0.15), value: isHovered)
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                hoveredFolder = hovering ? folder.id : nil
            }
        }
        // Inner padding, inside the fill. Reaches the 20pt margin the rows below
        // the list use, so the grip lines up with their labels.
        .padding(.leading, Self.contentMargin - Self.gap)
        .padding(.trailing, Self.contentMargin - Self.gap)
        .padding(.vertical, Self.contentPaddingY)
        .frame(maxWidth: .infinity, alignment: .leading)
        // The fill rides on the content. 6pt is the radius brand book 13
        // specifies for rows.
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? AppColors.brand : Color.clear)
        )
        // Outer padding: the visible whitespace around the fill.
        .padding(.horizontal, Self.gap)
        .padding(.vertical, Self.gap / 2)
        // Hit testing goes last, so the whole padded row selects, not just the
        // area the labels happen to cover.
        .contentShape(Rectangle())
        .onTapGesture { selectedFolder = folder }
        .contextMenu {
            Button("Delete Folder", role: .destructive) {
                folderToDelete = folder
                showDeleteAlert = true
            }
        }
    }

    private var orderedFolders: [MenuBarFolder] {
        let byId = Dictionary(store.folders.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var seen = Set<UUID>()
        var result: [MenuBarFolder] = []
        for id in order {
            if let folder = byId[id], seen.insert(id).inserted { result.append(folder) }
        }
        for folder in store.folders where seen.insert(folder.id).inserted { result.append(folder) }
        return result
    }

    private func centerY(of folder: MenuBarFolder) -> CGFloat {
        if let lifted, lifted.id == folder.id {
            return lifted.pointerY - lifted.grab
        }
        let index = order.firstIndex(of: folder.id) ?? order.count
        return Self.gap / 2 + (CGFloat(index) + 0.5) * rowPitch
    }

    private func drag(_ folder: MenuBarFolder, _ value: DragGesture.Value) {
        if lifted == nil {
            lifted = LiftedRow(
                id: folder.id,
                pointerY: value.startLocation.y,
                grab: value.startLocation.y - centerY(of: folder),
                startOrder: order
            )
            NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
        }
        guard var current = lifted, current.id == folder.id else { return }
        current.pointerY = value.location.y
        lifted = current

        let rowCenter = current.pointerY - current.grab
        let target = min(max(Int(((rowCenter - Self.gap / 2) / rowPitch).rounded(.down)), 0), order.count - 1)
        if let from = order.firstIndex(of: folder.id), from != target {
            withAnimation(Self.settle) {
                order.remove(at: from)
                order.insert(folder.id, at: target)
            }
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        }
    }

    private func drop() {
        guard let current = lifted else { return }
        withAnimation(Self.settle) { lifted = nil }
        if order != current.startOrder { commitOrder() }
    }

    /// Keyboard and VoiceOver path: the List this replaced had none either, but a
    /// row that only a pointer can move is a control half finished.
    private func move(_ folder: MenuBarFolder, by step: Int) {
        guard let from = order.firstIndex(of: folder.id) else { return }
        let to = min(max(from + step, 0), order.count - 1)
        guard to != from else { return }
        withAnimation(Self.settle) {
            order.remove(at: from)
            order.insert(folder.id, at: to)
        }
        commitOrder()
    }

    private func commitOrder() {
        let byId = Dictionary(store.folders.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        store.reorderFolders(to: order.compactMap { byId[$0] })
    }
}
