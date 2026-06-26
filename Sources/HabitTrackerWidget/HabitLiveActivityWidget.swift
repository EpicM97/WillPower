import ActivityKit
import SwiftUI
import WidgetKit

struct HabitLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: HabitActivityAttributes.self) { context in
            LockScreenView(context: context)
                .activityBackgroundTint(Color.black.opacity(0.85))
                .activitySystemActionForegroundColor(.white)
                .widgetURL(DeepLink.habit(context.attributes.habitID).url)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    energyDot(for: context.state.energy)
                        .opacity(context.isStale ? 0.4 : 1.0)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 2) {
                        Text(context.attributes.title)
                            .font(.headline)
                            .lineLimit(1)
                        if context.state.isPaused {
                            Text("Paused")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        } else if context.isStale {
                            Text("Tap to resume")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    elapsedText(state: context.state, isStale: context.isStale)
                        .font(.system(.title3, design: .monospaced))
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if context.state.isPaused {
                        ProgressView(value: pausedProgress(state: context.state))
                            .progressViewStyle(.linear)
                            .tint(.secondary)
                    } else {
                        ProgressView(
                            timerInterval: progressInterval(
                                startedAt: context.state.startedAt,
                                estimatedMinutes: context.state.estimatedMinutes
                            ),
                            countsDown: false
                        )
                        .progressViewStyle(.linear)
                        .opacity(context.isStale ? 0.5 : 1.0)
                    }
                }
            } compactLeading: {
                energyDot(for: context.state.energy)
            } compactTrailing: {
                elapsedText(state: context.state, isStale: context.isStale)
                    .monospacedDigit()
            } minimal: {
                energyDot(for: context.state.energy)
                    .opacity(context.isStale ? 0.4 : 1.0)
            }
            .widgetURL(DeepLink.habit(context.attributes.habitID).url)
        }
    }

    private func energyDot(for energy: EnergyLevel) -> some View {
        Circle()
            .fill(color(for: energy))
            .frame(width: 12, height: 12)
    }

    private func color(for energy: EnergyLevel) -> Color {
        switch energy {
        case .high: .red
        case .mid: .orange
        case .low: .blue
        }
    }

    private func elapsedText(state: HabitActivityAttributes.ContentState, isStale: Bool) -> Text {
        if let pausedAt = state.pausedAt {
            return Text(frozenElapsed(from: state.startedAt, to: pausedAt))
        }
        if isStale {
            return Text("--:--")
        }
        return Text(state.startedAt, style: .timer)
    }

    private func progressInterval(startedAt: Date, estimatedMinutes: Int) -> ClosedRange<Date> {
        let end = startedAt.addingTimeInterval(TimeInterval(max(1, estimatedMinutes) * 60))
        return startedAt...end
    }

    private func pausedProgress(state: HabitActivityAttributes.ContentState) -> Double {
        guard let pausedAt = state.pausedAt else { return 0 }
        let elapsed = pausedAt.timeIntervalSince(state.startedAt)
        let budget = TimeInterval(max(1, state.estimatedMinutes) * 60)
        return min(max(0, elapsed / budget), 1)
    }
}

/// Formats a frozen elapsed span as M:SS for the paused presentation.
func frozenElapsed(from startedAt: Date, to pausedAt: Date) -> String {
    let secs = max(0, Int(pausedAt.timeIntervalSince(startedAt)))
    return String(format: "%d:%02d", secs / 60, secs % 60)
}

private struct LockScreenView: View {
    let context: ActivityViewContext<HabitActivityAttributes>

    var body: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(color(for: context.state.energy))
                .frame(width: 14, height: 14)
                .opacity(context.isStale ? 0.4 : 1.0)
            VStack(alignment: .leading, spacing: 4) {
                Text(context.attributes.title)
                    .font(.headline)
                    .lineLimit(1)
                if context.state.isPaused {
                    Text("Paused")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if context.isStale {
                    Text("Tap to resume")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Estimated \(context.state.estimatedMinutes) min")
                        .font(.caption)
                        .opacity(0.7)
                }
            }
            Spacer()
            if let pausedAt = context.state.pausedAt {
                HStack(spacing: 6) {
                    Image(systemName: "pause.fill").font(.caption)
                    Text(frozenElapsed(from: context.state.startedAt, to: pausedAt))
                        .font(.system(.title2, design: .monospaced))
                }
                .foregroundStyle(.secondary)
            } else if context.isStale {
                Image(systemName: "exclamationmark.arrow.circlepath")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            } else {
                Text(context.state.startedAt, style: .timer)
                    .font(.system(.title2, design: .monospaced))
            }
        }
        .padding()
    }

    private func color(for energy: EnergyLevel) -> Color {
        switch energy {
        case .high: .red
        case .mid: .orange
        case .low: .blue
        }
    }
}
