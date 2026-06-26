import Foundation
import SwiftData

enum SessionStatus: Int, Codable, CaseIterable, Sendable {
    case pending = 0
    case active = 1
    case completed = 2
    case deferred = 3
}

/// Today's instance of a `Habit`, or a one-off interruption injected by the user.
/// Sessions are generated daily from active habits; `Habit` itself is the template.
/// See `docs/specs/elastic_compression.md` for `compressedMinutes` semantics.
@Model
final class DailySession {
    @Attribute(.unique) var id: UUID

    /// Start-of-day this session belongs to (UTC). Used to scope "today's deck".
    var date: Date

    /// Target as planned at session creation. Snapshot of `habit.estimatedMinutes`
    /// (or user-specified for interruptions). Never mutated after creation.
    var baseMinutes: Int

    /// Current target after compression. Equals `baseMinutes` until the
    /// compression engine recalculates.
    var compressedMinutes: Int

    /// Logged minutes when status == .completed. Nil otherwise.
    var actualMinutes: Int? = nil

    var statusRaw: Int = SessionStatus.pending.rawValue
    /// Set when the session was completed via the Stop control (logged the
    /// elapsed time but bailed before finishing). Drives the "stopped early"
    /// badge; scoring stays proportional via `actualMinutes`.
    var stoppedEarly: Bool = false
    var isInterruption: Bool = false
    /// Energy for sessions without an underlying habit (interruptions). Normal
    /// sessions read energy from `habit`; this is the fallback the user picks
    /// when injecting an interruption. Local-only (not synced).
    var energyRaw: Int = EnergyLevel.mid.rawValue
    var orderHint: Int = 0
    var startedAt: Date? = nil
    var completedAt: Date? = nil
    /// Free-form note. Used by interruptions ("phone call from X") and
    /// (later) by the evening ritual's session-level reflections.
    var note: String? = nil

    var createdAt: Date
    var updatedAt: Date = Date.distantPast
    var deletedAt: Date? = nil

    /// Nil for pure interruptions (no underlying habit template).
    var habit: Habit? = nil

    init(
        id: UUID = UUID(),
        date: Date = Calendar.current.startOfDay(for: .now),
        baseMinutes: Int,
        compressedMinutes: Int? = nil,
        actualMinutes: Int? = nil,
        status: SessionStatus = .pending,
        stoppedEarly: Bool = false,
        isInterruption: Bool = false,
        energy: EnergyLevel = .mid,
        orderHint: Int = 0,
        startedAt: Date? = nil,
        completedAt: Date? = nil,
        note: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        habit: Habit? = nil
    ) {
        self.id = id
        self.date = date
        self.baseMinutes = baseMinutes
        self.compressedMinutes = compressedMinutes ?? baseMinutes
        self.actualMinutes = actualMinutes
        self.statusRaw = status.rawValue
        self.stoppedEarly = stoppedEarly
        self.isInterruption = isInterruption
        self.energyRaw = energy.rawValue
        self.orderHint = orderHint
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.note = note
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.habit = habit
    }

    var status: SessionStatus {
        get { SessionStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }

    /// Effective energy: the habit's when present, otherwise the session's own
    /// (set when injecting an interruption).
    var energy: EnergyLevel {
        get { habit?.energy ?? EnergyLevel(rawValue: energyRaw) ?? .mid }
        set { energyRaw = newValue.rawValue }
    }

    /// Time-shape of this session for the compression engine. Interruptions (no
    /// habit) consume time like a duration habit.
    var kind: HabitKind { habit?.kind ?? .duration }

    /// True iff `actualMinutes ?? 0 >= compressedMinutes` and status is completed.
    /// Used by the discipline scorer.
    var hitTarget: Bool {
        status == .completed && (actualMinutes ?? 0) >= compressedMinutes
    }
}
