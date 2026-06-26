import Foundation
import SwiftData

@Observable @MainActor
final class MilestoneEditorViewModel {
    enum Mode: Equatable {
        case create(project: Project)
        case edit(milestone: Milestone)
    }

    var title: String
    var isCompleted: Bool
    private(set) var saving: Bool = false
    private(set) var lastError: String?

    let mode: Mode
    /// Milestones don't yet have a dedicated repo method; we mutate via the
    /// ModelContext directly. Pass the container in so the VM stays testable.
    private let container: ModelContainer

    init(mode: Mode, container: ModelContainer) {
        self.mode = mode
        self.container = container
        switch mode {
        case .create:
            title = ""
            isCompleted = false
        case .edit(let m):
            title = m.title
            isCompleted = m.isCompleted
        }
    }

    var isValid: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty }

    var screenTitle: String {
        switch mode {
        case .create: "New milestone"
        case .edit: "Edit milestone"
        }
    }

    @discardableResult
    func save() async -> Bool {
        guard isValid, !saving else { return false }
        saving = true
        defer { saving = false }
        lastError = nil
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        let context = container.mainContext
        do {
            switch mode {
            case .create(let project):
                let order = project.milestones.count
                let m = Milestone(title: trimmed, isCompleted: isCompleted, completedAt: isCompleted ? .now : nil, order: order, project: project)
                context.insert(m)
            case .edit(let m):
                m.title = trimmed
                if m.isCompleted != isCompleted {
                    if isCompleted { m.markCompleted() } else { m.markIncomplete() }
                }
                m.updatedAt = .now
            }
            try context.save()
            return true
        } catch {
            lastError = String(describing: error)
            return false
        }
    }
}
