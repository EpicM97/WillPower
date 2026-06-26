import Foundation
import SwiftData

@Model
final class Project {
    @Attribute(.unique) var id: UUID
    var title: String
    var details: String = ""
    var colorHex: String = "#5856D6"
    var order: Int = 0
    var updatedAt: Date = Date.distantPast
    var deletedAt: Date? = nil

    var keyResult: KeyResult?

    @Relationship(deleteRule: .cascade, inverse: \Milestone.project)
    var milestones: [Milestone]

    @Relationship(deleteRule: .cascade, inverse: \ProjectTask.project)
    var tasks: [ProjectTask]

    init(
        id: UUID = UUID(),
        title: String,
        details: String = "",
        colorHex: String = "#5856D6",
        order: Int = 0,
        updatedAt: Date = .now,
        keyResult: KeyResult? = nil,
        milestones: [Milestone] = [],
        tasks: [ProjectTask] = []
    ) {
        self.id = id
        self.title = title
        self.details = details
        self.colorHex = colorHex
        self.order = order
        self.updatedAt = updatedAt
        self.keyResult = keyResult
        self.milestones = milestones
        self.tasks = tasks
    }

    var activeMilestones: [Milestone] { milestones.filter { $0.deletedAt == nil } }
    var activeTasks: [ProjectTask] { tasks.filter { $0.deletedAt == nil } }

    var totalMilestones: Int { activeMilestones.count }
    var completedMilestones: Int { activeMilestones.lazy.filter(\.isCompleted).count }

    var totalTasks: Int { activeTasks.count }
    var completedTasks: Int { activeTasks.lazy.filter { $0.status == .done }.count }

    /// Blended completion: weighted by milestone weights + task count.
    var progress: Double {
        let totalUnits = Double(activeMilestones.count + activeTasks.count)
        guard totalUnits > 0 else { return 0 }
        let doneUnits = Double(completedMilestones + completedTasks)
        return doneUnits / totalUnits
    }

    func tasks(in status: TaskStatus) -> [ProjectTask] {
        activeTasks.filter { $0.status == status }.sorted { $0.order < $1.order }
    }
}
