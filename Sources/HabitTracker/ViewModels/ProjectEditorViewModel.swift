import Foundation

@Observable @MainActor
final class ProjectEditorViewModel {
    enum Mode: Equatable {
        case create(keyResult: KeyResult)
        case edit(project: Project)
    }

    var title: String
    var details: String
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
        case .edit(let project):
            title = project.title
            details = project.details
        }
    }

    var isValid: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty }

    var screenTitle: String {
        switch mode {
        case .create: "New project"
        case .edit: "Edit project"
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
            case .create(let kr):
                let order = kr.projects.count
                try await repository.add(project: Project(title: trimmed, details: details, order: order), to: kr)
            case .edit(let project):
                project.title = trimmed
                project.details = details
                project.updatedAt = .now
                try await repository.save()
            }
            return true
        } catch {
            lastError = String(describing: error)
            return false
        }
    }
}
