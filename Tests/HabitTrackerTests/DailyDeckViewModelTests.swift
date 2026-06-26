import XCTest
@testable import HabitTracker

@MainActor
final class DailyDeckViewModelTests: XCTestCase {
    private func setupRepoWithSession(actualMinutes: Int? = nil, status: SessionStatus = .pending) async throws -> (MockRepository, DailySession) {
        let repo = MockRepository()
        let habit = Habit(title: "Jog", energy: .high, estimatedMinutes: 30)
        try await repo.add(habit: habit)
        let s = DailySession(baseMinutes: 30, actualMinutes: actualMinutes, status: status, habit: habit)
        try await repo.add(session: s)
        return (repo, s)
    }

    func test_load_populatesSessions() async throws {
        let (repo, _) = try await setupRepoWithSession()
        let vm = DailyDeckViewModel(repository: repo)
        await vm.load()
        XCTAssertEqual(vm.sessions.count, 1)
        XCTAssertEqual(vm.pendingSessions.count, 1)
    }

    func test_complete_movesSessionToCompleted() async throws {
        let (repo, session) = try await setupRepoWithSession()
        let vm = DailyDeckViewModel(repository: repo)
        await vm.load()
        await vm.complete(session, actualMinutes: 28)
        XCTAssertEqual(vm.completedSessions.count, 1)
        XCTAssertEqual(vm.completedSessions.first?.actualMinutes, 28)
    }

    func test_delete_removesSession() async throws {
        let (repo, session) = try await setupRepoWithSession()
        let vm = DailyDeckViewModel(repository: repo)
        await vm.load()
        await vm.delete(session)
        XCTAssertTrue(vm.sessions.isEmpty)
    }

    func test_budget_summarizesPlannedMinutes() async throws {
        let (repo, _) = try await setupRepoWithSession()
        let vm = DailyDeckViewModel(repository: repo)
        vm.availableMinutes = 60
        await vm.load()
        XCTAssertEqual(vm.budget.plannedMinutes, 30)
        XCTAssertEqual(vm.budget.spentMinutes, 0)
    }

    // Budget = time spent (only grows): completed sessions count actual logged
    // minutes in `spentMinutes`; pending estimates live in `plannedMinutes`.
    func test_budget_spentCountsActualCompletedMinutes() async throws {
        let repo = MockRepository()
        let habit = Habit(title: "Stretch", energy: .low, estimatedMinutes: 5)
        try await repo.add(habit: habit)
        let pending = DailySession(baseMinutes: 120, status: .pending, habit: habit)
        let done = DailySession(baseMinutes: 5, actualMinutes: 1, status: .completed, habit: habit)
        try await repo.add(session: pending)
        try await repo.add(session: done)

        let vm = DailyDeckViewModel(repository: repo)
        vm.availableMinutes = 120
        await vm.load()
        XCTAssertEqual(vm.budget.spentMinutes, 1) // actual logged, not the 5-min estimate
        XCTAssertEqual(vm.budget.plannedMinutes, vm.upNextSessions.reduce(0) { $0 + $1.compressedMinutes })
    }

    // Resume re-opens an under-target completion; repeat clones a fresh run.
    func test_reopen_movesCompletedBackToActive() async throws {
        let (repo, session) = try await setupRepoWithSession()
        let vm = DailyDeckViewModel(repository: repo)
        await vm.load()
        await vm.complete(session, actualMinutes: 3, stoppedEarly: true)
        await vm.reopen(session, active: true)
        XCTAssertEqual(vm.goingOnSessions.count, 1)
        XCTAssertTrue(vm.completedSessions.isEmpty)
        XCTAssertFalse(vm.goingOnSessions.first?.stoppedEarly ?? true)
    }

    func test_markActive_enforcesOneRunningAtATime() async throws {
        let repo = MockRepository()
        let habit = Habit(title: "A", energy: .high, estimatedMinutes: 20)
        try await repo.add(habit: habit)
        let a = DailySession(baseMinutes: 20, status: .active, habit: habit)
        let b = DailySession(baseMinutes: 20, status: .pending, habit: habit)
        try await repo.add(session: a)
        try await repo.add(session: b)
        let vm = DailyDeckViewModel(repository: repo)
        await vm.load()
        await vm.markActive(b)
        XCTAssertEqual(vm.goingOnSessions.count, 1)
        XCTAssertEqual(vm.goingOnSessions.first?.id, b.id)
    }

    func test_repeatHabit_clonesFreshPendingRun() async throws {
        let (repo, session) = try await setupRepoWithSession()
        let vm = DailyDeckViewModel(repository: repo)
        await vm.load()
        await vm.complete(session, actualMinutes: 30)
        let clone = await vm.repeatHabit(session)
        XCTAssertNotNil(clone)
        XCTAssertEqual(clone?.status, .pending)
        XCTAssertEqual(vm.upNextSessions.count, 1)
        XCTAssertEqual(clone?.habit?.id, session.habit?.id)
    }

    // A 2nd+ run of the same habit (via Repeat) is flagged as a bonus rep; the
    // earliest run for that habit is not.
    func test_extraRunSessionIDs_flagsRepeatRunsOnly() async throws {
        let (repo, session) = try await setupRepoWithSession()
        let vm = DailyDeckViewModel(repository: repo)
        await vm.load()
        await vm.complete(session, actualMinutes: 30)
        let clone = await vm.repeatHabit(session)
        let extras = vm.extraRunSessionIDs
        XCTAssertFalse(extras.contains(session.id), "first run is the primary, not a bonus")
        XCTAssertTrue(extras.contains(clone!.id), "the cloned repeat is a bonus rep")
    }

    // Confirming an Up-next habit the user actually did logs its planned
    // (compressed) minutes into spent budget — no timer was run.
    func test_completeAsPlanned_logsEstimateIntoBudget() async throws {
        let (repo, session) = try await setupRepoWithSession() // 30-min estimate, pending
        let vm = DailyDeckViewModel(repository: repo)
        vm.availableMinutes = 120
        await vm.load()
        XCTAssertEqual(vm.budget.spentMinutes, 0)

        await vm.completeAsPlanned(session)

        XCTAssertEqual(vm.completedSessions.first?.actualMinutes, 30, "logs the planned estimate")
        XCTAssertEqual(vm.budget.spentMinutes, 30, "estimate counts toward spent budget")
        XCTAssertEqual(vm.completedSessions.first?.stoppedEarly, false, "they did the full habit")
    }

    // Editing a habit's duration is mirrored into its pending session on the
    // next load; active/completed sessions keep their captured minutes.
    func test_syncPendingEstimates_mirrorsHabitDurationEdits() async throws {
        let repo = MockRepository()
        let habit = Habit(title: "Read", energy: .mid, estimatedMinutes: 20)
        try await repo.add(habit: habit)
        let pending = DailySession(baseMinutes: 20, status: .pending, habit: habit)
        let done = DailySession(baseMinutes: 20, actualMinutes: 20, status: .completed, habit: habit)
        try await repo.add(session: pending)
        try await repo.add(session: done)

        let vm = DailyDeckViewModel(repository: repo)
        vm.availableMinutes = 120
        await vm.load()
        XCTAssertEqual(vm.upNextSessions.first?.baseMinutes, 20)

        // User edits the habit duration after creation.
        habit.estimatedMinutes = 45
        try await repo.save()
        await vm.load()

        XCTAssertEqual(vm.upNextSessions.first?.baseMinutes, 45, "pending mirrors the edited estimate")
        XCTAssertEqual(vm.upNextSessions.first?.compressedMinutes, 45)
        XCTAssertEqual(vm.completedSessions.first?.baseMinutes, 20, "completed keeps captured minutes")
    }

    // Confirming the switch wizard: the running habit is logged as a stopped-early
    // completion (they actually did it), and the chosen habit becomes active.
    func test_switchActive_logsRunningAsStoppedEarlyAndStartsNext() async throws {
        let repo = MockRepository()
        let habit = Habit(title: "A", energy: .high, estimatedMinutes: 20)
        try await repo.add(habit: habit)
        let running = DailySession(baseMinutes: 20, status: .active, habit: habit)
        let next = DailySession(baseMinutes: 15, status: .pending, habit: habit)
        try await repo.add(session: running)
        try await repo.add(session: next)
        let vm = DailyDeckViewModel(repository: repo)
        await vm.load()

        await vm.switchActive(from: running, loggedMinutes: 7, to: next)

        let logged = vm.completedSessions.first { $0.id == running.id }
        XCTAssertEqual(logged?.actualMinutes, 7, "elapsed time is logged, not lost")
        XCTAssertEqual(logged?.stoppedEarly, true, "interrupted habit is a stopped-early completion")
        XCTAssertEqual(vm.goingOnSessions.count, 1)
        XCTAssertEqual(vm.goingOnSessions.first?.id, next.id)
    }

    // Logged minutes are floored at 1 — they did the habit, so it never logs 0.
    func test_switchActive_flooredAtOneMinute() async throws {
        let repo = MockRepository()
        let habit = Habit(title: "A", energy: .high, estimatedMinutes: 20)
        try await repo.add(habit: habit)
        let running = DailySession(baseMinutes: 20, status: .active, habit: habit)
        let next = DailySession(baseMinutes: 15, status: .pending, habit: habit)
        try await repo.add(session: running)
        try await repo.add(session: next)
        let vm = DailyDeckViewModel(repository: repo)
        await vm.load()

        await vm.switchActive(from: running, loggedMinutes: 0, to: next)

        XCTAssertEqual(vm.completedSessions.first { $0.id == running.id }?.actualMinutes, 1)
    }

    // Stop control logs elapsed and flags the session as a partial completion.
    func test_stop_logsPartialCompletion() async throws {
        let (repo, session) = try await setupRepoWithSession()
        let vm = DailyDeckViewModel(repository: repo)
        await vm.load()
        await vm.complete(session, actualMinutes: 3, stoppedEarly: true)
        let done = vm.completedSessions.first
        XCTAssertEqual(done?.actualMinutes, 3)
        XCTAssertEqual(done?.stoppedEarly, true)
        // Proportional discipline score, not a full 1.0 and not 0.
        let score = DisciplineScorer.score(for: done!)
        XCTAssertNotNil(score)
        XCTAssertLessThan(score!, 1.0)
        XCTAssertGreaterThan(score!, 0.0)
    }

    // Progress-bar fill fraction: spent/available, clamped to [0, 1].
    func test_budgetFraction_clampsAndGuardsZeroAvailable() {
        XCTAssertEqual(BudgetSnapshot.fraction(spent: 0, available: 120), 0, accuracy: 0.0001)
        XCTAssertEqual(BudgetSnapshot.fraction(spent: 60, available: 120), 0.5, accuracy: 0.0001)
        XCTAssertEqual(BudgetSnapshot.fraction(spent: 200, available: 120), 1.0, accuracy: 0.0001)
        XCTAssertEqual(BudgetSnapshot.fraction(spent: 30, available: 0), 0, accuracy: 0.0001)
    }
}
