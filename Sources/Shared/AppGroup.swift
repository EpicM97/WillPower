import Foundation

enum AppGroup {
    static let identifier = "group.com.willpower.HabitTracker"

    static var sharedStoreURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: identifier)?
            .appendingPathComponent("HabitTracker-v3.store")
    }
}
