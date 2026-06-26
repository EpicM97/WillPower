import Foundation
import Observation

@Observable
@MainActor
final class DailyDeckViewModel {
    private(set) var sessions: [DailySession] = []
    private(set) var loadError: String?
    var availableMinutes: Int = 120

    private let repository: any DataRepository

    init(repository: any DataRepository) {
        self.repository = repository
    }

    /// "Going on": the at-most-one session currently in progress (status active).
    var goingOnSessions: [DailySession] { sessions.filter { $0.status == .active } }
    /// "Up next": not-yet-started sessions.
    var upNextSessions: [DailySession] { sessions.filter { $0.status == .pending } }
    /// Back-compat alias used by tests + reordering.
    var pendingSessions: [DailySession] { upNextSessions }
    var completedSessions: [DailySession] { sessions.filter { $0.status == .completed } }

    /// IDs of sessions that are a 2nd+ run of the same habit today — i.e. bonus
    /// reps created via "Repeat" after the habit was already done. The earliest
    /// run for a habit is the "primary"; every later one is flagged extra so the
    /// Completed list can badge it as a bonus the user notices.
    var extraRunSessionIDs: Set<UUID> {
        let ordered = sessions
            .filter { $0.habit != nil && $0.deletedAt == nil }
            .sorted { lhs, rhs in
                let l = lhs.completedAt ?? lhs.startedAt ?? lhs.createdAt
                let r = rhs.completedAt ?? rhs.startedAt ?? rhs.createdAt
                return l < r
            }
        var seenHabits = Set<UUID>()
        var extras = Set<UUID>()
        for s in ordered {
            guard let hid = s.habit?.id else { continue }
            if seenHabits.contains(hid) { extras.insert(s.id) } else { seenHabits.insert(hid) }
        }
        return extras
    }

    /// Minutes actually invested so far today: the sum of logged minutes across
    /// completed sessions. The live elapsed of the running session is added in
    /// the view (it lives in `ActiveHabitSession`). This number only grows.
    var spentMinutes: Int {
        sessions
            .filter { $0.status == .completed && $0.deletedAt == nil }
            .reduce(0) { $0 + ($1.actualMinutes ?? 0) }
    }

    /// Minutes still planned but not started (compressed estimate of pending).
    var plannedMinutes: Int {
        upNextSessions.reduce(0) { $0 + $1.compressedMinutes }
    }

    var budget: BudgetSnapshot {
        BudgetSnapshot(
            availableMinutes: availableMinutes,
            spentMinutes: spentMinutes,
            plannedMinutes: plannedMinutes
        )
    }

    func load(day: Date = .now) async {
        do {
            sessions = try await repository.fetchSessions(on: day)
            syncPendingEstimates()
            recompress()
            loadError = nil
        } catch {
            loadError = String(describing: error)
        }
    }

    /// Pending sessions mirror their habit's current estimate, so editing a
    /// habit's duration (or changing it post-creation) is reflected in Up next
    /// on the next load. Active/completed sessions keep their captured minutes.
    private func syncPendingEstimates() {
        for s in sessions where s.status == .pending && !s.isInterruption {
            guard let estimate = s.habit?.estimatedMinutes, s.baseMinutes != estimate else { continue }
            s.baseMinutes = estimate
            s.compressedMinutes = estimate
            s.updatedAt = .now
        }
    }

    /// Runs the compression engine against current sessions + budget and
    /// persists the resulting `compressedMinutes` / `status` changes.
    private func recompress() {
        BudgetRecalculator.recompute(sessions: sessions, availableMinutes: availableMinutes)
        Task { try? await repository.save() }
    }

    func injectInterruption(title: String, energy: EnergyLevel = .mid, expectedMinutes: Int) async {
        let s = DailySession(
            baseMinutes: expectedMinutes,
            compressedMinutes: expectedMinutes,
            isInterruption: true,
            energy: energy,
            orderHint: -1,
            note: title.trimmingCharacters(in: .whitespaces).isEmpty ? nil : title
        )
        try? await repository.add(session: s)
        await load()
    }

    var todayDisciplineScore: Double? {
        DisciplineScorer.dayScore(sessions: sessions, atEndOfDay: false)
    }

    func move(from source: IndexSet, to destination: Int) async {
        var pending = pendingSessions
        pending.move(fromOffsets: source, toOffset: destination)
        for (index, session) in pending.enumerated() {
            session.orderHint = index
            session.updatedAt = .now
        }
        try? await repository.save()
        await load()
    }

    func complete(_ session: DailySession, actualMinutes: Int, stoppedEarly: Bool = false, at date: Date = .now) async {
        session.actualMinutes = actualMinutes
        session.status = .completed
        session.stoppedEarly = stoppedEarly
        session.completedAt = date
        session.updatedAt = .now
        try? await repository.save()
        await load() // triggers recompress with updated remaining budget
    }

    /// Completes an Up-next habit the user confirms they actually did, logging
    /// its planned (compressed) minutes into spent budget. No timer ran, so the
    /// estimate is what counts — and it's a full completion, not stopped-early.
    func completeAsPlanned(_ session: DailySession, at date: Date = .now) async {
        await complete(session, actualMinutes: session.compressedMinutes, at: date)
    }

    /// Confirmed switch-while-running: log the running habit as a stopped-early
    /// completion (it was actually done — never lose the time) and promote the
    /// chosen session to "going on". `loggedMinutes` is floored at 1.
    func switchActive(from running: DailySession, loggedMinutes: Int, to next: DailySession, at date: Date = .now) async {
        await complete(running, actualMinutes: max(1, loggedMinutes), stoppedEarly: true, at: date)
        await markActive(next, at: date)
    }

    /// Marks a session as the one "going on". Enforces one-at-a-time: any other
    /// active session is demoted back to the Up next queue.
    func markActive(_ session: DailySession, at date: Date = .now) async {
        for other in sessions where other.status == .active && other.id != session.id {
            other.status = .pending
            other.startedAt = nil
            other.updatedAt = date
        }
        session.status = .active
        session.startedAt = date
        session.updatedAt = date
        try? await repository.save()
        await load()
    }

    /// Re-opens a completed session so more time can be logged against it.
    /// `active` puts it straight into "Going on" (demoting any other), otherwise
    /// it returns to the Up next queue. `actualMinutes` is preserved as the
    /// already-logged offset to continue from.
    func reopen(_ session: DailySession, active: Bool, at date: Date = .now) async {
        session.stoppedEarly = false
        session.completedAt = nil
        if active {
            for other in sessions where other.status == .active && other.id != session.id {
                other.status = .pending
                other.startedAt = nil
                other.updatedAt = date
            }
            session.status = .active
            session.startedAt = date
        } else {
            session.status = .pending
            session.startedAt = nil
        }
        session.updatedAt = date
        try? await repository.save()
        await load()
    }

    /// Clones a fresh run of the same habit for today (a second session). Used by
    /// the "Repeat" action on a habit that already hit its target. Returns the
    /// new session (post-reload) so the caller can start it if nothing is running.
    @discardableResult
    func repeatHabit(_ session: DailySession, at date: Date = .now) async -> DailySession? {
        guard let habit = session.habit else { return nil }
        let newID = UUID()
        let clone = DailySession(
            id: newID,
            date: Calendar.current.startOfDay(for: date),
            baseMinutes: habit.estimatedMinutes,
            orderHint: (upNextSessions.map { $0.orderHint }.max() ?? 0) + 1,
            habit: habit
        )
        try? await repository.add(session: clone)
        await load()
        return sessions.first { $0.id == newID }
    }

    func delete(_ session: DailySession) async {
        try? await repository.delete(session)
        await load()
    }
}

struct BudgetSnapshot: Equatable {
    let availableMinutes: Int
    let spentMinutes: Int
    let plannedMinutes: Int

    /// Over budget once actual time invested exceeds the available window.
    var isOverBudget: Bool { spentMinutes > availableMinutes }
    var utilization: Double {
        availableMinutes > 0 ? Double(spentMinutes) / Double(availableMinutes) : 0
    }

    /// Progress-bar fill fraction for a given spent/available pair, clamped to
    /// [0, 1]. Standalone so the budget card can fold in live running minutes
    /// (which aren't in the snapshot) and still get a safe, bounded value.
    static func fraction(spent: Int, available: Int) -> Double {
        guard available > 0 else { return 0 }
        return min(Double(spent) / Double(available), 1.0)
    }
}
