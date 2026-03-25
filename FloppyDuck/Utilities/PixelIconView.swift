import SwiftUI

/// Shared pixel-icon helper — eliminates duplicate `pixelIcon(_:size:)` methods
/// across `GameContainerView`, `HomeView`, `SettingsView`, and `BotLadderView`.
extension View {
    func pixelIcon(_ icon: PixelIcon, size: CGFloat) -> some View {
        Image(uiImage: PixelIconFactory.shared.image(for: icon))
            .interpolation(.none)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
    }
}
