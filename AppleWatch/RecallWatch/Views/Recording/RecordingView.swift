import SwiftUI

struct RecordingView: View {
    @Bindable var viewModel: RecordingViewModel
    let logger: ActivityLogger

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                recordingStateSection
                VADMeter(probability: viewModel.vadProbability)
                statsSection
                activityLogSection
            }
            .padding(.horizontal)
        }
        .navigationTitle("REC")
    }

    private var recordingStateSection: some View {
        VStack(spacing: 8) {
            Image(systemName: viewModel.state == .recording ? "mic.fill" : "mic.slash.fill")
                .font(.system(size: 36))
                .foregroundStyle(stateColor)
                .symbolEffect(.pulse, isActive: viewModel.state == .recording)

            Text(viewModel.state.rawValue.uppercased())
                .font(.caption.monospaced())
                .foregroundStyle(stateColor)

            Button(action: viewModel.toggleRecording) {
                Text(viewModel.state == .idle ? "START" : "STOP")
                    .font(.caption.monospaced().bold())
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(viewModel.state == .idle ? .cyan : .red)
        }
    }

    private var statsSection: some View {
        HStack(spacing: 8) {
            WatchStatItem(title: "CHUNKS", value: "\(viewModel.totalChunksRecorded)")
            WatchStatItem(title: "TIME", value: DateFormatting.durationString(from: TimeInterval(viewModel.elapsedSeconds)))
        }
    }

    private var activityLogSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("LOG")
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)

            ForEach(logger.recentEntries.suffix(5).reversed()) { entry in
                HStack(spacing: 4) {
                    NeonBadge(text: entry.category.rawValue, color: categoryColor(entry.category))
                    Text(entry.message)
                        .font(.system(size: 10).monospaced())
                        .lineLimit(1)
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

private struct WatchStatItem: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.system(size: 9).monospaced())
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.monospaced().bold())
                .foregroundStyle(.cyan)
        }
        .frame(maxWidth: .infinity)
    }
}
