import Foundation

@Observable @MainActor
final class ReportsViewModel {
    var range: ReportRange = .week
    private(set) var report: ProgressReport?
    private(set) var loading: Bool = false
    private(set) var lastError: String?

    private let service: any ReportsService

    init(service: any ReportsService) {
        self.service = service
    }

    func load() async {
        guard !loading else { return }
        loading = true
        defer { loading = false }
        lastError = nil
        do {
            report = try await service.fetchReport(range: range)
        } catch {
            lastError = describe(error)
        }
    }

    func switchRange(_ newRange: ReportRange) async {
        range = newRange
        await load()
    }

    private func describe(_ error: Error) -> String {
        switch error {
        case ReportsError.network(let msg): "Network error: \(msg)"
        case ReportsError.decoding(let msg): "Decoding error: \(msg)"
        case ReportsError.notSignedIn: "You must be signed in."
        default: String(describing: error)
        }
    }
}
