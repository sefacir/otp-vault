import Foundation

public struct KdfParams: Codable, Equatable, Sendable {
    public let algorithm: String
    public let iterations: Int
    public let saltBase64: String

    public init(algorithm: String, iterations: Int, saltBase64: String) {
        self.algorithm = algorithm
        self.iterations = iterations
        self.saltBase64 = saltBase64
    }
}

public struct BackupEnvelope: Codable, Equatable, Sendable {
    public let format: Int
    public let version: Int
    public let kdf: KdfParams
    public let cipher: String
    public let blobBase64: String

    public init(format: Int = 2, version: Int, kdf: KdfParams, cipher: String, blobBase64: String) {
        self.format = format
        self.version = version
        self.kdf = kdf
        self.cipher = cipher
        self.blobBase64 = blobBase64
    }
}
