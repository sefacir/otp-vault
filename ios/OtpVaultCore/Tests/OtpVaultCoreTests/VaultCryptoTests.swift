import CryptoKit
import XCTest
@testable import OtpVaultCore

final class VaultCryptoTests: XCTestCase {

    private let plaintext = Data(#"[{"issuer":"GitHub","label":"sefacir"}]"#.utf8)
    private let iterations = 1_000

    func testSealOpenRoundTrip() throws {
        let envelope = try VaultCrypto.seal(plaintext, password: "correct horse", version: 1, iterations: iterations)
        let opened = try VaultCrypto.open(envelope, password: "correct horse")
        XCTAssertEqual(opened, plaintext)
    }

    func testWrongPasswordFailsCleanly() throws {
        let envelope = try VaultCrypto.seal(plaintext, password: "right", version: 1, iterations: iterations)
        XCTAssertThrowsError(try VaultCrypto.open(envelope, password: "wrong")) { error in
            XCTAssertEqual(error as? VaultCrypto.CryptoError, .decryptionFailed)
        }
    }

    func testEnvelopeRecordsKdfAndCipher() throws {
        let envelope = try VaultCrypto.seal(plaintext, password: "pw", version: 3, iterations: iterations)
        XCTAssertEqual(envelope.version, 3)
        XCTAssertEqual(envelope.cipher, "AES-256-GCM")
        XCTAssertEqual(envelope.kdf.algorithm, "pbkdf2-hmac-sha256")
        XCTAssertEqual(envelope.kdf.iterations, iterations)
        XCTAssertEqual(Data(base64Encoded: envelope.kdf.saltBase64)?.count, 16)
    }

    func testEachSealUsesFreshSaltAndBlob() throws {
        let first = try VaultCrypto.seal(plaintext, password: "pw", version: 1, iterations: iterations)
        let second = try VaultCrypto.seal(plaintext, password: "pw", version: 1, iterations: iterations)
        XCTAssertNotEqual(first.kdf.saltBase64, second.kdf.saltBase64)
        XCTAssertNotEqual(first.blobBase64, second.blobBase64)
    }

    func testTamperedBlobFails() throws {
        let envelope = try VaultCrypto.seal(plaintext, password: "pw", version: 1, iterations: iterations)
        var blob = Data(base64Encoded: envelope.blobBase64)!
        blob[blob.count - 1] ^= 0x01
        let tampered = BackupEnvelope(
            version: envelope.version,
            kdf: envelope.kdf,
            cipher: envelope.cipher,
            blobBase64: blob.base64EncodedString()
        )
        XCTAssertThrowsError(try VaultCrypto.open(tampered, password: "pw"))
    }

    func testDeriveKeyIsDeterministic() throws {
        let params = KdfParams(
            algorithm: "pbkdf2-hmac-sha256",
            iterations: iterations,
            saltBase64: Data(repeating: 7, count: 16).base64EncodedString()
        )
        let a = try VaultCrypto.deriveKey(password: "pw", params: params)
        let b = try VaultCrypto.deriveKey(password: "pw", params: params)
        XCTAssertEqual(a.withUnsafeBytes { Data($0) }, b.withUnsafeBytes { Data($0) })
        XCTAssertEqual(a.withUnsafeBytes { Data($0) }.count, 32)
    }

    func testEnvelopeIsJSONCodable() throws {
        let envelope = try VaultCrypto.seal(plaintext, password: "pw", version: 2, iterations: iterations)
        let data = try JSONEncoder().encode(envelope)
        let decoded = try JSONDecoder().decode(BackupEnvelope.self, from: data)
        XCTAssertEqual(decoded, envelope)
        let opened = try VaultCrypto.open(decoded, password: "pw")
        XCTAssertEqual(opened, plaintext)
    }

    func testTamperedKdfParamsFail() throws {
        let envelope = try VaultCrypto.seal(plaintext, password: "pw", version: 1, iterations: iterations)
        let weakened = BackupEnvelope(
            version: envelope.version,
            kdf: KdfParams(
                algorithm: envelope.kdf.algorithm,
                iterations: 1,
                saltBase64: envelope.kdf.saltBase64
            ),
            cipher: envelope.cipher,
            blobBase64: envelope.blobBase64
        )
        XCTAssertThrowsError(try VaultCrypto.open(weakened, password: "pw")) { error in
            XCTAssertEqual(error as? VaultCrypto.CryptoError, .decryptionFailed)
        }
    }

    func testWrongFormatRejected() throws {
        let envelope = try VaultCrypto.seal(plaintext, password: "pw", version: 1, iterations: iterations)
        let legacy = BackupEnvelope(
            format: 1,
            version: envelope.version,
            kdf: envelope.kdf,
            cipher: envelope.cipher,
            blobBase64: envelope.blobBase64
        )
        XCTAssertThrowsError(try VaultCrypto.open(legacy, password: "pw")) { error in
            XCTAssertEqual(error as? VaultCrypto.CryptoError, .malformedEnvelope)
        }
    }

    func testMalformedEnvelopeRejected() {
        let bad = BackupEnvelope(
            version: 1,
            kdf: KdfParams(algorithm: "pbkdf2-hmac-sha256", iterations: iterations, saltBase64: "!!!!"),
            cipher: "AES-256-GCM",
            blobBase64: "not-base64!!"
        )
        XCTAssertThrowsError(try VaultCrypto.open(bad, password: "pw")) { error in
            XCTAssertEqual(error as? VaultCrypto.CryptoError, .malformedEnvelope)
        }
    }
}
