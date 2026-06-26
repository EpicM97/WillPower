import Foundation
import SwiftData

/// OKR top-level: what matters this quarter/cycle.
@Model
final class Objective {
    @Attribute(.unique) var id: UUID
    var title: String
    var details: String = ""
    var dueDate: Date?
    /// 0 = active, 1 = archived
    var statusRaw: Int = 0
    var createdAt: Date
    var updatedAt: Date = Date.distantPast
    var deletedAt: Date? = nil

    @Relationship(deleteRule: .cascade, inverse: \KeyResult.objective)
    var keyResults: [KeyResult]

    init(
        id: UUID = UUID(),
        title: String,
        details: String = "",
        dueDate: Date? = nil,
        statusRaw: Int = 0,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        keyResults: [KeyResult] = []
    ) {
        self.id = id
        self.title = title
        self.details = details
        self.dueDate = dueDate
        self.statusRaw = statusRaw
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.keyResults = keyResults
    }

    var isArchived: Bool { statusRaw == 1 }
    var activeKeyResults: [KeyResult] { keyResults.filter { $0.deletedAt == nil } }
}
