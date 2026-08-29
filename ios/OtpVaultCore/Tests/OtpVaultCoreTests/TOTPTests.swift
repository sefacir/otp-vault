import XCTest
@testable import OtpVaultCore

final class TOTPTests: XCTestCase {

    private let sha1Secret = Data("12345678901234567890".utf8)
    private let sha256Secret = Data("12345678901234567890123456789012".utf8)
    private let sha512Secret = Data("1234567890123456789012345678901234567890123456789012345678901234".utf8)

    private func code(
        _ secret: Data,
        _ algorithm: TOTP.Algorithm,
        at seconds: TimeInterval
    ) -> String {
        let totp = TOTP(secret: secret, digits: 8, period: 30, algorithm: algorithm)
        return totp.code(at: Date(timeIntervalSince1970: seconds))
    }

    func testRFC6238_SHA1() {
        XCTAssertEqual(code(sha1Secret, .sha1, at: 59), "94287082")
        XCTAssertEqual(code(sha1Secret, .sha1, at: 1111111109), "07081804")
        XCTAssertEqual(code(sha1Secret, .sha1, at: 1111111111), "14050471")
        XCTAssertEqual(code(sha1Secret, .sha1, at: 1234567890), "89005924")
        XCTAssertEqual(code(sha1Secret, .sha1, at: 2000000000), "69279037")
        XCTAssertEqual(code(sha1Secret, .sha1, at: 20000000000), "65353130")
    }

    func testRFC6238_SHA256() {
        XCTAssertEqual(code(sha256Secret, .sha256, at: 59), "46119246")
        XCTAssertEqual(code(sha256Secret, .sha256, at: 1111111109), "68084774")
        XCTAssertEqual(code(sha256Secret, .sha256, at: 1234567890), "91819424")
        XCTAssertEqual(code(sha256Secret, .sha256, at: 20000000000), "77737706")
    }

    func testRFC6238_SHA512() {
        XCTAssertEqual(code(sha512Secret, .sha512, at: 59), "90693936")
        XCTAssertEqual(code(sha512Secret, .sha512, at: 1111111109), "25091201")
        XCTAssertEqual(code(sha512Secret, .sha512, at: 1234567890), "93441116")
        XCTAssertEqual(code(sha512Secret, .sha512, at: 20000000000), "47863826")
    }

    func testDefaultConfiguration() {
        let totp = TOTP(secret: sha1Secret)
        XCTAssertEqual(totp.digits, 6)
        XCTAssertEqual(totp.period, 30)
    }

    func testCodeIsZeroPaddedToDigits() {
        let value = code(sha1Secret, .sha1, at: 1111111109)
        XCTAssertEqual(value.count, 8)
    }

    func testClampsOutOfRangeConfiguration() {
        let zeroPeriod = TOTP(secret: sha1Secret, digits: 20, period: 0)
        XCTAssertEqual(zeroPeriod.digits, 9)
        XCTAssertEqual(zeroPeriod.period, 30)

        let negative = TOTP(secret: sha1Secret, digits: -3, period: -10)
        XCTAssertEqual(negative.digits, 1)
        XCTAssertEqual(negative.period, 30)
    }

    func testDoesNotCrashOnExtremeConfiguration() {
        let totp = TOTP(secret: sha1Secret, digits: 999, period: 0)
        XCTAssertFalse(totp.code(at: Date(timeIntervalSince1970: 59)).isEmpty)
    }
}
