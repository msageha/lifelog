import SwiftUI

struct RecordingView: View {
    @Bindable var viewModel: RecordingViewModel
    let logger: ActivityLogger

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Recording state indicator
                    recordingStateCard

                    // VAD probability meter
                    VADMeter(probability: viewModel.vadProbability)

                    // Stats
                    statsCard

                    // Activity log
                    activityLogCard
                }
                .padding()
            }
            .navigationTitle("REC")
        }
    }

    private var recordingStateCard: some View {
        GlassCard {
            VStack(spacing: 12) {
                Image(systemName: viewModel.state == .recording ? "mic.fill" : "mic.slash.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(stateColor)
                    .symbolEffect(.pulse, isActive: viewModel.state == .recording)

                Text(viewModel.state.rawValue.uppercased())
                    .font(.headline.monospaced())
                    .foregroundStyle(stateColor)

                Button(action: viewModel.toggleRecording) {
                    Text(viewModel.state == .idle ? "START" : "STOP")
                        .font(.headline.monospaced())
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(viewModel.state == .idle ? .cyan : .red)
            }
        }
    }

    private var statsCard: some View {
        GlassCard {
            HStack(spacing: 20) {
                StatItem(
                    title: "CHUNKS",
                    value: "\(viewModel.totalChunksRecorded)"
                )
                StatItem(
                    title: "DURATION",
                    value: DateFormatting.durationString(from: viewModel.currentChunkDuration)
                )
                StatItem(
                    title: "ELAPSED",
                    value: DateFormatting.durationString(from: TimeInterval(viewModel.elapsedSeconds))
                )
            }
        }
    }

    private var activityLogCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("ACTIVITY LOG")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)

                ForEach(logger.recentEntries.suffix(20).reversed()) { entry in
                    HStack {
                        Text(DateFormatting.shortTimeString(from: entry.timestamp))
                            .font(.caption2.monospaced())
                            .foregroundStyle(.secondary)
                        NeonBadge(text: entry.category.rawValue, color: categoryColor(entry.category))
                        Text(entry.message)
                            .font(.caption.monospaced())
                            .lineLimit(1)
                    }
                }
            }
        }
    }

    private var stateColor: Color {
        switch viewModel.state {
        case .idle: .gray
        case .listening: .cyan
        case .recording: .green
        }
    }

    private func categoryColor(_ category: LogCategory) -> Color {
        switch category {
        case .state: .cyan
        case .vad: .green
        case .chunk: .mint
        case .upload: .blue
        case .network: .purple
        case .error: .red
        case .health: .pink
        case .location: .orange
        case .telemetry: .yellow
        case .agent: .indigo
        }
    }
}

private struct StatItem: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.monospaced().bold())
                .foregroundStyle(.cyan)
        }
        .frame(maxWidth: .infinity)
    }
}
