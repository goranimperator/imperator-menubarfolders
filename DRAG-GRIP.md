# Drag grip on a reorderable row

The grip that sits at the left of a row you can drag to reorder. Two columns of
three dots, Lucide `grip-vertical`. Same grip madrs-s uses in Settings under
Startsidan and Kontakter.

Drop this into any Imperator app with a reorderable list.

## The view

```swift
/// Lucide `grip-vertical`, two columns of three dots.
///
/// The sizes are half-points, not the 3.33pt and 1.67pt that Lucide's 24-unit
/// box gives at 20pt. A fraction like that falls between device pixels, and each
/// dot rounds by where it happens to land, so they come out visibly unequal.
/// Half-points are exact at 2x.
///
/// Drawn rather than added to the app's Lucide icon set, which would put it in
/// the icon picker as a selectable icon.
private struct DragGrip: View {
    /// At rest the grip sits at the weight of the secondary text beside it, so a
    /// row reads as one line rather than a control with a label after it.
    /// Hovering the row brings it up to the weight of the row's other buttons.
    var hovered: Bool

    private static let dot: CGFloat = 3.5
    private static let columnGap: CGFloat = 1.5
    private static let rowGap: CGFloat = 2.5

    var body: some View {
        VStack(spacing: Self.rowGap) {
            ForEach(0..<3, id: \.self) { _ in
                HStack(spacing: Self.columnGap) {
                    Circle().frame(width: Self.dot, height: Self.dot)
                    Circle().frame(width: Self.dot, height: Self.dot)
                }
            }
        }
        .foregroundStyle(hovered ? AnyShapeStyle(Color.gray) : AnyShapeStyle(.tertiary))
        .animation(.easeInOut(duration: 0.3), value: hovered)
    }
}
```

## Using it

First item in the row's `HStack`, before the icon:

```swift
DragGrip(hovered: hoveredItem == item.id)
    .help("Drag to reorder")
```

`hovered` comes from the row's own `.onHover`, the same flag that reveals the
row's rename and remove buttons. Hovering anywhere on the row lights the grip,
not just the grip itself.

```swift
.onHover { h in
    withAnimation(.easeInOut(duration: 0.1)) {
        hoveredItem = h ? item.id : nil
    }
}
```

The grip is the affordance only. The drag stays on the list's own `.onMove`, so
the whole row is still the drag target.

## Three things that will bite

**Do not use a stock symbol.** `line.3.horizontal` and the other hamburger
glyphs run the full width of a column next to a 40pt icon. The dot grip is
8.5pt wide.

**Do not compute the sizes from Lucide's viewBox.** `4 / 24 * 20` is 3.333pt.
At 2x that is 6.67 device pixels, so each dot rounds to 6 or 7 depending on its
position, and the six dots come out different sizes. The half-point values above
land on whole pixels: 7px dots, 3px between columns, 5px between rows.

**Do not add `grip-vertical` to the app's Lucide set** if that set feeds an icon
picker. It would show up as something the user can pick as an app or folder
icon.

## Colours

| State | Value |
|-------|-------|
| Rest | `.tertiary`, the same weight as the secondary text in the row |
| Row hovered | `Color.gray`, the same weight as the row's rename and remove buttons |

The colour crosses over `.easeInOut(duration: 0.3)`.

Put the animation on the grip, never on an enclosing `Button`. A
`.animation(_:value:)` on the button animates its whole label, image included,
and SwiftUI cross-fades the image on every hover: it reads as the icon blinking.
