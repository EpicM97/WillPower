import Foundation

/// Single source of truth for the app's auth state. The root `App` reads
/// `state` to decide between `AuthRootView` and the main `RootView`; child
/// auth screens drive the coordinator's mutation methods.
@Observable @MainActor
final class AuthCoordinator {
    enum State: Equatable {
        case checking
        case signedOut
        case signedIn(UUID)

        var userID: UUID? {
            if case .signedIn(let id) = self { return id }
            return nil
        }

        var isSignedIn: Bool { userID != nil }
    }

    private(set) var state: State = .checking
    private(set) var email: String?
    private(set) var lastError: String?

    let auth: any AuthService

    init(auth: any AuthService) {
        self.auth = auth
    }

    func bootstrap() async {
        if let id = await auth.currentUserID() {
            state = .signedIn(id)
            email = await auth.currentEmail()
        } else {
            state = .signedOut
            email = nil
        }
    }

    func didSignIn(userID: UUID) {
        lastError = nil
        state = .signedIn(userID)
    }

    func setLastError(_ message: String?) {
        lastError = message
    }

    func signOut() async {
        do {
            try await auth.signOut()
            state = .signedOut
            email = nil
        } catch {
            lastError = String(describing: error)
        }
    }

    func requestEmailChange(to newEmail: String) async -> Bool {
        do {
            try await auth.requestEmailChange(to: newEmail)
            return true
        } catch {
            lastError = String(describing: error)
            return false
        }
    }

    func deleteAccount() async {
        do {
            try await auth.deleteAccount()
            state = .signedOut
            email = nil
        } catch {
            lastError = String(describing: error)
        }
    }
}
