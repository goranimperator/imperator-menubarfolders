import SwiftUI

/// Lucide `grip-vertical`, two columns of three dots, at the left of a
/// reorderable row. Same grip imperator-dock-folder and madrs-s use.
///
/// The sizes are half-points, not the 3.33pt and 1.67pt that Lucide's 24-unit
/// box gives at 20pt. A fraction like that falls between device pixels, and each
/// dot rounds by where it happens to land, so they come out visibly unequal.
/// Half-points are exact at 2x.
///
/// Drawn rather than added to LucideIcons, which feeds the folder icon picker
/// and would offer it as something to pick.
///
/// Carries no colour of its own: the caller sets `foregroundStyle`, because what
/// the grip should read as depends on whether its row is selected. See
/// `DRAG-GRIP.md`.
struct DragGrip: View {
    private static let dot: CGFloat = 3.5
    private static let columnGap: CGFloat = 1.5
    private static let rowGap: CGFloat = 2.5

    /// Three dot rows plus the two gaps between them: 15.5pt. Exposed so the
    /// glyph beside the grip can match its height exactly.
    static let height: CGFloat = dot * 3 + rowGap * 2

    var body: some View {
        VStack(spacing: Self.rowGap) {
            ForEach(0..<3, id: \.self) { _ in
                HStack(spacing: Self.columnGap) {
                    Circle().frame(width: Self.dot, height: Self.dot)
                    Circle().frame(width: Self.dot, height: Self.dot)
                }
            }
        }
    }
}
