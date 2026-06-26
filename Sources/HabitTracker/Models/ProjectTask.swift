import Foundation
import SwiftData

enum TaskStatus: Int, Codable, CaseIterable {
    case todo = 0
    case doing = 1
    case done = 2

    var label: String {
        switch self {
        case .todo: "To do"
        case .doing: "Doing"
        case .done: "Done"
        }
    }
}

/// A workable unit inside a Project. Status drives Kanban swimlane.
/// Named `ProjectTask` to avoid clashing with `Swift.Task`.
@Model
final class ProjectTask {
    @Attribute(.unique) var id: UUID
    var title: String
    var details: String = ""
    var statusRaw: Int = 0
    var estimatedMinutes: Int = 30
    var dueDate: Date?
    var order: Int = 0
    var completedAt: Date?
    var updatedAt: Date = Date.distantPast
    var deletedAt: Date? = nil

    var project: Project?

    init(
        id: UUID = UUID(),
        title: String,
        details: String = "",
        status: TaskStatus = .todo,
        estimatedMinutes: Int = 30,
        dueDate: Date? = nil,
        order: Int = 0,
        completedAt: Date? = nil,
        updatedAt: Date = .now,
        project: Project? = nil
    ) {
        self.id = id
        self.title = title
        self.details = details
        self.statusRaw = status.rawValue
        self.estimatedMinutes = estimatedMinutes
        self.dueDate = dueDate
        self.order = order
        self.completedAt = completedAt
        self.updatedAt = updatedAt
        self.project = project
    }

    var status: TaskStatus {
        get { TaskStatus(rawValue: statusRaw) ?? .todo }
        set {
            statusRaw = newValue.rawValue
            if newValue == .done && completedAt == nil { completedAt = .now }
            if newValue != .done { completedAt = nil }
        }
    }
}
