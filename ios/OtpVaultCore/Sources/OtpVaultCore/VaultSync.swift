import Foundation

public enum VaultSync {

    public static func push(
        plaintext: Data,
        masterPassword: String,
        currentVersion: Int?,
        accessToken: String,
        api: BackendAPI,
        iterations: Int = VaultCrypto.defaultIterations
    ) async throws -> Int {
        let envelope = try VaultCrypto.seal(
            plaintext,
            password: masterPassword,
            version: (currentVersion ?? 0) + 1,
            iterations: iterations
        )
        let encoded = try JSONEncoder().encode(envelope)
        return try await api.putVault(
            envelope: String(decoding: encoded, as: UTF8.self),
            expectedVersion: currentVersion,
            accessToken: accessToken
        )
    }

    public static func pull(
        masterPassword: String,
        accessToken: String,
        api: BackendAPI
    ) async throws -> (plaintext: Data, version: Int)? {
        guard let state = try await api.getVault(accessToken: accessToken) else {
            return nil
        }
        guard let envelopeData = state.envelope.data(using: .utf8) else {
            throw VaultCrypto.CryptoError.malformedEnvelope
        }
        let envelope: BackupEnvelope
        do {
            envelope = try JSONDecoder().decode(BackupEnvelope.self, from: envelopeData)
        } catch {
            throw VaultCrypto.CryptoError.malformedEnvelope
        }
        let plaintext = try VaultCrypto.open(envelope, password: masterPassword)
        return (plaintext, state.version)
    }
}
