import Foundation
import CryptoKit

public struct TOTP {

    public enum Algorithm: String, Codable, Sendable {
        case sha1
        case sha256
        case sha512
    }

    public let secret: Data
    public let digits: Int
    public let period: TimeInterval
    public let algorithm: Algorithm

    public init(
        secret: Data,
        digits: Int = 6,
        period: TimeInterval = 30,
        algorithm: Algorithm = .sha1
    ) {
        self.secret = secret
        self.digits = digits
        self.period = period
        self.algorithm = algorithm
    }

    public func code(at date: Date = Date()) -> String {
        let counter = UInt64(date.timeIntervalSince1970 / period)
        var bigEndianCounter = counter.bigEndian
        let message = withUnsafeBytes(of: &bigEndianCounter) { Data($0) }

        let key = SymmetricKey(data: secret)
        let hash: [UInt8]
        switch algorithm {
        case .sha1:
            hash = Array(HMAC<Insecure.SHA1>.authenticationCode(for: message, using: key))
        case .sha256:
            hash = Array(HMAC<SHA256>.authenticationCode(for: message, using: key))
        case .sha512:
            hash = Array(HMAC<SHA512>.authenticationCode(for: message, using: key))
        }

        let offset = Int(hash[hash.count - 1] & 0x0f)
        let binary = (UInt32(hash[offset] & 0x7f) << 24)
            | (UInt32(hash[offset + 1]) << 16)
            | (UInt32(hash[offset + 2]) << 8)
            | UInt32(hash[offset + 3])

        let modulo = UInt32(pow(10, Double(digits)))
        return String(format: "%0\(digits)u", binary % modulo)
    }
}
