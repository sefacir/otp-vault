import Foundation
import OtpVaultCore

struct Account: Identifiable {
    let id = UUID()
    let issuer: String
    let label: String
    let totp: TOTP
}

extension Account {
    static let samples: [Account] = [
        Account(
            issuer: "GitHub",
            label: "sefacir",
            totp: TOTP(secret: Base32.decode("JBSWY3DPEHPK3PXP") ?? Data())
        ),
        Account(
            issuer: "Google",
            label: "ecirsefa@gmail.com",
            totp: TOTP(secret: Base32.decode("GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ") ?? Data())
        ),
        Account(
            issuer: "AWS",
            label: "root",
            totp: TOTP(secret: Base32.decode("KRSXG5CTMVRXEZLUKN2XAZLSKNSWG4TFOQ") ?? Data())
        )
    ]
}
