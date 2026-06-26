import Foundation
import OSLog
import Supabase

private let authLog = Logger(subsystem: "com.willpower.HabitTracker", category: "auth")

enum AuthError: Error, Equatable {
    case invalidEmail
    case invalidCode
    case rateLimited(retryAfterSeconds: Int)
    /// Genuine transport failure — couldn't reach the server at all.
    case network(String)
    /// The server was reached but returned an error (bad config, 4xx/5xx, etc).
    /// Distinct from `.network` so we never tell the user "check your
    /// connection" when their connection is fine.
    case server(String)
}

/// Auth surface used by the app. Concrete impl wraps supabase-swift;
/// `MockAuthService` (in tests) records calls and lets us drive flows
/// without network.
protocol AuthService: Sendable {
    /// Sends a one-time code (email magic link / OTP) to the address.
    func sendOTP(to email: String) async throws

    /// Verifies the code the user pasted from the email.
    /// Returns the user's id on success.
    func verifyOTP(email: String, code: String) async throws -> UUID

    /// Currently signed-in user id, if any.
    func currentUserID() async -> UUID?

    /// Currently signed-in user email, if any.
    func currentEmail() async -> String?

    /// Requests an email change. Triggers Supabase to send a confirmation to
    /// the new address; until confirmed, the change is not effective.
    func requestEmailChange(to newEmail: String) async throws

    /// Wipes the local session. Server-side row deletion still needs a
    /// service-role Edge Function; for now this is the user-facing escape hatch.
    func deleteAccount() async throws

    func signOut() async throws
}

actor SupabaseAuthService: AuthService {
    private let client: SupabaseClient

    init(config: SupabaseConfig) {
        self.client = SupabaseClient(supabaseURL: config.url, supabaseKey: config.anonKey)
    }

    func sendOTP(to email: String) async throws {
        guard email.contains("@") else { throw AuthError.invalidEmail }
        do {
            try await client.auth.signInWithOTP(email: email)
        } catch {
            authLog.error("sendOTP failed: \(String(describing: error), privacy: .public)")
            throw Self.classify(error)
        }
    }

    func verifyOTP(email: String, code: String) async throws -> UUID {
        guard !code.isEmpty else { throw AuthError.invalidCode }
        do {
            let session = try await client.auth.verifyOTP(email: email, token: code, type: .email)
            return session.user.id
        } catch {
            authLog.error("verifyOTP failed: \(String(describing: error), privacy: .public)")
            throw Self.classify(error)
        }
    }

    /// Classifies a raw SDK/transport error into a typed `AuthError`. Order
    /// matters: a rate-limit is a specific server response; a true transport
    /// failure is `.network`; everything else the server returned is `.server`
    /// (so we never blame the user's connection for a server-side problem).
    static func classify(_ error: Error) -> AuthError {
        if let rate = rateLimit(from: error) { return rate }
        if isTransport(error) { return .network(String(describing: error)) }
        return .server(String(describing: error))
    }

    /// A genuine "couldn't reach the host" failure (offline, DNS, timeout).
    static func isTransport(_ error: Error) -> Bool {
        if error is URLError { return true }
        return (error as NSError).domain == NSURLErrorDomain
    }

    /// Detects Supabase's email rate-limit and pulls the retry window out of the
    /// message. We pattern-match the string form because the SDK exposes errors
    /// as associated values with private types; this survives SDK minor bumps.
    static func rateLimit(from error: Error) -> AuthError? {
        let dump = String(describing: error)
        guard dump.contains("over_email_send_rate_limit") || dump.contains("rate_limit") else { return nil }
        // Look for "after N seconds" — Supabase includes this in the message.
        let pattern = #/after\s+(\d+)\s+seconds?/#
        let retry = dump.firstMatch(of: pattern).flatMap { Int($0.1) } ?? 60
        return .rateLimited(retryAfterSeconds: retry)
    }

    func currentUserID() async -> UUID? {
        try? await client.auth.session.user.id
    }

    func currentEmail() async -> String? {
        try? await client.auth.session.user.email
    }

    func requestEmailChange(to newEmail: String) async throws {
        guard newEmail.contains("@") else { throw AuthError.invalidEmail }
        do {
            try await client.auth.update(user: UserAttributes(email: newEmail))
        } catch {
            authLog.error("requestEmailChange failed: \(String(describing: error), privacy: .public)")
            throw Self.classify(error)
        }
    }

    func deleteAccount() async throws {
        // Server-side row purge requires a service-role Edge Function — TBD.
        // For now: sign out so the user can't keep writing into the account.
        try await signOut()
    }

    func signOut() async throws {
        do {
            try await client.auth.signOut()
        } catch {
            authLog.error("signOut failed: \(String(describing: error), privacy: .public)")
            throw Self.classify(error)
        }
    }
}
