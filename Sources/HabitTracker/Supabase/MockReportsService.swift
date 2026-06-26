import Foundation

final actor MockReportsService: ReportsService {
    enum Call: Equatable { case fetch(ReportRange) }
    private(set) var calls: [Call] = []
    var errorOnNextFetch: ReportsError?
    var stubbedReport: ProgressReport?

    func fetchReport(range: ReportRange) async throws -> ProgressReport {
        calls.append(.fetch(range))
        if let err = errorOnNextFetch { errorOnNextFetch = nil; throw err }
        return stubbedReport ?? ProgressReport(
            range: range,
            start: .now.addingTimeInterval(-7 * 86_400),
            end: .now,
            totalMinutes: 0,
            sessionCount: 0,
            milestonesCompleted: 0,
            estimationAccuracy: nil,
            topHabits: [],
            byDay: []
        )
    }

    func setStubbedReport(_ report: ProgressReport) { stubbedReport = report }
}
