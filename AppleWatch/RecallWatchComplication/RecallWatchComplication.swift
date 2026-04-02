import SwiftUI
import WidgetKit

struct RecallComplicationEntry: TimelineEntry {
    let date: Date
    let isRecording: Bool
    let chunkCount: Int
}

struct RecallComplicationProvider: TimelineProvider {
    func placeholder(in context: Context) -> RecallComplicationEntry {
        RecallComplicationEntry(date: Date(), isRecording: false, chunkCount: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping (RecallComplicationEntry) -> Void) {
        let isRecording = SharedDefaults.bool(for: .isRecordingEnabled)
        let entry = RecallComplicationEntry(date: Date(), isRecording: isRecording, chunkCount: 0)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RecallComplicationEntry>) -> Void) {
        let isRecording = SharedDefaults.bool(for: .isRecordingEnabled)
        let entry = RecallComplicationEntry(date: Date(), isRecording: isRecording, chunkCount: 0)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 5, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

struct RecallComplicationCircularView: View {
    let entry: RecallComplicationEntry

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            Image(systemName: entry.isRecording ? "mic.fill" : "mic.slash.fill")
                .font(.title3)
                .foregroundStyle(entry.isRecording ? .green : .gray)
        }
    }
}

struct RecallComplicationRectangularView: View {
    let entry: RecallComplicationEntry

    var body: some View {
        HStack {
            Image(systemName: entry.isRecording ? "mic.fill" : "mic.slash.fill")
                .foregroundStyle(entry.isRecording ? .green : .gray)
            VStack(alignment: .leading) {
                Text("Recall")
                    .font(.caption.bold())
                Text(entry.isRecording ? "Recording" : "Idle")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct RecallComplicationInlineView: View {
    let entry: RecallComplicationEntry

    var body: some View {
        Label(
            entry.isRecording ? "Recording" : "Idle",
            systemImage: entry.isRecording ? "mic.fill" : "mic.slash.fill"
        )
    }
}

@main
struct RecallWatchComplicationBundle: WidgetBundle {
    var body: some Widget {
        RecallComplicationWidget()
    }
}

struct RecallComplicationWidget: Widget {
    let kind = "RecallWatchComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: RecallComplicationProvider()) { entry in
            RecallComplicationCircularView(entry: entry)
        }
        .configurationDisplayName("Recall")
        .description("Recording status")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
            .accessoryCorner,
        ])
    }
}
