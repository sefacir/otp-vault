import Foundation
import Observation
import OtpVaultCore

@Observable
final class BackupController {

    enum Phase: Equatable {
        case idle
        case working
        case done(version: Int)
        case restored(count: Int, version: Int)
        case error(String)
    }

    private let client: BackendClient
    var phase: Phase = .idle

    init(baseURL: URL = AppConfig.apiBaseURL, pinning: CertificatePinning = AppConfig.certificatePinning) {
        client = BackendClient(baseURL: baseURL, pinning: pinning)
    }

    @MainActor
    func authenticate(email: String, password: String, createAccount: Bool) async -> AuthTokens? {
        phase = .working
        do {
            if createAccount {
                try await client.register(email: email, password: password)
            }
            let tokens = try await client.login(email: email, password: password)
            phase = .idle
            return tokens
        } catch {
            phase = .error(message(for: error))
            return nil
        }
    }

    @MainActor
    func backUp(
        accounts: [Account],
        masterPassword: String,
        tokens: AuthTokens,
        knownVersion: Int?
    ) async -> (version: Int, tokens: AuthTokens)? {
        phase = .working
        do {
            let plaintext = try JSONEncoder().encode(accounts)
            let result = try await VaultSync.pushWithRetry(
                plaintext: plaintext,
                masterPassword: masterPassword,
                knownVersion: knownVersion,
                tokens: tokens,
                api: client
            )
            phase = .done(version: result.version)
            return result
        } catch {
            phase = .error(message(for: error))
            return nil
        }
    }

    @MainActor
    func restore(
        masterPassword: String,
        tokens: AuthTokens
    ) async -> (accounts: [Account], version: Int, tokens: AuthTokens)? {
        phase = .working
        do {
            guard let result = try await VaultSync.pullWithRetry(
                masterPassword: masterPassword,
                tokens: tokens,
                api: client
            ) else {
                phase = .error("No backup found for this account.")
                return nil
            }
            let accounts = try JSONDecoder().decode([Account].self, from: result.plaintext)
            phase = .restored(count: accounts.count, version: result.version)
            return (accounts, result.version, result.tokens)
        } catch {
            phase = .error(message(for: error))
            return nil
        }
    }

    private func message(for error: Error) -> String {
        switch error {
        case BackendClient.ClientError.unauthorized:
            return "Session expired — sign in again."
        case BackendClient.ClientError.conflict:
            return "Backup changed elsewhere — try again."
        case BackendClient.ClientError.rateLimited:
            return "Too many attempts. Wait a minute."
        case BackendClient.ClientError.accountLocked:
            return "Account locked after too many failed logins."
        case BackendClient.ClientError.badRequest:
            return "The server rejected the request."
        case BackendClient.ClientError.transport:
            return "Can't reach the server."
        case VaultCrypto.CryptoError.decryptionFailed:
            return "Wrong master password."
        default:
            return "Something went wrong."
        }
    }
}
