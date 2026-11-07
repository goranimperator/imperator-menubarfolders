import SwiftUI

struct FolderPopoverView: View {
    let folder: MenuBarFolder
    /// What a page holds here, which is the folder's setting unless the display
    /// is too short for it. Read instead of `folder.itemsPerPage`, so the pages
    /// the view draws always match the height the panel was given.
    let itemsPerPage: Int
    let gridHeight: CGFloat
    /// Fed by `MenuBarPanel.onScrollWheel`. A `.nonactivatingPanel` does not
    /// deliver scrolls to a local monitor the way the settings window does, so
    /// the panel overrides `scrollWheel(with:)` and hands the event here.
    let scrollEvents: PanelScrollRelay
    let onOpenApp: (AppEntry) -> Void
    let onOpenSettings: () -> Void
    let onShowAbout: () -> Void
    let onQuit: () -> Void

    @State private var hoveredApp: String?
    @State private var currentPage = 0
    @State private var pageDragOffset: CGFloat = 0
    /// Set once a press has travelled far enough to be a swipe rather than a
    /// click, so releasing it turns the page instead of launching an app.
    @State private var isSwiping = false

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 8), count: folder.columnsPerRow)
    }

    private static let widthPerColumn: CGFloat = 80
    private static let cellHeight: CGFloat = 68
    private static let gridSpacing: CGFloat = 12
    private static let gridPadding: CGFloat = 28
    static let headerHeight: CGFloat = 40
    // Tall enough for the login toggle plus the footer's vertical padding (10 + 10). The
    // macOS 27 switch claims 54x24pt in layout; scaleEffect shrinks the drawing, not the
    // space, so the toggle is 24pt tall here no matter what it looks like.
    static let footerHeight: CGFloat = 44
    /// No cap any more. A page holds exactly `itemsPerPage` slots and nothing
    /// scrolls inside it, so capping the height would hide rows with no way to
    /// reach them. `MenuBarPanel.show` clamps the finished panel to the screen,
    /// which is the only limit left.
    // The empty state draws an icon and two lines of text where the grid would be.
    // Returning 0 for it would size the popover to header + footer alone and clip it.
    private static let emptyStateHeight: CGFloat = 126
    /// The dots under the grid: the 7pt circle plus 9pt above and below it.
    private static let pageIndicatorHeight: CGFloat = 25

    /// Sized from one page, not from the whole folder: a folder of forty apps
    /// opens the same height as a folder of nine and swipes sideways for the
    /// rest. A folder with fewer apps than a page holds is still only as tall as
    /// it needs, so the setting never pads an almost empty folder.
    static func calculateGridHeight(appCount: Int, columns: Int, itemsPerPage: Int) -> CGFloat {
        guard appCount > 0 else { return emptyStateHeight }
        let onOnePage = min(appCount, itemsPerPage)
        let rowCount = Int(ceil(Double(onOnePage) / Double(columns)))
        var height = CGFloat(rowCount) * cellHeight + CGFloat(max(rowCount - 1, 0)) * gridSpacing + gridPadding
        if pageCount(appCount: appCount, itemsPerPage: itemsPerPage) > 1 {
            height += pageIndicatorHeight
        }
        return height
    }

    // The footer does not fit in whatever width the grid asks for: the login
    // toggle, Settings, About and Quit need more than a two-column grid (188pt)
    // or a three-column one (268pt) provides. It was floored at 300 and "Open at
    // Login" still came out as "Open a...", so the floor is the brandbook's own
    // 340, which is what every other Imperator menu bar panel is wide.
    private static let footerMinWidth: CGFloat = 340

    static func calculateWidth(columns: Int) -> CGFloat {
        max(CGFloat(columns) * widthPerColumn + gridPadding, footerMinWidth)
    }

    /// How many apps a page can hold in `availableHeight`, so a tall page shape
    /// on a short display is reduced rather than letting the panel grow past
    /// what the screen shows and crop its own header and footer.
    static func slotsThatFit(availableHeight: CGFloat, columns: Int) -> Int {
        GridMetrics.slotsThatFit(availableHeight: availableHeight, columns: columns,
                                 cellHeight: cellHeight, padding: gridPadding)
    }

    /// What is left for the grid once the header, the footer and the two
    /// dividers have taken theirs.
    static func availableGridHeight(totalAvailable: CGFloat) -> CGFloat {
        totalAvailable - headerHeight - footerHeight - 2
    }

    static func calculateTotalHeight(appCount: Int, columns: Int, itemsPerPage: Int) -> CGFloat {
        let grid = calculateGridHeight(appCount: appCount, columns: columns, itemsPerPage: itemsPerPage)
        return headerHeight + 1 + grid + 1 + footerHeight
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 8) {
                // The folder's own menu bar glyph at 16pt, left of the name, the way
                // imperator-widget-clock and the other popover apps draw their header.
                // Template rendering lets it take the popover's foreground colour instead
                // of the hardcoded white the preview renderer bakes in.
                if let img = folderStatusIcon(folder, size: 16) {
                    Image(nsImage: img)
                        .renderingMode(.template)
                        .foregroundStyle(.primary)
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
                    Text("No apps yet")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Text("Open Settings to add apps")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                pagedGrid
                    .frame(height: gridHeight)
            }

            Divider()

            HStack(spacing: 12) {
                LaunchAtLoginToggle()

                Spacer()

                HoverButton(action: onOpenSettings) {
                    HStack(spacing: 4) {
                        Image(systemName: "gear")
                        Text("Settings")
                    }
                    .font(.caption)
                }

                // Brand book §10.1: About sits next to Quit in the footer. It closes the
                // popover first, because .applicationDefined would otherwise leave it
                // hanging open behind the panel.
                HoverButton(action: onShowAbout) {
                    Text("About")
                        .font(.caption)
                }
                .help("About Imperator MenuBarFolders")

                HoverButton(action: onQuit) {
                    Text("Quit")
                        .font(.caption)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .frame(width: FolderPopoverView.calculateWidth(columns: folder.columnsPerRow))
        // Brandbook 6.1: the tint over the panel's material, the same one every
        // other Imperator menu bar panel paints. MenuBarPanel lays down the
        // system's `.popover` material and rounds itself at 17.5pt, so nothing
        // here clips or fills a second time.
        .background(AppColors.popoverBackground)
    }

    private var totalPages: Int {
        pageCount(appCount: folder.apps.count, itemsPerPage: itemsPerPage)
    }

    private func apps(onPage page: Int) -> [AppEntry] {
        let start = page * itemsPerPage
        guard start < folder.apps.count else { return [] }
        let end = min(start + itemsPerPage, folder.apps.count)
        return Array(folder.apps[start..<end])
    }

    /// Every page laid out side by side and slid into view, so a page change is
    /// one offset rather than a swap.
    ///
    /// No ScrollView inside a page. A page is exactly `itemsPerPage` slots and
    /// the panel is sized to hold them, so there is nothing to scroll to, and a
    /// scroll view here would swallow the vertical half of every gesture.
    @ViewBuilder
    private var pagedGrid: some View {
        let width = Self.calculateWidth(columns: folder.columnsPerRow)
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                // Behind the pages, so a drag that starts on the gaps between
                // icons swipes too. It is the only other place the swipe lives:
                // a second gesture on an ancestor of the cells ran on the same
                // press as the cell's own and raced it for `isSwiping`, and
                // whichever ended first decided, so a swipe begun on an icon
                // could still launch that app.
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(swipeGesture(width: width))

                // Top aligned, and each page stretched to the full height. A
                // page is only as tall as its own icons, so a last page holding
                // one app was centred in a panel sized for a full one and the
                // icon floated in the middle. The slots start at the top left
                // on every page.
                HStack(alignment: .top, spacing: 0) {
                    ForEach(0..<totalPages, id: \.self) { page in
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(apps(onPage: page)) { app in
                                appCell(app)
                            }
                        }
                        .padding(14)
                        .frame(width: width)
                        .frame(maxHeight: .infinity, alignment: .topLeading)
                    }
                }
                // .leading, not the default .center: this stack is every page
                // side by side, so centring it in one page's width parks the
                // panel half a page off and the offset then slides from the
                // wrong place.
                .frame(width: width, alignment: .leading)
                .frame(maxHeight: .infinity, alignment: .topLeading)
                .offset(x: -CGFloat(currentPage) * width + pageDragOffset)
            }
            .frame(width: width)
            .frame(maxHeight: .infinity, alignment: .topLeading)
            .clipped()

            if totalPages > 1 {
                HStack(spacing: 6) {
                    ForEach(0..<totalPages, id: \.self) { index in
                        Circle()
                            .fill(index == currentPage ? Color.primary : Color.secondary.opacity(0.4))
                            .frame(width: 7, height: 7)
                            .onTapGesture {
                                withAnimation(Self.pageTurn) { currentPage = index }
                            }
                    }
                }
                .padding(.vertical, 9)
            }
        }
        .onAppear {
            // The panel is rebuilt on every open, so `folder` here is always the
            // one the panel was sized from; `currentPage` is @State, so the
            // closure reads and writes the live value rather than a snapshot.
            scrollEvents.onPageStep = { step in
                let target = currentPage + step
                guard (0..<totalPages).contains(target) else { return }
                withAnimation(Self.pageTurn) { currentPage = target }
            }
        }
        .onDisappear { scrollEvents.onPageStep = nil }
    }

    /// Click and drag sideways, the way the pages move under a finger on a
    /// phone. `minimumDistance: 0` so the cells can tell a click from a swipe
    /// with the same gesture: a press that never travels is a launch.
    private func swipeGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if !isSwiping && abs(value.translation.width) > Self.swipeSlop {
                    isSwiping = true
                }
                guard isSwiping else { return }
                pageDragOffset = rubberBanded(value.translation.width, width: width)
            }
            .onEnded { value in
                guard isSwiping else { return }
                isSwiping = false
                finishPageSwipe(value, width: width)
            }
    }

    /// How far a press travels before it stops being a click.
    private static let swipeSlop: CGFloat = 6

    private func finishPageSwipe(_ value: DragGesture.Value, width: CGFloat) {
        let threshold = width * 0.2
        // A quick flick turns the page even if it did not travel far.
        let travel = abs(value.predictedEndTranslation.width) > abs(value.translation.width)
            ? value.predictedEndTranslation.width
            : value.translation.width
        withAnimation(Self.pageTurn) {
            if travel < -threshold && currentPage < totalPages - 1 {
                currentPage += 1
            } else if travel > threshold && currentPage > 0 {
                currentPage -= 1
            }
            pageDragOffset = 0
        }
    }

    /// Past the first or last page the grid follows the pointer at a third of
    /// the distance, so it gives without pretending there is more.
    private func rubberBanded(_ translation: CGFloat, width: CGFloat) -> CGFloat {
        let pastStart = currentPage == 0 && translation > 0
        let pastEnd = currentPage >= totalPages - 1 && translation < 0
        return pastStart || pastEnd ? translation / 3 : translation
    }

    private static let pageTurn = Animation.interactiveSpring(response: 0.35, dampingFraction: 0.86)

    /// Not a `Button`: a button fires on mouse-up wherever the pointer has
    /// been, so a swipe that started on an icon launched that app when it was
    /// released. The press decides for itself which it was.
    @ViewBuilder
    private func appCell(_ app: AppEntry) -> some View {
        let isHovered = hoveredApp == app.bundleIdentifier
        let width = Self.calculateWidth(columns: folder.columnsPerRow)
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
        .onHover { h in hoveredApp = h ? app.bundleIdentifier : nil }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if !isSwiping && abs(value.translation.width) > Self.swipeSlop {
                        isSwiping = true
                    }
                    guard isSwiping else { return }
                    pageDragOffset = rubberBanded(value.translation.width, width: width)
                }
                .onEnded { value in
                    if isSwiping {
                        isSwiping = false
                        finishPageSwipe(value, width: width)
                        return
                    }
                    // Only a press that stayed put launches. A bare gesture has
                    // none of a Button's "release inside me" rule, so pressing
                    // an icon and dragging away in any direction used to launch
                    // it on release wherever the pointer had got to.
                    let moved = hypot(value.translation.width, value.translation.height)
                    if moved <= Self.swipeSlop { onOpenApp(app) }
                }
        )
        // The gesture replaced the button, so the traits and the action it used
        // to carry are declared here instead.
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(app.displayName)
        .accessibilityAction { onOpenApp(app) }
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
