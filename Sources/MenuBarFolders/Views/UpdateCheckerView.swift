import SwiftUI

/// Check for updates, in the settings window sidebar between the drive scan and
/// Open at Login. Two lines: the switch, then what the last check found and the
/// Check Now button.
///
/// The row repeats the drive scan's shape: caption label, the shared switch, the
/// 20pt margin. The buttons are plain text rather than stock `Button`s because
/// main.swift forces the accent to the brand red, so a stock button's label would
/// come out red where every other control in this column is grey.
struct UpdateCheckerView: View {
    private static let contentMargin: CGFloat = 20

    @State private var checker = UpdateChecker.shared
    @AppStorage(UpdateChecker.enabledKey) private var checkForUpdates = true

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text("Check for updates")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 4)
                BrandSwitch(title: "Check for updates", isOn: $checkForUpdates)
            }
            // On the switch row only. On the whole block it also covered Check
            // Now, which works with the switch off, under a tooltip that talks
            // about a daily check that is not running.
            .help("Once a day the app asks GitHub for the latest release and compares it with this version. Nothing is sent but the app's name and version. Installing an update is up to you.")

            HStack(spacing: 8) {
                Text(statusText)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
                Spacer(minLength: 4)
                if let update = checker.available {
                    textButton("Download") { UpdateChecker.open(update.page) }
                }
                textButton("Check Now") { Task { await checker.check() } }
                    .disabled(checker.status == .checking)
            }
        }
        .padding(.horizontal, Self.contentMargin)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        // Both directions: switching on checks if one is due, switching off
        // stops the hourly tick and clears an update row left by a check the
        // user has just turned off.
        .onChange(of: checkForUpdates) { _, _ in
            checker.refreshSchedule()
        }
    }

    @ViewBuilder
    private func textButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
    }

    private var statusText: String {
        let current = UpdateChecker.currentVersion
        if checker.status == .checking { return "Checking…" }
        // An update the app already found wins over a failed re-check: it is
        // still true, and the failure says nothing about it.
        if let release = checker.available {
            return "Version \(release.version) is available, you have \(current)"
        }
        switch checker.status {
        case .idle, .checking: return "Version \(current)"
        case .upToDate: return "Up to date, version \(current)"
        case .failed: return "Could not reach GitHub"
        }
    }
}
