import Foundation
import SwiftData

@Observable @MainActor
final class IngestionViewModel {
    var rawText: String = ""
    private(set) var loading: Bool = false
    private(set) var proposal: IngestProposal?
    private(set) var lastError: String?
    var accept: IngestApplier.AcceptedSet = .init()
    private(set) var applyResult: IngestApplier.ApplyResult?

    private let service: any TaskIngestService
    private let container: ModelContainer

    init(service: any TaskIngestService, container: ModelContainer) {
        self.service = service
        self.container = container
    }

    var hasProposal: Bool { proposal != nil }

    func parse() async {
        guard !loading, !rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        loading = true
        defer { loading = false }
        lastError = nil
        do {
            let p = try await service.parse(rawText)
            proposal = p
            accept = .all(from: p)
            if p.habits.isEmpty && p.milestones.isEmpty && p.interruptions.isEmpty {
                lastError = "Nothing parseable found. Try being more specific."
            }
        } catch let IngestError.network(msg) {
            lastError = "Couldn't reach the parser: \(msg)"
        } catch {
            lastError = String(describing: error)
        }
    }

    func toggleHabit(_ id: String) {
        if accept.habits.contains(id) { accept.habits.remove(id) } else { accept.habits.insert(id) }
    }
    func toggleMilestone(_ id: String) {
        if accept.milestones.contains(id) { accept.milestones.remove(id) } else { accept.milestones.insert(id) }
    }
    func toggleInterruption(_ id: String) {
        if accept.interruptions.contains(id) { accept.interruptions.remove(id) } else { accept.interruptions.insert(id) }
    }

    @discardableResult
    func applyAccepted() -> IngestApplier.ApplyResult? {
        guard let proposal else { return nil }
        let result = IngestApplier.apply(proposal, accept: accept, in: container.mainContext)
        applyResult = result
        return result
    }

    func reset() {
        rawText = ""
        proposal = nil
        accept = .init()
        applyResult = nil
        lastError = nil
    }
}
