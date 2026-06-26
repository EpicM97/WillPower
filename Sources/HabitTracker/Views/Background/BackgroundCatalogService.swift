import Foundation
import Supabase

/// Fetches the hosted card-background catalog. Backed by Supabase Storage in the
/// app; `MockBackgroundCatalogService` is in-memory for tests/previews.
protocol BackgroundCatalogProviding: Sendable {
    func fetchCatalog() async throws -> BackgroundCatalog
}

actor SupabaseBackgroundCatalogService: BackgroundCatalogProviding {
    private let client: SupabaseClient
    private let bucket = "backgrounds"

    init(config: SupabaseConfig) {
        self.client = SupabaseClient(supabaseURL: config.url, supabaseKey: config.anonKey)
    }

    func fetchCatalog() async throws -> BackgroundCatalog {
        let storage = client.storage.from(bucket)
        let colorsData = try await storage.download(path: "colors.json")
        let files = try await storage.list(path: BackgroundCatalog.stockPrefix)
        return BackgroundCatalog(
            colors: BackgroundCatalog.decodeColors(from: colorsData),
            stockPaths: BackgroundCatalog.stockPaths(fromObjectNames: files.map(\.name))
        )
    }
}

struct MockBackgroundCatalogService: BackgroundCatalogProviding {
    let catalog: BackgroundCatalog
    func fetchCatalog() async throws -> BackgroundCatalog { catalog }
}
