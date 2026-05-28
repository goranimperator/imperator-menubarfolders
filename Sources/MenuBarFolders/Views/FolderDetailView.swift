import SwiftUI

struct FolderDetailView: View {
    @Binding var folder: MenuBarFolder
    @EnvironmentObject var store: FolderStore
    @State private var editingName: String = ""
    @State private var isEditingName = false
    @State private var showAppPicker = false
    @State private var showIconPicker = false
    @State private var hoveredApp: String?
    @State private var editingAppId: String?
    @State private var editingAppName: String = ""
    @FocusState private var nameFieldFocused: Bool
    @FocusState private var appNameFieldFocused: Bool

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

            HStack(spacing: 4) {
                Image(systemName: "square.grid.3x3")
                    .font(.system(size: 13))
                    .foregroundStyle(accentColor)
                Picker("", selection: Binding(
                    get: { folder.columnsPerRow },
                    set: { store.updateColumns(for: folder, columns: $0) }
                )) {
                    ForEach(2...6, id: \.self) { n in
                        Text("\(n)").tag(n)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 50)
            }
            .frame(height: 28)
            .help("Columns per row")

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
        HStack(alignment: .center, spacing: 10) {
            Image(nsImage: app.icon)
                .resizable()
                .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 2) {
                if editingAppId == app.bundleIdentifier {
                    TextField("Label", text: $editingAppName, onCommit: {
                        store.renameApp(in: folder, app: app, to: editingAppName)
                        editingAppId = nil
                    })
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13))
                    .focused($appNameFieldFocused)
                    .onAppear {
                        appNameFieldFocused = true
                    }
                } else {
                    HStack(spacing: 4) {
                        Text(app.displayName)
                            .font(.system(size: 13))
                        if app.customName != nil {
                            Text(app.name)
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .onTapGesture(count: 2) {
                        editingAppName = app.displayName
                        editingAppId = app.bundleIdentifier
                    }
                }
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
                    editingAppName = app.displayName
                    editingAppId = app.bundleIdentifier
                }) {
                    Image(systemName: "pencil")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .help("Rename")

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
