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

    static func calculateGridHeight(appCount: Int, columns: Int) -> CGFloat {
        let rowCount = Int(ceil(Double(appCount) / Double(columns)))
        return CGFloat(rowCount) * 68 + CGFloat(max(rowCount - 1, 0)) * 12 + 28
    }

    static func calculateWidth(columns: Int) -> CGFloat {
        CGFloat(columns) * widthPerColumn + 28
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                if let img = folderPreviewIcon(folder, size: 14) {
                    Image(nsImage: img)
                        .frame(width: 14, height: 14)
                }
                Text(folder.name)
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

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
                Button(action: onOpenSettings) {
                    HStack(spacing: 4) {
                        Image(systemName: "gear")
                        Text("Settings")
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)

                Spacer()

                Button(action: onQuit) {
                    Text("Quit")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .frame(width: FolderPopoverView.calculateWidth(columns: folder.columnsPerRow))
    }

    @ViewBuilder
    private func appCell(_ app: AppEntry) -> some View {
        let isHovered = hoveredApp == app.bundleIdentifier
        Button(action: { onOpenApp(app) }) {
            VStack(spacing: 4) {
                Image(nsImage: app.icon)
                    .resizable()
                    .frame(width: 40, height: 40)
                Text(app.displayName)
                    .font(.system(size: 10))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isHovered ? Color.primary.opacity(0.08) : Color.clear)
            )
        }
        .buttonStyle(.borderless)
        .onHover { h in hoveredApp = h ? app.bundleIdentifier : nil }
    }
}
