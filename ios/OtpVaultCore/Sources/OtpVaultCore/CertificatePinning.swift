import CryptoKit
import Foundation

public struct CertificatePinning: Sendable {

    public let pinnedCertificateHashes: Set<String>

    public init(pinnedCertificateHashes: Set<String> = []) {
        self.pinnedCertificateHashes = pinnedCertificateHashes
    }

    public var isEnabled: Bool {
        !pinnedCertificateHashes.isEmpty
    }

    public func matches(certificateDER: Data) -> Bool {
        let digest = SHA256.hash(data: certificateDER)
        return pinnedCertificateHashes.contains(Data(digest).base64EncodedString())
    }
}
