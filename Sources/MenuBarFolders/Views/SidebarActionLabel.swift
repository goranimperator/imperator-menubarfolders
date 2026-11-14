import SwiftUI

/// The icon and title of one of the sidebar's action rows: Add Folder, Settings.
///
/// One component rather than two rows that happen to look alike. SF Symbols are
/// not one width: `gear` is wider than `plus.circle.fill` at the same point size,
/// so with the glyph left at its natural size the two titles started 1.5pt apart.
/// Here every icon is scaled into the same square, and the gap after it is one
/// constant, so the titles share a left edge by construction.
struct SidebarActionLabel: View {
    let systemImage: String
    let title: String

    /// The square every icon is fitted into.
    static let iconSize: CGFloat = 15
    /// From the icon to the title.
    static let gap: CGFloat = 6

    var body: some View {
        HStack(spacing: Self.gap) {
            Image(systemName: systemImage)
                .resizable()
                .scaledToFit()
                .frame(width: Self.iconSize, height: Self.iconSize)
            Text(title)
        }
        .font(.system(size: 13))
        .foregroundColor(.secondary)
    }
}
