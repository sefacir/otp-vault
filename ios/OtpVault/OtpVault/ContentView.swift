import SwiftUI
import OtpVaultCore

struct ContentView: View {
    private let deviceCompromised = DeviceIntegrity.isCompromised()

    var body: some View {
        AppLock {
            VStack(spacing: 0) {
                if deviceCompromised {
                    Label("This device appears jailbroken — your secrets may not be safe.",
                          systemImage: "exclamationmark.shield.fill")
                        .font(.footnote)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(8)
                        .background(.red)
                }
                AccountsView()
            }
        }
    }
}

#Preview {
    ContentView()
}
