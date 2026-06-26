import Foundation

final actor MockAuthService: AuthService {
    enum Call: Equatable {
        case sendOTP(String)
        case verifyOTP(String, String)
        case currentUserID
        case signOut
    }

    private(set) var calls: [Call] = []
    private var signedInUserID: UUID?
    private var signedInEmail: String?
    var errorOnNextSend: AuthError?
    var errorOnNextVerify: AuthError?
    var stubbedUserID: UUID = UUID()
    var stubbedEmail: String = "user@example.com"

    func sendOTP(to email: String) async throws {
        calls.append(.sendOTP(email))
        if let err = errorOnNextSend { errorOnNextSend = nil; throw err }
        guard email.contains("@") else { throw AuthError.invalidEmail }
    }

    func verifyOTP(email: String, code: String) async throws -> UUID {
        calls.append(.verifyOTP(email, code))
        if let err = errorOnNextVerify { errorOnNextVerify = nil; throw err }
        guard !code.isEmpty else { throw AuthError.invalidCode }
        signedInUserID = stubbedUserID
        signedInEmail = email
        return stubbedUserID
    }

    func currentUserID() async -> UUID? {
        calls.append(.currentUserID)
        return signedInUserID
    }

    func currentEmail() async -> String? {
        signedInEmail ?? (signedInUserID != nil ? stubbedEmail : nil)
    }

    func requestEmailChange(to newEmail: String) async throws {
        guard newEmail.contains("@") else { throw AuthError.invalidEmail }
        signedInEmail = newEmail
    }

    func deleteAccount() async throws {
        try await signOut()
    }

    func signOut() async throws {
        calls.append(.signOut)
        signedInUserID = nil
        signedInEmail = nil
    }
}
