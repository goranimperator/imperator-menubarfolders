import SwiftUI

struct IconPickerView: View {
    @Binding var selectedIconName: String
    var onPasteSVG: ((String) -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var showPasteSVG = false
    @State private var svgText = ""
    @State private var svgPreview: NSImage?
    @State private var svgError = false

    private let accentColor = Color(red: 0xa0/255, green: 0x18/255, blue: 0x18/255)
    private let columns = Array(repeating: GridItem(.fixed(44), spacing: 6), count: 8)

    private var filteredIcons: [String] {
        if searchText.isEmpty { return LucideIcons.allIconNames }
        return LucideIcons.allIconNames.filter {
            $0.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            if showPasteSVG {
                pasteSVGView
            } else {
                searchBar
                Divider()
                iconGrid
            }
        }
        .frame(width: 420, height: 480)
    }

    @ViewBuilder
    private var header: some View {
        HStack {
            Text("Choose Icon")
                .font(.headline)
            Spacer()
            if onPasteSVG != nil {
                Button(action: { showPasteSVG.toggle(); svgText = ""; svgPreview = nil; svgError = false }) {
                    Text(showPasteSVG ? "Choose Icon" : "Paste SVG")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.borderless)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(accentColor, lineWidth: 1.5)
                )
            }
            Button(action: { dismiss() }) {
                Text("Done")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
            }
            .buttonStyle(.borderless)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(accentColor)
            .cornerRadius(6)
        }
        .padding()
    }

    @ViewBuilder
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search icons", text: $searchText)
                .textFieldStyle(.plain)
        }
        .padding(8)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var iconGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(filteredIcons, id: \.self) { name in
                    iconCell(name: name)
                }
            }
            .padding(12)
        }
    }

    @ViewBuilder
    private var pasteSVGView: some View {
        VStack(spacing: 16) {
            HStack(spacing: 0) {
                Text("Paste SVG from ")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                Text("Lucide Icons")
                    .font(.system(size: 13))
                    .foregroundStyle(accentColor)
                    .underline()
                    .onTapGesture {
                        NSWorkspace.shared.open(URL(string: "https://lucide.dev/icons/")!)
                    }
                    .onHover { h in
                        if h { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                    }
            }

            ZStack(alignment: .topLeading) {
                TextEditor(text: $svgText)
                    .font(.system(size: 11, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .foregroundColor(.white)
                    .padding(8)

                if svgText.isEmpty {
                    Text("<svg>...paste here...</svg>")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.3))
                        .padding(12)
                        .allowsHitTesting(false)
                }
            }
            .background(Color(NSColor.textBackgroundColor).opacity(0.12))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
            )
            .cornerRadius(6)
            .frame(maxHeight: .infinity)
            .onChange(of: svgText) { _, newValue in
                validateSVG(newValue)
            }

            if let preview = svgPreview {
                HStack(spacing: 12) {
                    Image(nsImage: preview)
                        .frame(width: 40, height: 40)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white.opacity(0.08))
                        )
                    Text("Preview")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button(action: {
                        onPasteSVG?(svgText.trimmingCharacters(in: .whitespacesAndNewlines))
                        dismiss()
                    }) {
                        Text("Use This Icon")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                    }
                    .buttonStyle(.borderless)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(accentColor)
                    .cornerRadius(6)
                }
            } else if svgError && !svgText.isEmpty {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("Could not parse SVG")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
        }
        .padding()
    }

    private func validateSVG(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.contains("<svg"), trimmed.contains("</svg>") || trimmed.contains("/>") else {
            svgPreview = nil
            svgError = !trimmed.isEmpty
            return
        }
        if let img = LucideIcons.previewImageFromSVG(trimmed, size: 40) {
            svgPreview = img
            svgError = false
        } else {
            svgPreview = nil
            svgError = true
        }
    }

    @ViewBuilder
    private func iconCell(name: String) -> some View {
        let isSelected = selectedIconName == name
        Button(action: {
            selectedIconName = name
        }) {
            if let img = LucideIcons.previewImage(named: name, size: 20) {
                Image(nsImage: img)
                    .frame(width: 40, height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isSelected
                                ? accentColor.opacity(0.15)
                                : Color.primary.opacity(0.03))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(isSelected
                                ? accentColor
                                : Color.clear, lineWidth: 2)
                    )
            }
        }
        .buttonStyle(.borderless)
        .help(name)
    }
}
