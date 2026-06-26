import Foundation
import SwiftData

/// Measurable outcome under an Objective. Projects move KRs.
@Model
final class KeyResult {
    @Attribute(.unique) var id: UUID
    var title: String
    /// Optional metric label, e.g. "users", "%", "lbs".
    var metricUnit: String = ""
    var targetValue: Double = 0
    var currentValue: Double = 0
    var dueDate: Date?
    var order: Int = 0
    var updatedAt: Date = Date.distantPast
    var deletedAt: Date? = nil

    var objective: Objective?

    @Relationship(deleteRule: .cascade, inverse: \Project.keyResult)
    var projects: [Project]

    init(
        id: UUID = UUID(),
        title: String,
        metricUnit: String = "",
        targetValue: Double = 0,
        currentValue: Double = 0,
        dueDate: Date? = nil,
        order: Int = 0,
        updatedAt: Date = .now,
        objective: Objective? = nil,
        projects: [Project] = []
    ) {
        self.id = id
        self.title = title
        self.metricUnit = metricUnit
        self.targetValue = targetValue
        self.currentValue = currentValue
        self.dueDate = dueDate
        self.order = order
        self.updatedAt = updatedAt
        self.objective = objective
        self.projects = projects
    }

    var activeProjects: [Project] { projects.filter { $0.deletedAt == nil } }

    /// 0…1 progress against `targetValue`. Returns 0 if no target set.
    var progress: Double {
        guard targetValue > 0 else { return 0 }
        return min(max(currentValue / targetValue, 0), 1)
    }
}
