import Foundation
import UserNotifications

/// Translates a `DayWindow` into scheduled daily local notifications. The pure
/// planning (what/when) lives in `DayNotificationScheduler`; this is the thin
/// OS-facing wrapper, kept out of the unit-tested logic layer.
struct DayNotificationService {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) { self.center = center }

    /// Requests alert authorization. Returns whether it was granted.
    @discardableResult
    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    }

    /// Clears any previously-scheduled day notifications, then (if the window
    /// enables them and the user grants permission) schedules the current plan
    /// as repeating daily calendar triggers. A disabled window just clears.
    func reschedule(for window: DayWindow) async {
        center.removePendingNotificationRequests(withIdentifiers: DayNotificationScheduler.allIdentifiers)
        let plan = DayNotificationScheduler.plan(for: window)
        guard !plan.isEmpty else { return }
        guard await requestAuthorization() else { return }
        for item in plan {
            var comps = DateComponents()
            comps.hour = item.minuteOfDay / 60
            comps.minute = item.minuteOfDay % 60
            let content = UNMutableNotificationContent()
            content.title = item.title
            content.body = item.body
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
            let request = UNNotificationRequest(identifier: item.identifier, content: content, trigger: trigger)
            try? await center.add(request)
        }
    }
}
