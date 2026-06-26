import AppIntents
import SwiftData
import SwiftUI
import WidgetKit

struct NextBestActionEntry: TimelineEntry {
    let date: Date
    let habitID: UUID?
    let title: String
    let estimatedMinutes: Int
    let energy: EnergyLevel
}

struct NextBestActionProvider: TimelineProvider {
    func placeholder(in context: Context) -> NextBestActionEntry {
        NextBestActionEntry(
            date: .now,
            habitID: nil,
            title: "Your next habit",
            estimatedMinutes: 25,
            energy: .mid
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (NextBestActionEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NextBestActionEntry>) -> Void) {
        let entry = loadEntry()
        // Refresh every 15 min so "logged today" status stays fresh.
        let next = Calendar.current.date(byAdding: .minute, value: 15, to: .now) ?? .now.addingTimeInterval(900)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func loadEntry() -> NextBestActionEntry {
        do {
            let container = try AppSchema.sharedContainer()
            let context = ModelContext(container)
            let cal = Calendar.current
            let start = cal.startOfDay(for: .now)
            let end = cal.date(byAdding: .day, value: 1, to: start) ?? start
            let sessions = try context.fetch(FetchDescriptor<DailySession>(
                predicate: #Predicate {
                    $0.date >= start && $0.date < end && $0.deletedAt == nil
                }
            ))
            if let pick = NextBestActionSelector.pick(from: sessions) {
                return NextBestActionEntry(
                    date: .now,
                    habitID: pick.habit?.id,
                    title: pick.habit?.title ?? "Untitled",
                    estimatedMinutes: pick.compressedMinutes,
                    energy: pick.habit?.energy ?? .mid
                )
            }
        } catch {
            // Fall through to empty entry.
        }
        return NextBestActionEntry(
            date: .now,
            habitID: nil,
            title: "All done for today",
            estimatedMinutes: 0,
            energy: .mid
        )
    }
}

struct NextBestActionWidget: Widget {
    let kind: String = "NextBestActionWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NextBestActionProvider()) { entry in
            NextBestActionView(entry: entry)
        }
        .configurationDisplayName("Next Best Action")
        .description("Your next habit, one tap to log.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct NextBestActionView: View {
    let entry: NextBestActionEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Circle()
                    .fill(color(for: entry.energy))
                    .frame(width: 10, height: 10)
                Text(label(for: entry.energy))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Text(entry.title)
                .font(.headline)
                .lineLimit(2)
            if entry.estimatedMinutes > 0 {
                Text("\(entry.estimatedMinutes) min")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if let id = entry.habitID {
                Button(intent: LogHabitIntent(habitID: id)) {
                    Label("Log", systemImage: "checkmark.circle.fill")
                        .font(.subheadline.bold())
                }
                .buttonStyle(.borderedProminent)
                .tint(.accentColor)
            }
        }
        .padding(12)
        .containerBackground(.background, for: .widget)
        .widgetURL(entry.habitID.map { DeepLink.habit($0).url })
    }

    private func color(for energy: EnergyLevel) -> Color {
        switch energy {
        case .high: .red
        case .mid: .orange
        case .low: .blue
        }
    }

    private func label(for energy: EnergyLevel) -> String {
        switch energy {
        case .high: "HIGH ENERGY"
        case .mid: "MID ENERGY"
        case .low: "LOW ENERGY"
        }
    }
}
