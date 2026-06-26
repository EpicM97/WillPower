import Foundation

enum HabitSorter {
    /// Reorders habits so those matching `targetEnergy` come first, then by
    /// distance from that energy level. Ties break by shorter duration —
    /// shorter quick-wins surface above heavy lifts at the same energy.
    static func sort(habits: [Habit], byMatch targetEnergy: EnergyLevel) -> [Habit] {
        habits.sorted { lhs, rhs in
            let lDist = abs(lhs.energy.rawValue - targetEnergy.rawValue)
            let rDist = abs(rhs.energy.rawValue - targetEnergy.rawValue)
            if lDist != rDist { return lDist < rDist }
            return lhs.estimatedMinutes < rhs.estimatedMinutes
        }
    }

    /// Returns only habits whose energy exactly matches `targetEnergy`,
    /// preserving input order.
    static func filter(habits: [Habit], matching targetEnergy: EnergyLevel) -> [Habit] {
        habits.filter { $0.energy == targetEnergy }
    }
}
