import SwiftUI

@main
struct OtpVaultApp: App {
    @State private var session = Session()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(session)
        }
    }
}
