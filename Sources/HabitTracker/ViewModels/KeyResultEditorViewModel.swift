import Foundation

@Observable @MainActor
final class KeyResultEditorViewModel {
    enum Mode: Equatable {
        case create(objective: Objective)
        case edit(keyResult: KeyResult)
    }

    var title: String
    var metricUnit: String
    var targetValue: Double
    var currentValue: Double
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
            metricUnit = ""
            targetValue = 0
            currentValue = 0
            dueDate = nil
        case .edit(let kr):
            title = kr.title
            metricUnit = kr.metricUnit
            targetValue = kr.targetValue
            currentValue = kr.currentValue
            dueDate = kr.dueDate
        }
    }

    var isValid: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty }

    var screenTitle: String {
        switch mode {
        case .create: "New key result"
        case .edit: "Edit key result"
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
            case .create(let objective):
                let order = objective.keyResults.count
                let kr = KeyResult(
                    title: trimmed,
                    metricUnit: metricUnit,
                    targetValue: targetValue,
                    currentValue: currentValue,
                    dueDate: dueDate,
                    order: order
                )
                try await repository.add(keyResult: kr, to: objective)
            case .edit(let kr):
                kr.title = trimmed
                kr.metricUnit = metricUnit
                kr.targetValue = targetValue
                kr.currentValue = currentValue
                kr.dueDate = dueDate
                kr.updatedAt = .now
                try await repository.save()
            }
            return true
        } catch {
            lastError = String(describing: error)
            return false
        }
    }
}
