import Foundation

struct BudgetSummary: Equatable {
    let availableMinutes: Int
    let scheduledMinutes: Int

    var remainingMinutes: Int { availableMinutes - scheduledMinutes }
    var isOverBudget: Bool { scheduledMinutes > availableMinutes }

    /// Fraction of the budget consumed. 0 when no budget is set.
    var utilization: Double {
        guard availableMinutes > 0 else { return 0 }
        return Double(scheduledMinutes) / Double(availableMinutes)
    }
}

/// Pure aggregation over today's sessions. Compression engine consumes
/// `remainingMinutes` to decide what to redistribute. Excludes `.deferred`.
enum BudgetCalculator {
    static func summarize(availableMinutes: Int, sessions: [DailySession]) -> BudgetSummary {
        let active = sessions.filter { $0.status != .deferred && $0.deletedAt == nil }
        let scheduled = active.reduce(0) { $0 + max(0, $1.compressedMinutes) }
        return BudgetSummary(
            availableMinutes: max(0, availableMinutes),
            scheduledMinutes: scheduled
        )
    }
}
