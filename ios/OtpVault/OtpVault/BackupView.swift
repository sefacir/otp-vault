import SwiftUI
import OtpVaultCore

struct BackupView: View {
    let accounts: [Account]

    @Environment(Session.self) private var session
    @Environment(\.dismiss) private var dismiss

    @State private var controller = BackupController()
    @State private var email = ""
    @State private var password = ""
    @State private var masterPassword = ""
    @State private var createAccount = false

    var body: some View {
        NavigationStack {
            Form {
                if session.isSignedIn {
                    backupSection
                    accountSection
                } else {
                    signInSection
                }
                statusSection
            }
            .navigationTitle("Backup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var signInSection: some View {
        Section("Sign in") {
            TextField("Email", text: $email)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
                .autocorrectionDisabled()
            SecureField("Password", text: $password)
            Toggle("Create a new account", isOn: $createAccount)
            Button(createAccount ? "Create account" : "Sign in") {
                Task {
                    if let tokens = await controller.authenticate(
                        email: email, password: password, createAccount: createAccount
                    ) {
                        session.signIn(tokens)
                        password = ""
                    }
                }
            }
            .disabled(email.isEmpty || password.count < 8 || isWorking)
        }
    }

    private var backupSection: some View {
        Section("Encrypted backup") {
            SecureField("Master password", text: $masterPassword)
            if let version = session.vaultVersion {
                LabeledContent("Last backup", value: "v\(version)")
            }
            Button("Back up now") {
                Task {
                    guard let tokens = session.tokens else { return }
                    if let result = await controller.backUp(
                        accounts: accounts,
                        masterPassword: masterPassword,
                        tokens: tokens,
                        knownVersion: session.vaultVersion
                    ) {
                        session.signIn(result.tokens)
                        session.recordBackup(version: result.version)
                        masterPassword = ""
                    }
                }
            }
            .disabled(masterPassword.count < 8 || accounts.isEmpty || isWorking)
        }
    }

    private var accountSection: some View {
        Section {
            Button("Sign out", role: .destructive) {
                session.signOut()
            }
        }
    }

    @ViewBuilder
    private var statusSection: some View {
        switch controller.phase {
        case .working:
            Section { HStack { ProgressView(); Text("Working…") } }
        case .done(let version):
            Section { Label("Backed up (v\(version))", systemImage: "checkmark.circle") .foregroundStyle(.green) }
        case .error(let message):
            Section { Label(message, systemImage: "exclamationmark.triangle").foregroundStyle(.red) }
        case .idle:
            EmptyView()
        }
    }

    private var isWorking: Bool {
        controller.phase == .working
    }
}
