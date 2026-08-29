import XCTest
@testable import OtpVaultCore

final class OtpAuthURITests: XCTestCase {

    private let secretB32 = "JBSWY3DPEHPK3PXP"
    private var secretData: Data { Base32.decode("JBSWY3DPEHPK3PXP")! }

    func testFullURI() {
        let uri = OtpAuthURI.parse("otpauth://totp/GitHub:sefacir?secret=\(secretB32)&issuer=GitHub&algorithm=SHA1&digits=6&period=30")
        XCTAssertNotNil(uri)
        XCTAssertEqual(uri?.issuer, "GitHub")
        XCTAssertEqual(uri?.account, "sefacir")
        XCTAssertEqual(uri?.secret, secretData)
        XCTAssertEqual(uri?.algorithm, .sha1)
        XCTAssertEqual(uri?.digits, 6)
        XCTAssertEqual(uri?.period, 30)
    }

    func testMinimalURI() {
        let uri = OtpAuthURI.parse("otpauth://totp/sefacir?secret=\(secretB32)")
        XCTAssertEqual(uri?.issuer, nil)
        XCTAssertEqual(uri?.account, "sefacir")
        XCTAssertEqual(uri?.secret, secretData)
        XCTAssertEqual(uri?.algorithm, .sha1)
        XCTAssertEqual(uri?.digits, 6)
        XCTAssertEqual(uri?.period, 30)
    }

    func testIssuerFromQueryOnly() {
        let uri = OtpAuthURI.parse("otpauth://totp/sefacir?secret=\(secretB32)&issuer=GitHub")
        XCTAssertEqual(uri?.issuer, "GitHub")
        XCTAssertEqual(uri?.account, "sefacir")
    }

    func testEncodedLabelWithSpaceAndAtSign() {
        let uri = OtpAuthURI.parse("otpauth://totp/Big%20Corp:alice%40example.com?secret=\(secretB32)")
        XCTAssertEqual(uri?.issuer, "Big Corp")
        XCTAssertEqual(uri?.account, "alice@example.com")
    }

    func testEncodedColonInLabel() {
        let uri = OtpAuthURI.parse("otpauth://totp/GitHub%3Asefacir?secret=\(secretB32)")
        XCTAssertEqual(uri?.issuer, "GitHub")
        XCTAssertEqual(uri?.account, "sefacir")
    }

    func testColonWithTrailingSpace() {
        let uri = OtpAuthURI.parse("otpauth://totp/GitHub:%20sefacir?secret=\(secretB32)")
        XCTAssertEqual(uri?.issuer, "GitHub")
        XCTAssertEqual(uri?.account, "sefacir")
    }

    func testCustomAlgorithmDigitsPeriod() {
        let uri = OtpAuthURI.parse("otpauth://totp/x?secret=\(secretB32)&algorithm=SHA256&digits=8&period=60")
        XCTAssertEqual(uri?.algorithm, .sha256)
        XCTAssertEqual(uri?.digits, 8)
        XCTAssertEqual(uri?.period, 60)
    }

    func testRejectsNonOtpauthScheme() {
        XCTAssertNil(OtpAuthURI.parse("https://totp/x?secret=\(secretB32)"))
    }

    func testRejectsHotp() {
        XCTAssertNil(OtpAuthURI.parse("otpauth://hotp/x?secret=\(secretB32)&counter=0"))
    }

    func testRejectsMissingSecret() {
        XCTAssertNil(OtpAuthURI.parse("otpauth://totp/x?issuer=GitHub"))
    }

    func testRejectsInvalidSecret() {
        XCTAssertNil(OtpAuthURI.parse("otpauth://totp/x?secret=0189"))
    }

    func testRejectsDigitsBelowRange() {
        XCTAssertNil(OtpAuthURI.parse("otpauth://totp/x?secret=\(secretB32)&digits=4"))
    }

    func testRejectsDigitsAboveRange() {
        XCTAssertNil(OtpAuthURI.parse("otpauth://totp/x?secret=\(secretB32)&digits=10"))
    }

    func testRejectsNonNumericDigits() {
        XCTAssertNil(OtpAuthURI.parse("otpauth://totp/x?secret=\(secretB32)&digits=abc"))
    }

    func testRejectsZeroPeriod() {
        XCTAssertNil(OtpAuthURI.parse("otpauth://totp/x?secret=\(secretB32)&period=0"))
    }

    func testRejectsNegativePeriod() {
        XCTAssertNil(OtpAuthURI.parse("otpauth://totp/x?secret=\(secretB32)&period=-30"))
    }
}
