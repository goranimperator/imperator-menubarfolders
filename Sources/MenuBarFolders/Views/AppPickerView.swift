import SwiftUI

struct AppPickerView: View {
    let folder: MenuBarFolder
    @EnvironmentObject var store: FolderStore
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var allApps: [DiscoveredApp] = []
    @State private var selectedIDs: Set<String> = []

    private var filteredApps: [DiscoveredApp] {
        if searchText.isEmpty { return allApps }
        return allApps.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var existingBundleIDs: Set<String> {
        Set(folder.apps.map { $0.bundleIdentifier })
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Text("Add Apps")
                    .font(.headline)
                Spacer()
                Button("Done") { addSelectedAndClose() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(selectedIDs.isEmpty)
            }
            .padding()

            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search apps", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(8)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            .padding(.horizontal)
            .padding(.bottom, 8)

            Divider()

            List(filteredApps) { app in
                appRow(app)
            }
            .listStyle(.inset)
        }
        .frame(width: 400, height: 500)
        .onAppear {
            Task.detached {
                let apps = AppDiscovery.installedApps()
                await MainActor.run { allApps = apps }
            }
        }
    }

    @ViewBuilder
    private func appRow(_ app: DiscoveredApp) -> some View {
        let alreadyAdded = existingBundleIDs.contains(app.bundleIdentifier)
        let isSelected = selectedIDs.contains(app.bundleIdentifier)

        HStack(spacing: 10) {
            Image(nsImage: app.icon)
                .resizable()
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(app.name)
                    .font(.system(size: 13))
                if app.isMenuBarApp {
                    Text("Menu bar app")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Color.secondary.opacity(0.15)))
                }
            }

            Spacer()

            if alreadyAdded {
                Text("Added")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            } else if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color(red: 0xa0/255, green: 0x18/255, blue: 0x18/255))
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onTapGesture {
            guard !alreadyAdded else { return }
            if isSelected {
                selectedIDs.remove(app.bundleIdentifier)
            } else {
                selectedIDs.insert(app.bundleIdentifier)
            }
        }
        .opacity(alreadyAdded ? 0.5 : 1.0)
    }

    private func addSelectedAndClose() {
        for app in allApps where selectedIDs.contains(app.bundleIdentifier) {
            store.addApp(to: folder, app: AppDiscovery.toAppEntry(app))
        }
        dismiss()
    }
}
