import Foundation
import CryptoKit

public struct TOTP {

    public enum Algorithm {
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
        return ""
    }
}
