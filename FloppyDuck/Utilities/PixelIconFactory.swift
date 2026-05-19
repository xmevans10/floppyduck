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

    // Power-ups (14×14 redesigned icons)
    case shield        // barrier circle
    case pipeExpander  // outward arrows (green +)
    case breadMagnet   // horseshoe magnet
    case slowMotion    // hourglass
    case ghost         // ghost silhouette
    case doublePoints  // 2× symbol
    case pipeSqueeze   // inward arrows (red squeeze)
    case speedBurst    // lightning bolt
    case dizzyDuck     // spiral
    case heavyDuck     // anchor
    case jumboDuck     // oversized duck
    case tinyDuck      // shrink arrow + duck
    case megaFlap      // powerful wing burst

    // New power-ups / collectibles
    case loafBread     // golden loaf (collectible worth 10×)
    case featherweight // feather (reduced gravity)
    case mysteryBox    // random power-up box (Mario ? block)
    case foggy         // fog debuff (obscured vision)

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
        case .doublePoints: grid = doublePointsGrid()
        case .dizzyDuck:    grid = dizzyDuckGrid()
        case .heavyDuck:    grid = heavyDuckGrid()
        case .jumboDuck:    grid = jumboDuckGrid()
        case .tinyDuck:     grid = tinyDuckGrid()
        case .megaFlap:       grid = megaFlapGrid()
        case .loafBread:     grid = loafBreadGrid()
        case .featherweight: grid = featherweightGrid()
        case .mysteryBox:    grid = mysteryBoxGrid()
        case .foggy:         grid = foggyGrid()
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

#if DEBUG
        // Validate grid consistency — flag malformed rows so we can fix the source
        for (i, row) in grid.enumerated() where row.count != gridW {
            print("[PixelIconFactory] ⚠️ '\(icon.rawValue)' row \(i) has \(row.count) cols, expected \(gridW)")
        }
#endif
        let imgSize = CGSize(width: CGFloat(gridW) * pixelSize, height: CGFloat(gridH) * pixelSize)

        let renderer = UIGraphicsImageRenderer(size: imgSize)
        return renderer.image { ctx in
            for row in 0..<gridH {
                let rowData = grid[row]
                let rowW = rowData.count
                for col in 0..<gridW {
                    guard col < rowW else { break }
                    let color = rowData[col]
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

    // Redesigned icon colors
    private var Dr: UIColor { UIColor(red: 0.67, green: 0.24, blue: 0.24, alpha: 1) }  // dark red
    private var Dy: UIColor { UIColor(red: 0.78, green: 0.67, blue: 0.16, alpha: 1) }  // dark yellow
    private var La: UIColor { UIColor(red: 1.00, green: 0.82, blue: 0.47, alpha: 1) }  // light amber
    private var Lb: UIColor { UIColor(red: 0.63, green: 0.82, blue: 1.00, alpha: 1) }  // lighter blue
    private var Lg: UIColor { UIColor(red: 0.63, green: 0.86, blue: 0.39, alpha: 1) }  // light green
    private var Lp: UIColor { UIColor(red: 0.78, green: 0.59, blue: 1.00, alpha: 1) }  // light purple
    private var Lt: UIColor { UIColor(red: 0.63, green: 0.86, blue: 0.86, alpha: 1) }  // light teal

    // Loaf bread colors
    private var Dc: UIColor { UIColor(red: 0.47, green: 0.27, blue: 0.10, alpha: 1) }  // dark crust
    private var Gc: UIColor { UIColor(red: 0.84, green: 0.65, blue: 0.27, alpha: 1) }  // golden crust
    private var Hi: UIColor { UIColor(red: 0.98, green: 0.90, blue: 0.69, alpha: 1) }  // highlight
    private var In_: UIColor { UIColor(red: 0.92, green: 0.78, blue: 0.51, alpha: 1) } // interior
    private var Cr: UIColor { UIColor(red: 0.71, green: 0.45, blue: 0.18, alpha: 1) }  // medium crust
    private var Gd: UIColor { UIColor(red: 1.00, green: 0.84, blue: 0.00, alpha: 1) }  // gold sparkle

    // Feather colors
    private var Fs: UIColor { UIColor(red: 0.24, green: 0.39, blue: 0.63, alpha: 1) }  // shaft
    private var Fd: UIColor { UIColor(red: 0.35, green: 0.59, blue: 0.82, alpha: 1) }  // dark vane
    private var Fm: UIColor { UIColor(red: 0.55, green: 0.76, blue: 0.94, alpha: 1) }  // mid vane
    private var Fl: UIColor { UIColor(red: 0.75, green: 0.88, blue: 1.00, alpha: 1) }  // light vane
    private var Fw: UIColor { UIColor(red: 0.90, green: 0.96, blue: 1.00, alpha: 1) }  // feather white

    // Mystery box gold
    private var Bk: UIColor { UIColor(red: 0.31, green: 0.22, blue: 0.02, alpha: 1) }  // darkest gold
    private var Bd: UIColor { UIColor(red: 0.63, green: 0.43, blue: 0.04, alpha: 1) }  // shadow gold
    private var Bm: UIColor { UIColor(red: 0.84, green: 0.65, blue: 0.12, alpha: 1) }  // mid gold
    private var Bx: UIColor { UIColor(red: 0.96, green: 0.78, blue: 0.20, alpha: 1) }  // light gold (box)
    private var Bh: UIColor { UIColor(red: 1.00, green: 0.90, blue: 0.39, alpha: 1) }  // highlight gold

    // Fog colors
    private var F3: UIColor { UIColor(red: 0.51, green: 0.53, blue: 0.59, alpha: 1) }  // dark fog
    private var F4: UIColor { UIColor(red: 0.67, green: 0.69, blue: 0.74, alpha: 1) }  // mid fog
    private var F5: UIColor { UIColor(red: 0.80, green: 0.82, blue: 0.86, alpha: 1) }  // light fog
    private var F2: UIColor { UIColor(red: 0.37, green: 0.39, blue: 0.47, alpha: 1) }  // darker fog
    private var Ey: UIColor { UIColor(red: 0.94, green: 0.94, blue: 0.96, alpha: 1) }  // eye white
    private var Ir: UIColor { UIColor(red: 0.27, green: 0.51, blue: 0.75, alpha: 1) }  // iris
    private var Ep: UIColor { UIColor(red: 0.10, green: 0.10, blue: 0.14, alpha: 1) }  // pupil

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
            [C,C,C,C,C,B,B,B,B,C,C,C,C,C],
            [C,C,C,C,B,Bl,Bl,Bl,Bl,B,C,C,C,C],
            [C,C,C,B,Bl,Bl,Bl,Bl,Bl,Bl,B,C,C,C],
            [C,C,B,Bl,Bl,Bl,Bl,Bl,Bl,Bl,Bl,B,C,C],
            [C,C,B,Bl,Bl,W,Bl,Bl,W,Bl,Bl,B,C,C],
            [C,C,B,Bl,Bl,Bl,W,W,Bl,Bl,Bl,B,C,C],
            [C,C,B,Bl,W,W,W,W,W,W,Bl,B,C,C],
            [C,C,B,Bl,Bl,Bl,W,W,Bl,Bl,Bl,B,C,C],
            [C,C,B,Bl,Bl,W,Bl,Bl,W,Bl,Bl,B,C,C],
            [C,C,C,B,Bl,Bl,Bl,Bl,Bl,Bl,B,C,C,C],
            [C,C,C,C,B,Bl,Bl,Bl,Bl,B,C,C,C,C],
            [C,C,C,C,C,B,Bl,Bl,B,C,C,C,C,C],
            [C,C,C,C,C,C,B,B,C,C,C,C,C,C],
            [C,C,C,C,C,C,C,C,C,C,C,C,C,C],
        ]
    }

    private func pipeExpanderGrid() -> [[UIColor]] {
        return [
            [C,C,C,C,C,C,C,C,C,C,C,C,C,C],
            [C,C,B,G,B,C,C,C,C,C,B,G,B,C],
            [C,C,B,G,B,C,C,C,C,C,B,G,B,C],
            [C,C,B,G,B,C,C,C,C,C,B,G,B,C],
            [C,C,B,G,B,C,B,B,C,C,B,G,B,C],
            [C,C,B,G,B,B,Lg,B,C,C,B,G,B,C],
            [B,B,B,G,Lg,Lg,Lg,Lg,Lg,B,B,G,B,C],
            [B,B,B,G,Lg,Lg,Lg,Lg,Lg,B,B,G,B,C],
            [C,C,B,G,B,B,Lg,B,C,C,B,G,B,C],
            [C,C,B,G,B,C,B,B,C,C,B,G,B,C],
            [C,C,B,G,B,C,C,C,C,C,B,G,B,C],
            [C,C,B,G,B,C,C,C,C,C,B,G,B,C],
            [C,C,B,G,B,C,C,C,C,C,B,G,B,C],
            [C,C,C,C,C,C,C,C,C,C,C,C,C,C],
        ]
    }

    private func breadMagnetGrid() -> [[UIColor]] {
        return [
            [C,C,B,B,B,C,C,C,B,B,B,C,C,C],
            [C,B,R,R,R,B,C,B,R,R,R,B,C,C],
            [C,B,R,R,R,B,C,B,R,R,R,B,C,C],
            [C,B,R,R,R,B,C,B,R,R,R,B,C,C],
            [C,B,A,A,A,B,C,B,A,A,A,B,C,C],
            [C,B,A,A,A,B,C,B,A,A,A,B,C,C],
            [C,B,A,A,B,C,C,C,B,A,A,B,C,C],
            [C,C,B,A,B,C,C,C,B,A,B,C,C,C],
            [C,C,B,B,C,C,C,C,C,B,B,C,C,C],
            [C,C,C,B,C,C,C,C,C,B,C,C,C,C],
            [C,C,C,C,B,C,C,C,B,C,C,C,C,C],
            [C,C,C,C,C,B,B,B,C,C,C,C,C,C],
            [C,C,C,C,C,C,C,C,C,C,C,C,C,C],
            [C,C,C,C,C,C,C,C,C,C,C,C,C,C],
        ]
    }

    private func slowMotionGrid() -> [[UIColor]] {
        return [
            [C,C,C,B,B,B,B,B,B,B,B,C,C,C],
            [C,C,C,B,T,T,T,T,T,T,B,C,C,C],
            [C,C,C,C,B,T,T,T,T,B,C,C,C,C],
            [C,C,C,C,C,B,T,T,B,C,C,C,C,C],
            [C,C,C,C,C,C,B,B,C,C,C,C,C,C],
            [C,C,C,C,C,B,Lt,Lt,B,C,C,C,C,C],
            [C,C,C,C,B,T,Lt,Lt,T,B,C,C,C,C],
            [C,C,C,B,T,T,Lt,Lt,T,T,B,C,C,C],
            [C,C,C,B,T,T,T,T,T,T,B,C,C,C],
            [C,C,C,C,B,T,T,T,T,B,C,C,C,C],
            [C,C,C,C,C,B,T,T,B,C,C,C,C,C],
            [C,C,C,C,C,C,B,B,C,C,C,C,C,C],
            [C,C,C,B,B,B,B,B,B,B,B,C,C,C],
            [C,C,C,C,C,C,C,C,C,C,C,C,C,C],
        ]
    }

    private func ghostGrid() -> [[UIColor]] {
        return [
            [C,C,C,C,C,B,B,B,B,C,C,C,C,C],
            [C,C,C,C,B,W,W,W,W,B,C,C,C,C],
            [C,C,C,B,W,W,W,W,W,W,B,C,C,C],
            [C,C,B,W,W,W,W,W,W,W,W,B,C,C],
            [C,C,B,W,B,B,W,W,B,B,W,B,C,C],
            [C,C,B,W,B,B,W,W,B,B,W,B,C,C],
            [C,C,B,W,W,W,W,W,W,W,W,B,C,C],
            [C,C,B,W,W,W,W,W,W,W,W,B,C,C],
            [C,C,B,W,W,W,W,W,W,W,W,B,C,C],
            [C,C,B,W,W,W,W,W,W,W,W,B,C,C],
            [C,C,B,W,W,W,W,W,W,W,W,B,C,C],
            [C,C,B,W,B,W,W,W,B,W,W,B,C,C],
            [C,C,B,C,C,B,W,B,C,C,B,C,C,C],
            [C,C,C,C,C,C,C,C,C,C,C,C,C,C],
        ]
    }

    private func pipeSqueezeGrid() -> [[UIColor]] {
        return [
            [C,C,C,C,C,C,C,C,C,C,C,C,C,C],
            [C,B,Dr,B,C,C,C,C,C,C,B,Dr,B,C],
            [C,B,Dr,B,C,C,C,C,C,C,B,Dr,B,C],
            [C,B,Dr,B,C,C,C,C,C,C,B,Dr,B,C],
            [C,B,Dr,B,C,C,B,B,C,C,B,Dr,B,C],
            [C,B,Dr,B,C,B,R,B,B,C,B,Dr,B,C],
            [C,B,Dr,B,B,R,R,R,R,B,B,Dr,B,C],
            [C,B,Dr,B,B,R,R,R,R,B,B,Dr,B,C],
            [C,B,Dr,B,C,B,R,B,B,C,B,Dr,B,C],
            [C,B,Dr,B,C,C,B,B,C,C,B,Dr,B,C],
            [C,B,Dr,B,C,C,C,C,C,C,B,Dr,B,C],
            [C,B,Dr,B,C,C,C,C,C,C,B,Dr,B,C],
            [C,B,Dr,B,C,C,C,C,C,C,B,Dr,B,C],
            [C,C,C,C,C,C,C,C,C,C,C,C,C,C],
        ]
    }

    private func speedBurstGrid() -> [[UIColor]] {
        return [
            [C,C,C,C,C,C,B,B,B,C,C,C,C,C],
            [C,C,C,C,C,B,Y,Y,B,C,C,C,C,C],
            [C,C,C,C,B,Y,Y,B,C,C,C,C,C,C],
            [C,C,C,B,Y,Y,B,C,C,C,C,C,C,C],
            [C,C,B,Y,Y,Y,B,C,C,C,C,C,C,C],
            [C,B,Y,Y,Y,Y,Y,Y,B,C,C,C,C,C],
            [B,Y,Y,Y,Y,Y,Y,Y,Y,B,C,C,C,C],
            [C,C,C,C,C,B,Y,Y,Y,B,C,C,C,C],
            [C,C,C,C,C,C,B,Y,Y,B,C,C,C,C],
            [C,C,C,C,C,B,Y,Y,B,C,C,C,C,C],
            [C,C,C,C,B,Y,Y,B,C,C,C,C,C,C],
            [C,C,C,B,Y,Y,B,C,C,C,C,C,C,C],
            [C,C,C,B,B,B,C,C,C,C,C,C,C,C],
            [C,C,C,C,C,C,C,C,C,C,C,C,C,C],
        ]
    }

    private func dizzyDuckGrid() -> [[UIColor]] {
        return [
            [C,C,C,C,C,C,C,C,C,C,C,B,C,C],
            [C,C,C,B,B,B,B,B,B,B,B,P,B,C],
            [C,C,B,P,P,P,P,P,P,P,B,C,C,C],
            [C,B,P,P,B,B,B,B,B,P,P,B,C,C],
            [C,B,P,B,C,C,C,C,B,P,P,B,C,C],
            [C,B,P,B,C,B,B,B,C,B,P,B,C,C],
            [C,B,P,B,C,B,Lp,B,C,C,B,B,C,C],
            [C,B,P,B,C,C,B,B,C,C,C,B,C,C],
            [C,B,P,B,C,C,C,C,C,C,B,C,C,C],
            [C,B,P,P,B,B,B,B,B,B,C,C,C,C],
            [C,C,B,P,P,P,P,P,P,B,C,C,C,C],
            [C,C,C,B,B,B,B,B,B,C,C,C,C,C],
            [C,B,C,C,C,C,C,C,C,C,C,C,C,C],
            [B,P,B,C,C,C,C,C,C,C,C,C,C,C],
        ]
    }

    private func doublePointsGrid() -> [[UIColor]] {
        return [
            [C,C,C,C,C,C,C,C,C,C,C,C,C,C],
            [C,C,C,C,B,B,B,B,B,C,C,C,C,C],
            [C,C,C,B,Y,Y,Y,Y,Y,B,C,C,C,C],
            [C,C,C,B,Y,Dy,Y,Dy,Y,B,C,C,C,C],
            [C,C,C,B,Y,Y,Y,Y,Y,B,C,C,C,C],
            [C,C,C,C,B,B,B,B,B,C,C,C,C,C],
            [C,C,C,C,C,C,C,C,C,C,C,C,C,C],
            [C,C,C,C,B,B,B,B,B,C,C,C,C,C],
            [C,C,C,B,Y,Y,Y,Y,Y,B,C,C,C,C],
            [C,C,C,B,Y,Dy,Y,Dy,Y,B,C,C,C,C],
            [C,C,C,B,Y,Y,Y,Y,Y,B,C,C,C,C],
            [C,C,C,C,B,B,B,B,B,C,C,C,C,C],
            [C,C,C,C,C,C,C,C,C,C,C,C,C,C],
            [C,C,C,C,C,C,C,C,C,C,C,C,C,C],
        ]
    }

    private func heavyDuckGrid() -> [[UIColor]] {
        let Ds = UIColor(red: 0.35, green: 0.35, blue: 0.40, alpha: 1) // dark steel
        let Ss = UIColor(red: 0.55, green: 0.55, blue: 0.60, alpha: 1) // steel
        return [
            [C,C,C,C,C,C,C,C,C,C,C,C,C,C],
            [C,C,C,B,B,B,B,B,B,B,B,C,C,C],
            [C,C,B,Ss,Ss,Ss,Ss,Ss,Ss,Ss,Ss,B,C,C],
            [C,C,C,B,B,B,B,B,B,B,B,C,C,C],
            [C,C,C,C,C,B,Ss,Ss,B,C,C,C,C,C],
            [C,C,C,C,C,B,Ss,Ss,B,C,C,C,C,C],
            [C,C,C,C,C,B,Ss,Ss,B,C,C,C,C,C],
            [C,C,C,C,C,B,Ss,Ss,B,C,C,C,C,C],
            [C,C,C,C,B,Ss,Ss,Ss,Ss,B,C,C,C,C],
            [C,C,C,B,Ss,Ss,Ss,Ss,Ss,Ss,B,C,C,C],
            [C,B,B,Ss,Ss,Ss,Ss,Ss,Ss,Ss,Ss,B,B,C],
            [C,B,Ds,Ds,Ds,Ds,Ds,Ds,Ds,Ds,Ds,Ds,B,C],
            [C,B,B,B,B,B,B,B,B,B,B,B,B,C],
            [C,C,C,C,C,C,C,C,C,C,C,C,C,C],
        ]
    }

    private func jumboDuckGrid() -> [[UIColor]] {
        return [
            [C,C,C,C,C,C,C,C,C,C,C,C,C,C],
            [C,B,C,C,C,C,C,C,C,C,C,C,B,C],
            [C,O,B,C,C,C,C,C,C,C,C,B,O,C],
            [C,B,O,B,C,C,C,C,C,C,B,O,B,C],
            [C,C,B,C,C,B,B,B,B,C,C,B,C,C],
            [C,C,C,C,B,O,O,O,O,B,C,C,C,C],
            [C,C,C,B,O,O,O,O,O,O,B,C,C,C],
            [C,C,C,B,O,O,O,O,O,O,B,C,C,C],
            [C,C,C,C,B,O,O,O,O,B,C,C,C,C],
            [C,C,C,C,C,B,B,B,B,C,C,C,C,C],
            [C,C,B,C,C,C,C,C,C,C,C,B,C,C],
            [C,B,O,B,C,C,C,C,C,C,B,O,B,C],
            [C,O,B,C,C,C,C,C,C,C,C,B,O,C],
            [C,B,C,C,C,C,C,C,C,C,C,C,B,C],
        ]
    }

    private func tinyDuckGrid() -> [[UIColor]] {
        return [
            [C,C,C,C,C,C,C,C,C,C,C,C,C,C],
            [C,C,C,B,C,C,C,C,C,C,B,C,C,C],
            [C,C,C,C,B,C,C,C,C,B,C,C,C,C],
            [C,C,C,C,C,B,C,C,B,C,C,C,C,C],
            [C,C,C,C,C,C,B,B,C,C,C,C,C,C],
            [C,C,C,C,C,B,Lb,Lb,B,C,C,C,C,C],
            [C,C,C,C,B,Lb,Bl,Bl,Lb,B,C,C,C,C],
            [C,C,C,C,B,Lb,Bl,Bl,Lb,B,C,C,C,C],
            [C,C,C,C,C,B,Lb,Lb,B,C,C,C,C,C],
            [C,C,C,C,C,C,B,B,C,C,C,C,C,C],
            [C,C,C,C,C,B,C,C,B,C,C,C,C,C],
            [C,C,C,C,B,C,C,C,C,B,C,C,C,C],
            [C,C,C,B,C,C,C,C,C,C,B,C,C,C],
            [C,C,C,C,C,C,C,C,C,C,C,C,C,C],
        ]
    }

    private func megaFlapGrid() -> [[UIColor]] {
        let Am = UIColor(red: 1.0, green: 0.7, blue: 0.2, alpha: 1) // amber
        return [
            [C,C,C,C,C,C,B,B,C,C,C,C,C,C],
            [C,C,C,C,C,B,Am,Am,B,C,C,C,C,C],
            [C,C,C,C,B,Am,Am,Am,Am,B,C,C,C,C],
            [C,C,C,B,Am,Am,La,La,Am,Am,B,C,C,C],
            [C,C,B,Am,Am,La,La,La,La,Am,Am,B,C,C],
            [C,B,Am,Am,La,La,La,La,La,La,Am,Am,B,C],
            [B,Am,B,B,B,B,B,B,B,B,B,B,Am,B],
            [C,B,C,C,C,C,C,C,C,C,C,C,B,C],
            [C,C,C,C,C,C,B,B,C,C,C,C,C,C],
            [C,C,C,C,C,C,Am,Am,C,C,C,C,C,C],
            [C,C,C,C,C,C,B,B,C,C,C,C,C,C],
            [C,C,C,C,C,C,Am,Am,C,C,C,C,C,C],
            [C,C,C,C,C,C,B,B,C,C,C,C,C,C],
            [C,C,C,C,C,C,C,C,C,C,C,C,C,C],
        ]
    }

    // MARK: - New Power-Up / Collectible Grids (14×14)

    private func loafBreadGrid() -> [[UIColor]] {
        return [
            [C,C,C,C,C,C,C,C,C,C,C,C,C,C],
            [C,C,C,C,C,B,B,B,B,C,C,W,C,C],
            [C,C,C,C,B,Dc,Dc,Dc,Dc,B,W,C,W,C],
            [C,C,C,B,Dc,Gc,Gc,Gc,Gc,Dc,B,C,C,C],
            [C,C,B,Dc,Gc,Hi,Gc,Gc,Hi,Gc,Dc,B,C,C],
            [C,B,Dc,Gc,Gc,Gc,Dc,Gc,Gc,Gc,Gc,Dc,B,C],
            [C,B,Cr,Gc,Gc,Gc,Gc,Gc,Gc,Gc,Gc,Cr,B,C],
            [C,B,Cr,In_,In_,In_,In_,In_,In_,In_,In_,Cr,B,C],
            [C,B,Cr,In_,Hi,Hi,In_,In_,Hi,Hi,In_,Cr,B,C],
            [C,B,Cr,In_,In_,In_,In_,In_,In_,In_,In_,Cr,B,C],
            [C,C,B,Dc,Cr,Cr,Cr,Cr,Cr,Cr,Dc,B,C,C],
            [C,C,C,B,B,B,B,B,B,B,B,B,C,C],
            [C,C,C,C,C,Gd,C,C,Gd,C,C,C,C,C],
            [C,C,C,C,C,C,C,C,C,C,C,C,C,C],
        ]
    }

    private func featherweightGrid() -> [[UIColor]] {
        return [
            [C,C,C,C,C,C,C,C,C,C,C,C,B,C],
            [C,C,C,C,C,C,C,C,C,C,C,B,Fs,B],
            [C,C,C,C,C,C,C,C,C,C,B,Fs,B,C],
            [C,C,C,C,C,C,C,C,C,B,Fd,Fs,B,C],
            [C,C,C,C,C,C,C,C,B,Fm,Fd,Fs,B,C],
            [C,C,C,C,C,C,C,B,Fl,Fm,Fs,B,C,C],
            [C,C,C,C,C,C,B,Fw,Fl,Fs,Fd,B,C,C],
            [C,C,C,C,C,B,Fl,Fw,Fs,Fd,B,C,C,C],
            [C,C,C,C,B,Fm,Fl,Fs,Fd,B,C,C,C,C],
            [C,C,C,B,Fd,Fm,Fs,Fd,B,C,C,C,C,C],
            [C,C,B,Fd,Fm,Fs,Fd,B,C,C,C,C,C,C],
            [C,B,Fw,Fl,Fs,Fd,B,C,C,C,C,C,C,C],
            [C,C,B,Fs,Fs,B,C,C,C,C,C,C,C,C],
            [C,C,C,B,B,C,C,C,C,C,C,C,C,C],
        ]
    }

    private func mysteryBoxGrid() -> [[UIColor]] {
        return [
            [C, B, B, B, B, B, B, B, B, B, B, B, B, C],
            [B,Bh,Bh,Bx,Bx,Bx,Bx,Bx,Bx,Bx,Bx,Bd,Bd, B],
            [B,Bh,Bm,Bm, B, B, B, B, B, B,Bm,Bm,Bd, B],
            [B,Bx,Bm, B, W, W, W, W, W, W, B,Bm,Bd, B],
            [B,Bx,Bm, B, W, W, B, B, W, W, B,Bm,Bd, B],
            [B,Bx,Bm,Bm, B, B,Bm,Bm, B, W, W, B,Bd, B],
            [B,Bx,Bm,Bm,Bm,Bm, B, W, W, B,Bm,Bm,Bd, B],
            [B,Bx,Bm,Bm,Bm, B, W, W, B,Bm,Bm,Bm,Bd, B],
            [B,Bx,Bm,Bm,Bm, B, W, W, B,Bm,Bm,Bm,Bd, B],
            [B,Bx,Bm,Bm,Bm,Bm, B, B,Bm,Bm,Bm,Bm,Bd, B],
            [B,Bx,Bm,Bm,Bm, B, W, W, B,Bm,Bm,Bm,Bd, B],
            [B,Bd,Bm,Bm,Bm,Bm, B, B,Bm,Bm,Bm,Bm,Bd, B],
            [B,Bd,Bd,Bd,Bd,Bd,Bd,Bd,Bd,Bd,Bd,Bd,Bd, B],
            [C, B, B, B, B, B, B, B, B, B, B, B, B, C],
        ]
    }

    private func foggyGrid() -> [[UIColor]] {
        return [
            [C,C,C,C,C,C,C,C,C,C,C,C,C,C],
            [C,C,C,C, B, B, B, B, B, B,C,C,C,C],
            [C,C, B, B,Ey,Ey,Ey,Ey,Ey,Ey, B, B,C,C],
            [C, B,Ey,Ey,Ey, B, B, B, B,Ey,Ey,Ey, B,C],
            [ B,Ey,Ey,Ey, B,Ir,Ir,Ir,Ir, B,Ey,Ey,Ey, B],
            [ B,Ey,Ey,Ey, B,Ir,Ep,Ep,Ir, B,Ey,Ey,Ey, B],
            [F4,F4, B,F4,F5, B, B, B,F5,F5,F4,F4, B,C],
            [C,F3,F4,F4,F5,F5,F5,F5,F5,F5,F4,F3,C,C],
            [C,C,F3,F3,F4,F4,F5,F5,F4,F4,F3,F3,C,C],
            [C,C,C,C,C,C,C,C,C,C,C,C,C,C],
            [F3,F3,F4,F4,F5,F5,F5,F5,F5,F4,F4,F3,F2,C],
            [C,C,C,C,C,C,C,C,C,C,C,C,C,C],
            [F2,F3,F3,F4,F4,F5,F5,F5,F4,F4,F3,F3,F2,C],
            [C,F2,F3,F3,F4,F4,F5,F5,F4,F4,F3,F2,C,C],
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
