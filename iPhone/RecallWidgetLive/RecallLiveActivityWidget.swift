import ActivityKit
import SwiftUI
import WidgetKit

struct RecallLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RecallActivityAttributes.self) { context in
            // Lock screen / banner view
            lockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: context.state.isRecording ? "mic.fill" : "mic.slash.fill")
                        .foregroundStyle(context.state.isRecording ? .green : .gray)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(formatDuration(context.state.elapsedSeconds))
                        .font(.caption.monospaced())
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Label("\(context.state.chunkCount) chunks", systemImage: "waveform")
                        Spacer()
                        Text(String(format: "VAD: %.0f%%", context.state.vadProbability * 100))
                    }
                    .font(.caption2.monospaced())
                }
            } compactLeading: {
                Image(systemName: "mic.fill")
                    .foregroundStyle(context.state.isRecording ? .green : .gray)
            } compactTrailing: {
                Text(formatDuration(context.state.elapsedSeconds))
                    .font(.caption2.monospaced())
            } minimal: {
                Image(systemName: "circle.fill")
                    .foregroundStyle(.red)
                    .font(.caption2)
            }
        }
    }

    private func lockScreenView(context: ActivityViewContext<RecallActivityAttributes>) -> some View {
        HStack {
            Image(systemName: context.state.isRecording ? "mic.fill" : "mic.slash.fill")
                .font(.title2)
                .foregroundStyle(context.state.isRecording ? .green : .gray)

            VStack(alignment: .leading) {
                Text("Recall")
                    .font(.headline.monospaced())
                Text(formatDuration(context.state.elapsedSeconds))
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing) {
                Text("\(context.state.chunkCount) chunks")
                    .font(.caption.monospaced())
                Text(String(format: "VAD %.0f%%", context.state.vadProbability * 100))
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }

    private func formatDuration(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
