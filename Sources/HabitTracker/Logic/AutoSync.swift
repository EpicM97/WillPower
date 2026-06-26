import Foundation
import SwiftData

/// Fire-and-forget cloud sync for *automatic* triggers (app foreground, midnight
/// refresh) — distinct from the manual "Sync now" button. No-ops cleanly when
/// Supabase isn't configured, and swallows errors (a failed background sync
/// should never surface UI; the next trigger retries).
enum AutoSync {
    @MainActor
    static func run(container: ModelContainer) async {
        guard let config = try? SupabaseConfig.fromBundle() else { return }
        let service = SupabaseSyncService(config: config)
        let coordinator = SyncCoordinator(container: container, service: service)
        _ = try? await coordinator.syncNow()
    }
}
