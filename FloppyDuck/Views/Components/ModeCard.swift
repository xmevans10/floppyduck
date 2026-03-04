import SwiftUI

/// Retro-styled card button — kept for potential reuse.
struct ModeCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(icon)
                    .font(.system(size: 22))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .opacity(0.7)
                }
                Spacer()
                Text("›")
                    .font(.system(size: 22, weight: .bold))
                    .opacity(0.5)
            }
            .foregroundStyle(GK.Colors.panelBorder)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(GK.Colors.panelCream)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(GK.Colors.panelBorder, lineWidth: 2)
                    )
                    .shadow(color: GK.Colors.panelBorder.opacity(0.3), radius: 0, x: 2, y: 3)
            )
        }
        .buttonStyle(RetroPress())
    }
}
