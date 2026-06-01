import SwiftUI

/// Pixel-art styled share card rendered to UIImage for social sharing.
/// Pulls the player's equipped background theme, duck skin, and pipe skin
/// so the card reflects their personal setup.
struct ShareCardView: View {
    let score: Int
    let medal: Medal
    let skin: DuckSkin
    let theme: BackgroundTheme
    let pipeSkin: PipeSkin

    private let cardWidth: CGFloat = 360
    private let cardHeight: CGFloat = 200

    // MARK: - Body

    var body: some View {
        ZStack {
            // ── Background: user's selected theme gradient ──
            LinearGradient(
                colors: theme.gradientColors,
                startPoint: .top,
                endPoint: .bottom
            )

            // ── Scene elements (pipes + duck) ──
            sceneLayer

            // ── Ground strip ──
            VStack(spacing: 0) {
                Spacer()
                HillShape()
                    .fill(theme.previewHillColor)
                    .frame(height: 16)
                Rectangle()
                    .fill(theme.previewGroundColor)
                    .frame(height: 16)
            }

            // ── Score overlay ──
            VStack(spacing: 8) {
                Text("FLOPPY DUCK")
                    .font(.custom(GK.pixelFontName, size: 14))
                    .foregroundColor(titleColor)
                    .shadow(color: .black.opacity(0.6), radius: 0, x: 2, y: 2)

                Text("\(score)")
                    .font(.custom(GK.pixelFontName, size: 52))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.7), radius: 0, x: 3, y: 3)

                if medal != .none, let icon = medal.pixelIcon {
                    HStack(spacing: 6) {
                        Image(uiImage: PixelIconFactory.shared.image(for: icon))
                            .interpolation(.none)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 16, height: 16)
                        Text(medal.displayName.uppercased())
                            .font(.custom(GK.pixelFontName, size: 10))
                            .foregroundColor(medal.themeColor)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.black.opacity(0.4))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(medal.themeColor.opacity(0.5), lineWidth: 1)
                            )
                    )
                }
            }
        }
        .frame(width: cardWidth, height: cardHeight)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Scene Layer (duck + pipes)

    private var sceneLayer: some View {
        ZStack {
            // Left pipe pair
            HStack(spacing: 0) {
                pipeColumn
                    .offset(x: -8, y: 20)
                Spacer()
            }

            // Right pipe pair
            HStack(spacing: 0) {
                Spacer()
                pipeColumn
                    .offset(x: 8, y: -10)
            }

            // Duck – right side of card, above ground
            HStack {
                Spacer()
                duckImage
                    .rotationEffect(.degrees(-8))
                    .offset(y: 20)
                Spacer()
                    .frame(width: cardWidth * 0.12)
            }
        }
        .opacity(0.4)
    }

    private var duckImage: some View {
        Image(uiImage: TextureFactory.shared.skinDuckUIImage(skin: skin, pixelScale: 5.0))
            .interpolation(.none)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(height: 70)
    }

    private var pipeColumn: some View {
        VStack(spacing: 60) {
            VStack(spacing: 0) {
                Image(uiImage: TextureFactory.shared.pipeSkinPreviewUIImage(skin: pipeSkin, width: 24, height: 50))
                    .interpolation(.none)
                    .resizable()
                    .frame(width: 36, height: 60)
                    .rotationEffect(.degrees(180))
                Image(uiImage: TextureFactory.shared.pipeSkinCapPreviewUIImage(skin: pipeSkin))
                    .interpolation(.none)
                    .resizable()
                    .frame(width: 42, height: 12)
                    .rotationEffect(.degrees(180))
            }

            VStack(spacing: 0) {
                Image(uiImage: TextureFactory.shared.pipeSkinCapPreviewUIImage(skin: pipeSkin))
                    .interpolation(.none)
                    .resizable()
                    .frame(width: 42, height: 12)
                Image(uiImage: TextureFactory.shared.pipeSkinPreviewUIImage(skin: pipeSkin, width: 24, height: 50))
                    .interpolation(.none)
                    .resizable()
                    .frame(width: 36, height: 60)
            }
        }
    }

    // MARK: - Helpers

    private var titleColor: Color {
        switch theme {
        case .egypt, .western, .arctic, .lagoon, .clouds:
            return Color(red: 0.85, green: 0.65, blue: 0.0)
        default:
            return Color(red: 1.0, green: 0.84, blue: 0.0)
        }
    }

    @MainActor
    func renderToImage() -> UIImage {
        let renderer = ImageRenderer(content: self)
        renderer.scale = 3.0
        return renderer.uiImage ?? UIImage()
    }
}

// MARK: - Hill Silhouette Shape

private struct HillShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        path.move(to: CGPoint(x: 0, y: h))
        path.addCurve(
            to: CGPoint(x: w * 0.35, y: h * 0.25),
            control1: CGPoint(x: w * 0.08, y: h),
            control2: CGPoint(x: w * 0.20, y: h * 0.15)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.65, y: h * 0.45),
            control1: CGPoint(x: w * 0.45, y: h * 0.32),
            control2: CGPoint(x: w * 0.55, y: h * 0.50)
        )
        path.addCurve(
            to: CGPoint(x: w, y: h * 0.20),
            control1: CGPoint(x: w * 0.78, y: h * 0.38),
            control2: CGPoint(x: w * 0.90, y: h * 0.15)
        )
        path.addLine(to: CGPoint(x: w, y: h))
        path.closeSubpath()
        return path
    }
}
