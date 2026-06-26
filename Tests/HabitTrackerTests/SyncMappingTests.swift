import XCTest
@testable import HabitTracker

@MainActor
final class SyncMappingTests: XCTestCase {
    func testHabitRoundTrip() {
        let habit = Habit(title: "Sprint", energy: .high, estimatedMinutes: 20, order: 1)
        let dto = SyncMapping.dto(from: habit)
        XCTAssertEqual(dto.id, habit.id)
        XCTAssertEqual(dto.title, "Sprint")
        XCTAssertEqual(dto.energyRaw, 2)
        XCTAssertEqual(dto.estimatedMinutes, 20)
        XCTAssertEqual(dto.order, 1)
    }

    func testHabit_defaultKindIsDuration() {
        XCTAssertEqual(Habit(title: "x").kind, .duration)
    }

    func testHabitKindRoundTrips() {
        let habit = Habit(title: "Vitamins", energy: .low, estimatedMinutes: 1, kind: .moment)
        let dto = SyncMapping.dto(from: habit)
        XCTAssertEqual(dto.kindRaw, HabitKind.moment.rawValue)
    }

    /// Rows written before the `kind_raw` column existed must decode with the
    /// kind defaulted to `.duration` rather than throwing.
    func testHabitDecodesLegacyRowWithoutKind() throws {
        let json = """
        {
            "id": "\(UUID().uuidString)",
            "title": "Legacy",
            "energy_raw": 1,
            "estimated_minutes": 30,
            "order": 0,
            "priority": 1,
            "updated_at": "1970-01-01T00:00:01Z"
        }
        """.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let dto = try decoder.decode(SyncDTO.Habit.self, from: json)
        XCTAssertEqual(dto.kindRaw, HabitKind.duration.rawValue)
    }

    /// An anchored habit's clock time must survive a DTO round-trip.
    func testHabitAnchorRoundTrips() {
        let habit = Habit(title: "Wake up", kind: .anchored, anchorMinuteOfDay: 6 * 60 + 30)
        let dto = SyncMapping.dto(from: habit)
        XCTAssertEqual(dto.anchorMinuteOfDay, 6 * 60 + 30)
    }

    /// Rows written before the `anchor_minute_of_day` column existed must decode
    /// with the anchor nil rather than throwing.
    func testHabitDecodesLegacyRowWithoutAnchor() throws {
        let json = """
        {
            "id": "\(UUID().uuidString)",
            "title": "Legacy",
            "energy_raw": 1,
            "estimated_minutes": 30,
            "order": 0,
            "priority": 1,
            "kind_raw": 0,
            "updated_at": "1970-01-01T00:00:01Z"
        }
        """.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let dto = try decoder.decode(SyncDTO.Habit.self, from: json)
        XCTAssertNil(dto.anchorMinuteOfDay)
    }

    func testRemoteWinsOnlyWhenNewer() {
        let t1 = Date(timeIntervalSince1970: 1000)
        let t2 = Date(timeIntervalSince1970: 2000)
        XCTAssertTrue(SyncMapping.remoteWins(local: t1, remote: t2))
        XCTAssertFalse(SyncMapping.remoteWins(local: t2, remote: t1))
        XCTAssertFalse(SyncMapping.remoteWins(local: t1, remote: t1))
    }

    func testSessionStoppedEarlyRoundTrips() {
        let habit = Habit(title: "Stretch", energy: .low, estimatedMinutes: 5)
        let session = DailySession(baseMinutes: 5, actualMinutes: 3, status: .completed, stoppedEarly: true, habit: habit)
        let dto = SyncMapping.dto(from: session)
        XCTAssertTrue(dto.stoppedEarly)
        XCTAssertEqual(dto.actualMinutes, 3)
    }

    /// Rows written before the `stopped_early` column existed must decode with
    /// the flag defaulted to false rather than throwing.
    func testSessionDecodesLegacyRowWithoutStoppedEarly() throws {
        let json = """
        {
            "id": "\(UUID().uuidString)",
            "date": "1970-01-01T00:00:01Z",
            "base_minutes": 30,
            "compressed_minutes": 30,
            "status": 2,
            "is_interruption": false,
            "order_hint": 0,
            "updated_at": "1970-01-01T00:00:01Z"
        }
        """.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let dto = try decoder.decode(SyncDTO.DailySession.self, from: json)
        XCTAssertFalse(dto.stoppedEarly)
    }

    /// An injected interruption's chosen energy must survive a DTO round-trip.
    func testSessionEnergyRoundTrips() {
        let session = DailySession(baseMinutes: 20, isInterruption: true, energy: .high)
        let dto = SyncMapping.dto(from: session)
        XCTAssertEqual(dto.energyRaw, EnergyLevel.high.rawValue)
    }

    /// Rows written before the `energy_raw` column existed must decode with the
    /// flag defaulted to mid rather than throwing.
    func testSessionDecodesLegacyRowWithoutEnergy() throws {
        let json = """
        {
            "id": "\(UUID().uuidString)",
            "date": "1970-01-01T00:00:01Z",
            "base_minutes": 30,
            "compressed_minutes": 30,
            "status": 0,
            "is_interruption": true,
            "order_hint": 0,
            "updated_at": "1970-01-01T00:00:01Z"
        }
        """.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let dto = try decoder.decode(SyncDTO.DailySession.self, from: json)
        XCTAssertEqual(dto.energyRaw, EnergyLevel.mid.rawValue)
    }

    func testCodableRoundTrip() throws {
        let dto = SyncDTO.Habit(
            id: UUID(), title: "X", energyRaw: 1, estimatedMinutes: 30,
            order: 0, priority: 1,
            updatedAt: Date(timeIntervalSince1970: 1), deletedAt: nil
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(dto)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let back = try decoder.decode(SyncDTO.Habit.self, from: data)
        XCTAssertEqual(back, dto)
    }
}
