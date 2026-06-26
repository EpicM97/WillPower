import Foundation

/// Wire format mirroring Supabase tables. Snake_case JSON keys.
/// v3: Work hierarchy (Objectives/KRs/Projects/Milestones/Tasks) is local-only.
/// Only Habits, Sessions, and Journals sync remotely for now.
enum SyncDTO {
    struct Habit: Codable, Equatable, Sendable {
        var id: UUID
        var title: String
        var energyRaw: Int
        var estimatedMinutes: Int
        var order: Int
        var priority: Int
        var kindRaw: Int = HabitKind.duration.rawValue
        var anchorMinuteOfDay: Int?
        var updatedAt: Date
        var deletedAt: Date?

        enum CodingKeys: String, CodingKey {
            case id, title, order, priority
            case energyRaw = "energy_raw"
            case estimatedMinutes = "estimated_minutes"
            case kindRaw = "kind_raw"
            case anchorMinuteOfDay = "anchor_minute_of_day"
            case updatedAt = "updated_at"
            case deletedAt = "deleted_at"
        }

        init(
            id: UUID, title: String, energyRaw: Int, estimatedMinutes: Int,
            order: Int, priority: Int, kindRaw: Int = HabitKind.duration.rawValue,
            anchorMinuteOfDay: Int? = nil,
            updatedAt: Date, deletedAt: Date?
        ) {
            self.id = id; self.title = title; self.energyRaw = energyRaw
            self.estimatedMinutes = estimatedMinutes; self.order = order
            self.priority = priority; self.kindRaw = kindRaw
            self.anchorMinuteOfDay = anchorMinuteOfDay
            self.updatedAt = updatedAt; self.deletedAt = deletedAt
        }

        // Tolerate rows written before the `kind_raw` / `anchor_minute_of_day`
        // columns existed.
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = try c.decode(UUID.self, forKey: .id)
            title = try c.decode(String.self, forKey: .title)
            energyRaw = try c.decode(Int.self, forKey: .energyRaw)
            estimatedMinutes = try c.decode(Int.self, forKey: .estimatedMinutes)
            order = try c.decode(Int.self, forKey: .order)
            priority = try c.decode(Int.self, forKey: .priority)
            kindRaw = try c.decodeIfPresent(Int.self, forKey: .kindRaw) ?? HabitKind.duration.rawValue
            anchorMinuteOfDay = try c.decodeIfPresent(Int.self, forKey: .anchorMinuteOfDay)
            updatedAt = try c.decode(Date.self, forKey: .updatedAt)
            deletedAt = try c.decodeIfPresent(Date.self, forKey: .deletedAt)
        }
    }

    struct DailySession: Codable, Equatable, Sendable {
        var id: UUID
        var habitID: UUID?
        var date: Date
        var baseMinutes: Int
        var compressedMinutes: Int
        var actualMinutes: Int?
        var status: Int
        var stoppedEarly: Bool
        var isInterruption: Bool
        var energyRaw: Int
        var orderHint: Int
        var startedAt: Date?
        var completedAt: Date?
        var note: String?
        var updatedAt: Date
        var deletedAt: Date?

        enum CodingKeys: String, CodingKey {
            case id, date, status, note
            case habitID = "habit_id"
            case baseMinutes = "base_minutes"
            case compressedMinutes = "compressed_minutes"
            case actualMinutes = "actual_minutes"
            case stoppedEarly = "stopped_early"
            case isInterruption = "is_interruption"
            case energyRaw = "energy_raw"
            case orderHint = "order_hint"
            case startedAt = "started_at"
            case completedAt = "completed_at"
            case updatedAt = "updated_at"
            case deletedAt = "deleted_at"
        }

        init(
            id: UUID, habitID: UUID?, date: Date, baseMinutes: Int, compressedMinutes: Int,
            actualMinutes: Int?, status: Int, stoppedEarly: Bool = false, isInterruption: Bool,
            energyRaw: Int = EnergyLevel.mid.rawValue,
            orderHint: Int, startedAt: Date?, completedAt: Date?, note: String?,
            updatedAt: Date, deletedAt: Date?
        ) {
            self.id = id; self.habitID = habitID; self.date = date
            self.baseMinutes = baseMinutes; self.compressedMinutes = compressedMinutes
            self.actualMinutes = actualMinutes; self.status = status
            self.stoppedEarly = stoppedEarly; self.isInterruption = isInterruption
            self.energyRaw = energyRaw
            self.orderHint = orderHint; self.startedAt = startedAt
            self.completedAt = completedAt; self.note = note
            self.updatedAt = updatedAt; self.deletedAt = deletedAt
        }

        // Tolerate rows written before the `stopped_early` column existed.
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = try c.decode(UUID.self, forKey: .id)
            habitID = try c.decodeIfPresent(UUID.self, forKey: .habitID)
            date = try c.decode(Date.self, forKey: .date)
            baseMinutes = try c.decode(Int.self, forKey: .baseMinutes)
            compressedMinutes = try c.decode(Int.self, forKey: .compressedMinutes)
            actualMinutes = try c.decodeIfPresent(Int.self, forKey: .actualMinutes)
            status = try c.decode(Int.self, forKey: .status)
            stoppedEarly = try c.decodeIfPresent(Bool.self, forKey: .stoppedEarly) ?? false
            isInterruption = try c.decode(Bool.self, forKey: .isInterruption)
            energyRaw = try c.decodeIfPresent(Int.self, forKey: .energyRaw) ?? EnergyLevel.mid.rawValue
            orderHint = try c.decode(Int.self, forKey: .orderHint)
            startedAt = try c.decodeIfPresent(Date.self, forKey: .startedAt)
            completedAt = try c.decodeIfPresent(Date.self, forKey: .completedAt)
            note = try c.decodeIfPresent(String.self, forKey: .note)
            updatedAt = try c.decode(Date.self, forKey: .updatedAt)
            deletedAt = try c.decodeIfPresent(Date.self, forKey: .deletedAt)
        }
    }

    struct Journal: Codable, Equatable, Sendable {
        var id: UUID
        var date: Date
        var disciplineScore: Double
        var completedCount: Int
        var deferredCount: Int
        var interruptionCount: Int
        var totalMinutes: Int
        var summaryNote: String?
        var updatedAt: Date
        var deletedAt: Date?

        enum CodingKeys: String, CodingKey {
            case id, date
            case disciplineScore = "discipline_score"
            case completedCount = "completed_count"
            case deferredCount = "deferred_count"
            case interruptionCount = "interruption_count"
            case totalMinutes = "total_minutes"
            case summaryNote = "summary_note"
            case updatedAt = "updated_at"
            case deletedAt = "deleted_at"
        }
    }

    struct Snapshot: Codable, Equatable, Sendable {
        var habits: [Habit] = []
        var sessions: [DailySession] = []
        var journals: [Journal] = []

        var isEmpty: Bool {
            habits.isEmpty && sessions.isEmpty && journals.isEmpty
        }
    }
}
