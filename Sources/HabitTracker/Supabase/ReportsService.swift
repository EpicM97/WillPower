import Foundation
import Supabase

enum ReportsError: Error, Equatable {
    case notSignedIn
    case network(String)
    case decoding(String)
}

protocol ReportsService: Sendable {
    func fetchReport(range: ReportRange) async throws -> ProgressReport
}

actor SupabaseReportsService: ReportsService {
    private let client: SupabaseClient

    init(config: SupabaseConfig) {
        self.client = SupabaseClient(supabaseURL: config.url, supabaseKey: config.anonKey)
    }

    func fetchReport(range: ReportRange) async throws -> ProgressReport {
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let report: ProgressReport = try await client.functions.invoke(
                "progress-report",
                options: FunctionInvokeOptions(
                    method: .get,
                    query: [URLQueryItem(name: "range", value: range.rawValue)]
                ),
                decoder: decoder
            )
            return report
        } catch {
            throw ReportsError.network(String(describing: error))
        }
    }
}
