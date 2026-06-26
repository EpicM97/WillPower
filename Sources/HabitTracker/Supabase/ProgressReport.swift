import Foundation

enum ReportRange: String, Codable, CaseIterable, Sendable {
    case week, month
}

struct ProgressReport: Codable, Equatable, Sendable {
    var range: ReportRange
    var start: Date
    var end: Date
    var totalMinutes: Int
    var sessionCount: Int
    var milestonesCompleted: Int
    /// 0.0–1.0, or nil when no logs carried an expected snapshot.
    var estimationAccuracy: Double?
    var topHabits: [HabitBucket]
    var byDay: [DayBucket]

    struct HabitBucket: Codable, Equatable, Sendable, Identifiable {
        var habitID: UUID
        var title: String
        var minutes: Int
        var sessions: Int

        var id: UUID { habitID }

        enum CodingKeys: String, CodingKey {
            case habitID = "habit_id"
            case title, minutes, sessions
        }
    }

    struct DayBucket: Codable, Equatable, Sendable, Identifiable {
        var date: String  // YYYY-MM-DD
        var minutes: Int
        var sessions: Int
        var id: String { date }
    }

    enum CodingKeys: String, CodingKey {
        case range, start, end
        case totalMinutes = "total_minutes"
        case sessionCount = "session_count"
        case milestonesCompleted = "milestones_completed"
        case estimationAccuracy = "estimation_accuracy"
        case topHabits = "top_habits"
        case byDay = "by_day"
    }
}
