import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: FolderStore
    @State private var selectedFolder: MenuBarFolder?
    @State private var showNewFolderSheet = false
    @State private var addFolderHovered = false

    private let accentColor = Color(red: 0xa0/255, green: 0x18/255, blue: 0x18/255)

    var body: some View {
        HSplitView {
            sidebar
                .frame(minWidth: 200, idealWidth: 240, maxWidth: 300)

            detail
                .frame(minWidth: 400)
        }
        .frame(minWidth: 700, minHeight: 500)
        .tint(accentColor)
        .accentColor(accentColor)
        .sheet(isPresented: $showNewFolderSheet) {
            NewFolderSheet { name, iconName in
                store.createFolder(name: name, iconName: iconName)
                if let created = store.folders.last {
                    selectedFolder = created
                }
            }
        }
        .onChange(of: store.folders) { _, newFolders in
            if let sel = selectedFolder,
               !newFolders.contains(where: { $0.id == sel.id }) {
                selectedFolder = newFolders.first
            }
        }
    }

    @ViewBuilder
    private var sidebar: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Imperator Menu Bar Folders")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)

            Divider()

            FolderListView(selectedFolder: $selectedFolder)
                .frame(maxHeight: .infinity)

            Divider()

            HStack {
                Button(action: { showNewFolderSheet = true }) {
                    HStack(spacing: 5) {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Folder")
                    }
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .opacity(addFolderHovered ? 1.0 : 0.7)
                }
                .buttonStyle(.borderless)
                .onHover { h in
                    withAnimation(.easeInOut(duration: 0.1)) { addFolderHovered = h }
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)

            Divider()

            SettingsView()
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
        }
        .background(Color(NSColor.controlBackgroundColor))
    }

    @ViewBuilder
    private var detail: some View {
        if let folder = selectedFolder ?? store.folders.first {
            FolderDetailView(folder: binding(for: folder))
        } else {
            VStack(spacing: 12) {
                Image(systemName: "menubar.rectangle")
                    .font(.system(size: 48))
                    .foregroundStyle(.tertiary)
                Text("Skapa din första mapp")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Button("Add Folder") { showNewFolderSheet = true }
                    .buttonStyle(.borderedProminent)
                    .tint(accentColor)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func binding(for folder: MenuBarFolder) -> Binding<MenuBarFolder> {
        Binding(
            get: { store.folders.first(where: { $0.id == folder.id }) ?? folder },
            set: { _ in }
        )
    }
}

struct NewFolderSheet: View {
    let onCreate: (String, String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var iconName = "folder"
    @State private var showIconPicker = false

    var body: some View {
        VStack(spacing: 16) {
            Text("New Folder")
                .font(.headline)

            HStack(spacing: 12) {
                Button(action: { showIconPicker = true }) {
                    if let img = LucideIcons.previewImage(named: iconName, size: 24) {
                        Image(nsImage: img)
                            .frame(width: 36, height: 36)
                            .background(Color.primary.opacity(0.05))
                            .cornerRadius(8)
                    }
                }
                .buttonStyle(.borderless)

                TextField("Folder name", text: $name)
                    .textFieldStyle(.roundedBorder)
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Create") {
                    guard !name.isEmpty else { return }
                    onCreate(name, iconName)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 340)
        .sheet(isPresented: $showIconPicker) {
            IconPickerView(selectedIconName: $iconName)
        }
    }
}
