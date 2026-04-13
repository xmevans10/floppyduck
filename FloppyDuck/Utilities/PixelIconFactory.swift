import UIKit
import SwiftUI
import SpriteKit

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
    case collection    // 2×2 grid (for collection/inventory screen)

    // Power-ups
    case shield        // barrier circle
    case pipeExpander  // outward arrows
    case breadMagnet   // horseshoe magnet
    case slowMotion    // hourglass
    case ghost         // ghost silhouette
    case pipeSqueeze   // inward arrows
    case speedBurst    // lightning bolt
    case dizzyDuck     // spiral

    // Game items & achievements
    case bread         // bread loaf
    case star          // 5-pointed star
    case crown         // royal crown
    case chick         // hatching chick
    case duck          // duck silhouette
    case swords        // crossed swords
    case ladder        // ladder rungs
    case calendar      // calendar page
    case palette       // paint palette
    case flame         // fire
    case skull         // skull face
    case muscle        // flexing arm
    case ribbon        // award ribbon

    // Medals
    case medalBronze
    case medalSilver
    case medalGold
    case medalPlatinum

    // UI
    case warning       // triangle !
    case checkmark     // ✓
    case questionMark  // ?
    case arrowRight    // →
}

final class PixelIconFactory {
    static let shared = PixelIconFactory()
    private init() {}

    private var cache: [String: UIImage] = [:]
    private let cacheLock = NSLock()

    /// Pre-renders commonly used icons on a background thread.
    func preWarm() {
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            // Pre-render the most used icons at default scale
            let criticalIcons: [PixelIcon] = [
                .play, .headToHead, .bot, .classic, .stats,
                .settings, .home, .retry, .share, .back,
                .medalBronze, .medalSilver, .medalGold, .medalPlatinum,
            ]
            for icon in criticalIcons {
                _ = image(for: icon)
            }
        }
    }

    /// Get a pixel icon as UIImage
    func image(for icon: PixelIcon, pixelScale: CGFloat = 3.0) -> UIImage {
        let key = "\(icon.rawValue)_\(Int(pixelScale))"
        cacheLock.lock()
        if let cached = cache[key] { cacheLock.unlock(); return cached }
        cacheLock.unlock()
        let img = renderIcon(icon, pixelSize: pixelScale)
        cacheLock.lock()
        cache[key] = img
        cacheLock.unlock()
        return img
    }

    /// Create an SKTexture from a pixel icon (for SpriteKit nodes).
    func skTexture(for icon: PixelIcon, pixelScale: CGFloat = 3.0) -> SKTexture {
        SKTexture(image: image(for: icon, pixelScale: pixelScale))
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
        case .collection: grid = collectionGrid()
        case .shield:       grid = shieldGrid()
        case .pipeExpander: grid = pipeExpanderGrid()
        case .breadMagnet:  grid = breadMagnetGrid()
        case .slowMotion:   grid = slowMotionGrid()
        case .ghost:        grid = ghostGrid()
        case .pipeSqueeze:  grid = pipeSqueezeGrid()
        case .speedBurst:   grid = speedBurstGrid()
        case .dizzyDuck:    grid = dizzyDuckGrid()
        case .bread:        grid = breadGrid()
        case .star:         grid = starGrid()
        case .crown:        grid = crownGrid()
        case .chick:        grid = chickGrid()
        case .duck:         grid = duckGrid()
        case .swords:       grid = swordsGrid()
        case .ladder:       grid = ladderGrid()
        case .calendar:     grid = calendarGrid()
        case .palette:      grid = paletteGrid()
        case .flame:        grid = flameGrid()
        case .skull:        grid = skullGrid()
        case .muscle:       grid = muscleGrid()
        case .ribbon:       grid = ribbonGrid()
        case .medalBronze:   grid = medalGrid(fill: Br)
        case .medalSilver:   grid = medalGrid(fill: A)
        case .medalGold:     grid = medalGrid(fill: Y)
        case .medalPlatinum: grid = medalGrid(fill: Bl)
        case .warning:      grid = warningGrid()
        case .checkmark:    grid = checkmarkGrid()
        case .questionMark: grid = questionMarkGrid()
        case .arrowRight:   grid = arrowRightGrid()
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
    private var Bl: UIColor { UIColor(red: 0.40, green: 0.70, blue: 1.00, alpha: 1) } // blue
    private var Br: UIColor { UIColor(red: 0.72, green: 0.45, blue: 0.20, alpha: 1) } // brown
    private var P: UIColor { UIColor(red: 0.65, green: 0.30, blue: 0.85, alpha: 1) }  // purple
    private var S: UIColor { UIColor(red: 0.95, green: 0.80, blue: 0.65, alpha: 1) }  // skin
    private var T: UIColor { UIColor(red: 0.45, green: 0.75, blue: 0.75, alpha: 1) }  // teal

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

    private func collectionGrid() -> [[UIColor]] {
        return [
            [C,B,B,B,B,C,B,B,B,B],
            [C,B,Y,Y,B,C,B,G,G,B],
            [C,B,Y,Y,B,C,B,G,G,B],
            [C,B,B,B,B,C,B,B,B,B],
            [C,C,C,C,C,C,C,C,C,C],
            [C,B,B,B,B,C,B,B,B,B],
            [C,B,O,O,B,C,B,W,W,B],
            [C,B,O,O,B,C,B,W,W,B],
            [C,B,B,B,B,C,B,B,B,B],
            [C,C,C,C,C,C,C,C,C,C],
        ]
    }

    // MARK: - Power-Up Grids

    private func shieldGrid() -> [[UIColor]] {
        return [
            [C,C,C,B,B,B,C,C,C,C],
            [C,C,B,Bl,Bl,Bl,B,C,C,C],
            [C,B,Bl,Bl,Bl,Bl,Bl,B,C,C],
            [C,B,Bl,W,Bl,W,Bl,B,C,C],
            [C,B,Bl,Bl,W,Bl,Bl,B,C,C],
            [C,B,Bl,Bl,Bl,Bl,Bl,B,C,C],
            [C,C,B,Bl,Bl,Bl,B,C,C,C],
            [C,C,C,B,Bl,B,C,C,C,C],
            [C,C,C,C,B,C,C,C,C,C],
            [C,C,C,C,C,C,C,C,C,C],
        ]
    }

    private func pipeExpanderGrid() -> [[UIColor]] {
        return [
            [C,C,C,C,C,C,C,C,C,C],
            [C,B,C,C,C,C,C,B,C,C],
            [B,G,B,C,C,C,B,G,B,C],
            [B,G,G,B,B,B,G,G,B,C],
            [B,G,G,G,G,G,G,G,B,C],
            [B,G,G,B,B,B,G,G,B,C],
            [B,G,B,C,C,C,B,G,B,C],
            [C,B,C,C,C,C,C,B,C,C],
            [C,C,C,C,C,C,C,C,C,C],
            [C,C,C,C,C,C,C,C,C,C],
        ]
    }

    private func breadMagnetGrid() -> [[UIColor]] {
        return [
            [C,B,B,C,C,C,B,B,C,C],
            [B,R,R,B,C,B,R,R,B,C],
            [B,R,R,B,C,B,R,R,B,C],
            [B,A,A,B,C,B,A,A,B,C],
            [B,A,B,C,C,C,B,A,B,C],
            [C,B,C,C,C,C,C,B,C,C],
            [C,B,C,C,C,C,C,B,C,C],
            [C,C,B,C,C,C,B,C,C,C],
            [C,C,C,B,B,B,C,C,C,C],
            [C,C,C,C,C,C,C,C,C,C],
        ]
    }

    private func slowMotionGrid() -> [[UIColor]] {
        return [
            [C,C,B,B,B,B,B,C,C,C],
            [C,C,C,B,T,B,C,C,C,C],
            [C,C,C,C,B,C,C,C,C,C],
            [C,C,C,B,T,B,C,C,C,C],
            [C,C,B,T,T,T,B,C,C,C],
            [C,C,C,B,T,B,C,C,C,C],
            [C,C,C,C,B,C,C,C,C,C],
            [C,C,C,B,T,B,C,C,C,C],
            [C,C,B,B,B,B,B,C,C,C],
            [C,C,C,C,C,C,C,C,C,C],
        ]
    }

    private func ghostGrid() -> [[UIColor]] {
        return [
            [C,C,C,B,B,B,C,C,C,C],
            [C,C,B,W,W,W,B,C,C,C],
            [C,B,W,W,W,W,W,B,C,C],
            [C,B,W,B,W,B,W,B,C,C],
            [C,B,W,W,W,W,W,B,C,C],
            [C,B,W,W,W,W,W,B,C,C],
            [C,B,W,W,W,W,W,B,C,C],
            [C,B,W,W,W,W,W,B,C,C],
            [C,B,C,B,C,B,C,B,C,C],
            [C,C,C,C,C,C,C,C,C,C],
        ]
    }

    private func pipeSqueezeGrid() -> [[UIColor]] {
        return [
            [C,C,C,C,C,C,C,C,C,C],
            [C,C,B,C,C,C,B,C,C,C],
            [C,B,A,B,C,B,A,B,C,C],
            [B,A,A,B,B,B,A,A,B,C],
            [B,A,A,A,A,A,A,A,B,C],
            [B,A,A,B,B,B,A,A,B,C],
            [C,B,A,B,C,B,A,B,C,C],
            [C,C,B,C,C,C,B,C,C,C],
            [C,C,C,C,C,C,C,C,C,C],
            [C,C,C,C,C,C,C,C,C,C],
        ]
    }

    private func speedBurstGrid() -> [[UIColor]] {
        return [
            [C,C,C,C,B,B,C,C,C,C],
            [C,C,C,B,Y,B,C,C,C,C],
            [C,C,B,Y,B,C,C,C,C,C],
            [C,B,Y,Y,B,C,C,C,C,C],
            [B,Y,Y,Y,Y,Y,B,C,C,C],
            [C,C,C,C,B,Y,B,C,C,C],
            [C,C,C,B,Y,B,C,C,C,C],
            [C,C,B,Y,B,C,C,C,C,C],
            [C,C,B,B,C,C,C,C,C,C],
            [C,C,C,C,C,C,C,C,C,C],
        ]
    }

    private func dizzyDuckGrid() -> [[UIColor]] {
        return [
            [C,C,C,C,C,C,C,C,C,C],
            [C,C,B,B,B,C,C,C,C,C],
            [C,B,P,P,P,B,C,C,C,C],
            [C,B,P,B,C,B,C,C,C,C],
            [C,C,B,P,P,B,C,C,C,C],
            [C,C,B,P,B,C,C,C,C,C],
            [C,C,C,B,C,C,C,C,C,C],
            [C,C,C,C,C,C,C,C,C,C],
            [C,C,C,B,C,C,C,C,C,C],
            [C,C,C,C,C,C,C,C,C,C],
        ]
    }

    // MARK: - Game Item Grids

    private func breadGrid() -> [[UIColor]] {
        let T = UIColor(red: 0.82, green: 0.62, blue: 0.30, alpha: 1) // tan
        let D = UIColor(red: 0.65, green: 0.45, blue: 0.20, alpha: 1) // dark crust
        return [
            [C,C,C,B,B,B,B,C,C,C],
            [C,C,B,D,D,D,D,B,C,C],
            [C,B,D,D,D,D,D,D,B,C],
            [C,B,D,T,T,T,T,D,B,C],
            [B,D,T,T,T,T,T,T,D,B],
            [B,T,T,T,T,T,T,T,T,B],
            [B,T,T,T,T,T,T,T,T,B],
            [C,B,T,T,T,T,T,T,B,C],
            [C,C,B,B,B,B,B,B,C,C],
            [C,C,C,C,C,C,C,C,C,C],
        ]
    }

    private func starGrid() -> [[UIColor]] {
        return [
            [C,C,C,C,B,C,C,C,C,C],
            [C,C,C,B,Y,B,C,C,C,C],
            [C,C,C,B,Y,B,C,C,C,C],
            [B,B,B,Y,Y,Y,B,B,B,C],
            [C,B,Y,Y,Y,Y,Y,B,C,C],
            [C,C,B,Y,Y,Y,B,C,C,C],
            [C,B,Y,Y,B,Y,Y,B,C,C],
            [C,B,Y,B,C,B,Y,B,C,C],
            [B,Y,B,C,C,C,B,Y,B,C],
            [C,B,C,C,C,C,C,B,C,C],
        ]
    }

    private func crownGrid() -> [[UIColor]] {
        return [
            [C,B,C,C,B,C,C,B,C,C],
            [C,B,Y,C,B,C,Y,B,C,C],
            [C,B,Y,B,Y,B,Y,B,C,C],
            [C,B,Y,Y,Y,Y,Y,B,C,C],
            [C,B,Y,Y,Y,Y,Y,B,C,C],
            [C,B,Y,Y,Y,Y,Y,B,C,C],
            [C,B,Y,R,Y,R,Y,B,C,C],
            [C,B,B,B,B,B,B,B,C,C],
            [C,C,C,C,C,C,C,C,C,C],
            [C,C,C,C,C,C,C,C,C,C],
        ]
    }

    private func chickGrid() -> [[UIColor]] {
        return [
            [C,C,C,C,B,B,C,C,C,C],
            [C,C,C,B,Y,Y,B,C,C,C],
            [C,C,B,Y,B,Y,Y,B,C,C],
            [C,C,B,Y,Y,Y,Y,B,C,C],
            [C,C,C,B,Y,O,B,C,C,C],
            [C,B,B,B,B,B,B,B,B,C],
            [B,W,W,W,W,W,W,W,W,B],
            [B,W,W,W,W,W,W,W,W,B],
            [C,B,W,W,W,W,W,W,B,C],
            [C,C,B,B,B,B,B,B,C,C],
        ]
    }

    private func duckGrid() -> [[UIColor]] {
        let g = UIColor(red: 0.08, green: 0.42, blue: 0.22, alpha: 1)
        return [
            [C,C,B,B,B,C,C,C,C,C],
            [C,B,g,g,g,B,C,C,C,C],
            [C,B,g,W,g,B,C,C,C,C],
            [C,C,B,B,B,O,B,C,C,C],
            [C,C,B,g,B,B,C,C,C,C],
            [C,B,g,g,g,B,C,C,C,C],
            [B,g,g,g,g,g,B,C,C,C],
            [B,g,g,g,g,g,B,C,C,C],
            [C,B,B,B,B,B,C,C,C,C],
            [C,C,O,C,O,C,C,C,C,C],
        ]
    }

    private func swordsGrid() -> [[UIColor]] {
        return [
            [B,C,C,C,C,C,C,C,B,C],
            [C,B,A,C,C,C,A,B,C,C],
            [C,C,B,A,C,A,B,C,C,C],
            [C,C,C,B,A,B,C,C,C,C],
            [C,C,C,A,B,A,C,C,C,C],
            [C,C,B,C,B,C,B,C,C,C],
            [C,B,C,C,B,C,C,B,C,C],
            [B,Br,C,C,C,C,C,Br,B,C],
            [C,B,C,C,C,C,C,B,C,C],
            [C,C,C,C,C,C,C,C,C,C],
        ]
    }

    private func ladderGrid() -> [[UIColor]] {
        return [
            [C,B,Br,B,C,B,Br,B,C,C],
            [C,B,Br,B,C,B,Br,B,C,C],
            [C,B,Br,Br,Br,Br,Br,B,C,C],
            [C,B,Br,B,C,B,Br,B,C,C],
            [C,B,Br,B,C,B,Br,B,C,C],
            [C,B,Br,Br,Br,Br,Br,B,C,C],
            [C,B,Br,B,C,B,Br,B,C,C],
            [C,B,Br,B,C,B,Br,B,C,C],
            [C,B,Br,Br,Br,Br,Br,B,C,C],
            [C,B,B,B,C,B,B,B,C,C],
        ]
    }

    private func calendarGrid() -> [[UIColor]] {
        return [
            [C,B,C,C,C,C,B,C,C,C],
            [B,B,B,B,B,B,B,B,B,C],
            [B,R,R,R,R,R,R,R,B,C],
            [B,B,B,B,B,B,B,B,B,C],
            [B,W,W,B,W,W,B,W,B,C],
            [B,W,W,B,W,W,B,C,B,C],
            [B,B,B,B,B,B,B,B,B,C],
            [B,W,W,B,W,W,B,W,B,C],
            [B,W,W,B,C,C,B,C,B,C],
            [B,B,B,B,B,B,B,B,B,C],
        ]
    }

    private func paletteGrid() -> [[UIColor]] {
        return [
            [C,C,B,B,B,B,B,C,C,C],
            [C,B,W,W,W,W,W,B,C,C],
            [B,W,R,B,W,Bl,B,W,B,C],
            [B,W,B,W,W,B,W,W,B,C],
            [B,W,W,W,W,W,W,B,C,C],
            [B,W,Y,B,W,W,B,C,C,C],
            [B,W,B,W,W,B,W,B,C,C],
            [C,B,W,W,G,B,W,B,C,C],
            [C,C,B,W,B,W,B,C,C,C],
            [C,C,C,B,B,B,C,C,C,C],
        ]
    }

    private func flameGrid() -> [[UIColor]] {
        return [
            [C,C,C,C,B,C,C,C,C,C],
            [C,C,C,B,O,B,C,C,C,C],
            [C,C,C,B,O,B,C,C,C,C],
            [C,C,B,O,Y,O,B,C,C,C],
            [C,B,O,O,Y,O,O,B,C,C],
            [C,B,R,O,Y,O,R,B,C,C],
            [C,B,R,O,Y,O,R,B,C,C],
            [C,B,R,R,Y,R,R,B,C,C],
            [C,C,B,R,R,R,B,C,C,C],
            [C,C,C,B,B,B,C,C,C,C],
        ]
    }

    private func skullGrid() -> [[UIColor]] {
        return [
            [C,C,B,B,B,B,B,C,C,C],
            [C,B,W,W,W,W,W,B,C,C],
            [B,W,W,W,W,W,W,W,B,C],
            [B,W,B,W,W,B,W,W,B,C],
            [B,W,B,W,W,B,W,W,B,C],
            [B,W,W,W,B,W,W,W,B,C],
            [C,B,W,W,W,W,W,B,C,C],
            [C,C,B,W,B,W,B,C,C,C],
            [C,C,C,B,C,B,C,C,C,C],
            [C,C,C,C,C,C,C,C,C,C],
        ]
    }

    private func muscleGrid() -> [[UIColor]] {
        return [
            [C,C,C,C,C,C,B,B,C,C],
            [C,C,C,C,C,B,S,S,B,C],
            [C,C,C,C,B,S,S,S,B,C],
            [C,B,B,B,S,S,S,B,C,C],
            [B,S,S,S,S,S,B,C,C,C],
            [C,B,S,S,S,B,C,C,C,C],
            [C,C,B,S,B,C,C,C,C,C],
            [C,C,B,S,B,C,C,C,C,C],
            [C,C,C,B,C,C,C,C,C,C],
            [C,C,C,C,C,C,C,C,C,C],
        ]
    }

    private func ribbonGrid() -> [[UIColor]] {
        return [
            [C,C,C,B,B,B,C,C,C,C],
            [C,C,B,Bl,Bl,Bl,B,C,C,C],
            [C,C,B,Bl,Bl,Bl,B,C,C,C],
            [C,C,C,B,Y,B,C,C,C,C],
            [C,C,C,B,Y,B,C,C,C,C],
            [C,C,C,B,Y,B,C,C,C,C],
            [C,C,B,Bl,Y,Bl,B,C,C,C],
            [C,B,Bl,C,Y,C,Bl,B,C,C],
            [C,B,C,C,C,C,C,B,C,C],
            [C,C,C,C,C,C,C,C,C,C],
        ]
    }

    // MARK: - Medal Grid (parameterized by fill color)

    private func medalGrid(fill: UIColor) -> [[UIColor]] {
        return [
            [C,C,C,C,B,C,C,C,C,C],
            [C,C,C,B,A,B,C,C,C,C],
            [C,C,B,B,B,B,B,C,C,C],
            [C,B,fill,fill,fill,fill,fill,B,C,C],
            [B,fill,fill,fill,fill,fill,fill,fill,B,C],
            [B,fill,fill,B,B,B,fill,fill,B,C],
            [B,fill,fill,fill,fill,fill,fill,fill,B,C],
            [C,B,fill,fill,fill,fill,fill,B,C,C],
            [C,C,B,B,B,B,B,C,C,C],
            [C,C,C,C,C,C,C,C,C,C],
        ]
    }

    // MARK: - UI Grids

    private func warningGrid() -> [[UIColor]] {
        return [
            [C,C,C,C,B,C,C,C,C,C],
            [C,C,C,B,Y,B,C,C,C,C],
            [C,C,C,B,Y,B,C,C,C,C],
            [C,C,B,Y,Y,Y,B,C,C,C],
            [C,C,B,Y,B,Y,B,C,C,C],
            [C,B,Y,Y,B,Y,Y,B,C,C],
            [C,B,Y,Y,B,Y,Y,B,C,C],
            [B,Y,Y,Y,Y,Y,Y,Y,B,C],
            [B,Y,Y,Y,B,Y,Y,Y,B,C],
            [B,B,B,B,B,B,B,B,B,C],
        ]
    }

    private func checkmarkGrid() -> [[UIColor]] {
        return [
            [C,C,C,C,C,C,C,C,C,C],
            [C,C,C,C,C,C,C,C,B,C],
            [C,C,C,C,C,C,C,B,G,B],
            [C,C,C,C,C,C,B,G,B,C],
            [C,C,C,C,C,B,G,B,C,C],
            [B,C,C,C,B,G,B,C,C,C],
            [C,B,C,B,G,B,C,C,C,C],
            [C,C,B,G,B,C,C,C,C,C],
            [C,C,C,B,C,C,C,C,C,C],
            [C,C,C,C,C,C,C,C,C,C],
        ]
    }

    private func questionMarkGrid() -> [[UIColor]] {
        return [
            [C,C,B,B,B,B,C,C,C,C],
            [C,B,W,W,W,W,B,C,C,C],
            [C,B,C,C,C,W,B,C,C,C],
            [C,C,C,C,B,W,B,C,C,C],
            [C,C,C,B,W,B,C,C,C,C],
            [C,C,C,B,W,B,C,C,C,C],
            [C,C,C,C,B,C,C,C,C,C],
            [C,C,C,B,W,B,C,C,C,C],
            [C,C,C,C,B,C,C,C,C,C],
            [C,C,C,C,C,C,C,C,C,C],
        ]
    }

    private func arrowRightGrid() -> [[UIColor]] {
        return [
            [C,C,C,C,C,C,C,C,C,C],
            [C,C,C,C,C,B,C,C,C,C],
            [C,C,C,C,C,C,B,C,C,C],
            [B,B,B,B,B,B,B,B,C,C],
            [B,W,W,W,W,W,W,W,B,C],
            [B,B,B,B,B,B,B,B,C,C],
            [C,C,C,C,C,C,B,C,C,C],
            [C,C,C,C,C,B,C,C,C,C],
            [C,C,C,C,C,C,C,C,C,C],
            [C,C,C,C,C,C,C,C,C,C],
        ]
    }
}
