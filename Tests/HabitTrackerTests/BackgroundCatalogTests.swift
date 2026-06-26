import XCTest
@testable import HabitTracker

final class BackgroundCatalogTests: XCTestCase {
    // colors.json may be an object {"colors":[...]} or a bare array.
    func test_decodeColors_objectForm() {
        let data = Data(##"{"colors":["#112233","#445566"]}"##.utf8)
        XCTAssertEqual(BackgroundCatalog.decodeColors(from: data), ["#112233", "#445566"])
    }

    func test_decodeColors_arrayForm() {
        let data = Data(##"["#AABBCC"]"##.utf8)
        XCTAssertEqual(BackgroundCatalog.decodeColors(from: data), ["#AABBCC"])
    }

    func test_decodeColors_garbageReturnsEmpty() {
        XCTAssertEqual(BackgroundCatalog.decodeColors(from: Data("nope".utf8)), [])
    }

    // Storage object names → bucket-relative stock paths, images only.
    func test_stockPaths_filtersImagesAndPrefixes() {
        let names = ["zen-01.jpg", "forest.PNG", "notes.txt", ".emptyFolderPlaceholder", "calm.heic"]
        XCTAssertEqual(
            BackgroundCatalog.stockPaths(fromObjectNames: names),
            ["stock/zen-01.jpg", "stock/forest.PNG", "stock/calm.heic"]
        )
    }

    // Catalog round-trips through the cache store and falls back to nil when empty.
    func test_store_cachesCatalog() throws {
        let suite = "test.bgcat.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = BackgroundCatalogStore(defaults: defaults)
        XCTAssertNil(store.cached)

        let catalog = BackgroundCatalog(colors: ["#000000"], stockPaths: ["stock/a.jpg"])
        store.save(catalog)
        XCTAssertEqual(BackgroundCatalogStore(defaults: defaults).cached, catalog)
    }

    // Mock provider returns its configured catalog.
    func test_mockProvider_returnsCatalog() async throws {
        let catalog = BackgroundCatalog(colors: ["#FFFFFF"], stockPaths: [])
        let service = MockBackgroundCatalogService(catalog: catalog)
        let fetched = try await service.fetchCatalog()
        XCTAssertEqual(fetched, catalog)
    }
}
