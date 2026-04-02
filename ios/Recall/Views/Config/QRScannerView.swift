import AVFoundation
import SwiftUI

struct QRScannerView: View {
    let onScan: (QRServerConfig) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            // TODO: Implement AVCaptureSession-based QR scanner
            VStack {
                Image(systemName: "qrcode.viewfinder")
                    .font(.system(size: 80))
                    .foregroundStyle(.cyan)
                Text("QR Scanner")
                    .font(.headline.monospaced())
                Text("Point camera at server config QR code")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.black)
            .navigationTitle("Scan QR")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
