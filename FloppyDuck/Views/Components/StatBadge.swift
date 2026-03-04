import SwiftUI

/// Small stat display — label over value, retro styled.
struct StatBadge: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(GK.Colors.panelBorder.opacity(0.6))
            Text(value)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(GK.Colors.panelBorder)
        }
    }
}
