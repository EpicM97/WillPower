import Foundation

/// Pure scorer per `docs/specs/discipline_score.md`.
/// Surfaced in Profile + Evening Ritual.
enum DisciplineScorer {
    static let streakThreshold: Double = 0.6

    /// Per-session score on [0, 1]. `.deferred` returns nil — those are
    /// excluded from aggregation.
    static func score(for session: DailySession, atEndOfDay: Bool = false) -> Double? {
        if session.deletedAt != nil { return nil }
        if session.isInterruption { return nil }
        if session.status == .deferred { return nil }

        switch session.status {
        case .completed:
            let actual = session.actualMinutes ?? 0
            let target = max(1, session.compressedMinutes)
            if actual >= target { return 1.0 }
            if actual >= Int(Double(target) * 0.7) { return 0.7 }
            if actual > 0 { return 0.5 }
            return 0.0
        case .active:
            return atEndOfDay ? 0.5 : nil
        case .pending:
            return atEndOfDay ? 0.0 : nil
        case .deferred:
            return nil
        }
    }

    /// Energy-weighted day aggregate. Returns nil when there's nothing to
    /// score (which counts as a "grace day" for streak purposes).
    static func dayScore(sessions: [DailySession], atEndOfDay: Bool = true) -> Double? {
        var weightedSum = 0.0
        var totalWeight = 0.0
        for s in sessions {
            guard let value = score(for: s, atEndOfDay: atEndOfDay) else { continue }
            let weight = Double(s.habit?.energy.rawValue ?? 1) + 1.0  // 1, 2, 3
            weightedSum += value * weight
            totalWeight += weight
        }
        guard totalWeight > 0 else { return nil }
        return weightedSum / totalWeight
    }

    /// Streak = consecutive days with `score >= threshold` ending today (or
    /// yesterday). Days with `nil` score (no scoreable sessions) are
    /// transparent — they neither extend nor break the streak.
    static func streakDays(
        sessions: [DailySession],
        today: Date = .now,
        calendar: Calendar = .current
    ) -> Int {
        let byDay = Dictionary(grouping: sessions.filter { $0.deletedAt == nil }) {
            calendar.startOfDay(for: $0.date)
        }
        var scoresByDay: [Date: Double?] = [:]
        for (day, list) in byDay {
            scoresByDay[day] = dayScore(sessions: list)
        }

        var cursor = calendar.startOfDay(for: today)
        // If today has no score yet, start from yesterday (grace day).
        if scoresByDay[cursor] == nil || (scoresByDay[cursor] ?? nil) == nil {
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor) ?? cursor
        }

        var streak = 0
        while true {
            let score = scoresByDay[cursor] ?? nil
            if score == nil {
                // Grace day — skip without breaking, but don't count it.
                guard let prev = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
                // Stop walking back forever — bail after a long stretch of empty days.
                if streak == 0 && cursor < calendar.date(byAdding: .day, value: -7, to: today)! { break }
                cursor = prev
                continue
            }
            if let s = score, s >= streakThreshold {
                streak += 1
                guard let prev = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
                cursor = prev
            } else {
                break
            }
        }
        return streak
    }
}
