import SwiftUI

struct ConfigView: View {
    @Bindable var viewModel: ConfigViewModel
    @State private var showQRScanner = false

    var body: some View {
        NavigationStack {
            Form {
                Section("SERVER") {
                    TextField("Upload Server URL", text: $viewModel.uploadServerURL)
                        .textContentType(.URL)
                        .autocorrectionDisabled()
                    TextField("Telemetry Server URL", text: $viewModel.telemetryServerURL)
                        .textContentType(.URL)
                        .autocorrectionDisabled()
                    TextField("WebSocket Server URL", text: $viewModel.webSocketServerURL)
                        .textContentType(.URL)
                        .autocorrectionDisabled()
                    SecureField("Bearer Token", text: $viewModel.bearerToken)

                    Button {
                        showQRScanner = true
                    } label: {
                        Label("Scan QR Code", systemImage: "qrcode.viewfinder")
                    }

                    Button("Save", action: viewModel.saveServerSettings)
                        .buttonStyle(.borderedProminent)
                        .tint(.cyan)
                }

                Section("TELEMETRY STREAMS") {
                    Toggle("Health", isOn: $viewModel.isHealthEnabled)
                    Toggle("Location", isOn: $viewModel.isLocationEnabled)
                    Toggle("Background Location", isOn: $viewModel.isBackgroundLocationEnabled)
                    Toggle("Motion", isOn: $viewModel.isMotionEnabled)
                }

                Section("NETWORK") {
                    Toggle("WiFi Only Upload", isOn: $viewModel.isWiFiOnly)
                }

                Section("STORAGE") {
                    HStack {
                        Text("Used")
                        Spacer()
                        Text(ByteCountFormatter.string(fromByteCount: Int64(viewModel.storageUsedBytes), countStyle: .file))
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Capacity")
                        Spacer()
                        Text(ByteCountFormatter.string(fromByteCount: Int64(viewModel.storageCapacityBytes), countStyle: .file))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("CONFIG")
            .sheet(isPresented: $showQRScanner) {
                QRScannerView { config in
                    viewModel.applyQRConfig(config)
                    showQRScanner = false
                }
            }
        }
    }
}
