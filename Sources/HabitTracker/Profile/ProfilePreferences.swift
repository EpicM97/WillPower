import Foundation
import SwiftUI
import Observation

enum AppearancePreference: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }
    var label: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

/// Local-only UserDefaults-backed profile preferences. Pre-PMF: not synced.
/// When we go cloud, replace with a real @Model + Supabase user_metadata sync.
@Observable
@MainActor
final class ProfilePreferences {
    static let shared = ProfilePreferences()

    private let defaults: UserDefaults
    private enum Keys {
        static let displayName = "WillPower.profile.displayName"
        static let dateOfBirth = "WillPower.profile.dateOfBirth"
        static let avatarData = "WillPower.profile.avatarData"
        static let appearance = "WillPower.profile.appearance"
    }

    var displayName: String {
        didSet { defaults.set(displayName, forKey: Keys.displayName) }
    }

    var dateOfBirth: Date? {
        didSet {
            if let dateOfBirth { defaults.set(dateOfBirth, forKey: Keys.dateOfBirth) }
            else { defaults.removeObject(forKey: Keys.dateOfBirth) }
        }
    }

    var avatarData: Data? {
        didSet {
            if let avatarData { defaults.set(avatarData, forKey: Keys.avatarData) }
            else { defaults.removeObject(forKey: Keys.avatarData) }
        }
    }

    var appearance: AppearancePreference {
        didSet { defaults.set(appearance.rawValue, forKey: Keys.appearance) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.displayName = defaults.string(forKey: Keys.displayName) ?? ""
        self.dateOfBirth = defaults.object(forKey: Keys.dateOfBirth) as? Date
        self.avatarData = defaults.data(forKey: Keys.avatarData)
        let raw = defaults.string(forKey: Keys.appearance) ?? AppearancePreference.system.rawValue
        self.appearance = AppearancePreference(rawValue: raw) ?? .system
    }

    func reset() {
        displayName = ""
        dateOfBirth = nil
        avatarData = nil
        appearance = .system
    }
}
