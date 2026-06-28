import Foundation
import SwiftData

@MainActor
final class SwiftDataRepository: DataRepository {
    private let container: ModelContainer
    private let context: ModelContext

    init(container: ModelContainer) {
        self.container = container
        self.context = container.mainContext
    }

    // MARK: Work hierarchy reads

    func fetchObjectives() async throws -> [Objective] {
        try fetch(FetchDescriptor<Objective>(
            predicate: #Predicate { $0.deletedAt == nil },
            sortBy: [SortDescriptor(\.createdAt)]
        ))
    }

    func fetchKeyResults(in objective: Objective) async throws -> [KeyResult] {
        objective.keyResults
            .filter { $0.deletedAt == nil }
            .sorted { $0.order < $1.order }
    }

    func fetchProjects(in keyResult: KeyResult) async throws -> [Project] {
        keyResult.projects
            .filter { $0.deletedAt == nil }
            .sorted { $0.order < $1.order }
    }

    func fetchAllProjects() async throws -> [Project] {
        try fetch(FetchDescriptor<Project>(
            predicate: #Predicate { $0.deletedAt == nil },
            sortBy: [SortDescriptor(\.order)]
        ))
    }

    func fetchTasks(in project: Project) async throws -> [ProjectTask] {
        project.tasks
            .filter { $0.deletedAt == nil }
            .sorted { $0.order < $1.order }
    }

    // MARK: Habits

    func fetchAllHabits() async throws -> [Habit] {
        try fetch(FetchDescriptor<Habit>(
            predicate: #Predicate { $0.deletedAt == nil },
            sortBy: [SortDescriptor(\.order)]
        ))
    }

    func reorder(habits: [Habit]) async throws {
        let now = Date.now
        for (index, habit) in habits.enumerated() {
            habit.order = index
            habit.updatedAt = now
        }
        try persist()
    }

    // MARK: Sessions

    func fetchSessions(on day: Date) async throws -> [DailySession] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: day)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        let all = try fetch(FetchDescriptor<DailySession>(
            predicate: #Predicate {
                $0.date >= start && $0.date < end && $0.deletedAt == nil
            }
        ))
        return all.sorted { lhs, rhs in
            if lhs.isInterruption != rhs.isInterruption { return lhs.isInterruption }
            return lhs.orderHint < rhs.orderHint
        }
    }

    func fetchAllSessions() async throws -> [DailySession] {
        try fetch(FetchDescriptor<DailySession>(
            predicate: #Predicate { $0.deletedAt == nil }
        ))
    }

    // MARK: Entries

    func fetchEntries(on day: Date) async throws -> [HabitEntry] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: day)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        return try fetch(FetchDescriptor<HabitEntry>(
            predicate: #Predicate {
                $0.date >= start && $0.date < end && $0.deletedAt == nil
            }
        ))
    }

    func fetchEntries(for habit: Habit) async throws -> [HabitEntry] {
        habit.entries
            .filter { $0.deletedAt == nil }
            .sorted { $0.date < $1.date }
    }

    // MARK: Mutations

    func add(objective: Objective) async throws {
        objective.updatedAt = .now
        context.insert(objective)
        try persist()
    }

    func add(keyResult: KeyResult, to objective: Objective) async throws {
        keyResult.objective = objective
        keyResult.updatedAt = .now
        context.insert(keyResult)
        try persist()
    }

    func add(project: Project, to keyResult: KeyResult) async throws {
        project.keyResult = keyResult
        project.updatedAt = .now
        context.insert(project)
        try persist()
    }

    func add(task: ProjectTask, to project: Project) async throws {
        task.project = project
        task.updatedAt = .now
        context.insert(task)
        try persist()
    }

    func add(habit: Habit) async throws {
        habit.updatedAt = .now
        context.insert(habit)
        try persist()
    }

    func add(session: DailySession) async throws {
        session.updatedAt = .now
        context.insert(session)
        try persist()
    }

    func add(entry: HabitEntry) async throws {
        entry.updatedAt = .now
        context.insert(entry)
        try persist()
    }

    func delete(_ objective: Objective) async throws { try softDelete(objective) }
    func delete(_ keyResult: KeyResult) async throws { try softDelete(keyResult) }
    func delete(_ project: Project) async throws { try softDelete(project) }
    func delete(_ task: ProjectTask) async throws { try softDelete(task) }
    func delete(_ habit: Habit) async throws { try softDelete(habit) }
    func delete(_ session: DailySession) async throws { try softDelete(session) }
    func delete(_ entry: HabitEntry) async throws { try softDelete(entry) }

    func save() async throws { try persist() }

    private func softDelete<T>(_ model: T) throws where T: AnyObject {
        let now = Date.now
        switch model {
        case let o as Objective: o.deletedAt = now; o.updatedAt = now
        case let k as KeyResult: k.deletedAt = now; k.updatedAt = now
        case let p as Project: p.deletedAt = now; p.updatedAt = now
        case let m as Milestone: m.deletedAt = now; m.updatedAt = now
        case let t as ProjectTask: t.deletedAt = now; t.updatedAt = now
        case let h as Habit: h.deletedAt = now; h.updatedAt = now
        case let s as DailySession: s.deletedAt = now; s.updatedAt = now
        case let e as HabitEntry: e.deletedAt = now; e.updatedAt = now
        default: break
        }
        try persist()
    }

    private func fetch<T: PersistentModel>(_ descriptor: FetchDescriptor<T>) throws -> [T] {
        do { return try context.fetch(descriptor) }
        catch { throw RepositoryError.persistenceFailure(String(describing: error)) }
    }

    private func persist() throws {
        do { try context.save() }
        catch { throw RepositoryError.persistenceFailure(String(describing: error)) }
    }
}
