import Foundation

/// Decides *when* to surface the evening reflection prompt — replacing the old
/// hard 20:00 screen-takeover. A nudge, never a mode: it appears on top of the
/// normal deck and is dismissible.
///
/// Two triggers:
/// 1. **Wind-down reached** — once the clock passes the user's wind-down minute,
///    surface regardless of how the day went (wins deserve reflection as much as
///    losses).
/// 2. **Early opportunistic** — everything planned is already resolved
///    (≥1 resolved, nothing left unresolved), so offer to close the day early.
///
/// Interruptions/bonus reps are excluded by the caller's counts.
enum EveningPromptPolicy {
    static func shouldSurface(
        nowMinute: Int,
        windDownMinute: Int,
        resolvedCount: Int,
        unresolvedCount: Int
    ) -> Bool {
        if nowMinute >= windDownMinute { return true }
        // Guard vacuous truth: only "all resolved" when something was actually done.
        return resolvedCount >= 1 && unresolvedCount == 0
    }
}
