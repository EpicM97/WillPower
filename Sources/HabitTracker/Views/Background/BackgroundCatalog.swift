import Foundation

/// The set of card-background assets hosted in the Supabase `backgrounds`
/// bucket: a solid-color board (`colors.json`) and stock image object paths
/// (`stock/*`). Cached locally so the picker opens instantly.
struct BackgroundCatalog: Codable, Equatable {
    var colors: [String]      // "#RRGGBB" hex strings
    var stockPaths: [String]  // bucket-relative, e.g. "stock/zen-01.jpg"

    static let stockPrefix = "stock"

    /// `colors.json` is either `{"colors":[...]}` or a bare `[...]` array.
    static func decodeColors(from data: Data) -> [String] {
        if let obj = try? JSONDecoder().decode([String: [String]].self, from: data),
           let colors = obj["colors"] {
            return colors
        }
        if let array = try? JSONDecoder().decode([String].self, from: data) {
            return array
        }
        return []
    }

    /// Maps Storage object names (just filenames) under `stock/` to
    /// bucket-relative paths, keeping image files only and skipping placeholders.
    static func stockPaths(fromObjectNames names: [String]) -> [String] {
        let exts = ["jpg", "jpeg", "png", "heic", "webp"]
        return names
            .filter { name in exts.contains { name.lowercased().hasSuffix(".\($0)") } }
            .map { "\(stockPrefix)/\($0)" }
    }
}

/// Caches the last-fetched catalog (JSON in UserDefaults) so the picker shows
/// colors/stock immediately, then refreshes in the background.
struct BackgroundCatalogStore {
    private let defaults: UserDefaults
    private let key = "willpower.backgroundCatalog"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var cached: BackgroundCatalog? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(BackgroundCatalog.self, from: data)
    }

    func save(_ catalog: BackgroundCatalog) {
        guard let data = try? JSONEncoder().encode(catalog) else { return }
        defaults.set(data, forKey: key)
    }
}
