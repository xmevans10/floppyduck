import SwiftUI

// Legacy component — kept for project reference. See StatsView for new design.
struct StatBadge: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.custom(GK.pixelFontName, size: 14))
                .foregroundColor(GK.Colors.panelBorder)
            Text(label)
                .font(.custom(GK.pixelFontName, size: 7))
                .foregroundColor(GK.Colors.panelBorder.opacity(0.5))
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(GK.Colors.panelCream)
        )
    }
}
