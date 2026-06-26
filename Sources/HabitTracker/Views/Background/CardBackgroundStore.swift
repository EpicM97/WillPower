import Foundation
import SwiftUI

/// Persists the user's `CardBackground` choice (JSON in UserDefaults). The
/// choice is device-local for now; it can be promoted to a synced profile field
/// later without changing this surface.
struct CardBackgroundStore {
    private let defaults: UserDefaults
    private let key = "willpower.cardBackground"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var current: CardBackground {
        guard let data = defaults.data(forKey: key),
              let bg = try? JSONDecoder().decode(CardBackground.self, from: data) else {
            return .surface
        }
        return bg
    }

    func save(_ background: CardBackground) {
        guard let data = try? JSONEncoder().encode(background) else { return }
        defaults.set(data, forKey: key)
    }
}

/// Stores user-uploaded background images as files under Application Support, so
/// only a small filename lives in the persisted `CardBackground.local`.
struct LocalImageStore {
    private let directory: URL

    init(directory: URL? = nil) {
        if let directory {
            self.directory = directory
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            self.directory = base.appendingPathComponent("CardBackgrounds", isDirectory: true)
        }
        try? FileManager.default.createDirectory(at: self.directory, withIntermediateDirectories: true)
    }

    /// Writes image data, returning the generated filename to persist.
    @discardableResult
    func save(_ data: Data) throws -> String {
        let filename = "\(UUID().uuidString).jpg"
        try data.write(to: directory.appendingPathComponent(filename))
        return filename
    }

    func load(_ filename: String) -> Data? {
        try? Data(contentsOf: directory.appendingPathComponent(filename))
    }

    func delete(_ filename: String) {
        try? FileManager.default.removeItem(at: directory.appendingPathComponent(filename))
    }
}
