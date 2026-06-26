import BackgroundTasks
import Foundation
import SwiftData

/// BGTaskScheduler glue for Phase 16's "midnight hard reset".
/// iOS doesn't guarantee exact timing — it fires when the system decides the
/// device is idle near our `earliestBeginDate`. Empirically it tends to land
/// in the early-AM hours, which is the intent.
enum MidnightRollover {
    static let identifier = "com.willpower.HabitTracker.midnightRollover"

    /// Submit (or re-submit) the next scheduled run for tomorrow's start-of-day.
    static func scheduleNext(calendar: Calendar = .current, now: Date = .now) {
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now
        let nextMidnight = calendar.startOfDay(for: tomorrow)
        request.earliestBeginDate = nextMidnight
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            // Common in sim (BGTaskScheduler is sketchy there). Real devices succeed.
            #if DEBUG
            print("BGTaskScheduler submit failed: \(error)")
            #endif
        }
    }

    /// Called from the `.backgroundTask(.appRefresh)` handler in
    /// `HabitTrackerApp`. Must complete fast; we just run the archiver +
    /// generator then reschedule.
    @MainActor
    static func handle(container: ModelContainer) {
        JournalArchiver.rollover(in: container.mainContext)
        scheduleNext()
    }
}
