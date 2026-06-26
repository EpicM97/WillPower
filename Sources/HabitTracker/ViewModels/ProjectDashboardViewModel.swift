import Foundation
import Observation

@Observable
@MainActor
final class ProjectDashboardViewModel {
    private(set) var objectives: [Objective] = []
    private(set) var loadError: String?

    private let repository: any DataRepository

    init(repository: any DataRepository) {
        self.repository = repository
    }

    func load() async {
        do {
            objectives = try await repository.fetchObjectives()
            loadError = nil
        } catch {
            loadError = String(describing: error)
        }
    }

    var totalKeyResults: Int { objectives.reduce(0) { $0 + $1.activeKeyResults.count } }

    var totalProjects: Int {
        objectives.flatMap(\.activeKeyResults).reduce(0) { $0 + $1.activeProjects.count }
    }

    func delete(objective: Objective) async {
        try? await repository.delete(objective)
        await load()
    }

    func delete(keyResult: KeyResult) async {
        try? await repository.delete(keyResult)
        await load()
    }

    func delete(project: Project) async {
        try? await repository.delete(project)
        await load()
    }

    /// Average progress across all projects. 0 when there are no projects.
    var overallProgress: Double {
        let projects = objectives.flatMap { $0.activeKeyResults.flatMap(\.activeProjects) }
        guard !projects.isEmpty else { return 0 }
        let sum = projects.reduce(0.0) { $0 + $1.progress }
        return sum / Double(projects.count)
    }
}
