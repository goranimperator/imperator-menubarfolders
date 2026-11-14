import SwiftUI

/// The stock macOS switch at the size and tint the sidebar rows use.
///
/// Shared so the bearings are measured once. The macOS 27 switch claims 54x24pt in
/// layout and `scaleEffect` shrinks only the drawing, so a 0.55 switch paints
/// 29.7 x 13.2pt and leaves the rest of its claimed box empty on every side. Pulled
/// back by that much, the drawn edge lands on the margin instead of 12pt inside it,
/// and a row holding the switch is as tall as its text instead of 24pt, which is
/// what lets a row gap mean the gap you can see. A fixed frame would set the same
/// size but clip the hit area, which is why it is padding: negative padding moves
/// the layout box and leaves the view, and what it answers a click on, alone.
///
/// No cursor modifier: the pointer stays the system arrow, the same as every
/// other switch on the system.
struct BrandSwitch: View {
    let title: String
    @Binding var isOn: Bool
    /// Pull the drawn switch onto the trailing margin and down to its own height.
    /// On for the sidebar rows, where the switch is the last thing in the row; off
    /// where something sits beside it, like the panel footer's Open at Login,
    /// whose panel height is computed for the full 24pt box.
    var bleed = true

    static let sideBearing: CGFloat = (54 - 54 * 0.55) / 2
    static let verticalBearing: CGFloat = (24 - 24 * 0.55) / 2

    var body: some View {
        Toggle(title, isOn: $isOn)
            .toggleStyle(.switch)
            .scaleEffect(0.55)
            .tint(AppColors.brand)
            .labelsHidden()
            .padding(.trailing, bleed ? -Self.sideBearing : 0)
            .padding(.vertical, bleed ? -Self.verticalBearing : 0)
    }
}
