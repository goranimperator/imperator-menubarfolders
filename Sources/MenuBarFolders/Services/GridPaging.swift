import AppKit

// The paging arithmetic and the scroll plumbing the grid is built on, kept apart
// from the views so it can be compiled and exercised on its own.

/// Carries scroll events from a panel's `scrollWheel(with:)` override into the
/// SwiftUI content hosted inside it.
///
/// The settings window uses `ScrollWheelOverlay` and a local monitor instead.
/// The menu bar panel cannot: it is a `.nonactivatingPanel`, so the app is not
/// frontmost while it is open and the monitor never sees the event. The window
/// override does, because the panel is this app's own window.
@MainActor
final class PanelScrollRelay {
    /// Called with -1 for a page back and 1 for a page forward, once per
    /// gesture. The accumulator lives here rather than in the view so nothing
    /// mutates view state from a closure the view stored outside its own body.
    var onPageStep: ((Int) -> Void)?
    private var swipe = PageSwipeAccumulator()

    init() {}

    func handle(_ event: NSEvent) {
        let direction = swipe.direction(for: event)
        guard direction != 0 else { return }
        onPageStep?(direction)
    }
}

/// Turns a scroll into one page change per gesture, from a trackpad or a mouse.
///
/// The two differ enough to need separate rules. A trackpad reports a gesture:
/// `.began` starts it, a momentum tail follows it, and both axes carry precise
/// deltas, so a page turn is a horizontal swipe and vertical scrolling is left
/// alone. A plain mouse wheel reports none of that: no phase, no momentum, and
/// on most mice no horizontal axis at all. Held to the trackpad rules it could
/// never turn a page, because the horizontal delta is always zero and the
/// accumulator would never reset without a `.began` to reset it.
struct PageSwipeAccumulator {
    /// Far enough that a diagonal two-finger scroll never turns a page.
    private static let trackpadThreshold: CGFloat = 10
    /// One detent of a line-unit wheel reports a delta of 1, measured off a
    /// CGEvent-built wheel event, so this is two detents: enough that a single
    /// nudge does not turn the page, few enough that paging does not feel stiff.
    private static let wheelThreshold: CGFloat = 2
    /// A wheel gesture has no end, so a pause ends it instead. Below this,
    /// spinning the wheel keeps adding to the same gesture and turns one page.
    private static let wheelGap: TimeInterval = 0.25

    private var x: CGFloat = 0
    private var y: CGFloat = 0
    private var triggered = false
    private var lastWheelTime: TimeInterval = -1

    /// Returns -1 for a page back, 1 for a page forward, 0 for nothing yet.
    mutating func direction(for event: NSEvent) -> Int {
        // Trackpads and the Magic Mouse send precise deltas and phases; a wheel
        // sends neither.
        if event.hasPreciseScrollingDeltas || event.phase != [] || event.momentumPhase != [] {
            return trackpadDirection(for: event)
        }
        return wheelDirection(for: event)
    }

    private mutating func trackpadDirection(for event: NSEvent) -> Int {
        if event.phase == .began { reset() }
        if event.phase == .cancelled || event.phase == .ended {
            reset()
            return 0
        }
        // The momentum tail is one gesture's leftovers, not a new swipe.
        if event.momentumPhase != [] { return 0 }
        guard !triggered else { return 0 }
        x += event.scrollingDeltaX
        y += event.scrollingDeltaY
        guard abs(x) > abs(y), abs(x) > Self.trackpadThreshold else { return 0 }
        triggered = true
        return x > 0 ? -1 : 1
    }

    private mutating func wheelDirection(for event: NSEvent) -> Int {
        if lastWheelTime < 0 || event.timestamp - lastWheelTime > Self.wheelGap { reset() }
        lastWheelTime = event.timestamp
        guard !triggered else { return 0 }
        x += event.scrollingDeltaX
        y += event.scrollingDeltaY
        // Whichever axis the wheel actually moves. A plain wheel only has Y; a
        // tilt wheel has X as well, and then the larger one wins.
        let delta = abs(x) >= abs(y) ? x : y
        guard abs(delta) >= Self.wheelThreshold else { return 0 }
        triggered = true
        // Up or left goes back, the same direction a swipe of that sign goes.
        // NSEvent has already applied the natural-scrolling preference.
        return delta > 0 ? -1 : 1
    }

    mutating func reset() {
        x = 0
        y = 0
        triggered = false
    }
}

/// Where each slot of a page sits, and which slot a point falls in.
struct GridMetrics {
    static let spacing: CGFloat = 12
    static let horizontalPadding: CGFloat = 24
    /// Breathing room above and below the grid inside its page.
    static let verticalPadding: CGFloat = 24

    let size: CGSize
    let columns: Int
    let itemsPerPage: Int
    let rows: Int
    let cellWidth: CGFloat
    let cellHeight: CGFloat
    let top: CGFloat

    init(size: CGSize, columns: Int, itemsPerPage: Int) {
        self.size = size
        self.columns = max(1, columns)
        self.itemsPerPage = max(1, itemsPerPage)
        rows = max(1, Int(ceil(Double(itemsPerPage) / Double(max(1, columns)))))
        let availableWidth = size.width - Self.horizontalPadding * 2 - Self.spacing * CGFloat(self.columns - 1)
        let availableHeight = size.height - Self.verticalPadding - Self.spacing * CGFloat(rows - 1)
        cellWidth = max(1, availableWidth / CGFloat(self.columns))
        cellHeight = max(1, min(availableHeight / CGFloat(rows), cellWidth * 1.2))
        // Centred vertically, as the stacked grid this replaces was.
        let gridHeight = cellHeight * CGFloat(rows) + Self.spacing * CGFloat(rows - 1)
        top = (size.height - gridHeight) / 2
    }

    func center(ofSlot slot: Int) -> CGPoint {
        let col = slot % columns
        let row = slot / columns
        return CGPoint(
            x: Self.horizontalPadding + CGFloat(col) * (cellWidth + Self.spacing) + cellWidth / 2,
            y: top + CGFloat(row) * (cellHeight + Self.spacing) + cellHeight / 2
        )
    }

    func slot(nearest point: CGPoint) -> Int {
        let col = Int(((point.x - Self.horizontalPadding) / (cellWidth + Self.spacing)).rounded(.down))
        let row = Int(((point.y - top) / (cellHeight + Self.spacing)).rounded(.down))
        let raw = min(max(row, 0), rows - 1) * columns + min(max(col, 0), columns - 1)
        // A page's rows can hold more than the page does: 4 per row and 9 per
        // page is 3 rows, which is 12 slots for 9 apps. Dropping an icon in one
        // of those 3 phantom slots used to name an index on the next page, so
        // the icon jumped off the page it was dropped on.
        return min(raw, itemsPerPage - 1)
    }

    /// How many slots fit in `availableHeight` at this column count, so a panel
    /// never asks for a page taller than the screen can show.
    static func slotsThatFit(availableHeight: CGFloat, columns: Int,
                             cellHeight: CGFloat, padding: CGFloat) -> Int {
        let columns = max(1, columns)
        let usable = availableHeight - padding
        // One row at least: a panel with no room for even that is a display
        // problem, not a reason to draw an empty page.
        guard usable > 0, cellHeight > 0 else { return columns }
        let rows = max(1, Int((usable + spacing) / (cellHeight + spacing)))
        return rows * columns
    }
}

/// How many pages a given number of apps needs.
func pageCount(appCount: Int, itemsPerPage: Int) -> Int {
    max(1, Int(ceil(Double(max(appCount, 0)) / Double(max(1, itemsPerPage)))))
}
