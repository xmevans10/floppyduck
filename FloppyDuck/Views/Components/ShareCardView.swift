import SwiftUI

/// Pixel-art styled share card rendered to UIImage for social sharing.
/// Pulls the player's equipped background theme, duck skin, and pipe skin
/// so the card reflects their personal setup.
struct ShareCardView: View {
    let score: Int
    let medal: Medal
    let bestScore: Int
    let mode: GameMode
    let skin: DuckSkin
    let theme: BackgroundTheme
    let pipeSkin: PipeSkin

    private let cardWidth: CGFloat = 360
    private let cardHeight: CGFloat = 240

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
                // Hill silhouette
                HillShape()
                    .fill(theme.previewHillColor)
                    .frame(height: 18)
                // Ground
                Rectangle()
                    .fill(theme.previewGroundColor)
                    .frame(height: 20)
            }

            // ── Score / info overlay ──
            scoreOverlay
        }
        .frame(width: cardWidth, height: cardHeight)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Scene Layer (duck + pipes)

    private var sceneLayer: some View {
        ZStack {
            // Left pipe pair (partially off-screen)
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

            // Duck – positioned slightly left-of-center, above the ground
            HStack {
                Spacer()
                    .frame(width: cardWidth * 0.25)
                duckImage
                    .rotationEffect(.degrees(-8))
                    .offset(y: -10)
                Spacer()
            }
        }
        .opacity(0.35)
    }

    private var duckImage: some View {
        Image(uiImage: TextureFactory.shared.skinDuckUIImage(skin: skin, pixelScale: 5.0))
            .interpolation(.none)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(height: 80)
    }

    private var pipeColumn: some View {
        VStack(spacing: 60) {
            // Top pipe (upside-down)
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

            // Bottom pipe
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

    // MARK: - Score Overlay

    private var scoreOverlay: some View {
        VStack(spacing: 6) {
            // Title
            Text("FLOPPY DUCK")
                .font(.custom(GK.pixelFontName, size: 14))
                .foregroundColor(titleColor)
                .shadow(color: .black.opacity(0.6), radius: 0, x: 2, y: 2)
                .padding(.top, 14)

            // Score
            Text("\(score)")
                .font(.custom(GK.pixelFontName, size: 48))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.7), radius: 0, x: 3, y: 3)

            // Medal badge
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

            Spacer()

            // Stats row
            HStack(spacing: 20) {
                VStack(spacing: 2) {
                    Text("BEST")
                        .font(.custom(GK.pixelFontName, size: 7))
                        .foregroundColor(.white.opacity(0.6))
                    Text("\(bestScore)")
                        .font(.custom(GK.pixelFontName, size: 12))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.5), radius: 0, x: 1, y: 1)
                }
                VStack(spacing: 2) {
                    Text("MODE")
                        .font(.custom(GK.pixelFontName, size: 7))
                        .foregroundColor(.white.opacity(0.6))
                    Text(mode.shareDisplayName.uppercased())
                        .font(.custom(GK.pixelFontName, size: 10))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.5), radius: 0, x: 1, y: 1)
                }
            }

            // CTA
            Text("CAN YOU BEAT THIS?")
                .font(.custom(GK.pixelFontName, size: 7))
                .foregroundColor(.white.opacity(0.5))
                .padding(.bottom, 26)   // above the ground strip
        }
    }

    // MARK: - Helpers

    /// Title color adapts for readability against the theme's sky gradient.
    private var titleColor: Color {
        switch theme {
        case .egypt, .western, .arctic, .lagoon, .clouds:
            // Light-gradient themes — use a darker gold
            return Color(red: 0.85, green: 0.65, blue: 0.0)
        default:
            return Color(red: 1.0, green: 0.84, blue: 0.0)
        }
    }

    /// Renders this view to a shareable UIImage.
    @MainActor
    func renderToImage() -> UIImage {
        let renderer = ImageRenderer(content: self)
        renderer.scale = 3.0  // Retina quality
        return renderer.uiImage ?? UIImage()
    }
}

// MARK: - Hill Silhouette Shape

/// Simple rolling-hill silhouette for the share card ground layer.
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
