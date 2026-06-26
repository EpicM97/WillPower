import XCTest
import SwiftData
@testable import HabitTracker

@MainActor
final class JournalArchiverTests: XCTestCase {
    private func makeContainer() throws -> ModelContainer { try AppSchema.inMemoryContainer() }

    func testArchive_createsJournalFromTodaySessions() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let today = Calendar.current.startOfDay(for: .now)

        let h = Habit(title: "h", energy: .high, estimatedMinutes: 30)
        context.insert(h)
        let done = DailySession(date: today, baseMinutes: 30, actualMinutes: 30, status: .completed, habit: h)
        let bumped = DailySession(date: today, baseMinutes: 30, status: .deferred, habit: h)
        let interruption = DailySession(date: today, baseMinutes: 15, status: .completed, isInterruption: true)
        context.insert(done); context.insert(bumped); context.insert(interruption)
        try context.save()

        let journal = JournalArchiver.archive(in: context)
        let unwrapped = try XCTUnwrap(journal)
        XCTAssertEqual(unwrapped.completedCount, 1) // interruption excluded
        XCTAssertEqual(unwrapped.deferredCount, 1)
        XCTAssertEqual(unwrapped.interruptionCount, 1)
        XCTAssertEqual(unwrapped.disciplineScore, 1.0, accuracy: 0.001) // single completed high-energy hit
    }

    func testArchive_idempotentForSameDay() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let today = Calendar.current.startOfDay(for: .now)
        let h = Habit(title: "h", estimatedMinutes: 30); context.insert(h)
        context.insert(DailySession(date: today, baseMinutes: 30, actualMinutes: 30, status: .completed, habit: h))
        try context.save()

        _ = JournalArchiver.archive(in: context)
        _ = JournalArchiver.archive(in: context)
        let journals = try context.fetch(FetchDescriptor<Journal>())
        XCTAssertEqual(journals.count, 1)
    }

    func testArchive_returnsNilWhenNoSessions() throws {
        let container = try makeContainer()
        XCTAssertNil(JournalArchiver.archive(in: container.mainContext))
    }
}
