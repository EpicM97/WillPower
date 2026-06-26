import Foundation

/// Pure selector for "On this day" memories — journals from the same calendar
/// day (month + day) in an earlier year than the reference date, newest first.
/// Powers the recap surface; kept pure so it's unit-testable without a store.
enum OnThisDaySelector {
    static func onThisDay(reference: Date, journals: [Journal], calendar: Calendar = .current) -> [Journal] {
        let ref = calendar.dateComponents([.year, .month, .day], from: reference)
        return journals
            .filter { journal in
                guard journal.deletedAt == nil else { return false }
                let c = calendar.dateComponents([.year, .month, .day], from: journal.date)
                return c.month == ref.month
                    && c.day == ref.day
                    && (c.year ?? 0) < (ref.year ?? 0)
            }
            .sorted { $0.date > $1.date }
    }
}
