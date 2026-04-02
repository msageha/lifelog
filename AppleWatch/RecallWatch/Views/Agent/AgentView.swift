import SwiftUI

struct AgentView: View {
    @Bindable var viewModel: AgentViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(viewModel.isWebSocketConnected ? .green : .red)
                        .frame(width: 6, height: 6)
                    Text(viewModel.isWebSocketConnected ? "CONNECTED" : "OFFLINE")
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                    Spacer()
                }

                if viewModel.messages.isEmpty {
                    Text("No messages")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .padding(.top, 20)
                } else {
                    ForEach(viewModel.messages) { message in
                        WatchMessageBubble(message: message)
                    }
                }

                HStack {
                    Text("Vol")
                        .font(.system(size: 10).monospaced())
                    Slider(
                        value: Binding(
                            get: { Double(viewModel.volume) },
                            set: { viewModel.volume = Float($0) }
                        ),
                        in: 0...1
                    )
                }
                .padding(.top, 8)
            }
            .padding(.horizontal)
        }
        .navigationTitle("AGENT")
    }
}

private struct WatchMessageBubble: View {
    let message: AgentMessage

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(message.textContent)
                .font(.caption2)
            Text(DateFormatting.shortTimeString(from: message.receivedAt))
                .font(.system(size: 9).monospaced())
                .foregroundStyle(.secondary)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
    }
}
