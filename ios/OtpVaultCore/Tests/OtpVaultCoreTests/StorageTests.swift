import XCTest
@testable import OtpVaultCore

private final class InMemoryStore: KeyValueStore, @unchecked Sendable {
    var items: [String: Data] = [:]
    func data(forKey key: String) -> Data? { items[key] }
    func set(_ data: Data, forKey key: String) { items[key] = data }
    func removeValue(forKey key: String) { items.removeValue(forKey: key) }
}

final class TokenStoreTests: XCTestCase {

    private let tokens = AuthTokens(accessToken: "a", refreshToken: "r", expiresInSeconds: 0)

    func testLoadReturnsNilWhenEmpty() {
        XCTAssertNil(TokenStore(store: InMemoryStore()).load())
    }

    func testSaveThenLoadRoundTrips() {
        let store = TokenStore(store: InMemoryStore())
        store.save(tokens)
        XCTAssertEqual(store.load(), tokens)
    }

    func testLoadNilWhenOnlyOneTokenPresent() {
        let backing = InMemoryStore()
        backing.set(Data("a".utf8), forKey: "auth.accessToken")
        XCTAssertNil(TokenStore(store: backing).load())
    }

    func testClearRemovesBoth() {
        let store = TokenStore(store: InMemoryStore())
        store.save(tokens)
        store.clear()
        XCTAssertNil(store.load())
    }
}

final class CodableStoreTests: XCTestCase {

    private struct Item: Codable, Equatable {
        let name: String
    }

    func testMissingWhenNoData() {
        let result = CodableStore<[Item]>(store: InMemoryStore(), key: "k").load()
        guard case .missing = result else {
            return XCTFail("expected .missing")
        }
    }

    func testValueWhenPresent() {
        let backing = InMemoryStore()
        let store = CodableStore<[Item]>(store: backing, key: "k")
        store.save([Item(name: "x")])
        guard case .value(let items) = store.load() else {
            return XCTFail("expected .value")
        }
        XCTAssertEqual(items, [Item(name: "x")])
    }

    func testCorruptWhenUndecodable() {
        let backing = InMemoryStore()
        backing.set(Data("not json".utf8), forKey: "k")
        guard case .corrupt = CodableStore<[Item]>(store: backing, key: "k").load() else {
            return XCTFail("expected .corrupt")
        }
    }
}
