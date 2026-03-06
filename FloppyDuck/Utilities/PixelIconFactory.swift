import UIKit
import SwiftUI

/// Generates pixel-art icons as UIImage / SwiftUI Image for buttons and UI.
/// Replaces all emoji usage with consistent pixel art.
enum PixelIcon: String, CaseIterable {
    case play          // triangle
    case headToHead    // two ducks facing
    case bot           // robot head
    case classic       // star/crown
    case stats         // bar chart
    case settings      // gear
    case share         // arrow-out-of-box
    case home          // house
    case retry         // circular arrow
    case tapHand       // pointing hand
    case trophy        // trophy cup
    case cancel        // X mark
    case back          // left chevron
    case shop          // shopping bag
    case lock          // padlock
}

final class PixelIconFactory {
    static let shared = PixelIconFactory()
    private init() {}

    private var cache: [String: UIImage] = [:]

    /// Get a pixel icon as UIImage
    func image(for icon: PixelIcon, pixelScale: CGFloat = 3.0) -> UIImage {
        let key = "\(icon.rawValue)_\(Int(pixelScale))"
        if let cached = cache[key] { return cached }
        let img = renderIcon(icon, pixelSize: pixelScale)
        cache[key] = img
        return img
    }

    /// SwiftUI Image view of a pixel icon
    func swiftUIImage(for icon: PixelIcon, pixelScale: CGFloat = 3.0, size: CGFloat = 24) -> some View {
        Image(uiImage: image(for: icon, pixelScale: pixelScale))
            .interpolation(.none)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
    }

    // MARK: - Rendering

    private func renderIcon(_ icon: PixelIcon, pixelSize: CGFloat) -> UIImage {
        let grid: [[UIColor]]
        switch icon {
        case .play:       grid = playGrid()
        case .headToHead: grid = headToHeadGrid()
        case .bot:        grid = botGrid()
        case .classic:    grid = classicGrid()
        case .stats:      grid = statsGrid()
        case .settings:   grid = settingsGrid()
        case .share:      grid = shareGrid()
        case .home:       grid = homeGrid()
        case .retry:      grid = retryGrid()
        case .tapHand:    grid = tapHandGrid()
        case .trophy:     grid = trophyGrid()
        case .cancel:     grid = cancelGrid()
        case .back:       grid = backGrid()
        case .shop:       grid = shopGrid()
        case .lock:       grid = lockGrid()
        }

        let gridH = grid.count
        let gridW = grid[0].count
        let imgSize = CGSize(width: CGFloat(gridW) * pixelSize, height: CGFloat(gridH) * pixelSize)

        let renderer = UIGraphicsImageRenderer(size: imgSize)
        return renderer.image { ctx in
            for row in 0..<gridH {
                for col in 0..<gridW {
                    let color = grid[row][col]
                    guard color != UIColor.clear else { continue }
                    color.setFill()
                    ctx.fill(CGRect(
                        x: CGFloat(col) * pixelSize,
                        y: CGFloat(row) * pixelSize,
                        width: pixelSize,
                        height: pixelSize
                    ))
                }
            }
        }
    }

    // Shorthand colors
    private var W: UIColor { .white }
    private var B: UIColor { .black }
    private var C: UIColor { .clear }
    private var G: UIColor { UIColor(red: 0.45, green: 0.75, blue: 0.18, alpha: 1) }  // green
    private var O: UIColor { UIColor(red: 0.93, green: 0.55, blue: 0.16, alpha: 1) }  // orange
    private var R: UIColor { UIColor(red: 0.85, green: 0.30, blue: 0.30, alpha: 1) }  // red
    private var Y: UIColor { UIColor(red: 0.95, green: 0.80, blue: 0.18, alpha: 1) }  // yellow/gold
    private var A: UIColor { UIColor(red: 0.60, green: 0.60, blue: 0.60, alpha: 1) }  // gray

    // MARK: - Icon Grids (10×10)

    private func playGrid() -> [[UIColor]] {
        return [
            [C,C,B,C,C,C,C,C,C,C],
            [C,C,B,B,C,C,C,C,C,C],
            [C,C,B,W,B,C,C,C,C,C],
            [C,C,B,W,W,B,C,C,C,C],
            [C,C,B,W,W,W,B,C,C,C],
            [C,C,B,W,W,W,B,C,C,C],
            [C,C,B,W,W,B,C,C,C,C],
            [C,C,B,W,B,C,C,C,C,C],
            [C,C,B,B,C,C,C,C,C,C],
            [C,C,B,C,C,C,C,C,C,C],
        ]
    }

    private func headToHeadGrid() -> [[UIColor]] {
        let g = UIColor(red: 0.08, green: 0.42, blue: 0.22, alpha: 1)
        return [
            [C,B,B,C,C,C,C,B,B,C],
            [B,g,g,B,C,C,B,g,g,B],
            [B,g,W,B,C,C,B,W,g,B],
            [C,B,B,C,B,B,C,B,B,C],
            [C,C,C,C,B,Y,C,C,C,C],
            [C,C,C,Y,B,C,C,C,C,C],
            [C,C,C,C,Y,B,C,C,C,C],
            [C,B,B,C,B,C,C,B,B,C],
            [B,g,g,B,C,C,B,g,g,B],
            [C,B,B,C,C,C,C,B,B,C],
        ]
    }

    private func botGrid() -> [[UIColor]] {
        return [
            [C,C,C,C,B,C,C,C,C,C],
            [C,C,B,B,B,B,B,C,C,C],
            [C,B,A,A,A,A,A,B,C,C],
            [C,B,A,B,A,B,A,B,C,C],
            [C,B,A,A,A,A,A,B,C,C],
            [C,B,A,B,B,B,A,B,C,C],
            [C,C,B,B,B,B,B,C,C,C],
            [C,C,C,B,A,B,C,C,C,C],
            [C,C,B,A,A,A,B,C,C,C],
            [C,C,B,C,C,C,B,C,C,C],
        ]
    }

    private func classicGrid() -> [[UIColor]] {
        return [
            [C,C,C,C,B,C,C,C,C,C],
            [C,C,C,B,Y,B,C,C,C,C],
            [C,B,C,B,Y,B,C,B,C,C],
            [C,B,B,Y,Y,Y,B,B,C,C],
            [C,C,B,Y,Y,Y,B,C,C,C],
            [C,C,B,Y,Y,Y,B,C,C,C],
            [C,B,Y,Y,Y,Y,Y,B,C,C],
            [B,Y,Y,Y,Y,Y,Y,Y,B,C],
            [B,Y,Y,Y,Y,Y,Y,Y,B,C],
            [C,B,B,B,B,B,B,B,C,C],
        ]
    }

    private func statsGrid() -> [[UIColor]] {
        return [
            [C,C,C,C,C,C,C,B,B,C],
            [C,C,C,C,C,C,C,B,W,B],
            [C,C,C,C,B,B,C,B,W,B],
            [C,C,C,C,B,W,B,B,W,B],
            [C,B,B,C,B,W,B,B,W,B],
            [C,B,W,B,B,W,B,B,W,B],
            [C,B,W,B,B,W,B,B,W,B],
            [C,B,W,B,B,W,B,B,W,B],
            [C,B,W,B,B,W,B,B,W,B],
            [B,B,B,B,B,B,B,B,B,B],
        ]
    }

    private func settingsGrid() -> [[UIColor]] {
        // Gear with protruding teeth
        return [
            [C,C,C,B,B,B,C,C,C,C],
            [C,B,B,A,A,A,B,B,C,C],
            [C,B,A,A,B,A,A,B,C,C],
            [B,A,A,B,C,B,A,A,B,C],
            [B,A,B,C,C,C,B,A,B,C],
            [B,A,A,B,C,B,A,A,B,C],
            [C,B,A,A,B,A,A,B,C,C],
            [C,B,B,A,A,A,B,B,C,C],
            [C,C,C,B,B,B,C,C,C,C],
            [C,C,C,C,C,C,C,C,C,C],
        ]
    }

    private func shareGrid() -> [[UIColor]] {
        return [
            [C,C,C,C,B,C,C,C,C,C],
            [C,C,C,B,W,B,C,C,C,C],
            [C,C,B,W,W,W,B,C,C,C],
            [C,B,C,C,W,C,C,B,C,C],
            [C,C,C,C,W,C,C,C,C,C],
            [C,C,B,C,W,C,B,C,C,C],
            [C,C,B,C,C,C,B,C,C,C],
            [C,C,B,C,C,C,B,C,C,C],
            [C,C,B,W,W,W,B,C,C,C],
            [C,C,B,B,B,B,B,C,C,C],
        ]
    }

    private func homeGrid() -> [[UIColor]] {
        return [
            [C,C,C,C,B,C,C,C,C,C],
            [C,C,C,B,W,B,C,C,C,C],
            [C,C,B,W,W,W,B,C,C,C],
            [C,B,W,W,W,W,W,B,C,C],
            [B,B,B,B,B,B,B,B,B,C],
            [C,B,W,W,W,W,W,B,C,C],
            [C,B,W,W,B,W,W,B,C,C],
            [C,B,W,W,B,W,W,B,C,C],
            [C,B,W,W,B,W,W,B,C,C],
            [C,B,B,B,B,B,B,B,C,C],
        ]
    }

    private func retryGrid() -> [[UIColor]] {
        return [
            [C,C,C,B,B,B,B,C,C,C],
            [C,C,B,W,W,W,W,B,C,C],
            [C,B,W,W,C,C,W,W,B,C],
            [C,B,W,C,C,C,C,B,C,C],
            [B,B,B,C,C,C,C,B,C,C],
            [C,C,C,C,C,C,W,B,C,C],
            [C,C,C,C,C,W,W,B,C,C],
            [C,C,B,W,W,W,B,C,C,C],
            [C,C,C,B,B,B,C,B,B,C],
            [C,C,C,C,C,C,C,C,B,C],
        ]
    }

    private func tapHandGrid() -> [[UIColor]] {
        let S = UIColor(red: 0.95, green: 0.85, blue: 0.70, alpha: 1)
        return [
            [C,C,C,B,B,C,C,C,C,C],
            [C,C,B,S,S,B,C,C,C,C],
            [C,C,B,S,S,B,C,C,C,C],
            [C,C,B,S,S,B,C,C,C,C],
            [C,C,B,S,S,B,B,B,C,C],
            [C,C,B,S,S,S,S,S,B,C],
            [C,B,S,S,S,S,S,S,B,C],
            [C,B,S,S,S,S,S,S,B,C],
            [C,C,B,S,S,S,S,B,C,C],
            [C,C,C,B,B,B,B,C,C,C],
        ]
    }

    private func trophyGrid() -> [[UIColor]] {
        return [
            [C,B,B,B,B,B,B,B,C,C],
            [C,B,Y,Y,Y,Y,Y,B,C,C],
            [B,C,B,Y,Y,Y,B,C,B,C],
            [B,C,B,Y,Y,Y,B,C,B,C],
            [C,B,C,B,Y,B,C,B,C,C],
            [C,C,C,B,Y,B,C,C,C,C],
            [C,C,C,B,Y,B,C,C,C,C],
            [C,C,B,Y,Y,Y,B,C,C,C],
            [C,B,B,B,B,B,B,B,C,C],
            [C,C,B,B,B,B,B,C,C,C],
        ]
    }

    private func cancelGrid() -> [[UIColor]] {
        return [
            [C,C,C,C,C,C,C,C,C,C],
            [C,B,B,C,C,C,B,B,C,C],
            [C,B,W,B,C,B,W,B,C,C],
            [C,C,B,W,B,W,B,C,C,C],
            [C,C,C,B,W,B,C,C,C,C],
            [C,C,B,W,B,W,B,C,C,C],
            [C,B,W,B,C,B,W,B,C,C],
            [C,B,B,C,C,C,B,B,C,C],
            [C,C,C,C,C,C,C,C,C,C],
            [C,C,C,C,C,C,C,C,C,C],
        ]
    }

    private func shopGrid() -> [[UIColor]] {
        // Shopping bag
        let S = UIColor(red: 0.85, green: 0.68, blue: 0.30, alpha: 1) // gold bag
        return [
            [C,C,C,B,B,B,C,C,C,C],
            [C,C,B,C,C,C,B,C,C,C],
            [C,C,B,C,C,C,B,C,C,C],
            [C,B,B,B,B,B,B,B,C,C],
            [C,B,S,S,S,S,S,B,C,C],
            [C,B,S,S,S,S,S,B,C,C],
            [C,B,S,S,S,S,S,B,C,C],
            [C,B,S,S,S,S,S,B,C,C],
            [C,B,S,S,S,S,S,B,C,C],
            [C,B,B,B,B,B,B,B,C,C],
        ]
    }

    private func lockGrid() -> [[UIColor]] {
        return [
            [C,C,C,B,B,B,C,C,C,C],
            [C,C,B,C,C,C,B,C,C,C],
            [C,C,B,C,C,C,B,C,C,C],
            [C,B,B,B,B,B,B,B,C,C],
            [C,B,A,A,A,A,A,B,C,C],
            [C,B,A,A,B,A,A,B,C,C],
            [C,B,A,B,W,B,A,B,C,C],
            [C,B,A,A,B,A,A,B,C,C],
            [C,B,A,A,A,A,A,B,C,C],
            [C,B,B,B,B,B,B,B,C,C],
        ]
    }

    private func backGrid() -> [[UIColor]] {
        // Bold left-pointing chevron — reads clearly at small sizes
        return [
            [C,C,C,C,C,C,C,C,C,C],
            [C,C,C,C,C,B,C,C,C,C],
            [C,C,C,C,B,W,B,C,C,C],
            [C,C,C,B,W,W,B,C,C,C],
            [C,C,B,W,W,B,C,C,C,C],
            [C,C,C,B,W,W,B,C,C,C],
            [C,C,C,C,B,W,B,C,C,C],
            [C,C,C,C,C,B,C,C,C,C],
            [C,C,C,C,C,C,C,C,C,C],
            [C,C,C,C,C,C,C,C,C,C],
        ]
    }
}
