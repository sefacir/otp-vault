import XCTest
@testable import OtpVaultCore

private final class FakeBackend: BackendAPI, @unchecked Sendable {

    var envelope: String?
    var version = 0
    var putCalls: [(envelope: String, expected: Int?)] = []

    func register(email: String, password: String) async throws {}

    func login(email: String, password: String) async throws -> AuthTokens {
        AuthTokens(accessToken: "a", refreshToken: "r", expiresInSeconds: 900)
    }

    func refresh(refreshToken: String) async throws -> AuthTokens {
        AuthTokens(accessToken: "a2", refreshToken: "r2", expiresInSeconds: 900)
    }

    func getVault(accessToken: String) async throws -> VaultState? {
        guard let envelope else { return nil }
        return VaultState(envelope: envelope, version: version, updatedAt: "x")
    }

    func putVault(envelope: String, expectedVersion: Int?, accessToken: String) async throws -> Int {
        putCalls.append((envelope, expectedVersion))
        guard (expectedVersion ?? 0) == version else {
            throw BackendClient.ClientError.conflict
        }
        self.envelope = envelope
        version += 1
        return version
    }

    func deleteVault(accessToken: String) async throws {
        envelope = nil
        version = 0
    }
}

final class VaultSyncTests: XCTestCase {

    private let plaintext = Data(#"[{"issuer":"GitHub","label":"sefacir"}]"#.utf8)
    private let iterations = 1_000

    func testPushToEmptyVaultCreatesVersionOne() async throws {
        let backend = FakeBackend()
        let version = try await VaultSync.push(
            plaintext: plaintext, masterPassword: "pw", currentVersion: nil,
            accessToken: "t", api: backend, iterations: iterations
        )
        XCTAssertEqual(version, 1)
        XCTAssertNotNil(backend.envelope)
        XCTAssertNil(backend.putCalls.first?.expected)
    }

    func testPushThenPullRoundTrips() async throws {
        let backend = FakeBackend()
        _ = try await VaultSync.push(
            plaintext: plaintext, masterPassword: "pw", currentVersion: nil,
            accessToken: "t", api: backend, iterations: iterations
        )
        let result = try await VaultSync.pull(masterPassword: "pw", accessToken: "t", api: backend)
        XCTAssertEqual(result?.plaintext, plaintext)
        XCTAssertEqual(result?.version, 1)
    }

    func testPullFromEmptyVaultReturnsNil() async throws {
        let result = try await VaultSync.pull(masterPassword: "pw", accessToken: "t", api: FakeBackend())
        XCTAssertNil(result)
    }

    func testPushWithStaleVersionThrowsConflict() async {
        let backend = FakeBackend()
        backend.envelope = "{}"
        backend.version = 2
        do {
            _ = try await VaultSync.push(
                plaintext: plaintext, masterPassword: "pw", currentVersion: 1,
                accessToken: "t", api: backend, iterations: iterations
            )
            XCTFail("expected conflict")
        } catch BackendClient.ClientError.conflict {
            // expected
        } catch {
            XCTFail("unexpected \(error)")
        }
    }

    func testPullWithWrongPasswordFails() async throws {
        let backend = FakeBackend()
        _ = try await VaultSync.push(
            plaintext: plaintext, masterPassword: "right", currentVersion: nil,
            accessToken: "t", api: backend, iterations: iterations
        )
        do {
            _ = try await VaultSync.pull(masterPassword: "wrong", accessToken: "t", api: backend)
            XCTFail("expected failure")
        } catch let error as VaultCrypto.CryptoError {
            XCTAssertEqual(error, .decryptionFailed)
        } catch {
            XCTFail("unexpected \(error)")
        }
    }

    func testPullWithGarbageEnvelopeThrowsMalformed() async {
        let backend = FakeBackend()
        backend.envelope = "{ not an envelope"
        backend.version = 1
        do {
            _ = try await VaultSync.pull(masterPassword: "pw", accessToken: "t", api: backend)
            XCTFail("expected malformed")
        } catch let error as VaultCrypto.CryptoError {
            XCTAssertEqual(error, .malformedEnvelope)
        } catch {
            XCTFail("unexpected \(error)")
        }
    }

    func testPushStoresDecodableEnvelope() async throws {
        let backend = FakeBackend()
        _ = try await VaultSync.push(
            plaintext: plaintext, masterPassword: "pw", currentVersion: nil,
            accessToken: "t", api: backend, iterations: iterations
        )
        let data = try XCTUnwrap(backend.envelope?.data(using: .utf8))
        let envelope = try JSONDecoder().decode(BackupEnvelope.self, from: data)
        XCTAssertEqual(envelope.cipher, "AES-256-GCM")
        XCTAssertEqual(envelope.version, 1)
    }
}
