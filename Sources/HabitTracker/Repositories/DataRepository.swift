import Foundation

enum RepositoryError: Error, Equatable {
    case notFound
    case persistenceFailure(String)
}

/// Read/write surface for SwiftData and (via `MockRepository`) test fixtures.
/// View models depend on this protocol, never on `ModelContext` directly.
@MainActor
protocol DataRepository {
    // MARK: Work hierarchy
    func fetchObjectives() async throws -> [Objective]
    func fetchKeyResults(in objective: Objective) async throws -> [KeyResult]
    func fetchProjects(in keyResult: KeyResult) async throws -> [Project]
    func fetchAllProjects() async throws -> [Project]
    func fetchTasks(in project: Project) async throws -> [ProjectTask]

    // MARK: Habits (top-level)
    func fetchAllHabits() async throws -> [Habit]
    func reorder(habits: [Habit]) async throws

    // MARK: Sessions
    func fetchSessions(on day: Date) async throws -> [DailySession]
    func fetchAllSessions() async throws -> [DailySession]

    // MARK: Mutations
    func add(objective: Objective) async throws
    func add(keyResult: KeyResult, to objective: Objective) async throws
    func add(project: Project, to keyResult: KeyResult) async throws
    func add(task: ProjectTask, to project: Project) async throws
    func add(habit: Habit) async throws
    func add(session: DailySession) async throws

    func delete(_ objective: Objective) async throws
    func delete(_ keyResult: KeyResult) async throws
    func delete(_ project: Project) async throws
    func delete(_ task: ProjectTask) async throws
    func delete(_ habit: Habit) async throws
    func delete(_ session: DailySession) async throws

    func save() async throws
}
