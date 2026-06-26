import Foundation

/// A habit's time-shape — drives how the budget/compression engine treats it.
///
/// - `.duration`: consumes discretionary budget and is compressible (deep work,
///   workout). The only kind the compression engine squeezes.
/// - `.moment`: a ~0-minute checkbox done at a point in time (drink water,
///   vitamins). Streak-only; effectively no budget cost.
/// - `.anchored`: a fixed time block that bounds the day rather than spending
///   discretionary budget (wake at 6am, the 9-5). Subtracts from the window;
///   not compressible.
///
/// New/legacy habits default to `.duration` so existing budget math is unchanged
/// until the post-onboarding AI workflow classifies them.
enum HabitKind: Int, Codable, CaseIterable, Sendable {
    case duration = 0
    case moment = 1
    case anchored = 2
}
