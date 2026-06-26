import AppIntents
import Foundation
import SwiftData

/// Marks today's `DailySession` for this habit as completed (`actualMinutes`
/// = compressedMinutes). Creates a new session if one doesn't already exist
/// for today. Runs in-process inside the widget extension.
struct LogHabitIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Habit"
    static var description = IntentDescription("Marks today's session for this habit as done.")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Habit ID")
    var habitID: String

    init() {}

    init(habitID: UUID) {
        self.habitID = habitID.uuidString
    }

    func perform() async throws -> some IntentResult {
        guard let uuid = UUID(uuidString: habitID) else { return .result() }
        let container = try AppSchema.sharedContainer()
        let context = ModelContext(container)

        let descriptor = FetchDescriptor<Habit>(predicate: #Predicate { $0.id == uuid })
        guard let habit = try context.fetch(descriptor).first else { return .result() }

        let cal = Calendar.current
        let start = cal.startOfDay(for: .now)
        let end = cal.date(byAdding: .day, value: 1, to: start) ?? start
        let id = habit.id
        let existing = try context.fetch(FetchDescriptor<DailySession>(
            predicate: #Predicate {
                $0.habit?.id == id &&
                $0.date >= start && $0.date < end &&
                $0.deletedAt == nil
            }
        )).first

        let session = existing ?? {
            let s = DailySession(
                date: start,
                baseMinutes: habit.estimatedMinutes,
                orderHint: habit.order,
                habit: habit
            )
            context.insert(s)
            return s
        }()

        session.actualMinutes = session.actualMinutes ?? session.compressedMinutes
        session.status = .completed
        session.completedAt = .now
        session.updatedAt = .now
        try context.save()
        return .result()
    }
}
