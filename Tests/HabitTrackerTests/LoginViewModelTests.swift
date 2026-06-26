import XCTest
@testable import HabitTracker

@MainActor
final class EmailLoginViewModelTests: XCTestCase {
    private func makeVM(
        auth: MockAuthService = MockAuthService(),
        now: @escaping () -> Date = Date.init,
        onSignedIn: @escaping (UUID) -> Void = { _ in }
    ) -> EmailLoginViewModel {
        EmailLoginViewModel(auth: auth, now: now, onSignedIn: onSignedIn)
    }

    func testSendCode_movesToCodeStep() async {
        let auth = MockAuthService()
        let vm = makeVM(auth: auth)
        vm.email = "me@example.com"
        await vm.sendCode()
        XCTAssertEqual(vm.step, .code)
        let calls = await auth.calls
        XCTAssertEqual(calls, [.sendOTP("me@example.com")])
    }

    func testSendCode_invalidEmail_surfacesError() async {
        let vm = makeVM()
        vm.email = "not-an-email"
        await vm.sendCode()
        XCTAssertEqual(vm.step, .email)
        XCTAssertNotNil(vm.lastError)
    }

    func testVerify_success_invokesCallback() async {
        let auth = MockAuthService()
        let id = UUID()
        await auth.setStubbedUserID(id)
        var captured: UUID?
        let vm = makeVM(auth: auth) { captured = $0 }
        vm.email = "me@example.com"
        vm.code = "123456"
        await vm.verify()
        XCTAssertEqual(captured, id)
    }

    func testBackToEmail_clearsCodeAndResetsStep() async {
        let vm = makeVM()
        vm.email = "me@example.com"
        await vm.sendCode()
        vm.code = "999"
        vm.backToEmail()
        XCTAssertEqual(vm.step, .email)
        XCTAssertEqual(vm.code, "")
        XCTAssertEqual(vm.email, "me@example.com")
    }

    func testResendCooldown_blocksUntilElapsed() async {
        var clock = Date(timeIntervalSince1970: 1000)
        let auth = MockAuthService()
        let vm = makeVM(auth: auth, now: { clock })
        vm.email = "me@example.com"
        await vm.sendCode()
        XCTAssertEqual(vm.resendSecondsRemaining(), 60)

        clock = Date(timeIntervalSince1970: 1010)
        await vm.sendCode()
        let calls1 = await auth.calls
        XCTAssertEqual(calls1.count, 1)

        clock = Date(timeIntervalSince1970: 1061)
        await vm.sendCode()
        let calls2 = await auth.calls
        XCTAssertEqual(calls2.count, 2)
    }

    /// Catches the bug class we just shipped a fix for: server says
    /// "rate limited, wait 25s" → VM must surface a clean message AND extend
    /// its local cooldown to match (not 60s default).
    func testServerRateLimit_extendsCooldownAndShowsCleanMessage() async {
        let clock = Date(timeIntervalSince1970: 1000)
        let auth = MockAuthService()
        await auth.setError(.rateLimited(retryAfterSeconds: 25))
        let vm = makeVM(auth: auth, now: { clock })
        vm.email = "me@example.com"
        await vm.sendCode()
        XCTAssertEqual(vm.resendSecondsRemaining(), 25)
        XCTAssertEqual(vm.lastError, "Please wait 25s before requesting another code.")
    }

    func testNetworkFailure_showsFriendlyCopy_notRawDump() async {
        let auth = MockAuthService()
        await auth.setError(.network("api(message: \"For security purposes...\", errorCode: ...)"))
        let vm = makeVM(auth: auth)
        vm.email = "me@example.com"
        await vm.sendCode()
        XCTAssertEqual(vm.lastError, "Couldn't reach the server. Check your connection and try again.")
    }
}

extension MockAuthService {
    func setError(_ error: AuthError) { errorOnNextSend = error }
}

extension MockAuthService {
    func setStubbedUserID(_ id: UUID) { stubbedUserID = id }
}

@MainActor
final class AuthCoordinatorTests: XCTestCase {
    func testBootstrap_noSession_movesToSignedOut() async {
        let coord = AuthCoordinator(auth: MockAuthService())
        XCTAssertEqual(coord.state, .checking)
        await coord.bootstrap()
        XCTAssertEqual(coord.state, .signedOut)
    }

    func testDidSignIn_movesToSignedIn() {
        let coord = AuthCoordinator(auth: MockAuthService())
        let id = UUID()
        coord.didSignIn(userID: id)
        XCTAssertEqual(coord.state, .signedIn(id))
        XCTAssertEqual(coord.state.userID, id)
        XCTAssertTrue(coord.state.isSignedIn)
    }

    func testSignOut_movesBackToSignedOut() async {
        let auth = MockAuthService()
        let coord = AuthCoordinator(auth: auth)
        coord.didSignIn(userID: UUID())
        await coord.signOut()
        XCTAssertEqual(coord.state, .signedOut)
    }
}
