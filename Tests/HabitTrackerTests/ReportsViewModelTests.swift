import XCTest
@testable import HabitTracker

@MainActor
final class ReportsViewModelTests: XCTestCase {
    private func sampleReport(range: ReportRange = .week, totalMinutes: Int = 120) -> ProgressReport {
        ProgressReport(
            range: range,
            start: Date(timeIntervalSince1970: 0),
            end: Date(timeIntervalSince1970: 86_400),
            totalMinutes: totalMinutes,
            sessionCount: 3,
            milestonesCompleted: 1,
            estimationAccuracy: 0.82,
            topHabits: [.init(habitID: UUID(), title: "Sprint", minutes: 60, sessions: 2)],
            byDay: [.init(date: "2026-05-21", minutes: 60, sessions: 2)]
        )
    }

    func testLoad_populatesReport() async {
        let svc = MockReportsService()
        await svc.setStubbedReport(sampleReport())
        let vm = ReportsViewModel(service: svc)
        await vm.load()
        XCTAssertEqual(vm.report?.totalMinutes, 120)
        XCTAssertNil(vm.lastError)
        let calls = await svc.calls
        XCTAssertEqual(calls, [.fetch(.week)])
    }

    func testSwitchRange_refetches() async {
        let svc = MockReportsService()
        await svc.setStubbedReport(sampleReport(range: .month, totalMinutes: 500))
        let vm = ReportsViewModel(service: svc)
        await vm.switchRange(.month)
        XCTAssertEqual(vm.range, .month)
        XCTAssertEqual(vm.report?.totalMinutes, 500)
    }

    func testNetworkError_surfacesMessage() async {
        let svc = MockReportsService()
        await svc.setError(.network("offline"))
        let vm = ReportsViewModel(service: svc)
        await vm.load()
        XCTAssertNil(vm.report)
        XCTAssertEqual(vm.lastError, "Network error: offline")
    }

    func testProgressReportCodable_decodesEdgeFunctionShape() throws {
        let json = """
        {
            "range": "week",
            "start": "2026-05-14T00:00:00Z",
            "end":   "2026-05-21T00:00:00Z",
            "total_minutes": 320,
            "session_count": 12,
            "milestones_completed": 1,
            "estimation_accuracy": 0.85,
            "top_habits": [
                {"habit_id": "00000000-0000-0000-0000-000000000001", "title": "Sprint", "minutes": 80, "sessions": 4}
            ],
            "by_day": [
                {"date": "2026-05-14", "minutes": 45, "sessions": 2}
            ]
        }
        """.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let report = try decoder.decode(ProgressReport.self, from: json)
        XCTAssertEqual(report.totalMinutes, 320)
        XCTAssertEqual(report.topHabits.first?.title, "Sprint")
        XCTAssertEqual(report.estimationAccuracy, 0.85)
        XCTAssertEqual(report.byDay.first?.date, "2026-05-14")
    }
}

extension MockReportsService {
    func setError(_ error: ReportsError) { errorOnNextFetch = error }
}
