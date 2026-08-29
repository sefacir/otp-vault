import Foundation

public protocol KeyValueStore: Sendable {
    func data(forKey key: String) -> Data?
    func set(_ data: Data, forKey key: String)
    func removeValue(forKey key: String)
}

public enum StoredValue<T> {
    case missing
    case corrupt
    case value(T)
}

public struct TokenStore {

    private let store: KeyValueStore
    private let accessKey: String
    private let refreshKey: String

    public init(
        store: KeyValueStore,
        accessKey: String = "auth.accessToken",
        refreshKey: String = "auth.refreshToken"
    ) {
        self.store = store
        self.accessKey = accessKey
        self.refreshKey = refreshKey
    }

    public func load() -> AuthTokens? {
        guard
            let accessData = store.data(forKey: accessKey),
            let refreshData = store.data(forKey: refreshKey)
        else {
            return nil
        }
        return AuthTokens(
            accessToken: String(decoding: accessData, as: UTF8.self),
            refreshToken: String(decoding: refreshData, as: UTF8.self),
            expiresInSeconds: 0
        )
    }

    public func save(_ tokens: AuthTokens) {
        store.set(Data(tokens.accessToken.utf8), forKey: accessKey)
        store.set(Data(tokens.refreshToken.utf8), forKey: refreshKey)
    }

    public func clear() {
        store.removeValue(forKey: accessKey)
        store.removeValue(forKey: refreshKey)
    }
}

public struct CodableStore<T: Codable> {

    private let store: KeyValueStore
    private let key: String

    public init(store: KeyValueStore, key: String) {
        self.store = store
        self.key = key
    }

    public func load() -> StoredValue<T> {
        guard let data = store.data(forKey: key) else {
            return .missing
        }
        guard let decoded = try? JSONDecoder().decode(T.self, from: data) else {
            return .corrupt
        }
        return .value(decoded)
    }

    public func save(_ value: T) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        store.set(data, forKey: key)
    }
}
