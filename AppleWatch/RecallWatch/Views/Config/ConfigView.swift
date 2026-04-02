import SwiftUI

struct ConfigView: View {
    @Bindable var viewModel: ConfigViewModel

    var body: some View {
        List {
            Section("SERVER") {
                TextField("Upload URL", text: $viewModel.uploadServerURL)
                    .font(.caption2)
                    .autocorrectionDisabled()
                TextField("Telemetry URL", text: $viewModel.telemetryServerURL)
                    .font(.caption2)
                    .autocorrectionDisabled()
                TextField("WebSocket URL", text: $viewModel.webSocketServerURL)
                    .font(.caption2)
                    .autocorrectionDisabled()
                SecureField("Token", text: $viewModel.bearerToken)
                    .font(.caption2)

                Button("Save", action: viewModel.saveServerSettings)
                    .tint(.cyan)
            }

            Section("TELEMETRY") {
                Toggle("Health", isOn: $viewModel.isHealthEnabled)
                    .font(.caption2)
                Toggle("Location", isOn: $viewModel.isLocationEnabled)
                    .font(.caption2)
                Toggle("Motion", isOn: $viewModel.isMotionEnabled)
                    .font(.caption2)
            }

            Section("NETWORK") {
                Toggle("WiFi Only", isOn: $viewModel.isWiFiOnly)
                    .font(.caption2)
            }

            Section("STORAGE") {
                HStack {
                    Text("Used")
                        .font(.caption2)
                    Spacer()
                    Text(ByteCountFormatter.string(fromByteCount: Int64(viewModel.storageUsedBytes), countStyle: .file))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Cap")
                        .font(.caption2)
                    Spacer()
                    Text(ByteCountFormatter.string(fromByteCount: Int64(viewModel.storageCapacityBytes), countStyle: .file))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("CONFIG")
    }
}
