import AppKit
import SwiftUI

/// Delivers trackpad scrolls over the grid, wherever the pointer is on it.
///
/// Overriding `scrollWheel(with:)` from behind the grid only ever sees a scroll
/// in the gaps between icons: over an icon SwiftUI's own view takes the event,
/// and an unused scroll travels up the superview chain rather than sideways to
/// this one, so a two-finger swipe started over an app did nothing. A local
/// monitor sees every scroll in the window first, and this view only decides
/// whether the pointer is over its own bounds. It returns nil from hit testing,
/// so it never takes a click.
///
/// This is the settings window's route. The menu bar panel is a
/// `.nonactivatingPanel`, which a monitor does not reach, so it overrides
/// `scrollWheel(with:)` on the window instead. See `MenuBarPanel`.
final class ScrollWheelNSView: NSView {
    var onScrollEvent: ((NSEvent) -> Void)?
    private var monitor: Any?

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
        guard window != nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self, let window = self.window, event.window === window else { return event }
            if self.bounds.contains(self.convert(event.locationInWindow, from: nil)) {
                self.onScrollEvent?(event)
            }
            return event
        }
    }
}

struct ScrollWheelOverlay: NSViewRepresentable {
    let onScrollEvent: (NSEvent) -> Void

    func makeNSView(context: Context) -> ScrollWheelNSView {
        let view = ScrollWheelNSView()
        view.onScrollEvent = onScrollEvent
        return view
    }

    func updateNSView(_ nsView: ScrollWheelNSView, context: Context) {
        nsView.onScrollEvent = onScrollEvent
    }
}

/// The folder's apps as a paged grid, arranged the way an iPhone home screen is.
///
/// Hold an app (or press Arrange) and the grid starts arranging: every icon
/// wiggles and shows its remove badge. Drag an icon and it lifts out from under
/// the pointer while the others slide out of its way as it moves, so the drop
/// only confirms what is already on screen. Holding it at a side edge turns the
/// page. Done, Escape or a click on empty space stops arranging.
///
/// The drag is a plain gesture over a hand-placed layout rather than
/// onDrag/onDrop. A system drag session floats a translucent snapshot over the
/// window and moves nothing until the drop, which is what made the grid feel
/// broken: the icon you grabbed faded in place and its neighbours never moved.
///
/// Ported from imperator-dock-folder 1.0.8's `AppGridCarousel`.
struct AppGridCarousel: View {
    let apps: [AppEntry]
    let columns: Int
    let itemsPerPage: Int
    @Binding var isArranging: Bool
    let onRemove: (AppEntry) -> Void
    let onReorder: ([AppEntry]) -> Void
    let onSetLabel: (AppEntry, String?) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var currentPage = 0
    @State private var pageDragOffset: CGFloat = 0
    @State private var editingAppId: String?
    @State private var editingText = ""
    @FocusState private var isLabelFieldFocused: Bool
    @State private var swipe = PageSwipeAccumulator()

    /// Display order as app ids. Follows `apps`, except while an icon is lifted,
    /// when it is the live order the other icons slide into.
    @State private var order: [String] = []
    @State private var press: Press?
    @State private var lifted: Lifted?
    @State private var longPressTask: Task<Void, Never>?
    @State private var edgeTask: Task<Void, Never>?
    @State private var edgeDirection = 0
    @State private var keyMonitor: Any?

    private static let space = "appGrid"
    /// Icons settling into slots: quick, with a little give at the end.
    private static let settle = Animation.spring(response: 0.32, dampingFraction: 0.78)
    private static let pageTurn = Animation.interactiveSpring(response: 0.35, dampingFraction: 0.86)
    /// Long enough that a click or a swipe never lifts an icon by accident.
    private static let holdToLift: Duration = .milliseconds(380)
    /// How long an icon has to rest at a side edge before the page turns.
    private static let edgeDwell: Duration = .milliseconds(550)
    private static let edgeWidth: CGFloat = 36

    /// One pointer interaction on an icon, from mouse-down to mouse-up.
    private struct Press {
        enum Phase {
            /// Not arranging, not moved yet: becomes a lift if held, a page swipe if dragged.
            case waiting
            case swiping
            /// Arranging, not moved yet: becomes a lift on the first move.
            case armed
            case lifted
        }
        let id: String
        var phase: Phase
        var location: CGPoint
    }

    private struct Lifted {
        let id: String
        var location: CGPoint
        /// Pointer minus icon centre at the moment of lifting, so the icon stays
        /// where it was grabbed instead of jumping to centre on the pointer.
        let grab: CGSize
        let startOrder: [String]
    }

    private var orderedApps: [AppEntry] {
        let byId = Dictionary(apps.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var seen = Set<String>()
        var result: [AppEntry] = []
        for id in order {
            if let app = byId[id], seen.insert(id).inserted { result.append(app) }
        }
        for app in apps where seen.insert(app.id).inserted { result.append(app) }
        return result
    }

    private var totalPages: Int {
        pageCount(appCount: max(order.count, apps.count), itemsPerPage: itemsPerPage)
    }

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geo in
                let metrics = GridMetrics(size: geo.size, columns: columns, itemsPerPage: itemsPerPage)
                ZStack(alignment: .topLeading) {
                    // The empty grid behaves like the wallpaper on an iPhone:
                    // swiping it turns the page, clicking it stops arranging.
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if isArranging { endArranging() }
                        }
                        .gesture(
                            DragGesture(minimumDistance: 6)
                                .onChanged { value in
                                    pageDragOffset = rubberBanded(value.translation.width, width: geo.size.width)
                                }
                                .onEnded { value in
                                    finishPageSwipe(value, width: geo.size.width)
                                }
                        )

                    ForEach(orderedApps) { app in
                        appCell(app, metrics: metrics)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .coordinateSpace(name: Self.space)
                .clipped()
                .background(
                    ScrollWheelOverlay { event in
                        var accumulator = swipe
                        let direction = accumulator.direction(for: event)
                        swipe = accumulator
                        guard direction != 0 else { return }
                        turnPage(by: direction)
                    }
                )
            }

            if totalPages > 1 {
                pageIndicator
                    .padding(.vertical, 12)
            }
        }
        .onAppear { order = apps.map(\.id) }
        .onChange(of: apps.map(\.id)) { _, ids in
            // Adding, removing or committing a reorder lands here. While an icon
            // is lifted the live order is the source of truth.
            guard lifted == nil, ids != order else { return }
            withAnimation(Self.settle) { order = ids }
            currentPage = min(currentPage, totalPages - 1)
        }
        .onChange(of: itemsPerPage) { _, _ in
            currentPage = min(currentPage, totalPages - 1)
        }
        .onChange(of: isArranging) { _, arranging in
            if arranging {
                installKeyMonitor()
            } else {
                // A label field open when arranging ends would otherwise stay
                // rendered on the icon, and `including: .subviews` would keep
                // that one cell un-liftable until focus happened to move. Commit
                // first, so pressing Done keeps what was typed.
                if let id = editingAppId, let app = apps.first(where: { $0.id == id }) {
                    commitLabel(for: app)
                }
                editingAppId = nil
                stopInteraction()
                removeKeyMonitor()
            }
        }
        .onDisappear {
            stopInteraction()
            removeKeyMonitor()
        }
        .onChange(of: isLabelFieldFocused) { _, focused in
            if !focused, let appId = editingAppId {
                if let app = apps.first(where: { $0.id == appId }) { commitLabel(for: app) }
                editingAppId = nil
            }
        }
    }

    // MARK: - Cells

    private func appCell(_ app: AppEntry, metrics: GridMetrics) -> some View {
        let isLifted = lifted?.id == app.id
        return cellContent(app, metrics: metrics, isLifted: isLifted)
            .modifier(Wiggle(active: isArranging && !isLifted && !reduceMotion, seed: app.id))
            .frame(width: metrics.cellWidth, height: metrics.cellHeight)
            .contentShape(Rectangle())
            .scaleEffect(isLifted ? 1.15 : 1)
            .shadow(color: .black.opacity(isLifted ? 0.45 : 0), radius: isLifted ? 14 : 0, y: isLifted ? 8 : 0)
            .position(position(of: app, metrics: metrics))
            .zIndex(isLifted ? 1 : 0)
            // Animates the lift and, on release, the glide from the pointer into
            // the slot. While the icon is held it tracks the pointer unanimated.
            .animation(Self.settle, value: isLifted)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.space))
                    .onChanged { value in pointerChanged(on: app, value, metrics: metrics) }
                    .onEnded { value in pointerEnded(on: app, value, metrics: metrics) },
                including: editingAppId == app.id ? .subviews : .all
            )
            .accessibilityAction(named: "Move Left") { move(app, by: -1) }
            .accessibilityAction(named: "Move Right") { move(app, by: 1) }
            .transition(.scale(scale: 0.4).combined(with: .opacity))
    }

    private func cellContent(_ app: AppEntry, metrics: GridMetrics, isLifted: Bool) -> some View {
        let iconSize = min(metrics.cellWidth * 0.55, metrics.cellHeight * 0.55)

        return VStack(spacing: 4) {
            Image(nsImage: app.icon)
                .resizable()
                .interpolation(.high)
                .frame(width: iconSize, height: iconSize)
                .overlay(alignment: .topTrailing) {
                    if isArranging && !isLifted {
                        DeleteBadge { remove(app) }
                            .offset(x: 4, y: -4)
                            .transition(.scale(scale: 0.2).combined(with: .opacity))
                    }
                }

            Group {
                if editingAppId == app.id {
                    TextField("Label", text: $editingText, onCommit: {
                        commitLabel(for: app)
                        editingAppId = nil
                    })
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)
                    .frame(maxWidth: metrics.cellWidth - 4)
                    .focused($isLabelFieldFocused)
                } else {
                    HStack(spacing: 10) {
                        Text(app.displayName)
                            .font(.caption)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .contentShape(Rectangle())
                            .onTapGesture(count: 2) {
                                editingText = app.displayName
                                editingAppId = app.id
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                    isLabelFieldFocused = true
                                }
                            }

                        if app.customName != nil {
                            RevertLabelButton { onSetLabel(app, nil) }
                        }
                    }
                    .frame(maxWidth: metrics.cellWidth - 4)
                }

                if !app.exists {
                    Text("Missing")
                        .font(.caption2)
                        .foregroundStyle(AppColors.brand)
                }
            }
            // The label stays behind while the icon is carried, as on an iPhone.
            .opacity(isLifted ? 0 : 1)
        }
    }

    private func commitLabel(for app: AppEntry) {
        let trimmed = editingText.trimmingCharacters(in: .whitespacesAndNewlines)
        onSetLabel(app, trimmed.isEmpty || trimmed == app.name ? nil : trimmed)
    }

    private func position(of app: AppEntry, metrics: GridMetrics) -> CGPoint {
        if let lifted, lifted.id == app.id {
            return CGPoint(x: lifted.location.x - lifted.grab.width, y: lifted.location.y - lifted.grab.height)
        }
        let index = order.firstIndex(of: app.id) ?? order.count
        let page = index / itemsPerPage
        var point = metrics.center(ofSlot: index % itemsPerPage)
        point.x += CGFloat(page - currentPage) * metrics.size.width + pageDragOffset
        return point
    }

    // MARK: - Pointer

    private func pointerChanged(on app: AppEntry, _ value: DragGesture.Value, metrics: GridMetrics) {
        if press?.id != app.id {
            press = Press(id: app.id, phase: isArranging ? .armed : .waiting, location: value.location)
            if !isArranging { scheduleLift(of: app, metrics: metrics) }
        }
        guard var current = press else { return }
        current.location = value.location
        let moved = hypot(value.translation.width, value.translation.height)

        switch current.phase {
        case .waiting:
            if moved > 6 {
                cancelScheduledLift()
                current.phase = .swiping
                pageDragOffset = rubberBanded(value.translation.width, width: metrics.size.width)
            }
        case .swiping:
            pageDragOffset = rubberBanded(value.translation.width, width: metrics.size.width)
        case .armed:
            if moved > 3 {
                current.phase = .lifted
                lift(app, at: value.startLocation, metrics: metrics)
                moveLifted(to: value.location, metrics: metrics)
            }
        case .lifted:
            moveLifted(to: value.location, metrics: metrics)
        }
        press = current
    }

    private func pointerEnded(on app: AppEntry, _ value: DragGesture.Value, metrics: GridMetrics) {
        cancelScheduledLift()
        guard let current = press, current.id == app.id else {
            press = nil
            return
        }
        press = nil
        switch current.phase {
        case .swiping:
            finishPageSwipe(value, width: metrics.size.width)
        case .lifted:
            drop()
        case .waiting, .armed:
            break
        }
    }

    /// Holding an app without moving starts arranging and picks that app up in
    /// the same motion, so the drag that follows moves it.
    private func scheduleLift(of app: AppEntry, metrics: GridMetrics) {
        cancelScheduledLift()
        longPressTask = Task { @MainActor in
            try? await Task.sleep(for: Self.holdToLift)
            guard !Task.isCancelled, var current = press, current.id == app.id, current.phase == .waiting else { return }
            withAnimation(.easeOut(duration: 0.2)) { isArranging = true }
            current.phase = .lifted
            press = current
            lift(app, at: current.location, metrics: metrics)
        }
    }

    private func cancelScheduledLift() {
        longPressTask?.cancel()
        longPressTask = nil
    }

    private func lift(_ app: AppEntry, at location: CGPoint, metrics: GridMetrics) {
        let center = position(of: app, metrics: metrics)
        lifted = Lifted(
            id: app.id,
            location: location,
            grab: CGSize(width: location.x - center.x, height: location.y - center.y),
            startOrder: order
        )
        haptic(.levelChange)
    }

    private func moveLifted(to location: CGPoint, metrics: GridMetrics) {
        guard var current = lifted else { return }
        current.location = location
        lifted = current

        let center = CGPoint(x: location.x - current.grab.width, y: location.y - current.grab.height)
        let target = min(currentPage * itemsPerPage + metrics.slot(nearest: center), order.count - 1)
        if let from = order.firstIndex(of: current.id), from != target {
            withAnimation(Self.settle) {
                order.remove(at: from)
                order.insert(current.id, at: target)
            }
            haptic(.alignment)
        }
        updateEdgeTurn(iconCenter: center, metrics: metrics)
    }

    /// An icon held at a side edge turns the page after a short rest, and keeps
    /// turning while it stays there.
    private func updateEdgeTurn(iconCenter: CGPoint, metrics: GridMetrics) {
        let direction: Int
        if iconCenter.x < Self.edgeWidth {
            direction = -1
        } else if iconCenter.x > metrics.size.width - Self.edgeWidth {
            direction = 1
        } else {
            direction = 0
        }

        guard direction != 0, (0..<totalPages).contains(currentPage + direction) else {
            edgeTask?.cancel()
            edgeTask = nil
            edgeDirection = 0
            return
        }
        if edgeTask != nil && edgeDirection == direction { return }

        edgeTask?.cancel()
        edgeDirection = direction
        edgeTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.edgeDwell)
                guard !Task.isCancelled, let current = lifted,
                      (0..<totalPages).contains(currentPage + direction) else { return }
                withAnimation(Self.pageTurn) { currentPage += direction }
                haptic(.generic)
                // Re-target on the new page; the pointer has not moved.
                moveLifted(to: current.location, metrics: metrics)
            }
        }
    }

    private func drop() {
        edgeTask?.cancel()
        edgeTask = nil
        edgeDirection = 0
        guard let current = lifted else { return }
        withAnimation(Self.settle) { lifted = nil }
        if order != current.startOrder {
            let byId = Dictionary(apps.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            onReorder(order.compactMap { byId[$0] })
        }
    }

    private func remove(_ app: AppEntry) {
        haptic(.generic)
        withAnimation(Self.settle) { onRemove(app) }
    }

    /// Keyboard and VoiceOver path, since the pointer is the only other way in.
    private func move(_ app: AppEntry, by step: Int) {
        guard let from = order.firstIndex(of: app.id) else { return }
        let to = min(max(from + step, 0), order.count - 1)
        guard to != from else { return }
        withAnimation(Self.settle) {
            order.remove(at: from)
            order.insert(app.id, at: to)
        }
        let byId = Dictionary(apps.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        onReorder(order.compactMap { byId[$0] })
    }

    /// Ends whatever the pointer is doing. A lifted icon is dropped where it is,
    /// so its move is kept rather than thrown away.
    private func stopInteraction() {
        cancelScheduledLift()
        if lifted != nil { drop() }
        press = nil
        edgeTask?.cancel()
        edgeTask = nil
        edgeDirection = 0
    }

    private func endArranging() {
        stopInteraction()
        withAnimation(.easeOut(duration: 0.2)) { isArranging = false }
    }

    // MARK: - Paging

    private func turnPage(by direction: Int) {
        let target = currentPage + direction
        guard (0..<totalPages).contains(target) else { return }
        withAnimation(Self.pageTurn) { currentPage = target }
    }

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

    /// Past the first or last page the grid follows the pointer at a third of the
    /// distance, so it gives without pretending there is more.
    private func rubberBanded(_ translation: CGFloat, width: CGFloat) -> CGFloat {
        let pastStart = currentPage == 0 && translation > 0
        let pastEnd = currentPage >= totalPages - 1 && translation < 0
        return pastStart || pastEnd ? translation / 3 : translation
    }

    private func haptic(_ pattern: NSHapticFeedbackManager.FeedbackPattern) {
        NSHapticFeedbackManager.defaultPerformer.perform(pattern, performanceTime: .now)
    }

    // MARK: - Monitors

    private func installKeyMonitor() {
        removeKeyMonitor()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Escape in a label field cancels the rename, not the arranging.
            guard event.keyCode == 53, editingAppId == nil else { return event }
            endArranging()
            return nil
        }
    }

    private func removeKeyMonitor() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
    }

    private var pageIndicator: some View {
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
    }
}

/// The arranging wiggle. Driven by a timeline rather than a repeating animation:
/// a `repeatForever` animation leaks into every other change made in the same
/// transaction, and would have set the icons' slide into slots wobbling too.
/// Paused, the timeline costs nothing, and keeping the same view structure in
/// both states lets the remove badges animate in.
private struct Wiggle: ViewModifier {
    let active: Bool
    let seed: String

    func body(content: Content) -> some View {
        TimelineView(.animation(minimumInterval: nil, paused: !active)) { context in
            content
                .rotationEffect(.degrees(active ? angle(at: context.date) : 0))
                .animation(.easeOut(duration: 0.15), value: active)
        }
    }

    /// About two degrees each way, a little under four times a second, each icon
    /// out of step with its neighbours.
    private func angle(at date: Date) -> Double {
        let phase = Double(abs(seed.hashValue) % 628) / 100
        return sin(date.timeIntervalSinceReferenceDate * 2 * .pi / 0.28 + phase) * 1.8
    }
}

struct DeleteBadge: View {
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            // White glyph on a brand-red disc: hierarchical foregroundStyle takes
            // the mark first, the fill second.
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 21, weight: .bold))
                .foregroundStyle(.white, AppColors.brand)
                .scaleEffect(isHovered ? 1.2 : 1.0)
                .animation(.easeOut(duration: 0.15), value: isHovered)
        }
        .buttonStyle(.borderless)
        .onHover { isHovered = $0 }
        .help("Remove from this folder")
    }
}

struct RevertLabelButton: View {
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.counterclockwise")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .opacity(isHovered ? 0.4 : 1.0)
                .animation(.easeOut(duration: 0.15), value: isHovered)
        }
        .buttonStyle(.borderless)
        .onHover { isHovered = $0 }
        .help("Use the app's own name")
    }
}
