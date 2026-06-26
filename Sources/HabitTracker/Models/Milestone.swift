import Foundation
import SwiftData

@Model
final class Milestone {
    @Attribute(.unique) var id: UUID
    var title: String
    var isCompleted: Bool
    var completedAt: Date?
    var order: Int
    /// Per-milestone weight for `Project.weightedProgress`. Defaults to 1.0
    /// so legacy rows behave like unweighted progress (count-based).
    var weight: Double = 1.0
    var updatedAt: Date = Date.distantPast
    var deletedAt: Date? = nil

    var project: Project?

    init(
        id: UUID = UUID(),
        title: String,
        isCompleted: Bool = false,
        completedAt: Date? = nil,
        order: Int = 0,
        weight: Double = 1.0,
        updatedAt: Date = .now,
        project: Project? = nil
    ) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.completedAt = completedAt
        self.order = order
        self.weight = weight
        self.updatedAt = updatedAt
        self.project = project
    }

    func markCompleted(at date: Date = .now) {
        isCompleted = true
        completedAt = date
    }

    func markIncomplete() {
        isCompleted = false
        completedAt = nil
    }
}
