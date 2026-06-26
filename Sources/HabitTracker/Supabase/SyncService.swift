import Foundation
import Supabase

enum SyncError: Error, Equatable {
    case notSignedIn
    case network(String)
}

/// Bidirectional sync surface. Pull returns everything updated server-side
/// since the cursor; push uploads a local snapshot. Concrete impl wraps
/// supabase-swift's `PostgrestClient`; `MockSyncService` (in tests) is purely
/// in-memory.
protocol SyncService: Sendable {
    func pullChanges(since cursor: Date?) async throws -> SyncDTO.Snapshot
    func pushChanges(_ snapshot: SyncDTO.Snapshot) async throws
}

actor SupabaseSyncService: SyncService {
    private let client: SupabaseClient

    init(config: SupabaseConfig) {
        self.client = SupabaseClient(supabaseURL: config.url, supabaseKey: config.anonKey)
    }

    func pullChanges(since cursor: Date?) async throws -> SyncDTO.Snapshot {
        do {
            let habits: [SyncDTO.Habit] = try await fetch(table: "habits", since: cursor)
            let sessions: [SyncDTO.DailySession] = try await fetch(table: "daily_sessions", since: cursor)
            let journals: [SyncDTO.Journal] = try await fetch(table: "journals", since: cursor)
            return SyncDTO.Snapshot(habits: habits, sessions: sessions, journals: journals)
        } catch {
            throw SyncError.network(String(describing: error))
        }
    }

    func pushChanges(_ snapshot: SyncDTO.Snapshot) async throws {
        do {
            if !snapshot.habits.isEmpty { try await upsert(table: "habits", rows: snapshot.habits) }
            if !snapshot.sessions.isEmpty { try await upsert(table: "daily_sessions", rows: snapshot.sessions) }
            if !snapshot.journals.isEmpty { try await upsert(table: "journals", rows: snapshot.journals) }
        } catch {
            throw SyncError.network(String(describing: error))
        }
    }

    private func fetch<T: Decodable & Sendable>(table: String, since cursor: Date?) async throws -> [T] {
        let query = client.from(table).select()
        if let cursor {
            return try await query.gt("updated_at", value: ISO8601DateFormatter().string(from: cursor)).execute().value
        }
        return try await query.execute().value
    }

    private func upsert<T: Encodable & Sendable>(table: String, rows: [T]) async throws {
        try await client.from(table).upsert(rows).execute()
    }
}
