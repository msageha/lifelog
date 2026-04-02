import SwiftUI

struct NeonBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption2.monospaced().bold())
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.2), in: Capsule())
            .foregroundStyle(color)
            .overlay(
                Capsule()
                    .stroke(color.opacity(0.5), lineWidth: 1)
            )
    }
}
