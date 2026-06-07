import SwiftUI

struct FolderPopoverView: View {
    let folder: MenuBarFolder
    let gridHeight: CGFloat
    let onOpenApp: (AppEntry) -> Void
    let onOpenSettings: () -> Void
    let onQuit: () -> Void

    @State private var hoveredApp: String?

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 8), count: folder.columnsPerRow)
    }

    private static let widthPerColumn: CGFloat = 80
    private static let cellHeight: CGFloat = 68
    private static let gridSpacing: CGFloat = 12
    private static let gridPadding: CGFloat = 28
    static let headerHeight: CGFloat = 40
    static let footerHeight: CGFloat = 36
    static let maxGridHeight: CGFloat = 300

    static func calculateGridHeight(appCount: Int, columns: Int) -> CGFloat {
        guard appCount > 0 else { return 0 }
        let rowCount = Int(ceil(Double(appCount) / Double(columns)))
        return CGFloat(rowCount) * cellHeight + CGFloat(max(rowCount - 1, 0)) * gridSpacing + gridPadding
    }

    static func calculateWidth(columns: Int) -> CGFloat {
        CGFloat(columns) * widthPerColumn + gridPadding
    }

    static func calculateTotalHeight(appCount: Int, columns: Int) -> CGFloat {
        let grid = min(calculateGridHeight(appCount: appCount, columns: columns), maxGridHeight)
        return headerHeight + 1 + grid + 1 + footerHeight
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                if let img = folderPreviewIcon(folder, size: 14) {
                    Image(nsImage: img)
                        .frame(width: 14, height: 14)
                }
                Text(folder.name)
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            if folder.apps.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "plus.app")
                        .font(.system(size: 28))
                        .foregroundStyle(.tertiary)
                    Text("Inga appar ännu")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Text("Öppna Settings för att lägga till appar")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(folder.apps) { app in
                            appCell(app)
                        }
                    }
                    .padding(14)
                }
                .frame(height: min(gridHeight, 300))
            }

            Divider()

            HStack {
                HoverButton(action: onOpenSettings) {
                    HStack(spacing: 4) {
                        Image(systemName: "gear")
                        Text("Settings")
                    }
                    .font(.caption)
                }

                Spacer()

                HoverButton(action: onQuit) {
                    Text("Quit")
                        .font(.caption)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .frame(width: FolderPopoverView.calculateWidth(columns: folder.columnsPerRow))
        .background(Color.black.opacity(0.15))
    }

    @ViewBuilder
    private func appCell(_ app: AppEntry) -> some View {
        let isHovered = hoveredApp == app.bundleIdentifier
        Button(action: { onOpenApp(app) }) {
            VStack(spacing: 2) {
                Image(nsImage: app.icon)
                    .resizable()
                    .frame(width: 40, height: 40)
                    .shadow(color: .black.opacity(0.4), radius: 4, y: 2)
                    .scaleEffect(isHovered ? 1.15 : 1.0)
                Text(app.displayName)
                    .font(.system(size: 10))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .foregroundStyle(.primary.opacity(isHovered ? 1.0 : 0.7))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
            .animation(.easeOut(duration: 0.12), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { h in hoveredApp = h ? app.bundleIdentifier : nil }
    }
}

struct HoverButton<Label: View>: View {
    let action: () -> Void
    @ViewBuilder let label: () -> Label
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            label()
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
        .opacity(isHovered ? 1.0 : 0.45)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
        .onHover { isHovered = $0 }
    }
}
