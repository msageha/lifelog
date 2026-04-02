import SwiftUI

struct UploadView: View {
    @Bindable var viewModel: UploadViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                HStack(spacing: 4) {
                    Image(systemName: viewModel.serverConnected ? "wifi" : "wifi.slash")
                        .foregroundStyle(viewModel.serverConnected ? .green : .red)
                        .font(.caption)
                    Text(viewModel.serverConnected ? "CONNECTED" : "OFFLINE")
                        .font(.caption2.monospaced())
                }

                HStack(spacing: 8) {
                    UploadStatBadge(title: "PEND", count: viewModel.pendingCount, color: .yellow)
                    UploadStatBadge(title: "DONE", count: viewModel.uploadedCount, color: .green)
                    UploadStatBadge(title: "FAIL", count: viewModel.failedCount, color: .red)
                }

                Button(action: viewModel.retryFailed) {
                    Label("RETRY", systemImage: "arrow.clockwise")
                        .font(.caption.monospaced())
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .disabled(viewModel.failedCount == 0)
            }
            .padding(.horizontal)
        }
        .navigationTitle("UPLOAD")
    }
}

private struct UploadStatBadge: View {
    let title: String
    let count: Int
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.system(size: 9).monospaced())
                .foregroundStyle(.secondary)
            Text("\(count)")
                .font(.caption.monospaced().bold())
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
    }
}
