import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @State private var launchAtLogin = false

    private let accentColor = Color(red: 0xa0/255, green: 0x18/255, blue: 0x18/255)

    var body: some View {
        HStack {
            Text("Open at login")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Spacer()
            Toggle("", isOn: $launchAtLogin)
                .toggleStyle(.switch)
                .scaleEffect(0.55)
                .frame(width: 36, height: 20)
                .tint(accentColor)
                .onChange(of: launchAtLogin) { _, newValue in
                    do {
                        if newValue {
                            try SMAppService.mainApp.register()
                        } else {
                            try SMAppService.mainApp.unregister()
                        }
                    } catch {
                        launchAtLogin = !newValue
                    }
                }
        }
        .onAppear {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}
