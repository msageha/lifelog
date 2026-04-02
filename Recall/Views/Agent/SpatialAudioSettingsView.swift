import SwiftUI

struct SpatialAudioSettingsView: View {
    @Bindable var viewModel: AgentViewModel

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("SPATIAL AUDIO")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)

                VStack(spacing: 8) {
                    HStack {
                        Text("Azimuth")
                            .font(.caption.monospaced())
                        Slider(
                            value: Binding(
                                get: { Double(viewModel.spatialAzimuth) },
                                set: { viewModel.spatialAzimuth = Float($0) }
                            ),
                            in: -180...180
                        )
                        Text("\(Int(viewModel.spatialAzimuth))°")
                            .font(.caption.monospaced())
                            .frame(width: 40)
                    }

                    HStack {
                        Text("Distance")
                            .font(.caption.monospaced())
                        Slider(
                            value: Binding(
                                get: { Double(viewModel.spatialDistance) },
                                set: { viewModel.spatialDistance = Float($0) }
                            ),
                            in: 0.1...10.0
                        )
                        Text(String(format: "%.1f", viewModel.spatialDistance))
                            .font(.caption.monospaced())
                            .frame(width: 40)
                    }

                    HStack {
                        Text("Volume")
                            .font(.caption.monospaced())
                        Slider(
                            value: Binding(
                                get: { Double(viewModel.spatialVolume) },
                                set: { viewModel.spatialVolume = Float($0) }
                            ),
                            in: 0...1
                        )
                        Text("\(Int(viewModel.spatialVolume * 100))%")
                            .font(.caption.monospaced())
                            .frame(width: 40)
                    }
                }
            }
        }
        .padding()
    }
}
