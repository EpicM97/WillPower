import PhotosUI
import SwiftUI

/// Lets the user back the "Today's budget" card with a solid color, a stock
/// image, or their own photo. Solid colors + stock images are Supabase-hosted
/// (stock fetch lands in increment 2); uploads are stored on-device.
struct BackgroundPickerSheet: View {
    let current: CardBackground
    /// Called with the chosen background; the caller persists + applies it.
    let onSelect: (CardBackground) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var tab: Tab = .colors
    @State private var photoItem: PhotosPickerItem?
    @State private var importing = false
    @State private var importError: String?
    @State private var catalog = BackgroundCatalog(colors: CardBackground.defaultColorBoard, stockPaths: [])
    @State private var loadingStock = false

    private let imageStore = LocalImageStore()
    private let catalogStore = BackgroundCatalogStore()

    enum Tab: String, CaseIterable, Identifiable {
        case colors = "Colors", stock = "Stock", upload = "Upload"
        var id: String { rawValue }
    }

    private let columns = [GridItem(.adaptive(minimum: 72), spacing: 12)]

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Picker("Source", selection: $tab) {
                    ForEach(Tab.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                ScrollView {
                    switch tab {
                    case .colors: colorsGrid
                    case .stock: stockGrid
                    case .upload: uploadPane
                    }
                }
            }
            .padding(.top)
            .task { await loadCatalog() }
            .navigationTitle("Card background")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Default") { choose(.surface) }
                }
            }
        }
    }

    private var colorsGrid: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(catalog.colors, id: \.self) { hex in
                Button { choose(.solid(hex: hex)) } label: {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(hex: hex) ?? .gray)
                        .frame(height: 72)
                        .overlay(selectionRing(isSelected: current == .solid(hex: hex)))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal)
    }

    // Stock images served from the Supabase `backgrounds/stock` bucket.
    @ViewBuilder private var stockGrid: some View {
        if catalog.stockPaths.isEmpty {
            ContentUnavailableView {
                Label("No stock images yet", systemImage: "photo.on.rectangle.angled")
            } description: {
                Text(loadingStock ? "Loading…" : "Calm, zen, peaceful and forest scenes will appear here once they're added to the server.")
            }
            .padding(.top, 40)
        } else {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(catalog.stockPaths, id: \.self) { path in
                    Button { choose(.remote(path: path)) } label: {
                        AsyncImage(url: CardBackground.publicStorageURL(path: path)) { img in
                            img.resizable().scaledToFill()
                        } placeholder: {
                            Color(.secondarySystemBackground)
                        }
                        .frame(height: 72)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(selectionRing(isSelected: current == .remote(path: path)))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
    }

    private var uploadPane: some View {
        VStack(spacing: 16) {
            PhotosPicker(selection: $photoItem, matching: .images) {
                Label(importing ? "Importing…" : "Choose a photo", systemImage: "photo.badge.plus")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
            }
            .disabled(importing)
            if let importError {
                Text(importError).font(.caption).foregroundStyle(.red)
            }
            Text("Your photo stays on this device.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding()
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task { await importPhoto(item) }
        }
    }

    private func selectionRing(isSelected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 14)
            .strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 3)
    }

    private func importPhoto(_ item: PhotosPickerItem) async {
        importing = true
        importError = nil
        defer { importing = false }
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                importError = "Couldn't read that photo."
                return
            }
            let filename = try imageStore.save(data)
            choose(.local(filename: filename))
        } catch {
            importError = "Import failed: \(error.localizedDescription)"
        }
    }

    private func choose(_ background: CardBackground) {
        onSelect(background)
        Haptics.tap()
        dismiss()
    }

    /// Show the cached catalog immediately (falling back to the bundled color
    /// board), then refresh from Supabase Storage in the background.
    private func loadCatalog() async {
        if let cached = catalogStore.cached, !cached.colors.isEmpty {
            catalog = cached
        }
        guard let config = try? SupabaseConfig.fromBundle() else { return }
        loadingStock = true
        defer { loadingStock = false }
        let service = SupabaseBackgroundCatalogService(config: config)
        if let fresh = try? await service.fetchCatalog(), !fresh.colors.isEmpty {
            catalog = fresh
            catalogStore.save(fresh)
        }
    }
}
