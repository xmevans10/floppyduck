import SwiftUI

/// Mini-scene preview for theme selection cards.
/// Shows sky gradient + pixel hill silhouette + ground strip
/// so users can see what a theme actually looks like in-game.
struct ThemePreviewView: View {
    let theme: BackgroundTheme

    var body: some View {
        GeometryReader { geo in
            let h = geo.size.height

            ZStack(alignment: .bottom) {
                // Sky gradient (same as in-game)
                LinearGradient(
                    colors: theme.gradientColors,
                    startPoint: .top,
                    endPoint: .bottom
                )

                // Stars overlay for night/space themes
                if theme.showStars {
                    starsOverlay
                }

                // Hill silhouette
                PixelHillShape(seed: theme.rawValue.hashValue)
                    .fill(theme.previewHillColor)
                    .frame(height: h * 0.45)
                    .offset(y: -h * 0.12)

                // Ground strip at bottom
                VStack(spacing: 0) {
                    // Surface edge (slightly lighter)
                    Rectangle()
                        .fill(theme.previewGroundColor.opacity(0.8))
                        .frame(height: 3)
                    // Ground body
                    Rectangle()
                        .fill(theme.previewGroundColor)
                }
                .frame(height: h * 0.22)
            }
        }
    }

    private var starsOverlay: some View {
        GeometryReader { geo in
            let positions = starPositions(width: geo.size.width, height: geo.size.height * 0.6)
            ForEach(0..<positions.count, id: \.self) { i in
                Circle()
                    .fill(.white.opacity(positions[i].opacity))
                    .frame(width: positions[i].size, height: positions[i].size)
                    .position(x: positions[i].x, y: positions[i].y)
            }
        }
    }

    private func starPositions(width: CGFloat, height: CGFloat) -> [(x: CGFloat, y: CGFloat, size: CGFloat, opacity: Double)] {
        var result: [(x: CGFloat, y: CGFloat, size: CGFloat, opacity: Double)] = []
        var state = UInt64(abs(theme.rawValue.hashValue)) | 1
        for _ in 0..<12 {
            state ^= state << 13; state ^= state >> 7; state ^= state << 17
            let x = CGFloat(state % UInt64(max(width, 1)))
            state ^= state << 13; state ^= state >> 7; state ^= state << 17
            let y = CGFloat(state % UInt64(max(height, 1)))
            state ^= state << 13; state ^= state >> 7; state ^= state << 17
            let size = CGFloat(state % 3) + 1
            state ^= state << 13; state ^= state >> 7; state ^= state << 17
            let opacity = Double(state % 60 + 30) / 100.0
            result.append((x, y, size, opacity))
        }
        return result
    }
}

/// Pixel-art styled hill silhouette shape for theme previews.
private struct PixelHillShape: Shape {
    let seed: Int

    func path(in rect: CGRect) -> Path {
        let step: CGFloat = 4
        let w = rect.width
        let h = rect.height
        var state = UInt64(abs(seed)) | 1
        state ^= state << 13; state ^= state >> 7; state ^= state << 17
        let phase1 = CGFloat(state % 100) / 50.0
        state ^= state << 13; state ^= state >> 7; state ^= state << 17
        let phase2 = CGFloat(state % 100) / 30.0

        var path = Path()
        path.move(to: CGPoint(x: 0, y: h))

        var x: CGFloat = 0
        while x <= w {
            let f1 = sin(x / max(w, 1) * .pi * 2.0 + phase1)
            let f2 = sin(x / max(w, 1) * .pi * 4.0 + phase2) * 0.4
            let combined = (f1 + f2) * 0.5 + 0.5
            let y = h - combined * h * 0.8
            let snappedY = (y / step).rounded() * step
            path.addLine(to: CGPoint(x: x, y: snappedY))
            x += step
        }

        path.addLine(to: CGPoint(x: w, y: h))
        path.closeSubpath()
        return path
    }
}
