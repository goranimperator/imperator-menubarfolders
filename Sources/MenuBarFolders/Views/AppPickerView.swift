import SwiftUI
import UniformTypeIdentifiers

struct AppPickerView: View {
    let folder: MenuBarFolder
    @EnvironmentObject var store: FolderStore
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var allApps: [DiscoveredApp] = []
    @State private var selectedIDs: Set<String> = []
    @State private var isScanning = true

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

            content

            Divider()

            HStack {
                // The scan is a heuristic and never complete: it stops at the depth cap,
                // skips drives the user switched off, and never looks at network shares.
                // The file dialog reaches an app anywhere.
                Button(action: chooseAppFromDisk) {
                    Label("Choose App…", systemImage: "folder")
                }
                // main.swift forces the system accent to the brand red, so a stock
                // button's label and glyph would come out red. Same reason the detail
                // header puts its controls back on the neutral.
                .tint(.primary)

                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
        .frame(width: 400, height: 500)
        .task {
            let apps = await Task.detached(priority: .userInitiated) {
                AppDiscovery.installedApps()
            }.value
            allApps = apps
            isScanning = false
        }
    }

    @ViewBuilder
    private var content: some View {
        if isScanning {
            VStack(spacing: 12) {
                ProgressView()
                    .controlSize(.small)
                    .tint(AppColors.brand)
                Text("Looking for apps")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if filteredApps.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 36))
                    .foregroundStyle(.tertiary)
                Text(searchText.isEmpty ? "No apps found" : "No apps match \"\(searchText)\"")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Text("Use Choose App… to pick one from anywhere on disk.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List(filteredApps) { app in
                appRow(app)
            }
            .listStyle(.inset)
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
                    .foregroundStyle(AppColors.brand)
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

    /// Picked apps go into the list already selected rather than straight into the folder,
    /// so everything in this sheet is added by the one Done button.
    private func chooseAppFromDisk() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.applicationBundle]
        panel.prompt = "Choose"
        panel.message = "Choose an app to add to this folder"

        guard panel.runModal() == .OK else { return }

        for url in panel.urls {
            guard let app = AppDiscovery.discoveredApp(at: url) else { continue }
            if !allApps.contains(where: { $0.bundleIdentifier == app.bundleIdentifier }) {
                allApps.insert(app, at: 0)
            }
            guard !existingBundleIDs.contains(app.bundleIdentifier) else { continue }
            selectedIDs.insert(app.bundleIdentifier)
        }

        // A search term that does not match the chosen app would otherwise hide the row
        // the user just picked.
        searchText = ""
    }

    private func addSelectedAndClose() {
        for app in allApps where selectedIDs.contains(app.bundleIdentifier) {
            store.addApp(to: folder, app: AppDiscovery.toAppEntry(app))
        }
        dismiss()
    }
}
