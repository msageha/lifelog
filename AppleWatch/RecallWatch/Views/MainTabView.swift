import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @State private var recording = RecordingViewModel()
    @State private var upload = UploadViewModel()
    @State private var agent = AgentViewModel()
    @State private var config = ConfigViewModel()
    @State private var activityLogger = ActivityLogger()

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("REC", systemImage: "mic.fill", value: 0) {
                RecordingView(viewModel: recording, logger: activityLogger)
            }
            Tab("UPLOAD", systemImage: "arrow.up.circle.fill", value: 1) {
                UploadView(viewModel: upload)
            }
            Tab("AGENT", systemImage: "brain.head.profile.fill", value: 2) {
                AgentView(viewModel: agent)
            }
            Tab("CONFIG", systemImage: "gearshape.fill", value: 3) {
                ConfigView(viewModel: config)
            }
        }
        .tint(.cyan)
        .task {
            await LaunchSequence.execute(
                recording: recording,
                upload: upload,
                agent: agent,
                config: config
            )
        }
    }
}
