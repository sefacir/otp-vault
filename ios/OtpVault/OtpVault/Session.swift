import Foundation
import Observation
import OtpVaultCore

@Observable
final class Session {

    private static let service = "dev.otpvault"
    private static let versionKey = "otpvault.vaultVersion"

    private let tokenStore = TokenStore(store: KeychainStore(service: service))

    private(set) var accessToken: String?
    private(set) var refreshToken: String?
    private(set) var vaultVersion: Int?

    var isSignedIn: Bool {
        accessToken != nil
    }

    var tokens: AuthTokens? {
        guard let accessToken, let refreshToken else { return nil }
        return AuthTokens(accessToken: accessToken, refreshToken: refreshToken, expiresInSeconds: 0)
    }

    init() {
        if let stored = tokenStore.load() {
            accessToken = stored.accessToken
            refreshToken = stored.refreshToken
        }
        let storedVersion = UserDefaults.standard.integer(forKey: Self.versionKey)
        vaultVersion = storedVersion > 0 ? storedVersion : nil
    }

    func signIn(_ tokens: AuthTokens) {
        accessToken = tokens.accessToken
        refreshToken = tokens.refreshToken
        tokenStore.save(tokens)
    }

    func recordBackup(version: Int) {
        vaultVersion = version
        UserDefaults.standard.set(version, forKey: Self.versionKey)
    }

    func signOut() {
        accessToken = nil
        refreshToken = nil
        vaultVersion = nil
        tokenStore.clear()
        UserDefaults.standard.removeObject(forKey: Self.versionKey)
    }
}
