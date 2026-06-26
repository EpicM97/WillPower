import ActivityKit
import Foundation

struct HabitActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var startedAt: Date
        public var estimatedMinutes: Int
        public var energyRaw: Int
        /// When non-nil the session is paused and elapsed is frozen at this date.
        public var pausedAt: Date?

        public init(startedAt: Date, estimatedMinutes: Int, energyRaw: Int, pausedAt: Date? = nil) {
            self.startedAt = startedAt
            self.estimatedMinutes = estimatedMinutes
            self.energyRaw = energyRaw
            self.pausedAt = pausedAt
        }

        public var energy: EnergyLevel {
            EnergyLevel(rawValue: energyRaw) ?? .mid
        }

        public var isPaused: Bool { pausedAt != nil }
    }

    public var habitID: UUID
    public var title: String

    public init(habitID: UUID, title: String) {
        self.habitID = habitID
        self.title = title
    }
}
