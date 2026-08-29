import SwiftUI
import LocalAuthentication

struct AppLock<Content: View>: View {
    @ViewBuilder var content: () -> Content

    @Environment(\.scenePhase) private var scenePhase
    @State private var unlocked = false
    @State private var authenticating = false
    @State private var wasBackgrounded = false

    var body: some View {
        ZStack {
            if unlocked && scenePhase == .active {
                content()
            } else if unlocked {
                PrivacyCover()
            } else {
                LockScreen(authenticating: authenticating, onUnlock: authenticate)
            }
        }
        .task { authenticate() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background {
                unlocked = false
                wasBackgrounded = true
            } else if phase == .active, wasBackgrounded {
                wasBackgrounded = false
                authenticate()
            }
        }
    }

    private func authenticate() {
        guard !authenticating, !unlocked else { return }

        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            unlocked = true
            return
        }

        authenticating = true
        context.evaluatePolicy(
            .deviceOwnerAuthentication,
            localizedReason: "Unlock OtpVault to view your codes."
        ) { success, _ in
            Task { @MainActor in
                authenticating = false
                unlocked = success
            }
        }
    }
}

private struct PrivacyCover: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("OtpVault")
                .font(.headline)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
    }
}

private struct LockScreen: View {
    let authenticating: Bool
    let onUnlock: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("OtpVault is locked")
                .font(.headline)
            Button("Unlock", action: onUnlock)
                .buttonStyle(.borderedProminent)
                .disabled(authenticating)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
    }
}
