import SwiftUI

struct VADMeter: View {
    let probability: Double

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("VAD")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(String(format: "%.1f%%", probability * 100))
                        .font(.caption.monospaced().bold())
                        .foregroundStyle(meterColor)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.white.opacity(0.1))
                        RoundedRectangle(cornerRadius: 4)
                            .fill(meterColor)
                            .frame(width: geo.size.width * probability)
                            .animation(.easeInOut(duration: 0.1), value: probability)
                    }
                }
                .frame(height: 8)
            }
        }
    }

    private var meterColor: Color {
        if probability > Constants.Audio.vadThreshold {
            return .green
        } else if probability > Constants.Audio.vadThreshold * 0.5 {
            return .yellow
        } else {
            return .gray
        }
    }
}
