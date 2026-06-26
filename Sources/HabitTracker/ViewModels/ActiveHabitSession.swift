import Foundation
import Observation

/// Tracks the currently-running habit and drives the Live Activity.
/// Apple caps Live Activities at 8 hours; sessions auto-cap there.
@Observable
@MainActor
final class ActiveHabitSession {
    static let maxDurationMinutes = 8 * 60

    private(set) var activeHabitID: UUID?
    /// The specific DailySession that's running. Distinct from `activeHabitID`
    /// because a habit can have several sessions in a day (bonus reps) and only
    /// one of them is actually counting.
    private(set) var activeSessionID: UUID?
    private(set) var startedAt: Date?
    private(set) var pausedAt: Date?
    private(set) var budgetMinutes: Int = 0
    private(set) var didFireOverrun: Bool = false
    private(set) var lastError: String?

    var isPaused: Bool { pausedAt != nil }

    private var overrunTask: Task<Void, Never>?
    private var liveState: HabitActivityAttributes.ContentState?
    private let controller: any LiveActivityController
    private let now: () -> Date

    init(controller: any LiveActivityController, now: @escaping () -> Date = Date.init) {
        self.controller = controller
        self.now = now
    }

    var isRunning: Bool { activeHabitID != nil }

    func elapsedMinutes(at reference: Date? = nil) -> Int {
        guard let startedAt else { return 0 }
        // While paused, time is frozen at pausedAt.
        let end = reference ?? pausedAt ?? now()
        let seconds = Int(end.timeIntervalSince(startedAt))
        return min(max(0, seconds / 60), Self.maxDurationMinutes)
    }

    /// `resumingFromMinutes` back-dates `startedAt` so a re-opened session
    /// continues accumulating from the minutes it already logged.
    func start(habit: Habit, sessionID: UUID? = nil, budgetMinutes: Int? = nil, resumingFromMinutes: Int = 0) async {
        guard activeHabitID == nil else {
            lastError = "Another session is already running."
            return
        }
        // The session runs against the compressed budget (when supplied), so the
        // Live Activity must show that same number — not the raw habit estimate —
        // to stay consistent with the in-app ring.
        let effectiveBudget = budgetMinutes ?? habit.estimatedMinutes
        let begin = now().addingTimeInterval(TimeInterval(-max(0, resumingFromMinutes) * 60))
        let attrs = HabitActivityAttributes(habitID: habit.id, title: habit.title)
        let state = HabitActivityAttributes.ContentState(
            startedAt: begin,
            estimatedMinutes: effectiveBudget,
            energyRaw: habit.energy.rawValue
        )
        do {
            try await controller.start(attributes: attrs, state: state)
            activeHabitID = habit.id
            activeSessionID = sessionID
            startedAt = state.startedAt
            pausedAt = nil
            liveState = state
            self.budgetMinutes = effectiveBudget
            didFireOverrun = false
            scheduleOverrun()
            lastError = nil
        } catch {
            lastError = String(describing: error)
        }
    }

    /// Freezes elapsed time without ending the session. The overrun timer is
    /// suspended and the Live Activity is updated to its paused presentation;
    /// `resume()` reschedules and un-freezes both.
    func pause() async {
        guard activeHabitID != nil, pausedAt == nil else { return }
        let at = now()
        pausedAt = at
        overrunTask?.cancel()
        overrunTask = nil
        if var state = liveState {
            state.pausedAt = at
            liveState = state
            await controller.update(state: state)
        }
    }

    /// Continues a paused session by shifting `startedAt` forward by the paused
    /// span so elapsed math (and the ring) pick up exactly where they left off.
    func resume() async {
        guard let pausedAt, let startedAt else { return }
        let pausedSpan = now().timeIntervalSince(pausedAt)
        let shifted = startedAt.addingTimeInterval(pausedSpan)
        self.startedAt = shifted
        self.pausedAt = nil
        if var state = liveState {
            state.startedAt = shifted
            state.pausedAt = nil
            liveState = state
            await controller.update(state: state)
        }
        scheduleOverrun()
    }

    func stop() async {
        guard activeHabitID != nil else { return }
        overrunTask?.cancel()
        overrunTask = nil
        await controller.end(finalState: nil)
        activeHabitID = nil
        activeSessionID = nil
        startedAt = nil
        pausedAt = nil
        liveState = nil
        budgetMinutes = 0
        didFireOverrun = false
    }

    /// Schedules the overrun haptic for the time remaining until budget is hit,
    /// computed from the current `startedAt`. Safe to call after a resume.
    private func scheduleOverrun() {
        overrunTask?.cancel()
        guard let startedAt, budgetMinutes > 0, !didFireOverrun else { return }
        let budgetSec = Double(budgetMinutes) * 60
        let remaining = budgetSec - now().timeIntervalSince(startedAt)
        overrunTask = Task { [weak self] in
            if remaining > 0 {
                try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
            }
            guard let self, !Task.isCancelled else { return }
            await MainActor.run {
                guard self.activeHabitID != nil, self.pausedAt == nil, !self.didFireOverrun else { return }
                self.didFireOverrun = true
                Haptics.warning()
            }
        }
    }
}
