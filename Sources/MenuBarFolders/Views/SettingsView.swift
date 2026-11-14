import SwiftUI
import ServiceManagement

struct LaunchAtLoginToggle: View {
    @State private var isEnabled = SMAppService.mainApp.status == .enabled
    @State private var isHovered = false

    /// Where the switch sits. In the sidebar the label stays left and the switch
    /// goes to the right edge, the same as every other row in that column; in the
    /// panel footer the two sit together on the left beside Settings, About and
    /// Quit, which is where the brand book puts them.
    enum Layout { case together, spread }
    var layout: Layout = .together

    var body: some View {
        HStack(spacing: 6) {
            Text("Open at Login")
                .font(.caption)
            if layout == .spread { Spacer(minLength: 4) }
            // The shared switch, so a style change is made once. It carries no fixed
            // frame and no cursor modifier: the macOS 27 switch claims 54x24pt in
            // layout and scaleEffect does not change the size it claims, so a frame
            // only clipped the hit area, and the pointer stays the system arrow.
            // Only the spread layout bleeds the drawn edge onto the margin; the
            // footer keeps the switch where it has always been.
            BrandSwitch(title: "Open at Login", isOn: $isEnabled, bleed: layout == .spread)
                .onChange(of: isEnabled) { _, newValue in
                    do {
                        if newValue { try SMAppService.mainApp.register() }
                        else { try SMAppService.mainApp.unregister() }
                    } catch {
                        isEnabled = SMAppService.mainApp.status == .enabled
                    }
                }
        }
        .opacity(isHovered ? 1.0 : 0.45)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
        .onHover { isHovered = $0 }
    }
}

struct SettingsView: View {
    var body: some View {
        LaunchAtLoginToggle(layout: .spread)
    }
}
