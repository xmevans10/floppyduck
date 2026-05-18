import SwiftUI

/// Pixel-art styled button background that replaces generic `Circle().fill(...)` patterns.
/// Maintains the 8-bit aesthetic across all UI screens.
struct PixelButtonBackground: View {
    let style: Style
    let size: CGFloat

    enum Style {
        /// Light theme (used on gradient/sky backgrounds): dark pixel border, light fill
        case light
        /// Dark theme (used on cream panels or colored backgrounds): subtle dark fill
        case dark
        /// Accent theme: uses a tinted fill with pixel border
        case accent(Color)
    }

    var body: some View {
        ZStack {
            // Outer pixel border (1-pixel step look)
            pixelSquare
                .fill(borderColor)
                .frame(width: size, height: size)

            // Inner fill
            pixelSquare
                .fill(fillColor)
                .frame(width: size - 4, height: size - 4)

            // Highlight pixel at top-left for depth
            VStack {
                HStack {
                    Rectangle()
                        .fill(highlightColor)
                        .frame(width: 2, height: 2)
                    Spacer()
                }
                Spacer()
            }
            .frame(width: size - 6, height: size - 6)
        }
    }

    private var borderColor: Color {
        switch style {
        case .light:         return Color.black.opacity(0.25)
        case .dark:          return Color.black.opacity(0.30)
        case .accent(let c): return c.opacity(0.6)
        }
    }

    private var fillColor: Color {
        switch style {
        case .light:         return Color.white.opacity(0.15)
        case .dark:          return Color.black.opacity(0.15)
        case .accent(let c): return c.opacity(0.20)
        }
    }

    private var highlightColor: Color {
        switch style {
        case .light:         return Color.white.opacity(0.25)
        case .dark:          return Color.white.opacity(0.10)
        case .accent:        return Color.white.opacity(0.20)
        }
    }

    /// Pixel-art style rounded square (slightly notched corners for 8-bit look)
    private var pixelSquare: PixelRoundedRect {
        PixelRoundedRect()
    }
}

/// A pixel-art style rounded rectangle shape — notches corner pixels for that classic 8-bit feel.
struct PixelRoundedRect: Shape {
    func path(in rect: CGRect) -> Path {
        let notch: CGFloat = 2  // corner notch size

        var path = Path()
        // Top edge (indented at corners)
        path.move(to: CGPoint(x: rect.minX + notch, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - notch, y: rect.minY))
        // Top-right notch
        path.addLine(to: CGPoint(x: rect.maxX - notch, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + notch))
        // Right edge
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - notch))
        // Bottom-right notch
        path.addLine(to: CGPoint(x: rect.maxX - notch, y: rect.maxY))
        // Bottom edge
        path.addLine(to: CGPoint(x: rect.minX + notch, y: rect.maxY))
        // Bottom-left notch
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - notch))
        // Left edge
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + notch))
        // Close to top-left notch
        path.closeSubpath()
        return path
    }
}

/// A reusable pixel-art container for rectangular elements (replaces RoundedRectangle in some contexts)
struct PixelPanelBackground: View {
    let fillColor: Color
    let borderColor: Color
    let cornerNotch: CGFloat

    init(fillColor: Color = Color.black.opacity(0.15),
         borderColor: Color = Color.black.opacity(0.25),
         cornerNotch: CGFloat = 3) {
        self.fillColor = fillColor
        self.borderColor = borderColor
        self.cornerNotch = cornerNotch
    }

    var body: some View {
        ZStack {
            PixelRoundedRect()
                .fill(borderColor)
            PixelRoundedRect()
                .fill(fillColor)
                .padding(2)
        }
    }
}

// MARK: - Pixel Outlined Text

/// Renders text with a crisp multi-directional pixel outline using ZStack offset copies.
/// Only the topmost fill layer is exposed to VoiceOver — shadow layers are hidden.
struct PixelOutlinedText: View {
    let text: String
    let fontSize: CGFloat
    var fillColor: Color = GK.Colors.titleCream
    var outlineColor: Color = GK.Colors.pipeBorder
    var outlineWidth: CGFloat = 2

    var body: some View {
        ZStack {
            // Cardinal-direction shadow layers (crisp pixel outline, no blur)
            Group {
                shadowLayer(offsetX: -outlineWidth, offsetY: 0)
                shadowLayer(offsetX:  outlineWidth, offsetY: 0)
                shadowLayer(offsetX: 0, offsetY: -outlineWidth)
                shadowLayer(offsetX: 0, offsetY:  outlineWidth)
            }
            .accessibilityHidden(true)

            // Diagonal offsets for heavier outline weights
            if outlineWidth >= 3 {
                Group {
                    shadowLayer(offsetX: -outlineWidth, offsetY: -outlineWidth)
                    shadowLayer(offsetX:  outlineWidth, offsetY: -outlineWidth)
                    shadowLayer(offsetX: -outlineWidth, offsetY:  outlineWidth)
                    shadowLayer(offsetX:  outlineWidth, offsetY:  outlineWidth)
                }
                .accessibilityHidden(true)
            }

            // Main fill text (only this layer exposed to VoiceOver)
            Text(text)
                .font(.custom(GK.pixelFontName, size: fontSize))
                .foregroundColor(fillColor)
        }
    }

    private func shadowLayer(offsetX: CGFloat, offsetY: CGFloat) -> some View {
        Text(text)
            .font(.custom(GK.pixelFontName, size: fontSize))
            .foregroundColor(outlineColor)
            .offset(x: offsetX, y: offsetY)
    }
}
