import CommonCrypto
import CryptoKit
import Foundation

public enum VaultCrypto {

    public enum CryptoError: Error, Equatable {
        case keyDerivationFailed
        case decryptionFailed
        case malformedEnvelope
    }

    public static let algorithmName = "pbkdf2-hmac-sha256"
    public static let cipherName = "AES-256-GCM"
    public static let formatVersion = 2
    public static let defaultIterations = 600_000
    public static let saltLength = 16
    public static let keyLength = 32

    public static func seal(
        _ plaintext: Data,
        password: String,
        version: Int,
        iterations: Int = defaultIterations
    ) throws -> BackupEnvelope {
        let params = KdfParams(
            algorithm: algorithmName,
            iterations: iterations,
            saltBase64: randomBytes(saltLength).base64EncodedString()
        )
        let key = try deriveKey(password: password, params: params)
        let sealedBox = try AES.GCM.seal(
            plaintext,
            using: key,
            authenticating: headerAAD(cipher: cipherName, params: params)
        )
        guard let combined = sealedBox.combined else {
            throw CryptoError.decryptionFailed
        }
        return BackupEnvelope(
            format: formatVersion,
            version: version,
            kdf: params,
            cipher: cipherName,
            blobBase64: combined.base64EncodedString()
        )
    }

    public static func open(_ envelope: BackupEnvelope, password: String) throws -> Data {
        guard
            envelope.format == formatVersion,
            envelope.cipher == cipherName,
            let blob = Data(base64Encoded: envelope.blobBase64)
        else {
            throw CryptoError.malformedEnvelope
        }

        let key = try deriveKey(password: password, params: envelope.kdf)
        do {
            let sealedBox = try AES.GCM.SealedBox(combined: blob)
            return try AES.GCM.open(
                sealedBox,
                using: key,
                authenticating: headerAAD(cipher: envelope.cipher, params: envelope.kdf)
            )
        } catch {
            throw CryptoError.decryptionFailed
        }
    }

    public static func deriveKey(password: String, params: KdfParams) throws -> SymmetricKey {
        guard
            params.algorithm == algorithmName,
            params.iterations > 0,
            let salt = Data(base64Encoded: params.saltBase64),
            !salt.isEmpty
        else {
            throw CryptoError.malformedEnvelope
        }

        let passwordBytes = Array(password.utf8)
        var derived = [UInt8](repeating: 0, count: keyLength)

        let status = salt.withUnsafeBytes { saltBuffer in
            CCKeyDerivationPBKDF(
                CCPBKDFAlgorithm(kCCPBKDF2),
                passwordBytes.map { CChar(bitPattern: $0) },
                passwordBytes.count,
                saltBuffer.bindMemory(to: UInt8.self).baseAddress,
                salt.count,
                CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                UInt32(params.iterations),
                &derived,
                keyLength
            )
        }

        guard status == kCCSuccess else {
            throw CryptoError.keyDerivationFailed
        }
        return SymmetricKey(data: Data(derived))
    }

    private static func headerAAD(cipher: String, params: KdfParams) -> Data {
        let canonical = [
            String(formatVersion),
            cipher,
            params.algorithm,
            String(params.iterations),
            params.saltBase64
        ].joined(separator: "|")
        return Data(canonical.utf8)
    }

    private static func randomBytes(_ count: Int) -> Data {
        var generator = SystemRandomNumberGenerator()
        var bytes = Data(count: count)
        for index in bytes.indices {
            bytes[index] = UInt8.random(in: UInt8.min...UInt8.max, using: &generator)
        }
        return bytes
    }
}
