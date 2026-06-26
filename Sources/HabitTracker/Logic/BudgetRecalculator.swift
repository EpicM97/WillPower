import Foundation

/// Elastic Compression (see `docs/specs/elastic_compression.md`). Pure — mutates
/// the passed sessions in place; caller persists via repository.
///
/// Habits are streak items (did / didn't), never tasks, so they are **never
/// deferred**. When the day is over-scheduled the engine only shrinks each
/// pending habit toward its floor and lets the day run over budget.
enum BudgetRecalculator {
    static func recompute(sessions: [DailySession], availableMinutes: Int) {
        let live = sessions.filter { $0.deletedAt == nil }

        // Minutes already spoken for: completed (actual), active (compressed as
        // best estimate — we don't track running elapsed here), and interruptions
        // (compressed = caller-specified expected).
        let consumed = live.reduce(0) { sum, s in
            switch s.status {
            case .completed: return sum + (s.actualMinutes ?? 0)
            case .active:    return sum + s.compressedMinutes
            default:
                return sum + (s.isInterruption ? s.compressedMinutes : 0)
            }
        }
        let remaining = max(0, availableMinutes - consumed)

        let pending = live.filter { $0.status == .pending && !$0.isInterruption }
        guard !pending.isEmpty else { return }

        // Only `.duration` habits are compressible. Moment (~0) and anchored
        // (fixed block) habits keep their base and *reserve* their minutes,
        // shrinking the pool the duration habits compress into.
        let reserved = pending.filter { $0.kind != .duration }
        for s in reserved {
            s.compressedMinutes = s.baseMinutes
            s.updatedAt = .now
        }
        let reservedMinutes = reserved.reduce(0) { $0 + $1.baseMinutes }

        let duration = pending.filter { $0.kind == .duration }
        guard !duration.isEmpty else { return }

        let pool = max(0, remaining - reservedMinutes)
        let targetTotal = duration.reduce(0) { $0 + $1.baseMinutes }
        if targetTotal == 0 { return }

        if pool >= targetTotal {
            for s in duration {
                s.compressedMinutes = s.baseMinutes
                s.updatedAt = .now
            }
            return
        }

        // Distribute the pool proportional to base, clamped to floor. When the
        // pool is tiny everyone simply lands on their floor (over budget).
        let scale = Double(pool) / Double(targetTotal)
        for s in duration {
            let proposed = Int((Double(s.baseMinutes) * scale).rounded())
            s.compressedMinutes = max(floor(for: s.baseMinutes), proposed)
            s.updatedAt = .now
        }
    }

    private static func floor(for base: Int) -> Int {
        max(5, Int(ceil(Double(base) * 0.30)))
    }
}
