import CryptoKit
import XCTest
@testable import OtpVaultCore

final class CertificatePinningTests: XCTestCase {

    private let certificate = Data("pretend-DER-certificate-bytes".utf8)

    private func hash(of data: Data) -> String {
        Data(SHA256.hash(data: data)).base64EncodedString()
    }

    func testDisabledWhenNoHashes() {
        XCTAssertFalse(CertificatePinning().isEnabled)
        XCTAssertTrue(CertificatePinning(pinnedCertificateHashes: ["abc"]).isEnabled)
    }

    func testMatchesPinnedHash() {
        let pinning = CertificatePinning(pinnedCertificateHashes: [hash(of: certificate)])
        XCTAssertTrue(pinning.matches(certificateDER: certificate))
    }

    func testRejectsUnknownCertificate() {
        let pinning = CertificatePinning(pinnedCertificateHashes: [hash(of: certificate)])
        XCTAssertFalse(pinning.matches(certificateDER: Data("different-cert".utf8)))
    }

    func testMatchesAnyOfSeveralPins() {
        let other = Data("backup-cert".utf8)
        let pinning = CertificatePinning(pinnedCertificateHashes: [hash(of: certificate), hash(of: other)])
        XCTAssertTrue(pinning.matches(certificateDER: certificate))
        XCTAssertTrue(pinning.matches(certificateDER: other))
    }
}
