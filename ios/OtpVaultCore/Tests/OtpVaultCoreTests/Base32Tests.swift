import XCTest
@testable import OtpVaultCore

final class Base32Tests: XCTestCase {

    private func decoded(_ input: String) -> String? {
        Base32.decode(input).map { String(decoding: $0, as: UTF8.self) }
    }

    func testRFC4648Vectors() {
        XCTAssertEqual(decoded("MY======"), "f")
        XCTAssertEqual(decoded("MZXQ===="), "fo")
        XCTAssertEqual(decoded("MZXW6==="), "foo")
        XCTAssertEqual(decoded("MZXW6YQ="), "foob")
        XCTAssertEqual(decoded("MZXW6YTB"), "fooba")
        XCTAssertEqual(decoded("MZXW6YTBOI======"), "foobar")
    }

    func testPaddingIsOptional() {
        XCTAssertEqual(decoded("MZXW6YTBOI"), "foobar")
    }

    func testLowercaseAndSpacesAreTolerated() {
        XCTAssertEqual(decoded("mzxw 6ytb oi"), "foobar")
    }

    func testInvalidCharacterReturnsNil() {
        XCTAssertNil(Base32.decode("MZXW6YTB0I"))
    }

    func testEmptyStringDecodesToEmptyData() {
        XCTAssertEqual(Base32.decode(""), Data())
    }
}
