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

    public static func pushWithRetry(
        plaintext: Data,
        masterPassword: String,
        knownVersion: Int?,
        tokens: AuthTokens,
        api: BackendAPI,
        iterations: Int = VaultCrypto.defaultIterations
    ) async throws -> (version: Int, tokens: AuthTokens) {
        var tokens = tokens
        var expectedVersion = knownVersion
        var refreshed = false

        while true {
            do {
                let version = try await push(
                    plaintext: plaintext,
                    masterPassword: masterPassword,
                    currentVersion: expectedVersion,
                    accessToken: tokens.accessToken,
                    api: api,
                    iterations: iterations
                )
                return (version, tokens)
            } catch BackendClient.ClientError.unauthorized {
                guard !refreshed else { throw BackendClient.ClientError.unauthorized }
                refreshed = true
                tokens = try await api.refresh(refreshToken: tokens.refreshToken)
            } catch BackendClient.ClientError.conflict {
                let serverVersion = try await api.getVault(accessToken: tokens.accessToken)?.version
                guard serverVersion != expectedVersion else {
                    throw BackendClient.ClientError.conflict
                }
                expectedVersion = serverVersion
            }
        }
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
