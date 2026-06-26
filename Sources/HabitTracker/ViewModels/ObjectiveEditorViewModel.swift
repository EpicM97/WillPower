import Foundation

@Observable @MainActor
final class ObjectiveEditorViewModel {
    enum Mode: Equatable {
        case create
        case edit(objective: Objective)
    }

    var title: String
    var details: String
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
            dueDate = nil
        case .edit(let o):
            title = o.title
            details = o.details
            dueDate = o.dueDate
        }
    }

    var isValid: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty }

    var screenTitle: String {
        switch mode {
        case .create: "New objective"
        case .edit: "Edit objective"
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
            case .create:
                try await repository.add(objective: Objective(title: trimmed, details: details, dueDate: dueDate))
            case .edit(let o):
                o.title = trimmed
                o.details = details
                o.dueDate = dueDate
                o.updatedAt = .now
                try await repository.save()
            }
            return true
        } catch {
            lastError = String(describing: error)
            return false
        }
    }
}
