import SwiftUI

struct EditAccountView: View {
    let account: Account
    let onSave: (Account) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var issuer: String
    @State private var label: String

    init(account: Account, onSave: @escaping (Account) -> Void) {
        self.account = account
        self.onSave = onSave
        _issuer = State(initialValue: account.issuer)
        _label = State(initialValue: account.label)
    }

    private var canSave: Bool {
        !issuer.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Account") {
                    TextField("Issuer", text: $issuer)
                        .textInputAutocapitalization(.words)
                    TextField("Label", text: $label)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            }
            .navigationTitle("Edit Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                }
            }
        }
    }

    private func save() {
        var updated = account
        updated.issuer = issuer.trimmingCharacters(in: .whitespaces)
        updated.label = label.trimmingCharacters(in: .whitespaces)
        onSave(updated)
        dismiss()
    }
}
