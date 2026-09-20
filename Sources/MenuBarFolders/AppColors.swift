import SwiftUI

enum AppColors {
    static let brand = Color(red: 0xa0/255.0, green: 0x18/255.0, blue: 0x18/255.0)

    /// Brandbook 6.1: the popover's surface is the system material with this
    /// tint over it, which is what every Imperator menu bar app paints. It was
    /// `NSColor.controlBackgroundColor` here, an opaque system grey that hid
    /// the material and made this popover the odd one out next to the others.
    static let popoverBackground = Color.black.opacity(0.15)
}
