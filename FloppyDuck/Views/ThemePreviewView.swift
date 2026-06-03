import SwiftUI

/// Per-theme hero preview for Collection / Shop selection cards.
/// Displays the actual hero PNG asset used in-game, square-cropped to
/// show the most visually distinctive region of each theme's backdrop.
/// The Park theme also renders The Duck (golden mallard) at the bottom.
struct ThemePreviewView: View {
    let theme: BackgroundTheme

    var body: some View {
        Rectangle()
            .fill(Color.clear)
            .aspectRatio(1.0, contentMode: .fit)
            .overlay(alignment: theme.previewCropAnchor.asAlignment) {
                Image(theme.heroAssetName)
                    .interpolation(.none)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            }
            .clipped()
            .overlay(alignment: .bottom) {
                if theme == .park {
                    // Render The Duck (golden mallard) at the bottom of the park card
                    Image(uiImage: TextureFactory.shared.skinDuckUIImage(skin: .golden, pixelScale: 5.0))
                        .interpolation(.none)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 40, height: 40)
                        .padding(.bottom, 6)
                }
            }
    }
}

private extension UnitPoint {
    var asAlignment: Alignment {
        Alignment(horizontal: UnitPoint.toHorizontalAlignment(x),
                  vertical: UnitPoint.toVerticalAlignment(y))
    }

    static func toHorizontalAlignment(_ x: CGFloat) -> HorizontalAlignment {
        if x < 0.4 { return .leading }
        if x > 0.6 { return .trailing }
        return .center
    }

    static func toVerticalAlignment(_ y: CGFloat) -> VerticalAlignment {
        if y < 0.4 { return .top }
        if y > 0.6 { return .bottom }
        return .center
    }
}
