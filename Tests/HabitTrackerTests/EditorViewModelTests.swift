import XCTest
import SwiftData
@testable import HabitTracker

@MainActor
final class EditorViewModelTests: XCTestCase {
    func testHabitEditor_create_addsHabit() async throws {
        let repo = MockRepository()
        let vm = HabitEditorViewModel(mode: .create, repository: repo)
        vm.title = "  Sprint  "
        vm.energy = .high
        vm.estimatedMinutes = 20
        let ok = await vm.save()
        XCTAssertTrue(ok)
        let habits = try await repo.fetchAllHabits()
        XCTAssertEqual(habits.count, 1)
        XCTAssertEqual(habits.first?.title, "Sprint")
        XCTAssertEqual(habits.first?.energy, .high)
    }

    func testHabitEditor_blankTitle_isInvalid() {
        let vm = HabitEditorViewModel(mode: .create, repository: MockRepository())
        vm.title = "   "
        XCTAssertFalse(vm.isValid)
    }

    func testHabitEditor_momentKind_validWithoutMinutes_andPersistsZero() async throws {
        let repo = MockRepository()
        let vm = HabitEditorViewModel(mode: .create, repository: repo)
        vm.title = "Vitamins"
        vm.kind = .moment
        vm.estimatedMinutes = 0
        XCTAssertTrue(vm.isValid, "a moment habit needs no duration")
        let ok = await vm.save()
        XCTAssertTrue(ok)
        let h = try await repo.fetchAllHabits().first
        XCTAssertEqual(h?.kind, .moment)
        XCTAssertEqual(h?.estimatedMinutes, 0)
    }

    func testHabitEditor_durationKind_requiresMinutes() {
        let vm = HabitEditorViewModel(mode: .create, repository: MockRepository())
        vm.title = "Run"
        vm.kind = .duration
        vm.estimatedMinutes = 0
        XCTAssertFalse(vm.isValid)
    }

    func testHabitEditor_anchoredKind_persistsAnchorTime() async throws {
        let repo = MockRepository()
        let vm = HabitEditorViewModel(mode: .create, repository: repo)
        vm.title = "Wake up"
        vm.kind = .anchored
        vm.anchorMinuteOfDay = 6 * 60 + 30
        let ok = await vm.save()
        XCTAssertTrue(ok)
        let h = try await repo.fetchAllHabits().first
        XCTAssertEqual(h?.kind, .anchored)
        XCTAssertEqual(h?.anchorMinuteOfDay, 6 * 60 + 30)
    }

    func testHabitEditor_nonAnchoredKind_clearsAnchor() async throws {
        let repo = MockRepository()
        let vm = HabitEditorViewModel(mode: .create, repository: repo)
        vm.title = "Run"
        vm.kind = .duration
        vm.anchorMinuteOfDay = 6 * 60 // set but irrelevant for a duration habit
        vm.estimatedMinutes = 20
        _ = await vm.save()
        let h = try await repo.fetchAllHabits().first
        XCTAssertNil(h?.anchorMinuteOfDay, "only anchored habits persist a clock time")
    }

    func testObjectiveEditor_edit_updatesTitleAndTouchesUpdatedAt() async throws {
        let repo = MockRepository()
        let obj = Objective(title: "old", updatedAt: Date(timeIntervalSince1970: 0))
        try await repo.add(objective: obj)
        let vm = ObjectiveEditorViewModel(mode: .edit(objective: obj), repository: repo)
        vm.title = "new"
        _ = await vm.save()
        XCTAssertEqual(obj.title, "new")
        XCTAssertGreaterThan(obj.updatedAt, Date(timeIntervalSince1970: 0))
    }

    func testProjectEditor_create_linksToKeyResult() async throws {
        let repo = MockRepository()
        let obj = Objective(title: "Obj"); try await repo.add(objective: obj)
        let kr = KeyResult(title: "KR"); try await repo.add(keyResult: kr, to: obj)
        let vm = ProjectEditorViewModel(mode: .create(keyResult: kr), repository: repo)
        vm.title = "Roadmap"
        _ = await vm.save()
        XCTAssertEqual(kr.projects.count, 1)
        XCTAssertEqual(kr.projects.first?.title, "Roadmap")
    }

    func testTaskEditor_create_linksToProject() async throws {
        let repo = MockRepository()
        let obj = Objective(title: "Obj"); try await repo.add(objective: obj)
        let kr = KeyResult(title: "KR"); try await repo.add(keyResult: kr, to: obj)
        let project = Project(title: "P"); try await repo.add(project: project, to: kr)
        let vm = TaskEditorViewModel(mode: .create(project: project), repository: repo)
        vm.title = "Wire analytics"
        vm.status = .doing
        vm.estimatedMinutes = 45
        _ = await vm.save()
        XCTAssertEqual(project.tasks.count, 1)
        XCTAssertEqual(project.tasks.first?.title, "Wire analytics")
        XCTAssertEqual(project.tasks.first?.status, .doing)
    }
}

@MainActor
final class DemoSeederTests: XCTestCase {
    func testSeedIfNeeded_addsObjectiveOnce() throws {
        let container = try AppSchema.inMemoryContainer()
        let defaults = UserDefaults(suiteName: "DemoSeederTests-\(UUID())")!

        DemoSeeder.seedIfNeeded(container: container, defaults: defaults)
        let count1 = try container.mainContext.fetch(FetchDescriptor<Objective>()).count
        XCTAssertGreaterThan(count1, 0)

        DemoSeeder.seedIfNeeded(container: container, defaults: defaults)
        let count2 = try container.mainContext.fetch(FetchDescriptor<Objective>()).count
        XCTAssertEqual(count2, count1, "second call must be a no-op")
    }

    func testSeedIfNeeded_skipsWhenDataExists() throws {
        let container = try AppSchema.inMemoryContainer()
        container.mainContext.insert(Objective(title: "user data"))
        try container.mainContext.save()
        let defaults = UserDefaults(suiteName: "DemoSeederTests-\(UUID())")!

        DemoSeeder.seedIfNeeded(container: container, defaults: defaults)
        let objectives = try container.mainContext.fetch(FetchDescriptor<Objective>())
        XCTAssertEqual(objectives.count, 1)
        XCTAssertEqual(objectives.first?.title, "user data")
    }
}
