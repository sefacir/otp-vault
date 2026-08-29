import XCTest
@testable import OtpVaultCore

final class MockURLProtocol: URLProtocol {

    nonisolated(unsafe) static var responder: ((URLRequest) -> (Int, Data))?
    nonisolated(unsafe) static var lastRequest: URLRequest?
    nonisolated(unsafe) static var lastBody: Data?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        MockURLProtocol.lastRequest = request
        MockURLProtocol.lastBody = Self.readBody(request)

        let (code, data) = MockURLProtocol.responder?(request) ?? (500, Data())
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: code,
            httpVersion: nil,
            headerFields: nil
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    private static func readBody(_ request: URLRequest) -> Data? {
        if let body = request.httpBody {
            return body
        }
        guard let stream = request.httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }
        var data = Data()
        let size = 4096
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: size)
        defer { buffer.deallocate() }
        while stream.hasBytesAvailable {
            let read = stream.read(buffer, maxLength: size)
            if read <= 0 { break }
            data.append(buffer, count: read)
        }
        return data
    }
}

final class BackendClientTests: XCTestCase {

    private var client: BackendClient!

    override func setUp() {
        super.setUp()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        client = BackendClient(baseURL: URL(string: "https://api.test")!,
                               session: URLSession(configuration: config))
    }

    override func tearDown() {
        MockURLProtocol.responder = nil
        MockURLProtocol.lastRequest = nil
        MockURLProtocol.lastBody = nil
        super.tearDown()
    }

    private func respond(_ code: Int, _ json: String = "{}") {
        MockURLProtocol.responder = { _ in (code, Data(json.utf8)) }
    }

    private func assertThrows(
        _ expected: BackendClient.ClientError,
        _ block: () async throws -> Void,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            try await block()
            XCTFail("expected \(expected)", file: file, line: line)
        } catch let error as BackendClient.ClientError {
            XCTAssertEqual(error, expected, file: file, line: line)
        } catch {
            XCTFail("unexpected error \(error)", file: file, line: line)
        }
    }

    func testLoginParsesTokens() async throws {
        respond(200, #"{"accessToken":"a","refreshToken":"r","expiresInSeconds":900}"#)
        let tokens = try await client.login(email: "x@y.z", password: "pw")
        XCTAssertEqual(tokens, BackendClient.Tokens(accessToken: "a", refreshToken: "r", expiresInSeconds: 900))
    }

    func testLoginUnauthorized() async {
        respond(401)
        await assertThrows(.unauthorized) { _ = try await self.client.login(email: "x@y.z", password: "bad") }
    }

    func testLoginAccountLocked() async {
        respond(423)
        await assertThrows(.accountLocked) { _ = try await self.client.login(email: "x@y.z", password: "pw") }
    }

    func testRegisterConflict() async {
        respond(409)
        await assertThrows(.conflict) { try await self.client.register(email: "a@b.c", password: "password123") }
    }

    func testRegisterRateLimited() async {
        respond(429)
        await assertThrows(.rateLimited) { try await self.client.register(email: "a@b.c", password: "password123") }
    }

    func testGetVaultNotFoundReturnsNil() async throws {
        respond(404)
        let state = try await client.getVault(accessToken: "t")
        XCTAssertNil(state)
    }

    func testGetVaultOkParsesState() async throws {
        respond(200, #"{"envelope":"blob","version":2,"updatedAt":"2026-01-01T00:00:00Z"}"#)
        let state = try await client.getVault(accessToken: "t")
        XCTAssertEqual(state?.envelope, "blob")
        XCTAssertEqual(state?.version, 2)
    }

    func testGetVaultSendsBearerHeader() async throws {
        respond(200, #"{"envelope":"b","version":1,"updatedAt":"x"}"#)
        _ = try await client.getVault(accessToken: "abc123")
        XCTAssertEqual(MockURLProtocol.lastRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer abc123")
    }

    func testPutVaultSendsEnvelopeVersionAndParsesResult() async throws {
        respond(200, #"{"version":5,"updatedAt":"x"}"#)
        let version = try await client.putVault(envelope: "ENV", expectedVersion: 4, accessToken: "tok")
        XCTAssertEqual(version, 5)

        let body = MockURLProtocol.lastBody
            .flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
        XCTAssertEqual(body?["envelope"] as? String, "ENV")
        XCTAssertEqual(body?["expectedVersion"] as? Int, 4)
        XCTAssertEqual(MockURLProtocol.lastRequest?.httpMethod, "PUT")
        XCTAssertEqual(MockURLProtocol.lastRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer tok")
    }

    func testPutVaultOmitsVersionWhenNil() async throws {
        respond(200, #"{"version":1,"updatedAt":"x"}"#)
        _ = try await client.putVault(envelope: "ENV", expectedVersion: nil, accessToken: "tok")
        let body = MockURLProtocol.lastBody
            .flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
        XCTAssertNil(body?["expectedVersion"])
    }

    func testPutVaultConflict() async {
        respond(409)
        await assertThrows(.conflict) {
            _ = try await self.client.putVault(envelope: "e", expectedVersion: 1, accessToken: "t")
        }
    }

    func testServerErrorCarriesStatus() async {
        respond(503)
        await assertThrows(.server(503)) { _ = try await self.client.login(email: "a@b.c", password: "pw") }
    }

    func testMalformedJsonThrowsDecoding() async {
        respond(200, "{ not json")
        await assertThrows(.decoding) { _ = try await self.client.login(email: "a@b.c", password: "pw") }
    }
}
