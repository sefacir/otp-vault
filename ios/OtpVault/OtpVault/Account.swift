import Foundation
import OtpVaultCore

struct Account: Identifiable, Codable {
    let id: UUID
    var issuer: String
    var label: String
    var secret: Data
    var digits: Int
    var period: TimeInterval
    var algorithm: TOTP.Algorithm

    init(
        id: UUID = UUID(),
        issuer: String,
        label: String,
        secret: Data,
        digits: Int = 6,
        period: TimeInterval = 30,
        algorithm: TOTP.Algorithm = .sha1
    ) {
        self.id = id
        self.issuer = issuer
        self.label = label
        self.secret = secret
        self.digits = digits
        self.period = period
        self.algorithm = algorithm
    }

    var totp: TOTP {
        TOTP(secret: secret, digits: digits, period: period, algorithm: algorithm)
    }
}

extension Account {
    init(from uri: OtpAuthURI) {
        self.init(
            issuer: uri.issuer ?? "",
            label: uri.account,
            secret: uri.secret,
            digits: uri.digits,
            period: uri.period,
            algorithm: uri.algorithm
        )
    }

    static let samples: [Account] = [
        Account(issuer: "GitHub", label: "sefacir", secret: Base32.decode("JBSWY3DPEHPK3PXP") ?? Data()),
        Account(issuer: "Google", label: "ecirsefa@gmail.com", secret: Base32.decode("GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ") ?? Data()),
        Account(issuer: "AWS", label: "root", secret: Base32.decode("KRSXG5CTMVRXEZLUKN2XAZLSKNSWG4TFOQ") ?? Data())
    ]
}
