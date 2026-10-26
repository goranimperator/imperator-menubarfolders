import SwiftUI

/// The external-drive scan, at the top of the settings sidebar: a master switch, then one
/// row per mounted drive.
///
/// The per-drive switch reads as "scan this drive", so it is the inverse of the stored
/// exclusion in `VolumeScanSettings.excludedVolumeNames`. The list refreshes on mount and
/// unmount, because a drive's row is the only place its name appears and pulling the cable
/// is exactly when that row goes away.
struct ExternalDrivesView: View {
    /// Matches the margin the Add Folder row and the sidebar rows below it use.
    private static let contentMargin: CGFloat = 20

    @State private var scanEnabled = VolumeScanSettings.scanExternalDrives
    @State private var excluded = VolumeScanSettings.excludedVolumeNames
    @State private var volumes: [URL] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            row(title: "Scan drives for apps", isOn: scanBinding)
                .help("Look for apps on mounted external drives")

            if scanEnabled {
                ForEach(volumes, id: \.self) { volume in
                    let name = AppDiscovery.volumeName(of: volume)
                    row(title: name, isOn: driveBinding(name))
                        .padding(.leading, 12)
                        .help("Scan \(name) for apps")
                }
            }
        }
        .padding(.horizontal, Self.contentMargin)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear(perform: reloadVolumes)
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didMountNotification)) { _ in
            reloadVolumes()
        }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didUnmountNotification)) { _ in
            reloadVolumes()
        }
    }

    @ViewBuilder
    private func row(title: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 6) {
            // Full opacity, unlike LaunchAtLoginToggle in the footer: this sits above
            // the folder list, where a row dimmed at rest reads as disabled. The
            // secondary foreground is what keeps it quieter than the folders below.
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 4)

            // The stock switch, styled only by the brand tint, the same shape
            // LaunchAtLoginToggle uses: no frame, because the macOS 27 switch claims
            // 54x24pt in layout and scaleEffect shrinks only the drawing, and no cursor
            // modifier, so the pointer stays the system arrow.
            Toggle(title, isOn: isOn)
                .toggleStyle(.switch)
                .scaleEffect(0.55)
                .tint(AppColors.brand)
                .labelsHidden()
        }
    }

    private var scanBinding: Binding<Bool> {
        Binding(
            get: { scanEnabled },
            set: { newValue in
                scanEnabled = newValue
                VolumeScanSettings.scanExternalDrives = newValue
            }
        )
    }

    private func driveBinding(_ name: String) -> Binding<Bool> {
        Binding(
            get: { !excluded.contains(name) },
            set: { shouldScan in
                if shouldScan { excluded.remove(name) } else { excluded.insert(name) }
                VolumeScanSettings.excludedVolumeNames = excluded
            }
        )
    }

    private func reloadVolumes() {
        volumes = AppDiscovery.externalVolumes()
    }
}
