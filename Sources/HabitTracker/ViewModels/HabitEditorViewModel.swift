import Foundation

@Observable @MainActor
final class HabitEditorViewModel {
    enum Mode: Equatable {
        case create
        case edit(habit: Habit)
    }

    var title: String
    var energy: EnergyLevel
    var estimatedMinutes: Int
    var priority: Int
    var kind: HabitKind
    /// Clock time (minutes from midnight) for an `.anchored` habit. Defaults to
    /// 8:00 so the time picker opens somewhere sensible; only persisted when the
    /// chosen kind is anchored (see `effectiveAnchor`).
    var anchorMinuteOfDay: Int
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
            energy = .mid
            estimatedMinutes = 30
            priority = 1
            kind = .duration
            anchorMinuteOfDay = 8 * 60
        case .edit(let habit):
            title = habit.title
            energy = habit.energy
            estimatedMinutes = habit.estimatedMinutes
            priority = habit.priority
            kind = habit.kind
            anchorMinuteOfDay = habit.anchorMinuteOfDay ?? 8 * 60
        }
    }

    /// Moment habits consume no budget, so they don't require a duration; the
    /// rest do.
    var isValid: Bool {
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        return kind == .moment || estimatedMinutes > 0
    }

    /// Minutes persisted for the chosen kind — a moment habit is always 0.
    private var effectiveMinutes: Int { kind == .moment ? 0 : estimatedMinutes }

    /// Anchor persisted for the chosen kind — only an anchored habit pins a time.
    private var effectiveAnchor: Int? { kind == .anchored ? anchorMinuteOfDay : nil }

    var screenTitle: String {
        switch mode {
        case .create: "New habit"
        case .edit: "Edit habit"
        }
    }

    /// Returns `true` on success so the view can dismiss.
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
                let existing = (try? await repository.fetchAllHabits()) ?? []
                let habit = Habit(title: trimmed, energy: energy, estimatedMinutes: effectiveMinutes, order: existing.count, priority: priority, kind: kind, anchorMinuteOfDay: effectiveAnchor)
                try await repository.add(habit: habit)
            case .edit(let habit):
                habit.title = trimmed
                habit.energy = energy
                habit.estimatedMinutes = effectiveMinutes
                habit.priority = priority
                habit.kind = kind
                habit.anchorMinuteOfDay = effectiveAnchor
                habit.updatedAt = .now
                try await repository.save()
            }
            return true
        } catch {
            lastError = String(describing: error)
            return false
        }
    }
}
