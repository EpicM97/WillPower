import Foundation
import SwiftData

/// End-of-day snapshot. Written by `JournalArchiver` at midnight rollover (or
/// manually). Surfaced in the Evening Ritual + future history view.
@Model
final class Journal {
    @Attribute(.unique) var id: UUID
    /// Start-of-day this journal records.
    @Attribute(.unique) var date: Date
    var disciplineScore: Double
    var completedCount: Int
    var deferredCount: Int
    var interruptionCount: Int
    var totalMinutes: Int
    var summaryNote: String? = nil

    var createdAt: Date
    var updatedAt: Date = Date.distantPast
    var deletedAt: Date? = nil

    init(
        id: UUID = UUID(),
        date: Date,
        disciplineScore: Double,
        completedCount: Int = 0,
        deferredCount: Int = 0,
        interruptionCount: Int = 0,
        totalMinutes: Int = 0,
        summaryNote: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.date = date
        self.disciplineScore = disciplineScore
        self.completedCount = completedCount
        self.deferredCount = deferredCount
        self.interruptionCount = interruptionCount
        self.totalMinutes = totalMinutes
        self.summaryNote = summaryNote
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
