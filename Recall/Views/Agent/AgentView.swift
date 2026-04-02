import SwiftUI

struct AgentView: View {
    @Bindable var viewModel: AgentViewModel

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Connection status
                HStack {
                    Circle()
                        .fill(viewModel.isWebSocketConnected ? .green : .red)
                        .frame(width: 8, height: 8)
                    Text(viewModel.isWebSocketConnected ? "CONNECTED" : "DISCONNECTED")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 8)

                // Messages
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(viewModel.messages) { message in
                            MessageBubble(message: message)
                        }
                    }
                    .padding()
                }

                // Spatial audio settings
                SpatialAudioSettingsView(viewModel: viewModel)
            }
            .navigationTitle("AGENT")
        }
    }
}

private struct MessageBubble: View {
    let message: AgentMessage

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 4) {
                Text(message.textContent)
                    .font(.body)
                Text(DateFormatting.shortTimeString(from: message.receivedAt))
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
            }
        }
    }
}
