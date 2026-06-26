import SwiftUI

struct SessionCardView: View {
    let session: DailySession
    /// True when this is a 2nd+ run of the same habit today (a bonus rep).
    var isExtraRun: Bool = false
    var isRunning: Bool = false
    var isPaused: Bool = false
    var runningStartedAt: Date? = nil
    var runningPausedAt: Date? = nil
    var runningBudgetMinutes: Int = 0
    var onToggleSession: (() -> Void)? = nil
    var onStop: (() -> Void)? = nil
    var onComplete: (() -> Void)? = nil
    var onResume: (() -> Void)? = nil

    private var title: String { session.habit?.title ?? (session.isInterruption ? "Interruption" : "Untitled") }
    private var energy: EnergyLevel { session.energy }

    // Completed-session classification, all relative to the session's target.
    private var target: Int { max(1, session.compressedMinutes) }
    private var logged: Int { session.actualMinutes ?? 0 }
    private var isUnderTarget: Bool { session.status == .completed && logged < target }
    private var isOverTarget: Bool { session.status == .completed && logged > target }
    /// Under-target completions can be resumed to log more time.
    private var isResumable: Bool { isUnderTarget }

    var body: some View {
        HStack(spacing: 12) {
            if isRunning, let startedAt = runningStartedAt, runningBudgetMinutes > 0 {
                runningRing(startedAt: startedAt, budget: runningBudgetMinutes)
            } else {
                leadingGlyph
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title).font(.headline)
                    if session.status == .completed {
                        if isExtraRun { pill("BONUS", color: .indigo) }
                        if let t = targetPill { pill(t.text, color: t.color) }
                    }
                }
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
                if let note = session.note, !note.isEmpty, !session.isInterruption {
                    Text(note).font(.caption2).foregroundStyle(.secondary).italic()
                }
            }
            Spacer()
            if session.status != .completed {
                if let onToggleSession { sessionButton(action: onToggleSession) }
                if isRunning, let onStop { stopButton(action: onStop) }
                if let onComplete { completeButton(action: onComplete) }
            }
            if session.status == .completed {
                if isResumable, let onResume {
                    resumeButton(action: onResume)
                } else {
                    completedCheck
                }
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(subtitle)")
    }

    /// Pill shown next to the habit name on a completed card. Over/under target
    /// only — on-target shows the green check and no pill.
    private var targetPill: (text: String, color: Color)? {
        if isOverTarget { return ("+\(logged - target) min over", .blue) }
        if isUnderTarget { return ("Under target", .orange) }
        return nil
    }

    private var subtitle: String {
        switch session.status {
        case .completed:
            session.kind == .moment ? "Done · \(energyLabel)" : "\(logged)/\(target) min · \(energyLabel)"
        default:
            if session.kind == .moment {
                "Quick check-in · \(energyLabel)"
            } else if session.compressedMinutes != session.baseMinutes {
                "\(session.compressedMinutes) min (was \(session.baseMinutes)) · \(energyLabel)"
            } else {
                "\(session.compressedMinutes) min · \(energyLabel)"
            }
        }
    }

    private var energyLabel: String {
        switch energy {
        case .high: "High energy"
        case .mid: "Mid energy"
        case .low: "Low energy"
        }
    }

    private var energyColor: Color {
        switch energy {
        case .high: .red
        case .mid: .orange
        case .low: .blue
        }
    }

    private var energyDot: some View {
        Circle().fill(energyColor).frame(width: 12, height: 12)
            .accessibilityLabel(energyLabel)
    }

    /// Leading marker: a normal habit gets its energy dot; an injected
    /// interruption gets the bolt in its place, tinted by the same energy color.
    @ViewBuilder private var leadingGlyph: some View {
        if session.isInterruption {
            Image(systemName: "bolt.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(energyColor)
                .frame(width: 12, alignment: .center)
                .accessibilityLabel("Interruption, \(energyLabel)")
        } else {
            energyDot
        }
    }

    private func runningRing(startedAt: Date, budget: Int) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { ctx in
            // When paused, freeze elapsed at the pause moment.
            let reference = runningPausedAt ?? ctx.date
            let elapsedSec = max(0, reference.timeIntervalSince(startedAt))
            let budgetSec = Double(budget) * 60
            let progress = min(elapsedSec / budgetSec, 1.0)
            let over = elapsedSec > budgetSec
            let tint: Color = isPaused ? .secondary : (over ? .red : energyColor)
            ZStack {
                ProgressRing(progress: over ? 1.0 : progress, tint: tint, lineWidth: 3, size: 32)
                Text(isPaused ? "❙❙" : remainingLabel(elapsedSec: elapsedSec, budgetSec: budgetSec))
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(tint)
                    .monospacedDigit()
            }
            .accessibilityLabel(isPaused ? "Paused" : (over ? "Over budget" : "Running"))
        }
    }

    private func remainingLabel(elapsedSec: Double, budgetSec: Double) -> String {
        let remaining = budgetSec - elapsedSec
        if remaining >= 0 {
            let m = Int(ceil(remaining / 60))
            return "\(m)m"
        } else {
            let m = Int(ceil(-remaining / 60))
            return "+\(m)"
        }
    }

    private func sessionButton(action: @escaping () -> Void) -> some View {
        // Not active → play. Active & running → pause. Active & paused → resume (play).
        let showPause = isRunning && !isPaused
        return Button(action: action) {
            Image(systemName: showPause ? "pause.circle.fill" : "play.circle")
                .imageScale(.large)
                .foregroundStyle(showPause ? .orange : .accentColor)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(showPause ? "Pause session" : (isPaused ? "Resume session" : "Start session"))
    }

    /// One badge style for every name-row pill (BONUS / over / under target) so
    /// they read as a single uniform family — same case, weight, height and shape.
    private func pill(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .heavy, design: .rounded))
            .textCase(.uppercase)
            .kerning(0.4)
            .lineLimit(1)
            .padding(.horizontal, 7)
            .frame(height: 18)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
            .accessibilityLabel(text)
    }

    private var completedCheck: some View {
        Image(systemName: "checkmark.circle.fill")
            .imageScale(.large)
            .foregroundStyle(.green)
            .accessibilityLabel("Completed")
    }

    private func resumeButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "play.circle")
                .imageScale(.large)
                .foregroundStyle(Color.accentColor)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Resume session")
    }

    private func stopButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "stop.circle.fill")
                .imageScale(.large)
                .foregroundStyle(.red)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Stop without logging")
    }

    private func completeButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "circle")
                .imageScale(.large)
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Mark complete")
    }
}
