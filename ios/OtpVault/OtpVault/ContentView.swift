import SwiftUI

struct ContentView: View {
    var body: some View {
        AppLock {
            AccountsView()
        }
    }
}

#Preview {
    ContentView()
}
