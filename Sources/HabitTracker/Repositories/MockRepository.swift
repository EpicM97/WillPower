import Foundation

@MainActor
final class MockRepository: DataRepository {
    private(set) var objectives: [Objective] = []
    private(set) var habits: [Habit] = []
    private(set) var sessions: [DailySession] = []
    private(set) var entries: [HabitEntry] = []
    var errorOnNextWrite: RepositoryError?

    func fetchObjectives() async throws -> [Objective] {
        objectives.filter { $0.deletedAt == nil }
    }

    func fetchKeyResults(in objective: Objective) async throws -> [KeyResult] {
        objective.keyResults.filter { $0.deletedAt == nil }.sorted { $0.order < $1.order }
    }

    func fetchProjects(in keyResult: KeyResult) async throws -> [Project] {
        keyResult.projects.filter { $0.deletedAt == nil }.sorted { $0.order < $1.order }
    }

    func fetchAllProjects() async throws -> [Project] {
        objectives
            .flatMap { $0.keyResults.flatMap(\.projects) }
            .filter { $0.deletedAt == nil }
            .sorted { $0.order < $1.order }
    }

    func fetchTasks(in project: Project) async throws -> [ProjectTask] {
        project.tasks.filter { $0.deletedAt == nil }.sorted { $0.order < $1.order }
    }

    func fetchAllHabits() async throws -> [Habit] {
        habits.filter { $0.deletedAt == nil }.sorted { $0.order < $1.order }
    }

    func fetchSessions(on day: Date) async throws -> [DailySession] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: day)
        let end = cal.date(byAdding: .day, value: 1, to: start) ?? start
        return sessions
            .filter { $0.deletedAt == nil && $0.date >= start && $0.date < end }
            .sorted { lhs, rhs in
                if lhs.isInterruption != rhs.isInterruption { return lhs.isInterruption }
                return lhs.orderHint < rhs.orderHint
            }
    }

    func fetchAllSessions() async throws -> [DailySession] {
        sessions.filter { $0.deletedAt == nil }
    }

    func fetchEntries(on day: Date) async throws -> [HabitEntry] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: day)
        let end = cal.date(byAdding: .day, value: 1, to: start) ?? start
        return entries
            .filter { $0.deletedAt == nil && $0.date >= start && $0.date < end }
    }

    func fetchEntries(for habit: Habit) async throws -> [HabitEntry] {
        entries
            .filter { $0.deletedAt == nil && $0.habit?.id == habit.id }
            .sorted { $0.date < $1.date }
    }

    func reorder(habits: [Habit]) async throws {
        try consumeInjectedError()
        for (index, habit) in habits.enumerated() { habit.order = index }
    }

    func add(objective: Objective) async throws {
        try consumeInjectedError()
        objectives.append(objective)
    }

    func add(keyResult: KeyResult, to objective: Objective) async throws {
        try consumeInjectedError()
        keyResult.objective = objective
        objective.keyResults.append(keyResult)
    }

    func add(project: Project, to keyResult: KeyResult) async throws {
        try consumeInjectedError()
        project.keyResult = keyResult
        keyResult.projects.append(project)
    }

    func add(task: ProjectTask, to project: Project) async throws {
        try consumeInjectedError()
        task.project = project
        project.tasks.append(task)
    }

    func add(habit: Habit) async throws {
        try consumeInjectedError()
        habits.append(habit)
    }

    func add(session: DailySession) async throws {
        try consumeInjectedError()
        sessions.append(session)
        if let habit = session.habit {
            habit.sessions.append(session)
        }
    }

    func add(entry: HabitEntry) async throws {
        try consumeInjectedError()
        entries.append(entry)
        if let habit = entry.habit {
            habit.entries.append(entry)
        }
    }

    func delete(_ objective: Objective) async throws { try consumeInjectedError(); softDelete(objective) }
    func delete(_ keyResult: KeyResult) async throws { try consumeInjectedError(); softDelete(keyResult) }
    func delete(_ project: Project) async throws { try consumeInjectedError(); softDelete(project) }
    func delete(_ task: ProjectTask) async throws { try consumeInjectedError(); softDelete(task) }
    func delete(_ habit: Habit) async throws { try consumeInjectedError(); softDelete(habit) }
    func delete(_ session: DailySession) async throws { try consumeInjectedError(); softDelete(session) }
    func delete(_ entry: HabitEntry) async throws { try consumeInjectedError(); softDelete(entry) }

    func save() async throws { try consumeInjectedError() }

    private func softDelete<T: AnyObject>(_ model: T) {
        let now = Date.now
        switch model {
        case let o as Objective: o.deletedAt = now; o.updatedAt = now
        case let k as KeyResult: k.deletedAt = now; k.updatedAt = now
        case let p as Project: p.deletedAt = now; p.updatedAt = now
        case let t as ProjectTask: t.deletedAt = now; t.updatedAt = now
        case let h as Habit: h.deletedAt = now; h.updatedAt = now
        case let s as DailySession: s.deletedAt = now; s.updatedAt = now
        case let e as HabitEntry: e.deletedAt = now; e.updatedAt = now
        default: break
        }
    }

    private func consumeInjectedError() throws {
        if let error = errorOnNextWrite {
            errorOnNextWrite = nil
            throw error
        }
    }
}
