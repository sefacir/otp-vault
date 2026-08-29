import Foundation
import Observation
import OtpVaultCore

@Observable
final class AccountStore {
    private static let service = "dev.otpvault"
    private static let key = "accounts.v1"

    private let store = CodableStore<[Account]>(
        store: KeychainStore(service: service),
        key: key
    )

    private(set) var accounts: [Account] = []

    init() {
        switch store.load() {
        case .missing:
            accounts = Account.samples
            store.save(accounts)
        case .corrupt:
            accounts = []
        case .value(let decoded):
            accounts = decoded
        }
    }

    func add(_ account: Account) {
        accounts.append(account)
        store.save(accounts)
    }

    func replaceAll(_ newAccounts: [Account]) {
        accounts = newAccounts
        store.save(accounts)
    }

    func delete(at offsets: IndexSet) {
        for index in offsets.sorted(by: >) {
            accounts.remove(at: index)
        }
        store.save(accounts)
    }

    func delete(_ account: Account) {
        accounts.removeAll { $0.id == account.id }
        store.save(accounts)
    }

    func update(_ account: Account) {
        guard let index = accounts.firstIndex(where: { $0.id == account.id }) else { return }
        accounts[index] = account
        store.save(accounts)
    }
}
