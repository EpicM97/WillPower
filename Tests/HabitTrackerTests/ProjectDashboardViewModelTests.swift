import XCTest
@testable import HabitTracker

@MainActor
final class ProjectDashboardViewModelTests: XCTestCase {
    func test_load_empty_returnsZeroTotals() async throws {
        let vm = ProjectDashboardViewModel(repository: MockRepository())
        await vm.load()

        XCTAssertTrue(vm.objectives.isEmpty)
        XCTAssertEqual(vm.totalKeyResults, 0)
        XCTAssertEqual(vm.totalProjects, 0)
        XCTAssertEqual(vm.overallProgress, 0)
    }

    func test_load_surfacesObjectivesAndProjects() async throws {
        let repo = MockRepository()
        let obj = Objective(title: "Ship v1")
        try await repo.add(objective: obj)
        let kr = KeyResult(title: "20 DAU", targetValue: 20)
        try await repo.add(keyResult: kr, to: obj)
        let project = Project(title: "MVP polish", milestones: [
            Milestone(title: "App Review", isCompleted: true),
            Milestone(title: "Beta launch")
        ])
        try await repo.add(project: project, to: kr)

        let vm = ProjectDashboardViewModel(repository: repo)
        await vm.load()

        XCTAssertEqual(vm.objectives.map(\.title), ["Ship v1"])
        XCTAssertEqual(vm.totalKeyResults, 1)
        XCTAssertEqual(vm.totalProjects, 1)
        XCTAssertEqual(vm.overallProgress, 0.5, accuracy: 0.0001)
    }
}
