import SwiftUI

struct FolderDetailView: View {
    @Binding var folder: MenuBarFolder
    @EnvironmentObject var store: FolderStore
    @State private var editingName: String = ""
    @State private var isEditingName = false
    @State private var showAppPicker = false
    @State private var showIconPicker = false
    @State private var hoveredApp: String?
    @FocusState private var nameFieldFocused: Bool

    private let accentColor = Color(red: 0xa0/255, green: 0x18/255, blue: 0x18/255)

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            appList
        }
        .sheet(isPresented: $showAppPicker) {
            AppPickerView(folder: folder)
        }
        .sheet(isPresented: $showIconPicker) {
            IconPickerView(
                selectedIconName: Binding(
                    get: { folder.iconName },
                    set: { newIcon in store.updateIcon(for: folder, iconName: newIcon) }
                ),
                onPasteSVG: { svg in
                    store.updateIcon(for: folder, iconName: "custom", customSVG: svg)
                }
            )
        }
    }

    @ViewBuilder
    private var header: some View {
        HStack(spacing: 12) {
            Button(action: { showIconPicker = true }) {
                if let img = folderPreviewIcon(folder, size: 28) {
                    Image(nsImage: img)
                        .frame(width: 44, height: 44)
                        .background(Color.primary.opacity(0.05))
                        .cornerRadius(10)
                }
            }
            .buttonStyle(.borderless)
            .help("Change icon")

            if isEditingName {
                TextField("Name", text: $editingName, onCommit: {
                    if !editingName.isEmpty {
                        store.renameFolder(folder, to: editingName)
                    }
                    isEditingName = false
                })
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 18, weight: .semibold))
                .focused($nameFieldFocused)
                .onAppear {
                    editingName = folder.name
                    nameFieldFocused = true
                }
            } else {
                Text(folder.name)
                    .font(.system(size: 18, weight: .semibold))
                    .onTapGesture {
                        editingName = folder.name
                        isEditingName = true
                    }
            }

            Spacer()

            Button(action: { showAppPicker = true }) {
                Label("Add Apps", systemImage: "plus")
                    .font(.system(size: 13))
            }
            .buttonStyle(.borderedProminent)
            .tint(accentColor)
        }
        .padding(20)
    }

    @ViewBuilder
    private var appList: some View {
        if folder.apps.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "app.dashed")
                    .font(.system(size: 36))
                    .foregroundStyle(.tertiary)
                Text("No apps in this folder")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                Button("Add Apps") { showAppPicker = true }
                    .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                ForEach(folder.apps) { app in
                    appRow(app)
                }
                .onMove { source, destination in
                    store.reorderApps(in: folder, from: source, to: destination)
                }
            }
            .listStyle(.inset)
        }
    }

    @ViewBuilder
    private func appRow(_ app: AppEntry) -> some View {
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

            if !app.exists {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.system(size: 12))
                    .help("App not found at \(app.path)")
            }

            if hoveredApp == app.bundleIdentifier {
                Button(action: {
                    store.removeApp(from: folder, app: app)
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.vertical, 4)
        .onHover { h in
            withAnimation(.easeInOut(duration: 0.1)) {
                hoveredApp = h ? app.bundleIdentifier : nil
            }
        }
    }
}
