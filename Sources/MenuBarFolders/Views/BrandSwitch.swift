import SwiftUI

/// The stock macOS switch at the size and tint the sidebar rows use.
///
/// Shared so the side bearing is measured once. The macOS 27 switch claims
/// 54x24pt in layout and `scaleEffect` shrinks only the drawing, so a 0.55
/// switch paints 29.7pt wide and leaves (54 - 29.7) / 2 of its claimed box empty
/// on each side. Pulled back by that much, the drawn edge lands on the margin
/// instead of 12pt inside it. A fixed frame would set the same gap right but
/// clip the hit area, which is why it is padding.
///
/// No cursor modifier: the pointer stays the system arrow, the same as every
/// other switch on the system.
struct BrandSwitch: View {
    let title: String
    @Binding var isOn: Bool
    /// Pull the drawn edge onto the trailing margin. On for the sidebar rows,
    /// where the switch is the last thing in the row; off where something sits
    /// beside it, like the panel footer's Open at Login.
    var bleed = true

    static let sideBearing: CGFloat = (54 - 54 * 0.55) / 2

    var body: some View {
        Toggle(title, isOn: $isOn)
            .toggleStyle(.switch)
            .scaleEffect(0.55)
            .tint(AppColors.brand)
            .labelsHidden()
            .padding(.trailing, bleed ? -Self.sideBearing : 0)
    }
}
