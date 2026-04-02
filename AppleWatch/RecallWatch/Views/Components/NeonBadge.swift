import SwiftUI

struct NeonBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 8).monospaced().bold())
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(color.opacity(0.2), in: Capsule())
            .foregroundStyle(color)
            .overlay(
                Capsule()
                    .stroke(color.opacity(0.5), lineWidth: 0.5)
            )
    }
}
