import SwiftUI
import VisionKit
import Vision
import OtpVaultCore

struct ScanSheet: View {
    let onResult: (OtpAuthURI) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var invalidCode = false

    private var scanningAvailable: Bool {
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }

    var body: some View {
        NavigationStack {
            Group {
                if scanningAvailable {
                    ScannerRepresentable { payload in
                        if let uri = OtpAuthURI.parse(payload) {
                            onResult(uri)
                            dismiss()
                        } else {
                            invalidCode = true
                        }
                    }
                    .ignoresSafeArea(edges: .bottom)
                } else {
                    ContentUnavailableView(
                        "Camera unavailable",
                        systemImage: "camera.fill",
                        description: Text("QR scanning needs a real device with a camera.")
                    )
                }
            }
            .navigationTitle("Scan QR")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Not a valid code", isPresented: $invalidCode) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("That QR code isn't an otpauth:// key.")
            }
        }
    }
}

private struct ScannerRepresentable: UIViewControllerRepresentable {
    let onScan: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.qr])],
            qualityLevel: .balanced,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ scanner: DataScannerViewController, context: Context) {
        try? scanner.startScanning()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onScan: onScan)
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onScan: (String) -> Void
        private var handled = false

        init(onScan: @escaping (String) -> Void) {
            self.onScan = onScan
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didAdd addedItems: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {
            guard !handled else { return }
            for case let .barcode(barcode) in addedItems {
                if let value = barcode.payloadStringValue {
                    handled = true
                    onScan(value)
                    return
                }
            }
        }
    }
}
