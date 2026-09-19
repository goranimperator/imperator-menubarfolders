import SwiftUI
import ServiceManagement

struct LaunchAtLoginToggle: View {
    @State private var isEnabled = SMAppService.mainApp.status == .enabled
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 6) {
            Text("Open at Login")
                .font(.caption)
            // The stock switch, styled only by the brand tint. No frame: the macOS 27
            // switch measures 54x24pt and scaleEffect does not change the size it claims
            // in layout, so a 36x20 frame only clipped the hit area while reading as a
            // size guarantee it never gave. No cursor modifier either, so the pointer
            // stays the system arrow the way every other switch on the system behaves.
            Toggle("Open at Login", isOn: $isEnabled)
                .toggleStyle(.switch)
                .scaleEffect(0.55)
                .tint(AppColors.brand)
                .labelsHidden()
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
        LaunchAtLoginToggle()
    }
}
