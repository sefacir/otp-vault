import Foundation

public struct OtpAuthURI {
    public let issuer: String?
    public let account: String
    public let secret: Data
    public let algorithm: TOTP.Algorithm
    public let digits: Int
    public let period: TimeInterval

    public init(
        issuer: String?,
        account: String,
        secret: Data,
        algorithm: TOTP.Algorithm = .sha1,
        digits: Int = 6,
        period: TimeInterval = 30
    ) {
        self.issuer = issuer
        self.account = account
        self.secret = secret
        self.algorithm = algorithm
        self.digits = digits
        self.period = period
    }

    public var totp: TOTP {
        TOTP(secret: secret, digits: digits, period: period, algorithm: algorithm)
    }
}

public extension OtpAuthURI {
    static func parse(_ string: String) -> OtpAuthURI? {
        guard let components = URLComponents(string: string) else { return nil }
        guard components.scheme == "otpauth" else { return nil }
        guard components.host?.lowercased() == "totp" else { return nil }

        var label = components.path
        if label.hasPrefix("/") {
            label.removeFirst()
        }
        guard !label.isEmpty else { return nil }

        let issuerFromLabel: String?
        let account: String
        if let colon = label.firstIndex(of: ":") {
            issuerFromLabel = String(label[..<colon]).trimmingCharacters(in: .whitespaces)
            account = String(label[label.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
        } else {
            issuerFromLabel = nil
            account = label.trimmingCharacters(in: .whitespaces)
        }

        var params: [String: String] = [:]
        for item in components.queryItems ?? [] {
            params[item.name] = item.value
        }

        guard let secretValue = params["secret"],
              let secret = Base32.decode(secretValue),
              !secret.isEmpty
        else { return nil }

        let issuer = params["issuer"] ?? issuerFromLabel

        let algorithm: TOTP.Algorithm
        switch params["algorithm"]?.uppercased() {
        case "SHA256": algorithm = .sha256
        case "SHA512": algorithm = .sha512
        default: algorithm = .sha1
        }

        let digits = params["digits"].flatMap(Int.init) ?? 6
        let period = params["period"].flatMap(TimeInterval.init) ?? 30

        return OtpAuthURI(
            issuer: issuer,
            account: account,
            secret: secret,
            algorithm: algorithm,
            digits: digits,
            period: period
        )
    }
}
