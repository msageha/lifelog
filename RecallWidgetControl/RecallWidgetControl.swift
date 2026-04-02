import SwiftUI
import WidgetKit

struct RecallWidgetControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.recall.recording-toggle") {
            ControlWidgetToggle(
                "Recording",
                isOn: SharedDefaults.bool(for: .isRecordingEnabled),
                action: ToggleRecordingIntent()
            ) { isOn in
                Label(
                    isOn ? "Recording" : "Stopped",
                    systemImage: isOn ? "mic.fill" : "mic.slash.fill"
                )
            }
        }
        .displayName("Recall Recording")
        .description("Toggle audio recording on/off")
    }
}
