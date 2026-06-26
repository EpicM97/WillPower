import Foundation

final actor MockSyncService: SyncService {
    enum Call: Equatable {
        case pull(Date?)
        case push(SyncDTO.Snapshot)
    }

    private(set) var calls: [Call] = []
    var stubbedRemote: SyncDTO.Snapshot = SyncDTO.Snapshot()
    var errorOnNextPull: SyncError?
    var errorOnNextPush: SyncError?

    func pullChanges(since cursor: Date?) async throws -> SyncDTO.Snapshot {
        calls.append(.pull(cursor))
        if let err = errorOnNextPull { errorOnNextPull = nil; throw err }
        if let cursor {
            return SyncDTO.Snapshot(
                habits: stubbedRemote.habits.filter { $0.updatedAt > cursor },
                sessions: stubbedRemote.sessions.filter { $0.updatedAt > cursor },
                journals: stubbedRemote.journals.filter { $0.updatedAt > cursor }
            )
        }
        return stubbedRemote
    }

    func pushChanges(_ snapshot: SyncDTO.Snapshot) async throws {
        calls.append(.push(snapshot))
        if let err = errorOnNextPush { errorOnNextPush = nil; throw err }
    }

    func setStubbedRemote(_ snapshot: SyncDTO.Snapshot) {
        stubbedRemote = snapshot
    }
}
