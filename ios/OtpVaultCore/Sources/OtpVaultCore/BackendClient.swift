import Foundation

public struct AuthTokens: Codable, Equatable, Sendable {
    public let accessToken: String
    public let refreshToken: String
    public let expiresInSeconds: Int

    public init(accessToken: String, refreshToken: String, expiresInSeconds: Int) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresInSeconds = expiresInSeconds
    }
}

public struct VaultState: Codable, Equatable, Sendable {
    public let envelope: String
    public let version: Int
    public let updatedAt: String

    public init(envelope: String, version: Int, updatedAt: String) {
        self.envelope = envelope
        self.version = version
        self.updatedAt = updatedAt
    }
}

public protocol BackendAPI: Sendable {
    func register(email: String, password: String) async throws
    func login(email: String, password: String) async throws -> AuthTokens
    func refresh(refreshToken: String) async throws -> AuthTokens
    func logout(accessToken: String) async throws
    func getVault(accessToken: String) async throws -> VaultState?
    func putVault(envelope: String, expectedVersion: Int?, accessToken: String) async throws -> Int
    func deleteVault(accessToken: String) async throws
}

public struct BackendClient: BackendAPI, Sendable {

    public enum ClientError: Error, Equatable, Sendable {
        case badRequest
        case unauthorized
        case notFound
        case conflict
        case accountLocked
        case rateLimited
        case server(Int)
        case transport
        case decoding
    }

    private struct PutVaultResult: Decodable {
        let version: Int
    }

    private let baseURL: URL
    private let session: URLSession

    public init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    public init(baseURL: URL, pinning: CertificatePinning) {
        self.baseURL = baseURL
        if pinning.isEnabled {
            self.session = URLSession(
                configuration: .ephemeral,
                delegate: PinnedSessionDelegate(pinning: pinning),
                delegateQueue: nil
            )
        } else {
            self.session = .shared
        }
    }

    public func register(email: String, password: String) async throws {
        _ = try await send("/auth/register", method: "POST",
                           body: ["email": email, "password": password], accessToken: nil)
    }

    public func login(email: String, password: String) async throws -> AuthTokens {
        let data = try await send("/auth/login", method: "POST",
                                  body: ["email": email, "password": password], accessToken: nil)
        return try decode(AuthTokens.self, from: data)
    }

    public func refresh(refreshToken: String) async throws -> AuthTokens {
        let data = try await send("/auth/refresh", method: "POST",
                                  body: ["refreshToken": refreshToken], accessToken: nil)
        return try decode(AuthTokens.self, from: data)
    }

    public func logout(accessToken: String) async throws {
        _ = try await send("/auth/logout", method: "POST", body: nil, accessToken: accessToken)
    }

    public func getVault(accessToken: String) async throws -> VaultState? {
        do {
            let data = try await send("/vault", method: "GET", body: nil, accessToken: accessToken)
            return try decode(VaultState.self, from: data)
        } catch ClientError.notFound {
            return nil
        }
    }

    public func putVault(envelope: String, expectedVersion: Int?, accessToken: String) async throws -> Int {
        var body: [String: Any] = ["envelope": envelope]
        if let expectedVersion {
            body["expectedVersion"] = expectedVersion
        }
        let data = try await send("/vault", method: "PUT", body: body, accessToken: accessToken)
        return try decode(PutVaultResult.self, from: data).version
    }

    public func deleteVault(accessToken: String) async throws {
        _ = try await send("/vault", method: "DELETE", body: nil, accessToken: accessToken)
    }

    private func send(
        _ path: String,
        method: String,
        body: [String: Any]?,
        accessToken: String?
    ) async throws -> Data {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = method
        if let accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw ClientError.transport
        }

        guard let http = response as? HTTPURLResponse else {
            throw ClientError.transport
        }

        switch http.statusCode {
        case 200...299:
            return data
        case 400:
            throw ClientError.badRequest
        case 401, 403:
            throw ClientError.unauthorized
        case 404:
            throw ClientError.notFound
        case 409:
            throw ClientError.conflict
        case 423:
            throw ClientError.accountLocked
        case 429:
            throw ClientError.rateLimited
        default:
            throw ClientError.server(http.statusCode)
        }
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw ClientError.decoding
        }
    }
}
