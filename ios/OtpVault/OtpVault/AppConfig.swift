import Foundation
import OtpVaultCore

enum AppConfig {

    static var apiBaseURL: URL {
        if
            let raw = Bundle.main.object(forInfoDictionaryKey: "OTPVAULT_API_URL") as? String,
            let url = URL(string: raw)
        {
            return url
        }
        return URL(string: "http://localhost:8080")!
    }

    static var certificatePinning: CertificatePinning {
        let raw = Bundle.main.object(forInfoDictionaryKey: "OTPVAULT_PINNED_CERT_SHA256") as? String ?? ""
        let hashes = raw
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return CertificatePinning(pinnedCertificateHashes: Set(hashes))
    }

    static let minimumMasterPasswordLength = 10
}
