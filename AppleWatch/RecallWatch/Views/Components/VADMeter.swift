import SwiftUI

struct VADMeter: View {
    let probability: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("VAD")
                    .font(.system(size: 10).monospaced())
                    .foregroundStyle(.secondary)
                Spacer()
                Text(String(format: "%.0f%%", probability * 100))
                    .font(.system(size: 10).monospaced().bold())
                    .foregroundStyle(meterColor)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(.white.opacity(0.1))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(meterColor)
                        .frame(width: geo.size.width * probability)
                        .animation(.easeInOut(duration: 0.1), value: probability)
                }
            }
            .frame(height: 6)
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
