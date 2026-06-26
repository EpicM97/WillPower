import Foundation
import Supabase

struct IngestProposal: Codable, Equatable, Sendable {
    var habits: [ProposedHabit]
    var milestones: [ProposedMilestone]
    var interruptions: [ProposedInterruption]
    var rawInput: String
    var modelNote: String?

    struct ProposedHabit: Codable, Equatable, Sendable, Identifiable {
        var title: String
        var energy: EnergyLevel
        var estimatedMinutes: Int
        var projectHint: String?
        var id: String { "h:\(title):\(estimatedMinutes)" }

        enum CodingKeys: String, CodingKey {
            case title, energy
            case estimatedMinutes = "estimated_minutes"
            case projectHint = "project_hint"
        }
    }

    struct ProposedMilestone: Codable, Equatable, Sendable, Identifiable {
        var title: String
        var projectHint: String?
        var id: String { "m:\(title)" }

        enum CodingKeys: String, CodingKey {
            case title
            case projectHint = "project_hint"
        }
    }

    struct ProposedInterruption: Codable, Equatable, Sendable, Identifiable {
        var title: String
        var expectedMinutes: Int
        var id: String { "i:\(title):\(expectedMinutes)" }

        enum CodingKeys: String, CodingKey {
            case title
            case expectedMinutes = "expected_minutes"
        }
    }

    enum CodingKeys: String, CodingKey {
        case habits, milestones, interruptions
        case rawInput = "raw_input"
        case modelNote = "model_note"
    }
}

enum IngestError: Error, Equatable {
    case missingConfig
    case network(String)
    case decoding(String)
}

protocol TaskIngestService: Sendable {
    func parse(_ text: String) async throws -> IngestProposal
}

actor SupabaseTaskIngestService: TaskIngestService {
    private let client: SupabaseClient

    init(config: SupabaseConfig) {
        self.client = SupabaseClient(supabaseURL: config.url, supabaseKey: config.anonKey)
    }

    func parse(_ text: String) async throws -> IngestProposal {
        do {
            let decoder = JSONDecoder()
            let body: [String: String] = ["text": text]
            let proposal: IngestProposal = try await client.functions.invoke(
                "task-ingest",
                options: FunctionInvokeOptions(body: body),
                decoder: decoder
            )
            return proposal
        } catch {
            throw IngestError.network(String(describing: error))
        }
    }
}

/// Test mock; used by `IngestionViewModel` when no Supabase config or for previews.
final actor MockTaskIngestService: TaskIngestService {
    var stubbedProposal: IngestProposal?
    var errorOnNextCall: IngestError?

    func parse(_ text: String) async throws -> IngestProposal {
        if let err = errorOnNextCall { errorOnNextCall = nil; throw err }
        return stubbedProposal ?? IngestProposal(
            habits: [.init(title: "Demo run", energy: .high, estimatedMinutes: 30, projectHint: nil)],
            milestones: [], interruptions: [], rawInput: text, modelNote: nil
        )
    }
    func setStub(_ p: IngestProposal) { stubbedProposal = p }
}
