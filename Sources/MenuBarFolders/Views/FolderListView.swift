import SwiftUI

struct FolderListView: View {
    @Binding var selectedFolder: MenuBarFolder?
    @EnvironmentObject var store: FolderStore
    @State private var hoveredFolder: UUID?
    @State private var showDeleteAlert = false
    @State private var folderToDelete: MenuBarFolder?

    private let accentColor = Color(red: 0xa0/255, green: 0x18/255, blue: 0x18/255)

    var body: some View {
        List(selection: Binding(
            get: { selectedFolder?.id },
            set: { id in selectedFolder = store.folders.first(where: { $0.id == id }) }
        )) {
            ForEach(store.folders) { folder in
                folderRow(folder)
                    .tag(folder.id)
            }
            .onMove { source, destination in
                store.reorderFolders(from: source, to: destination)
            }
        }
        .listStyle(.sidebar)
        .alert("Delete folder?", isPresented: $showDeleteAlert, presenting: folderToDelete) { folder in
            Button("Delete", role: .destructive) {
                store.deleteFolder(folder)
                if selectedFolder?.id == folder.id {
                    selectedFolder = store.folders.first
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: { folder in
            Text("Are you sure you want to delete \"\(folder.name)\"?")
        }
    }

    @ViewBuilder
    private func folderRow(_ folder: MenuBarFolder) -> some View {
        HStack(spacing: 8) {
            if let img = folderPreviewIcon(folder, size: 16) {
                Image(nsImage: img)
                    .frame(width: 16, height: 16)
            } else {
                Image(systemName: "folder")
                    .frame(width: 16, height: 16)
            }

            Text(folder.name)
                .font(.system(size: 13))
                .lineLimit(1)

            Spacer()

            Text("\(folder.apps.count)")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)

            if hoveredFolder == folder.id {
                Button(action: {
                    folderToDelete = folder
                    showDeleteAlert = true
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.vertical, 2)
        .onHover { h in
            withAnimation(.easeInOut(duration: 0.1)) {
                hoveredFolder = h ? folder.id : nil
            }
        }
        .contextMenu {
            Button("Delete") {
                folderToDelete = folder
                showDeleteAlert = true
            }
        }
    }
}
