import SwiftUI

/// Pixel-art styled share card rendered to UIImage for social sharing.
struct ShareCardView: View {
    let score: Int
    let medal: Medal
    let bestScore: Int
    let mode: GameMode

    private let cardWidth: CGFloat = 360
    private let cardHeight: CGFloat = 200

    var body: some View {
        ZStack {
            // Sky gradient background
            LinearGradient(
                colors: [
                    Color(red: 0.40, green: 0.75, blue: 0.95),
                    Color(red: 0.55, green: 0.85, blue: 0.98),
                    Color(red: 0.70, green: 0.92, blue: 0.65),
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // Ground strip at bottom
            VStack {
                Spacer()
                Rectangle()
                    .fill(Color(red: 0.45, green: 0.72, blue: 0.22))
                    .frame(height: 24)
                Rectangle()
                    .fill(Color(red: 0.55, green: 0.35, blue: 0.18))
                    .frame(height: 8)
            }

            // Content
            VStack(spacing: 8) {
                // Title
                Text("FLOPPY DUCK")
                    .font(.custom(GK.pixelFontName, size: 14))
                    .foregroundColor(Color(red: 1.0, green: 0.84, blue: 0.0))
                    .shadow(color: .black.opacity(0.5), radius: 0, x: 2, y: 2)

                // Score
                Text("\(score)")
                    .font(.custom(GK.pixelFontName, size: 42))
                    .foregroundColor(.white)
                    .shadow(color: Color(red: 0.2, green: 0.33, blue: 0.1, opacity: 0.9), radius: 0, x: 3, y: 3)

                // Medal badge
                if medal != .none {
                    HStack(spacing: 6) {
                        Text(medal.emoji)
                            .font(.system(size: 16))
                        Text(medal.displayName.uppercased())
                            .font(.custom(GK.pixelFontName, size: 10))
                            .foregroundColor(medal.color)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.black.opacity(0.3))
                    )
                }

                // Best score
                HStack(spacing: 16) {
                    VStack(spacing: 2) {
                        Text("BEST")
                            .font(.custom(GK.pixelFontName, size: 7))
                            .foregroundColor(.white.opacity(0.7))
                        Text("\(bestScore)")
                            .font(.custom(GK.pixelFontName, size: 12))
                            .foregroundColor(.white)
                    }
                    VStack(spacing: 2) {
                        Text("MODE")
                            .font(.custom(GK.pixelFontName, size: 7))
                            .foregroundColor(.white.opacity(0.7))
                        Text(mode.displayName.uppercased())
                            .font(.custom(GK.pixelFontName, size: 10))
                            .foregroundColor(.white)
                    }
                }
                .padding(.top, 4)

                // CTA
                Text("CAN YOU BEAT THIS? 🦆")
                    .font(.custom(GK.pixelFontName, size: 7))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(.vertical, 16)
        }
        .frame(width: cardWidth, height: cardHeight)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    /// Renders this view to a shareable UIImage.
    @MainActor
    func renderToImage() -> UIImage {
        let renderer = ImageRenderer(content: self)
        renderer.scale = 3.0  // Retina quality
        return renderer.uiImage ?? UIImage()
    }
}
