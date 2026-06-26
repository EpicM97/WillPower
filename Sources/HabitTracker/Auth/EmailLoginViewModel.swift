import Foundation

/// Drives the email branch of the auth flow: collect email → send OTP →
/// collect 6-digit code → verify. Owned by `EmailLoginView`; emits success
/// via callback so the parent (`AuthRootView`) can update the
/// `AuthCoordinator`.
@Observable @MainActor
final class EmailLoginViewModel {
    enum Step: Equatable { case email, code }
    /// Supabase's email-OTP rate limit is ~60s per address. We match it so
    /// the local button stays disabled until the server is ready to accept
    /// another request.
    static let resendCooldownSeconds: Int = 60

    var email: String = ""
    var code: String = ""
    private(set) var step: Step = .email
    private(set) var inFlight: Bool = false
    private(set) var lastError: String?
    private(set) var lastSentAt: Date?
    private(set) var resendOverrideSeconds: Int?

    private let auth: any AuthService
    private let now: () -> Date
    private let onSignedIn: (UUID) -> Void

    init(
        auth: any AuthService,
        now: @escaping () -> Date = Date.init,
        onSignedIn: @escaping (UUID) -> Void
    ) {
        self.auth = auth
        self.now = now
        self.onSignedIn = onSignedIn
    }

    func resendSecondsRemaining(at reference: Date? = nil) -> Int {
        guard let last = lastSentAt else { return 0 }
        let elapsed = Int((reference ?? now()).timeIntervalSince(last))
        let window = resendOverrideSeconds ?? Self.resendCooldownSeconds
        return max(0, window - elapsed)
    }

    func sendCode() async {
        guard !inFlight else { return }
        guard resendSecondsRemaining() == 0 else { return }
        inFlight = true
        defer { inFlight = false }
        lastError = nil
        do {
            try await auth.sendOTP(to: email)
            lastSentAt = now()
            resendOverrideSeconds = nil
            step = .code
        } catch let AuthError.rateLimited(retry) {
            // Server's cooldown is the truth — sync our local cooldown to it
            // so the button doesn't tease the user back in early.
            lastSentAt = now()
            resendOverrideSeconds = retry
            lastError = "Please wait \(retry)s before requesting another code."
            // Still move them to code entry — the previous email may still be valid.
            if step == .email { step = .code }
        } catch {
            lastError = describe(error)
        }
    }

    func verify() async {
        guard !inFlight else { return }
        inFlight = true
        defer { inFlight = false }
        lastError = nil
        do {
            let id = try await auth.verifyOTP(email: email, code: code)
            onSignedIn(id)
        } catch {
            lastError = describe(error)
        }
    }

    func backToEmail() {
        code = ""
        lastError = nil
        step = .email
    }

    private func describe(_ error: Error) -> String {
        switch error {
        case AuthError.invalidEmail: "Please enter a valid email."
        case AuthError.invalidCode: "That code didn't match. Try again, or resend a new one."
        case AuthError.rateLimited(let n): "Please wait \(n)s before requesting another code."
        case AuthError.network: "Couldn't reach the server. Check your connection and try again."
        case AuthError.server: "Something went wrong on our end. Please try again in a moment."
        default: "Something went wrong. Please try again."
        }
    }
}
