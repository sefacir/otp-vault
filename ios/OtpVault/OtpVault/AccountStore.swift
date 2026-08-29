import Foundation
import Observation

@Observable
final class AccountStore {
    private static let service = "dev.otpvault"
    private static let account = "accounts.v1"

    private(set) var accounts: [Account] = []

    init() {
        load()
    }

    func add(_ account: Account) {
        accounts.append(account)
        persist()
    }

    func delete(at offsets: IndexSet) {
        for index in offsets.sorted(by: >) {
            accounts.remove(at: index)
        }
        persist()
    }

    func delete(_ account: Account) {
        accounts.removeAll { $0.id == account.id }
        persist()
    }

    private func load() {
        guard
            let data = Keychain.read(service: Self.service, account: Self.account),
            let decoded = try? JSONDecoder().decode([Account].self, from: data)
        else {
            accounts = Account.samples
            persist()
            return
        }
        accounts = decoded
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(accounts) else { return }
        try? Keychain.write(data, service: Self.service, account: Self.account)
    }
}
