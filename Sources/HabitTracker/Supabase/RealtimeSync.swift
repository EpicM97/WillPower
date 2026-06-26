import Foundation
import Supabase

/// Wraps a Supabase Realtime channel listening to row-level changes on the
/// five user-scoped tables and fires `onChange` for each event.
/// Higher layers (e.g. AccountView) typically debounce that callback into a
/// single `SyncCoordinator.syncNow()` call.
actor RealtimeSync {
    private let client: SupabaseClient
    private var channel: RealtimeChannelV2?
    private var onChange: (@Sendable () -> Void)?

    init(config: SupabaseConfig) {
        self.client = SupabaseClient(supabaseURL: config.url, supabaseKey: config.anonKey)
    }

    func start(onChange: @escaping @Sendable () -> Void) async {
        guard channel == nil else { return }
        self.onChange = onChange
        let channel = client.realtimeV2.channel("willpower-sync")
        self.channel = channel
        let tables = ["habits", "daily_sessions", "journals"]
        for table in tables {
            let stream = channel.postgresChange(AnyAction.self, schema: "public", table: table)
            Task { [weak self] in
                for await _ in stream { await self?.fire() }
            }
        }
        await channel.subscribe()
    }

    func stop() async {
        if let channel { await channel.unsubscribe() }
        channel = nil
        onChange = nil
    }

    private func fire() {
        onChange?()
    }
}
