import SwiftUI

// Legacy component — kept for project reference. See HomeView for new design.
struct ModeCard: View {
    let title: String
    let icon: PixelIcon
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(uiImage: PixelIconFactory.shared.image(for: icon))
                    .interpolation(.none)
                    .resizable()
                    .frame(width: 24, height: 24)
                Text(title)
                    .font(.custom(GK.pixelFontName, size: 12))
                    .foregroundColor(.white)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 10).fill(color))
        }
        .buttonStyle(.plain)
    }
}
