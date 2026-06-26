import Foundation

@Observable @MainActor
final class TaskEditorViewModel {
    enum Mode: Equatable {
        case create(project: Project)
        case edit(task: ProjectTask)
    }

    var title: String
    var details: String
    var status: TaskStatus
    var estimatedMinutes: Int
    var dueDate: Date?
    private(set) var saving: Bool = false
    private(set) var lastError: String?

    let mode: Mode
    private let repository: any DataRepository

    init(mode: Mode, repository: any DataRepository) {
        self.mode = mode
        self.repository = repository
        switch mode {
        case .create:
            title = ""
            details = ""
            status = .todo
            estimatedMinutes = 30
            dueDate = nil
        case .edit(let t):
            title = t.title
            details = t.details
            status = t.status
            estimatedMinutes = t.estimatedMinutes
            dueDate = t.dueDate
        }
    }

    var isValid: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty }

    var screenTitle: String {
        switch mode {
        case .create: "New task"
        case .edit: "Edit task"
        }
    }

    @discardableResult
    func save() async -> Bool {
        guard isValid, !saving else { return false }
        saving = true
        defer { saving = false }
        lastError = nil
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        do {
            switch mode {
            case .create(let project):
                let order = project.tasks.count
                let t = ProjectTask(
                    title: trimmed,
                    details: details,
                    status: status,
                    estimatedMinutes: estimatedMinutes,
                    dueDate: dueDate,
                    order: order
                )
                try await repository.add(task: t, to: project)
            case .edit(let t):
                t.title = trimmed
                t.details = details
                t.status = status
                t.estimatedMinutes = estimatedMinutes
                t.dueDate = dueDate
                t.updatedAt = .now
                try await repository.save()
            }
            return true
        } catch {
            lastError = String(describing: error)
            return false
        }
    }
}
