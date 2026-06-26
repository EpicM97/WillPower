import XCTest
@testable import HabitTracker

/// `SupabaseAuthService.classify` turns raw SDK/transport errors into our typed
/// `AuthError`, so the UI can show honest copy instead of always claiming a
/// network failure.
final class AuthErrorClassifierTests: XCTestCase {
    private struct StubError: Error, CustomStringConvertible { let description: String }

    func test_classify_transportErrorIsNetwork() {
        if case .network = SupabaseAuthService.classify(URLError(.notConnectedToInternet)) {} else {
            XCTFail("expected .network for a URLError")
        }
    }

    func test_classify_nsurlDomainErrorIsNetwork() {
        let err = NSError(domain: NSURLErrorDomain, code: -1009)
        if case .network = SupabaseAuthService.classify(err) {} else {
            XCTFail("expected .network for NSURLErrorDomain")
        }
    }

    func test_classify_rateLimitParsesRetrySeconds() {
        let err = StubError(description: "AuthError: over_email_send_rate_limit, retry after 25 seconds")
        XCTAssertEqual(SupabaseAuthService.classify(err), .rateLimited(retryAfterSeconds: 25))
    }

    func test_classify_otherApiErrorIsServerNotNetwork() {
        let err = StubError(description: "api(message: \"Signups not allowed for otp\", code: 422)")
        if case .server = SupabaseAuthService.classify(err) {} else {
            XCTFail("expected .server for a non-transport API error, got network/other")
        }
    }
}
