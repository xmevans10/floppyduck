import AppKit
import Foundation

struct PixelDuck {
    static let grid: [[Int]] = [
        [0,0,0,0,1,1,1,1,0,0,0,0,0,0,0,0],
        [0,0,0,1,2,2,3,2,1,0,0,0,0,0,0,0],
        [0,0,1,2,2,3,2,2,2,1,0,0,0,0,0,0],
        [0,1,2,2,3,2,4,4,2,2,1,0,0,0,0,0],
        [0,1,2,2,2,2,1,0,2,2,1,1,1,1,0,0],
        [1,2,2,2,2,2,2,2,2,2,1,5,5,6,1,0],
        [1,7,7,2,2,2,2,2,2,1,5,5,5,1,0,0],
        [1,8,8,7,9,10,11,9,12,9,1,1,0,0,0,0],
        [0,1,8,9,9,9,12,9,9,1,0,0,0,0,0,0],
        [0,0,1,9,9,12,9,9,1,0,0,0,0,0,0,0],
        [0,0,0,1,1,1,1,1,0,0,0,0,0,0,0,0],
    ]

    static func color(for value: Int) -> NSColor {
        switch value {
        case 1: return NSColor(calibratedRed: 0.11, green: 0.17, blue: 0.08, alpha: 1) // outline
        case 2: return NSColor(calibratedRed: 0.08, green: 0.42, blue: 0.22, alpha: 1) // head
        case 3: return NSColor(calibratedRed: 0.15, green: 0.58, blue: 0.35, alpha: 1) // head hi
        case 4: return .white // eye
        case 5: return NSColor(calibratedRed: 0.93, green: 0.65, blue: 0.10, alpha: 1) // bill
        case 6: return NSColor(calibratedRed: 0.80, green: 0.55, blue: 0.08, alpha: 1) // bill tip
        case 7: return .white // collar
        case 8: return NSColor(calibratedRed: 0.55, green: 0.22, blue: 0.10, alpha: 1) // breast
        case 9: return NSColor(calibratedRed: 0.58, green: 0.58, blue: 0.58, alpha: 1) // body
        case 10: return NSColor(calibratedRed: 0.15, green: 0.30, blue: 0.70, alpha: 1) // wing
        case 11: return NSColor(calibratedRed: 0.25, green: 0.45, blue: 0.85, alpha: 1) // wing hi
        case 12: return NSColor(calibratedRed: 0.72, green: 0.72, blue: 0.72, alpha: 1) // body hi
        default: return .clear
        }
    }
}

func drawDuck(origin: CGPoint, pixel: CGFloat) {
    let rows = PixelDuck.grid.count
    let cols = PixelDuck.grid[0].count

    for row in 0..<rows {
        for col in 0..<cols {
            let value = PixelDuck.grid[row][col]
            if value == 0 { continue }

            PixelDuck.color(for: value).setFill()
            let rect = NSRect(
                x: origin.x + CGFloat(col) * pixel,
                y: origin.y + CGFloat(rows - 1 - row) * pixel,
                width: pixel,
                height: pixel
            )
            rect.fill()
        }
    }
}

func savePNG(size: CGSize, to path: String, draw: () -> Void) throws {
    let image = NSImage(size: size)
    image.lockFocus()
    draw()
    image.unlockFocus()

    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "asset", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode PNG"])
    }

    let url = URL(fileURLWithPath: path)
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try png.write(to: url)
}

func drawGradientBackground(rect: NSRect) {
    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.35, green: 0.65, blue: 0.90, alpha: 1),
        NSColor(calibratedRed: 0.75, green: 0.90, blue: 0.95, alpha: 1),
    ])!
    gradient.draw(in: rect, angle: -90)
}

func drawCloud(center: CGPoint, size: CGFloat, alpha: CGFloat = 0.8) {
    NSColor.white.withAlphaComponent(alpha).setFill()
    let r1 = NSRect(x: center.x - size * 0.8, y: center.y - size * 0.2, width: size, height: size * 0.55)
    let r2 = NSRect(x: center.x - size * 0.2, y: center.y, width: size * 0.85, height: size * 0.6)
    let r3 = NSRect(x: center.x + size * 0.35, y: center.y - size * 0.15, width: size * 0.75, height: size * 0.5)
    NSBezierPath(ovalIn: r1).fill()
    NSBezierPath(ovalIn: r2).fill()
    NSBezierPath(ovalIn: r3).fill()
}

func drawGround(in rect: NSRect, height: CGFloat) {
    let grass = NSRect(x: rect.minX, y: rect.minY, width: rect.width, height: height * 0.12)
    let dirt = NSRect(x: rect.minX, y: rect.minY, width: rect.width, height: height)

    NSColor(calibratedRed: 0.78, green: 0.70, blue: 0.50, alpha: 1).setFill()
    dirt.fill()

    NSColor(calibratedRed: 0.40, green: 0.72, blue: 0.22, alpha: 1).setFill()
    grass.fill()

    NSColor(calibratedRed: 0.28, green: 0.52, blue: 0.16, alpha: 1).setFill()
    NSRect(x: rect.minX, y: rect.minY + grass.height - 5, width: rect.width, height: 5).fill()
}

let repo = FileManager.default.currentDirectoryPath
let appIconPath = "\(repo)/FloppyDuck/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"
let launchBgPath = "\(repo)/FloppyDuck/Assets.xcassets/LaunchBackground.imageset/launch-background.png"
let launchDuckPath = "\(repo)/FloppyDuck/Assets.xcassets/LaunchDuck.imageset/launch-duck.png"

try savePNG(size: CGSize(width: 1024, height: 1024), to: appIconPath) {
    let rect = NSRect(x: 0, y: 0, width: 1024, height: 1024)

    let rounded = NSBezierPath(roundedRect: rect, xRadius: 220, yRadius: 220)
    rounded.addClip()

    drawGradientBackground(rect: rect)
    drawCloud(center: CGPoint(x: 230, y: 760), size: 180)
    drawCloud(center: CGPoint(x: 760, y: 690), size: 160, alpha: 0.72)

    drawGround(in: NSRect(x: 0, y: 0, width: 1024, height: 210), height: 210)

    let pixel: CGFloat = 34
    let duckWidth = CGFloat(PixelDuck.grid[0].count) * pixel
    let origin = CGPoint(x: (1024 - duckWidth) / 2 - 20, y: 300)

    drawDuck(origin: origin, pixel: pixel)

    // Simple drop shadow behind duck.
    NSColor.black.withAlphaComponent(0.12).setFill()
    NSBezierPath(ovalIn: NSRect(x: origin.x + 70, y: origin.y - 26, width: duckWidth - 100, height: 28)).fill()
}

try savePNG(size: CGSize(width: 1290, height: 2796), to: launchBgPath) {
    let rect = NSRect(x: 0, y: 0, width: 1290, height: 2796)
    drawGradientBackground(rect: rect)
    drawCloud(center: CGPoint(x: 240, y: 2320), size: 280)
    drawCloud(center: CGPoint(x: 960, y: 2200), size: 240, alpha: 0.68)
    drawCloud(center: CGPoint(x: 640, y: 2460), size: 220, alpha: 0.55)
    drawGround(in: NSRect(x: 0, y: 0, width: 1290, height: 360), height: 360)
}

try savePNG(size: CGSize(width: 512, height: 352), to: launchDuckPath) {
    NSColor.clear.setFill()
    NSRect(x: 0, y: 0, width: 512, height: 352).fill()

    let pixel: CGFloat = 20
    let width = CGFloat(PixelDuck.grid[0].count) * pixel
    let origin = CGPoint(x: (512 - width) / 2, y: 72)
    drawDuck(origin: origin, pixel: pixel)
}

print("Generated:\n- \(appIconPath)\n- \(launchBgPath)\n- \(launchDuckPath)")
