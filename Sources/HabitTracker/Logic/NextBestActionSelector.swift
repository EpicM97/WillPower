import Foundation

/// Picks the single "next best" session to surface in the focus UI / widget.
///
/// Rules, in order:
/// 1. Skip non-pending sessions (active / completed / deferred).
/// 2. Prefer interruptions (they reflect "what's actually happening").
/// 3. Sort by habit priority desc, then `orderHint` asc.
/// 4. Return the first.
enum NextBestActionSelector {
    static func pick(from sessions: [DailySession]) -> DailySession? {
        let pending = sessions.filter { $0.status == .pending && $0.deletedAt == nil }
        if let interruption = pending.first(where: { $0.isInterruption }) {
            return interruption
        }
        return pending.sorted { lhs, rhs in
            let lp = lhs.habit?.priority ?? 1
            let rp = rhs.habit?.priority ?? 1
            if lp != rp { return lp > rp }
            return lhs.orderHint < rhs.orderHint
        }.first
    }
}
