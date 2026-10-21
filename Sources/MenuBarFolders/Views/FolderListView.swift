import SwiftUI

struct FolderListView: View {
    @Binding var selectedFolder: MenuBarFolder?
    @EnvironmentObject var store: FolderStore
    @State private var hoveredFolder: UUID?
    @State private var showDeleteAlert = false
    @State private var folderToDelete: MenuBarFolder?

    /// Whitespace around a row's fill: at the sidebar edges and between rows.
    private static let gap: CGFloat = 8
    /// Where the row's content sits, matching the rows below the list.
    private static let contentMargin: CGFloat = 20
    /// Where the row box lands inside the sidebar, measured on macOS 27 with
    /// listRowInsets zeroed. The trailing side is wider because of the scroller
    /// gutter. The outer padding below is what is left to reach Self.gap, so one
    /// re-measure fixes the row if AppKit changes them.
    private static let boxInsetLeading: CGFloat = 8
    private static let boxInsetTrailing: CGFloat = 9.5
    /// Vertical padding inside the fill. 12, not dock-folder's 6: its rows carry
    /// two lines of text and already stand tall enough.
    private static let contentPaddingY: CGFloat = 12
    /// One gap for everything in a row: grip to glyph to name on the left, and
    /// count to eye to trash on the right.
    private static let itemGap: CGFloat = 10

    var body: some View {
        // No selection binding. The list's own highlight draws the full row
        // width behind listRowBackground, so the brand pill left a lighter ring
        // of system highlight showing around it. Selection is set on tap
        // instead, and the pill is the only thing that draws it. Same reason
        // imperator-dock-folder does it this way.
        List {
            ForEach(store.folders) { folder in
                folderRow(folder)
            }
            .onMove { source, destination in
                store.reorderFolders(from: source, to: destination)
            }
        }
        // .plain, not .sidebar: the sidebar style draws its own highlight over
        // listRowBackground, so the brand fill below would never be the colour
        // actually seen.
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .padding(.vertical, Self.gap / 2)
        .frame(minWidth: 200)
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

            Text(folder.name)
                .font(.system(size: 14))
                .lineLimit(1)
                .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(.secondary))

            Spacer()

            HStack(spacing: Self.itemGap) {
                Text("\(folder.apps.count) apps")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))

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
                // the count beside it.
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
        .contentShape(Rectangle())
        .onTapGesture { selectedFolder = folder }
        .contextMenu {
            Button("Delete Folder", role: .destructive) {
                folderToDelete = folder
                showDeleteAlert = true
            }
        }
        // Inner padding, inside the fill. Reaches the 20pt margin the rows below
        // the list use, so the grip lines up with their labels.
        .padding(.leading, Self.contentMargin - Self.gap)
        .padding(.trailing, Self.contentMargin - Self.gap)
        .padding(.vertical, Self.contentPaddingY)
        .frame(maxWidth: .infinity, alignment: .leading)
        // The fill rides on the content, not on listRowBackground: that one is
        // clipped to the row box, whose trailing edge the list keeps a few
        // points inside the sidebar, so the right margin could never be made to
        // match the left. 6pt is the radius brand book 13 specifies for rows.
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? AppColors.brand : Color.clear)
        )
        // Outer padding: whatever is left to make the visible whitespace
        // Self.gap on every side.
        .padding(.leading, Self.gap - Self.boxInsetLeading)
        .padding(.trailing, Self.gap - Self.boxInsetTrailing)
        .padding(.vertical, Self.gap / 2)
        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }
}
