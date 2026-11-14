import SwiftUI

/// The sidebar's settings, folded under one header: Scan drives for apps, Check
/// for updates and Open at Login.
///
/// An accordion rather than three rows always on show. They are set once and left
/// alone, and together they took more of the sidebar than the folder list they sit
/// under. The header copies the Add Folder row above it: same 13pt label, same
/// 20pt margin, same hover from 0.7 to 1.0.
///
/// Always starts closed, every launch. The open state used to be remembered, so
/// folding it open once to look at something put it back open on every launch
/// after; it is `@State`, so it lives only as long as the window does.
///
/// A closed accordion would hide the one thing that has to be seen, so the header
/// carries a brand dot while an update is available.
struct SidebarSettingsView: View {
    private static let contentMargin: CGFloat = 20
    // The spacing is imperator-dock-folder's, number for number, so the two apps'
    // sidebars read the same. The container owns it, not the rows: a row that pads
    // itself cannot be told apart from the gap between rows.
    /// Between one option and the next.
    static let rowGap: CGFloat = 12
    /// Above the header, and below it while the section is shut.
    private static let headerGap: CGFloat = 10
    /// Below the header while the section is open: a little more than above it,
    /// so the options read as their own group.
    private static let headerGapOpen: CGFloat = 16
    /// Under the last option.
    private static let contentBottom: CGFloat = 12

    @State private var isExpanded: Bool
    @State private var headerHovered = false
    @State private var checker = UpdateChecker.shared

    /// `startsExpanded` exists so a render can show the open state without a
    /// click. The app never passes it.
    init(startsExpanded: Bool = false) {
        _isExpanded = State(initialValue: startsExpanded)
    }

    var body: some View {
        VStack(spacing: 0) {
            Button(action: toggle) {
                HStack(spacing: SidebarActionLabel.gap) {
                    // The same label Add Folder uses, so the two titles share a
                    // left edge.
                    SidebarActionLabel(systemImage: "gear", title: "Settings")
                    if let update = checker.available {
                        Circle()
                            .fill(AppColors.brand)
                            .frame(width: 7, height: 7)
                            .help("Version \(update.version) is available")
                    }
                    Spacer(minLength: 4)
                    // Turns a quarter, so the same glyph says closed and open. Instantly.
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .opacity(headerHovered ? 1.0 : 0.7)
                .padding(.horizontal, Self.contentMargin)
                .padding(.top, Self.headerGap)
                .padding(.bottom, isExpanded ? Self.headerGapOpen : Self.headerGap)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { h in
                withAnimation(.easeInOut(duration: 0.1)) { headerHovered = h }
            }
            .accessibilityValue(isExpanded ? "expanded" : "collapsed")

            if isExpanded {
                // No dividers in here. With one above and below each row, every
                // setting sat in its own bordered band; as one group under the
                // header they read as what they are, a list of settings.
                VStack(alignment: .leading, spacing: Self.rowGap) {
                    ExternalDrivesView()
                    UpdateCheckerView()
                    // Last in the sidebar, as the footer of it.
                    SettingsView()
                }
                .padding(.horizontal, Self.contentMargin)
                .padding(.bottom, Self.contentBottom)
            }
        }
    }

    /// No animation: it snaps open and shut. `disablesAnimations` rather than a bare
    /// toggle, so nothing inherited from a parent transaction can animate it either,
    /// and the chevron turns with the content instead of after it.
    private func toggle() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) { isExpanded.toggle() }
    }
}
