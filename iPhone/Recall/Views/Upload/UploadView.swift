import SwiftUI

struct UploadView: View {
    @Bindable var viewModel: UploadViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Connection status
                    GlassCard {
                        HStack {
                            Image(systemName: viewModel.serverConnected ? "wifi" : "wifi.slash")
                                .foregroundStyle(viewModel.serverConnected ? .green : .red)
                            Text(viewModel.serverConnected ? "CONNECTED" : "DISCONNECTED")
                                .font(.headline.monospaced())
                        }
                    }

                    // Upload stats
                    GlassCard {
                        HStack(spacing: 20) {
                            UploadStatItem(title: "PENDING", count: viewModel.pendingCount, color: .yellow)
                            UploadStatItem(title: "UPLOADED", count: viewModel.uploadedCount, color: .green)
                            UploadStatItem(title: "FAILED", count: viewModel.failedCount, color: .red)
                        }
                    }

                    // Controls
                    GlassCard {
                        VStack(spacing: 12) {
                            Button(action: viewModel.retryFailed) {
                                Label("RETRY FAILED", systemImage: "arrow.clockwise")
                                    .font(.headline.monospaced())
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.orange)
                            .disabled(viewModel.failedCount == 0)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("UPLOAD")
        }
    }
}

private struct UploadStatItem: View {
    let title: String
    let count: Int
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)
            Text("\(count)")
                .font(.title2.monospaced().bold())
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
    }
}
