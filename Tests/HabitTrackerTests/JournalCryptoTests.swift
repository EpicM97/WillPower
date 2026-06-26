import XCTest
import CryptoKit
@testable import HabitTracker

final class JournalCryptoTests: XCTestCase {
    func test_sealThenOpen_roundTrips() {
        let key = SymmetricKey(size: .bits256)
        let plaintext = "Today felt heavy but I showed up. 🌧️"
        let sealed = JournalCrypto.seal(plaintext, key: key)
        XCTAssertNotNil(sealed)
        XCTAssertTrue(JournalCrypto.isSealed(sealed))
        XCTAssertEqual(JournalCrypto.open(sealed, key: key), plaintext)
    }

    func test_seal_emptyOrWhitespace_returnsNil() {
        let key = SymmetricKey(size: .bits256)
        XCTAssertNil(JournalCrypto.seal("", key: key))
        XCTAssertNil(JournalCrypto.seal("   \n ", key: key))
    }

    func test_open_legacyPlaintext_passesThrough() {
        let key = SymmetricKey(size: .bits256)
        XCTAssertEqual(JournalCrypto.open("an old un-encrypted note", key: key), "an old un-encrypted note")
        XCTAssertFalse(JournalCrypto.isSealed("an old un-encrypted note"))
    }

    func test_open_wrongKey_returnsNil_notGarbage() {
        let sealed = JournalCrypto.seal("private", key: SymmetricKey(size: .bits256))
        XCTAssertNil(JournalCrypto.open(sealed, key: SymmetricKey(size: .bits256)))
    }

    func test_seal_isNondeterministic() {
        let key = SymmetricKey(size: .bits256)
        XCTAssertNotEqual(JournalCrypto.seal("same", key: key), JournalCrypto.seal("same", key: key))
    }

    func test_open_nilOrEmpty_returnsNil() {
        let key = SymmetricKey(size: .bits256)
        XCTAssertNil(JournalCrypto.open(nil, key: key))
        XCTAssertNil(JournalCrypto.open("", key: key))
    }
}
