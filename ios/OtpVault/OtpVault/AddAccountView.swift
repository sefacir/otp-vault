import SwiftUI
import OtpVaultCore

struct AddAccountView: View {
    let onSave: (Account) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var issuer = ""
    @State private var label = ""
    @State private var secret = ""

    private var decodedSecret: Data? {
        guard let data = Base32.decode(secret), !data.isEmpty else { return nil }
        return data
    }

    private var canSave: Bool {
        !issuer.trimmingCharacters(in: .whitespaces).isEmpty && decodedSecret != nil
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
                Section("Secret") {
                    TextField("Base32 secret", text: $secret)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .font(.system(.body, design: .monospaced))
                    if !secret.isEmpty && decodedSecret == nil {
                        Text("Not a valid Base32 secret")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Add Account")
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
        guard let data = decodedSecret else { return }
        let account = Account(
            issuer: issuer.trimmingCharacters(in: .whitespaces),
            label: label.trimmingCharacters(in: .whitespaces),
            totp: TOTP(secret: data)
        )
        onSave(account)
        dismiss()
    }
}

#Preview {
    AddAccountView { _ in }
}
