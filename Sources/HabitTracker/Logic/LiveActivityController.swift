import ActivityKit
import Foundation

@MainActor
protocol LiveActivityController {
    func start(
        attributes: HabitActivityAttributes,
        state: HabitActivityAttributes.ContentState
    ) async throws

    func update(state: HabitActivityAttributes.ContentState) async
    func end(finalState: HabitActivityAttributes.ContentState?) async
    var isActive: Bool { get }
}

enum LiveActivityError: Error, Equatable {
    case notEnabled
    case alreadyActive
    case startFailed(String)
}

@MainActor
final class ActivityKitLiveActivityController: LiveActivityController {
    private var activity: Activity<HabitActivityAttributes>?

    var isActive: Bool { activity != nil }

    func start(
        attributes: HabitActivityAttributes,
        state: HabitActivityAttributes.ContentState
    ) async throws {
        guard activity == nil else { throw LiveActivityError.alreadyActive }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            throw LiveActivityError.notEnabled
        }
        do {
            activity = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: nil)
            )
        } catch {
            throw LiveActivityError.startFailed(String(describing: error))
        }
    }

    func update(state: HabitActivityAttributes.ContentState) async {
        await activity?.update(.init(state: state, staleDate: nil))
    }

    func end(finalState: HabitActivityAttributes.ContentState?) async {
        let content: ActivityContent<HabitActivityAttributes.ContentState>?
        if let finalState { content = .init(state: finalState, staleDate: nil) }
        else { content = nil }
        await activity?.end(content, dismissalPolicy: .immediate)
        activity = nil
    }
}

@MainActor
final class MockLiveActivityController: LiveActivityController {
    enum Call: Equatable {
        case start(HabitActivityAttributes.ContentState)
        case update(HabitActivityAttributes.ContentState)
        case end(HabitActivityAttributes.ContentState?)
    }

    private(set) var calls: [Call] = []
    var errorOnStart: LiveActivityError?
    private(set) var isActive: Bool = false

    func start(
        attributes: HabitActivityAttributes,
        state: HabitActivityAttributes.ContentState
    ) async throws {
        if let errorOnStart {
            self.errorOnStart = nil
            throw errorOnStart
        }
        calls.append(.start(state))
        isActive = true
    }

    func update(state: HabitActivityAttributes.ContentState) async {
        calls.append(.update(state))
    }

    func end(finalState: HabitActivityAttributes.ContentState?) async {
        calls.append(.end(finalState))
        isActive = false
    }
}
