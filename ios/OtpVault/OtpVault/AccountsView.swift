import SwiftUI
import OtpVaultCore

struct AccountsView: View {
    @State private var store = AccountStore()
    @State private var showingAdd = false

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                List {
                    ForEach(store.accounts) { account in
                        AccountRow(account: account, now: context.date)
                    }
                    .onDelete(perform: store.delete)
                }
            }
            .navigationTitle("Accounts")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAdd = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAdd) {
                AddAccountView { store.add($0) }
            }
        }
    }
}

private struct AccountRow: View {
    let account: Account
    let now: Date

    private var code: String {
        account.totp.code(at: now)
    }

    private var remaining: Double {
        let period = account.totp.period
        return period - now.timeIntervalSince1970.truncatingRemainder(dividingBy: period)
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(account.issuer)
                    .font(.headline)
                Text(account.label)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(grouped(code))
                .font(.system(.title2, design: .monospaced))
                .monospacedDigit()

            CountdownRing(remaining: remaining, period: account.totp.period)
                .frame(width: 22, height: 22)
        }
        .padding(.vertical, 4)
    }

    private func grouped(_ code: String) -> String {
        guard code.count == 6 else { return code }
        let mid = code.index(code.startIndex, offsetBy: 3)
        return String(code[..<mid]) + " " + String(code[mid...])
    }
}

private struct CountdownRing: View {
    let remaining: Double
    let period: Double

    var body: some View {
        Circle()
            .trim(from: 0, to: remaining / period)
            .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
            .rotationEffect(.degrees(-90))
    }
}

#Preview {
    AccountsView()
}
