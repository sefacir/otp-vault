import Foundation
import Observation
import OtpVaultCore

@Observable
final class Session {

    private static let service = "dev.otpvault"
    private static let accessAccount = "auth.accessToken"
    private static let refreshAccount = "auth.refreshToken"
    private static let versionKey = "otpvault.vaultVersion"

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
        accessToken = readString(Self.accessAccount)
        refreshToken = readString(Self.refreshAccount)
        let stored = UserDefaults.standard.integer(forKey: Self.versionKey)
        vaultVersion = stored > 0 ? stored : nil
    }

    func signIn(_ tokens: AuthTokens) {
        accessToken = tokens.accessToken
        refreshToken = tokens.refreshToken
        writeString(tokens.accessToken, Self.accessAccount)
        writeString(tokens.refreshToken, Self.refreshAccount)
    }

    func recordBackup(version: Int) {
        vaultVersion = version
        UserDefaults.standard.set(version, forKey: Self.versionKey)
    }

    func signOut() {
        accessToken = nil
        refreshToken = nil
        vaultVersion = nil
        Keychain.delete(service: Self.service, account: Self.accessAccount)
        Keychain.delete(service: Self.service, account: Self.refreshAccount)
        UserDefaults.standard.removeObject(forKey: Self.versionKey)
    }

    private func readString(_ account: String) -> String? {
        Keychain.read(service: Self.service, account: account)
            .map { String(decoding: $0, as: UTF8.self) }
    }

    private func writeString(_ value: String, _ account: String) {
        try? Keychain.write(Data(value.utf8), service: Self.service, account: account)
    }
}
