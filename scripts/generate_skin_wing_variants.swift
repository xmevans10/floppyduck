#!/usr/bin/env swift

import AppKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct RGBAImage {
    var width: Int
    var height: Int
    var pixels: [UInt8]

    init(width: Int, height: Int, pixels: [UInt8]? = nil) {
        self.width = width
        self.height = height
        self.pixels = pixels ?? [UInt8](repeating: 0, count: width * height * 4)
    }

    func index(x: Int, y: Int) -> Int {
        (y * width + x) * 4
    }

    func alphaAt(x: Int, y: Int) -> UInt8 {
        pixels[index(x: x, y: y) + 3]
    }
}

struct Bounds {
    var minX: Int
    var minY: Int
    var maxX: Int
    var maxY: Int

    var width: Int { maxX - minX + 1 }
    var height: Int { maxY - minY + 1 }
}

struct SkinSource {
    let fileURL: URL
    let character: String
}

let fileManager = FileManager.default
let repoURL = URL(fileURLWithPath: fileManager.currentDirectoryPath)
let reviewRoot = repoURL.appendingPathComponent("artifacts/skin_wing_variants")
let assetRoot = repoURL.appendingPathComponent("FloppyDuck/Assets.xcassets/DuckSkins")
let frameOrder = ["idle", "wing_up", "wing_down"]
let aliases = [
    "dino": "dinosaur",
    "phraoah": "pharaoh",
]
let onlyCharacter: String? = {
    guard let index = CommandLine.arguments.firstIndex(of: "--only"),
          CommandLine.arguments.indices.contains(index + 1) else {
        return nil
    }
    return aliases[CommandLine.arguments[index + 1]] ?? CommandLine.arguments[index + 1]
}()

func normalizedCharacterName(from fileName: String) -> String {
    let base = fileName.replacingOccurrences(of: " final.png", with: "")
    return aliases[base] ?? base
}

func makeContentsJSON(filename: String? = nil) -> Data {
    let images: [[String: String]] = [
        ["filename": filename ?? "", "idiom": "universal", "scale": "1x"],
        ["idiom": "universal", "scale": "2x"],
        ["idiom": "universal", "scale": "3x"],
    ]
    let filteredImages = images.map { image in
        image.filter { !$0.value.isEmpty }
    }
    let object: [String: Any] = [
        "images": filteredImages,
        "info": ["author": "xcode", "version": 1],
        "properties": ["template-rendering-intent": "original"],
    ]
    return try! JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
}

func ensureDirectory(_ url: URL) throws {
    try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
}

func loadImage(_ url: URL) throws -> RGBAImage {
    guard
        let source = CGImageSourceCreateWithURL(url as CFURL, nil),
        let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else {
        throw NSError(domain: "SkinGenerator", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to load \(url.path)"])
    }

    var image = RGBAImage(width: cgImage.width, height: cgImage.height)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
    guard let context = CGContext(
        data: &image.pixels,
        width: image.width,
        height: image.height,
        bitsPerComponent: 8,
        bytesPerRow: image.width * 4,
        space: colorSpace,
        bitmapInfo: bitmapInfo
    ) else {
        throw NSError(domain: "SkinGenerator", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unable to create bitmap context"])
    }

    context.interpolationQuality = .none
    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    return image
}

func saveImage(_ image: RGBAImage, to url: URL) throws {
    var mutable = image.pixels
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard
        let context = CGContext(
            data: &mutable,
            width: image.width,
            height: image.height,
            bitsPerComponent: 8,
            bytesPerRow: image.width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ),
        let cgImage = context.makeImage(),
        let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
    else {
        throw NSError(domain: "SkinGenerator", code: 3, userInfo: [NSLocalizedDescriptionKey: "Unable to save \(url.path)"])
    }

    CGImageDestinationAddImage(destination, cgImage, nil)
    CGImageDestinationFinalize(destination)
}

func isBackgroundWhite(_ image: RGBAImage, x: Int, y: Int) -> Bool {
    let i = image.index(x: x, y: y)
    return image.pixels[i] >= 245 && image.pixels[i + 1] >= 245 && image.pixels[i + 2] >= 245
}

func makeBackgroundMask(_ image: RGBAImage) -> [Bool] {
    var mask = [Bool](repeating: false, count: image.width * image.height)
    var queue: [(Int, Int)] = []

    func enqueue(_ x: Int, _ y: Int) {
        guard x >= 0, y >= 0, x < image.width, y < image.height else { return }
        let idx = y * image.width + x
        guard !mask[idx], isBackgroundWhite(image, x: x, y: y) else { return }
        mask[idx] = true
        queue.append((x, y))
    }

    for x in 0..<image.width {
        enqueue(x, 0)
        enqueue(x, image.height - 1)
    }
    for y in 0..<image.height {
        enqueue(0, y)
        enqueue(image.width - 1, y)
    }

    var cursor = 0
    while cursor < queue.count {
        let (x, y) = queue[cursor]
        cursor += 1
        enqueue(x + 1, y)
        enqueue(x - 1, y)
        enqueue(x, y + 1)
        enqueue(x, y - 1)
    }

    return mask
}

func transparentCutout(from image: RGBAImage, backgroundMask: [Bool]) -> (RGBAImage, Bounds) {
    var bounds = Bounds(minX: image.width, minY: image.height, maxX: -1, maxY: -1)
    for y in 0..<image.height {
        for x in 0..<image.width {
            let maskIndex = y * image.width + x
            guard !backgroundMask[maskIndex] else { continue }
            bounds.minX = min(bounds.minX, x)
            bounds.minY = min(bounds.minY, y)
            bounds.maxX = max(bounds.maxX, x)
            bounds.maxY = max(bounds.maxY, y)
        }
    }

    var output = RGBAImage(width: bounds.width, height: bounds.height)
    for y in 0..<bounds.height {
        for x in 0..<bounds.width {
            let sourceX = bounds.minX + x
            let sourceY = bounds.minY + y
            let sourceMaskIndex = sourceY * image.width + sourceX
            guard !backgroundMask[sourceMaskIndex] else { continue }
            let src = image.index(x: sourceX, y: sourceY)
            let dst = output.index(x: x, y: y)
            output.pixels[dst] = image.pixels[src]
            output.pixels[dst + 1] = image.pixels[src + 1]
            output.pixels[dst + 2] = image.pixels[src + 2]
            output.pixels[dst + 3] = 255
        }
    }
    return (output, bounds)
}

func padded(_ image: RGBAImage, margin: Int) -> RGBAImage {
    var output = RGBAImage(width: image.width + margin * 2, height: image.height + margin * 2)
    for y in 0..<image.height {
        for x in 0..<image.width where image.alphaAt(x: x, y: y) > 0 {
            let src = image.index(x: x, y: y)
            let dst = output.index(x: x + margin, y: y + margin)
            output.pixels[dst] = image.pixels[src]
            output.pixels[dst + 1] = image.pixels[src + 1]
            output.pixels[dst + 2] = image.pixels[src + 2]
            output.pixels[dst + 3] = image.pixels[src + 3]
        }
    }
    return output
}

func contentBounds(_ image: RGBAImage) -> Bounds {
    var bounds = Bounds(minX: image.width, minY: image.height, maxX: -1, maxY: -1)
    for y in 0..<image.height {
        for x in 0..<image.width where image.alphaAt(x: x, y: y) > 0 {
            bounds.minX = min(bounds.minX, x)
            bounds.minY = min(bounds.minY, y)
            bounds.maxX = max(bounds.maxX, x)
            bounds.maxY = max(bounds.maxY, y)
        }
    }
    return bounds
}

func averageColor(
    _ image: RGBAImage,
    xRange: ClosedRange<Int>,
    yRange: ClosedRange<Int>,
    filter: ((UInt8, UInt8, UInt8) -> Bool)? = nil
) -> (UInt8, UInt8, UInt8) {
    var totalR = 0
    var totalG = 0
    var totalB = 0
    var count = 0

    let minX = max(0, xRange.lowerBound)
    let maxX = min(image.width - 1, xRange.upperBound)
    let minY = max(0, yRange.lowerBound)
    let maxY = min(image.height - 1, yRange.upperBound)
    guard minX <= maxX, minY <= maxY else { return (150, 150, 150) }

    for y in minY...maxY {
        for x in minX...maxX where image.alphaAt(x: x, y: y) > 0 {
            let i = image.index(x: x, y: y)
            let r = image.pixels[i]
            let g = image.pixels[i + 1]
            let b = image.pixels[i + 2]
            if let filter, !filter(r, g, b) { continue }
            totalR += Int(r)
            totalG += Int(g)
            totalB += Int(b)
            count += 1
        }
    }

    guard count > 0 else { return (150, 150, 150) }
    return (UInt8(totalR / count), UInt8(totalG / count), UInt8(totalB / count))
}

func darken(_ color: (UInt8, UInt8, UInt8), amount: Double = 0.62) -> (UInt8, UInt8, UInt8) {
    (
        UInt8(Double(color.0) * amount),
        UInt8(Double(color.1) * amount),
        UInt8(Double(color.2) * amount)
    )
}

func dominantColor(
    _ image: RGBAImage,
    xRange: ClosedRange<Int>,
    yRange: ClosedRange<Int>,
    fallback: (UInt8, UInt8, UInt8),
    filter: ((UInt8, UInt8, UInt8) -> Bool)? = nil
) -> (UInt8, UInt8, UInt8) {
    struct Bucket {
        var totalR = 0
        var totalG = 0
        var totalB = 0
        var count = 0
    }

    let minX = max(0, xRange.lowerBound)
    let maxX = min(image.width - 1, xRange.upperBound)
    let minY = max(0, yRange.lowerBound)
    let maxY = min(image.height - 1, yRange.upperBound)
    guard minX <= maxX, minY <= maxY else { return fallback }

    var buckets: [Int: Bucket] = [:]
    for y in minY...maxY {
        for x in minX...maxX where image.alphaAt(x: x, y: y) > 0 {
            let i = image.index(x: x, y: y)
            let r = image.pixels[i]
            let g = image.pixels[i + 1]
            let b = image.pixels[i + 2]
            if let filter, !filter(r, g, b) { continue }

            let key = (Int(r) / 32) << 16 | (Int(g) / 32) << 8 | (Int(b) / 32)
            var bucket = buckets[key] ?? Bucket()
            bucket.totalR += Int(r)
            bucket.totalG += Int(g)
            bucket.totalB += Int(b)
            bucket.count += 1
            buckets[key] = bucket
        }
    }

    guard let best = buckets.values.max(by: { $0.count < $1.count }), best.count > 0 else {
        return fallback
    }
    return (
        UInt8(best.totalR / best.count),
        UInt8(best.totalG / best.count),
        UInt8(best.totalB / best.count)
    )
}

func drawBlock(_ image: inout RGBAImage, x: Int, y: Int, block: Int, color: (UInt8, UInt8, UInt8)) {
    fill(&image, x: x, y: y, width: block, height: block, color: (color.0, color.1, color.2, 255))
}

struct Component {
    var bounds: Bounds
    var area: Int

    var centerX: Int { (bounds.minX + bounds.maxX) / 2 }
    var centerY: Int { (bounds.minY + bounds.maxY) / 2 }
}

struct EyePlacement {
    let leftX: Int
    let bottomY: Int
    let block: Int
}

struct PixelSample {
    let x: Int
    let y: Int
}

func clamped(_ value: Int, min minValue: Int, max maxValue: Int) -> Int {
    min(max(value, minValue), maxValue)
}

func luma(_ r: UInt8, _ g: UInt8, _ b: UInt8) -> Int {
    (Int(r) * 30 + Int(g) * 59 + Int(b) * 11) / 100
}

func isDarkEyePixel(_ image: RGBAImage, x: Int, y: Int) -> Bool {
    guard image.alphaAt(x: x, y: y) > 0 else { return false }
    let i = image.index(x: x, y: y)
    return image.pixels[i] < 70 && image.pixels[i + 1] < 70 && image.pixels[i + 2] < 70
}

func isEyeLightPixel(_ image: RGBAImage, x: Int, y: Int) -> Bool {
    guard image.alphaAt(x: x, y: y) > 0 else { return false }
    let i = image.index(x: x, y: y)
    let r = image.pixels[i]
    let g = image.pixels[i + 1]
    let b = image.pixels[i + 2]
    if r > 225 && g > 225 && b > 225 { return true }
    if r < 150 && g > 150 && b > 150 { return true }
    return luma(r, g, b) > 180 && !(r > 180 && g > 120 && b < 90)
}

func isStrictEyeWhitePixel(_ image: RGBAImage, x: Int, y: Int) -> Bool {
    guard image.alphaAt(x: x, y: y) > 0 else { return false }
    let i = image.index(x: x, y: y)
    return image.pixels[i] > 235 && image.pixels[i + 1] > 235 && image.pixels[i + 2] > 235
}

func connectedComponents(
    in image: RGBAImage,
    searchBounds: Bounds,
    matches: (RGBAImage, Int, Int) -> Bool
) -> [Component] {
    var visited = [Bool](repeating: false, count: image.width * image.height)
    var components: [Component] = []
    let minX = clamped(searchBounds.minX, min: 0, max: image.width - 1)
    let maxX = clamped(searchBounds.maxX, min: 0, max: image.width - 1)
    let minY = clamped(searchBounds.minY, min: 0, max: image.height - 1)
    let maxY = clamped(searchBounds.maxY, min: 0, max: image.height - 1)
    guard minX <= maxX, minY <= maxY else { return [] }

    for y in minY...maxY {
        for x in minX...maxX {
            let startIndex = y * image.width + x
            guard !visited[startIndex], matches(image, x, y) else { continue }

            var queue = [(x, y)]
            var cursor = 0
            visited[startIndex] = true
            var component = Component(bounds: Bounds(minX: x, minY: y, maxX: x, maxY: y), area: 0)

            while cursor < queue.count {
                let (cx, cy) = queue[cursor]
                cursor += 1
                component.area += 1
                component.bounds.minX = min(component.bounds.minX, cx)
                component.bounds.minY = min(component.bounds.minY, cy)
                component.bounds.maxX = max(component.bounds.maxX, cx)
                component.bounds.maxY = max(component.bounds.maxY, cy)

                for (nx, ny) in [(cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)] {
                    guard nx >= minX, ny >= minY, nx <= maxX, ny <= maxY else { continue }
                    let nextIndex = ny * image.width + nx
                    guard !visited[nextIndex], matches(image, nx, ny) else { continue }
                    visited[nextIndex] = true
                    queue.append((nx, ny))
                }
            }

            components.append(component)
        }
    }

    return components
}

func lightBounds(around component: Component, in image: RGBAImage, padding: Int) -> Bounds? {
    let minX = clamped(component.bounds.minX - padding, min: 0, max: image.width - 1)
    let maxX = clamped(component.bounds.maxX + padding, min: 0, max: image.width - 1)
    let minY = clamped(component.bounds.minY - padding, min: 0, max: image.height - 1)
    let maxY = clamped(component.bounds.maxY + padding, min: 0, max: image.height - 1)
    var bounds = Bounds(minX: image.width, minY: image.height, maxX: -1, maxY: -1)

    for y in minY...maxY {
        for x in minX...maxX where isEyeLightPixel(image, x: x, y: y) {
            bounds.minX = min(bounds.minX, x)
            bounds.minY = min(bounds.minY, y)
            bounds.maxX = max(bounds.maxX, x)
            bounds.maxY = max(bounds.maxY, y)
        }
    }

    return bounds.maxX >= bounds.minX ? bounds : nil
}

func lightPixelCount(around component: Component, in image: RGBAImage, padding: Int) -> Int {
    let minX = clamped(component.bounds.minX - padding, min: 0, max: image.width - 1)
    let maxX = clamped(component.bounds.maxX + padding, min: 0, max: image.width - 1)
    let minY = clamped(component.bounds.minY - padding, min: 0, max: image.height - 1)
    let maxY = clamped(component.bounds.maxY + padding, min: 0, max: image.height - 1)
    var count = 0

    for y in minY...maxY {
        for x in minX...maxX where isEyeLightPixel(image, x: x, y: y) {
            count += 1
        }
    }

    return count
}

func darkPixelCount(around component: Component, in image: RGBAImage, padding: Int) -> Int {
    let minX = clamped(component.bounds.minX - padding, min: 0, max: image.width - 1)
    let maxX = clamped(component.bounds.maxX + padding, min: 0, max: image.width - 1)
    let minY = clamped(component.bounds.minY - padding, min: 0, max: image.height - 1)
    let maxY = clamped(component.bounds.maxY + padding, min: 0, max: image.height - 1)
    var count = 0

    for y in minY...maxY {
        for x in minX...maxX where isDarkEyePixel(image, x: x, y: y) {
            count += 1
        }
    }

    return count
}

func detectEyePlacement(in image: RGBAImage, bounds: Bounds) -> EyePlacement {
    let fallbackBlock = max(6, Int((Double(bounds.width) / 18.0).rounded()))
    let searchBounds = Bounds(
        minX: bounds.minX + bounds.width / 3,
        minY: bounds.minY + bounds.height / 8,
        maxX: bounds.minX + bounds.width * 4 / 5,
        maxY: bounds.minY + bounds.height * 2 / 3
    )
    let expectedX = bounds.minX + bounds.width * 11 / 20
    let expectedY = bounds.minY + bounds.height * 2 / 5
    let whiteComponents = connectedComponents(in: image, searchBounds: searchBounds, matches: isStrictEyeWhitePixel)
    let compactWhiteEye = whiteComponents
        .filter { component in
            component.area >= 12
                && component.centerX <= bounds.minX + bounds.width * 13 / 20
                && component.bounds.width <= max(fallbackBlock * 5, bounds.width / 4)
                && component.bounds.height <= max(fallbackBlock * 4, bounds.height / 5)
                && darkPixelCount(around: component, in: image, padding: fallbackBlock) > 4
        }
        .max { lhs, rhs in
            let lhsScore = lhs.area * 2
                + darkPixelCount(around: lhs, in: image, padding: fallbackBlock) * 4
                - abs(lhs.centerX - expectedX)
                - abs(lhs.centerY - expectedY)
            let rhsScore = rhs.area * 2
                + darkPixelCount(around: rhs, in: image, padding: fallbackBlock) * 4
                - abs(rhs.centerX - expectedX)
                - abs(rhs.centerY - expectedY)
            return lhsScore < rhsScore
        }

    if let eye = compactWhiteEye {
        let block = clamped(max(6, max(eye.bounds.width, eye.bounds.height) / 2), min: 6, max: max(8, fallbackBlock + fallbackBlock / 3))
        return EyePlacement(leftX: eye.bounds.minX, bottomY: eye.bounds.maxY, block: block)
    }

    let darkComponents = connectedComponents(in: image, searchBounds: searchBounds, matches: isDarkEyePixel)
    var bestDark: Component?
    var bestScore = Int.min

    for component in darkComponents {
        let width = component.bounds.width
        let height = component.bounds.height
        guard component.area >= 8 else { continue }
        guard component.centerX <= bounds.minX + bounds.width * 13 / 20 else { continue }
        guard width <= max(fallbackBlock * 2, bounds.width / 7) else { continue }
        guard height <= max(fallbackBlock * 2, bounds.height / 7) else { continue }

        let lightScore = lightPixelCount(around: component, in: image, padding: max(fallbackBlock * 2, max(width, height) * 2))
        guard lightScore > max(12, component.area / 3) else { continue }

        let distancePenalty = abs(component.centerX - expectedX) + abs(component.centerY - expectedY)
        let score = lightScore - component.area - distancePenalty
        if score > bestScore {
            bestScore = score
            bestDark = component
        }
    }

    if let eye = bestDark {
        let padding = max(fallbackBlock * 3, max(eye.bounds.width, eye.bounds.height) * 3)
        let detectedLightBounds = lightBounds(around: eye, in: image, padding: padding)
        let usableLightBounds = detectedLightBounds.flatMap { light -> Bounds? in
            let maxLightWidth = max(fallbackBlock * 5, eye.bounds.width * 5)
            let maxLightHeight = max(fallbackBlock * 5, eye.bounds.height * 5)
            return light.width <= maxLightWidth && light.height <= maxLightHeight ? light : nil
        }
        let eyeBounds = usableLightBounds ?? eye.bounds
        let blockFromEye = usableLightBounds.map { max(6, max($0.width, $0.height) / 2) } ?? max(6, max(eye.bounds.width, eye.bounds.height))
        let block = clamped(blockFromEye, min: 6, max: max(8, fallbackBlock + fallbackBlock / 3))
        return EyePlacement(leftX: eyeBounds.minX, bottomY: eyeBounds.maxY, block: block)
    }

    let lightComponents = connectedComponents(in: image, searchBounds: searchBounds, matches: isEyeLightPixel)
    let compactLight = lightComponents
        .filter { component in
            component.area >= 12
                && component.bounds.width <= max(fallbackBlock * 5, bounds.width / 4)
                && component.bounds.height <= max(fallbackBlock * 4, bounds.height / 5)
        }
        .max { lhs, rhs in
            let lhsScore = lhs.area - abs(lhs.centerX - (bounds.minX + bounds.width * 11 / 20))
            let rhsScore = rhs.area - abs(rhs.centerX - (bounds.minX + bounds.width * 11 / 20))
            return lhsScore < rhsScore
        }

    if let eye = compactLight {
        let block = clamped(max(6, max(eye.bounds.width, eye.bounds.height) / 2), min: 6, max: max(8, fallbackBlock + fallbackBlock / 3))
        return EyePlacement(leftX: eye.bounds.minX, bottomY: eye.bounds.maxY, block: block)
    }

    return EyePlacement(
        leftX: bounds.minX + bounds.width / 2,
        bottomY: bounds.minY + bounds.height * 9 / 20,
        block: fallbackBlock
    )
}

func detectedSpeculumPixels(in image: RGBAImage, bounds: Bounds) -> [PixelSample] {
    let minX = bounds.minX + bounds.width / 5
    let maxX = bounds.minX + bounds.width * 3 / 5
    let minY = bounds.minY + bounds.height / 2
    let maxY = bounds.minY + bounds.height * 5 / 6
    var samples: [PixelSample] = []

    for y in minY...maxY {
        for x in minX...maxX where image.alphaAt(x: x, y: y) > 0 {
            let i = image.index(x: x, y: y)
            let r = image.pixels[i]
            let g = image.pixels[i + 1]
            let b = image.pixels[i + 2]
            guard Int(b) > Int(r) + 18 && Int(b) > Int(g) + 5 else { continue }
            samples.append(PixelSample(x: x, y: y))
        }
    }

    return samples
}

func replacementColor(nearX x: Int, y: Int, in image: RGBAImage, fallback: (UInt8, UInt8, UInt8)) -> (UInt8, UInt8, UInt8) {
    let radius = 8
    let preferredOffsets = [
        (0, 1), (-1, 0), (1, 0), (0, -1),
        (-1, 1), (1, 1), (-1, -1), (1, -1),
    ]

    for distance in 1...radius {
        for (dx, dy) in preferredOffsets {
            let sampleX = x + dx * distance
            let sampleY = y + dy * distance
            guard sampleX >= 0, sampleY >= 0, sampleX < image.width, sampleY < image.height else { continue }
            guard image.alphaAt(x: sampleX, y: sampleY) > 0 else { continue }
            let i = image.index(x: sampleX, y: sampleY)
            let r = image.pixels[i]
            let g = image.pixels[i + 1]
            let b = image.pixels[i + 2]
            guard !(Int(b) > Int(r) + 18 && Int(b) > Int(g) + 5) else { continue }
            return (r, g, b)
        }
    }

    return fallback
}

func erasePixels(_ image: inout RGBAImage, pixels: [PixelSample], fallbackFill: (UInt8, UInt8, UInt8)) {
    for pixel in pixels {
        let fillColor = replacementColor(nearX: pixel.x, y: pixel.y, in: image, fallback: fallbackFill)
        let i = image.index(x: pixel.x, y: pixel.y)
        image.pixels[i] = fillColor.0
        image.pixels[i + 1] = fillColor.1
        image.pixels[i + 2] = fillColor.2
        image.pixels[i + 3] = 255
    }
}

func normalizedWingFill(_ color: (UInt8, UInt8, UInt8)) -> (UInt8, UInt8, UInt8) {
    let brightness = luma(color.0, color.1, color.2)
    if brightness < 100 {
        return (
            UInt8(min(255, Int(color.0) + 90)),
            UInt8(min(255, Int(color.1) + 90)),
            UInt8(min(255, Int(color.2) + 90))
        )
    }
    if brightness > 228 {
        return darken(color, amount: 0.82)
    }
    return color
}

func drawStandardWing(
    _ image: inout RGBAImage,
    rightEdgeX: Int,
    startY: Int,
    block: Int,
    fillColor: (UInt8, UInt8, UInt8),
    direction: Int
) {
    let black: (UInt8, UInt8, UInt8) = (0, 0, 0)
    let wingFill = normalizedWingFill(fillColor)
    let rightBlockX = rightEdgeX - block
    let downCells: [(dx: Int, dy: Int, fill: Bool)] = [
        (-4, 0, false), (-3, 0, true),  (-2, 0, true),  (-1, 0, true),  (0, 0, false),
        (-4, 1, false), (-3, 1, true),  (-2, 1, true),  (-1, 1, false),
        (-3, 2, false), (-2, 2, false),
    ]
    for cell in downCells {
        let y = direction > 0
            ? startY + cell.dy * block
            : startY - (cell.dy + 1) * block
        drawBlock(
            &image,
            x: rightBlockX + cell.dx * block,
            y: y,
            block: block,
            color: cell.fill ? wingFill : black
        )
    }
}

func makeWingVariant(idle: RGBAImage, character: String, direction: Int) -> RGBAImage {
    let bounds = contentBounds(idle)
    var output = idle
    let eye = detectEyePlacement(in: idle, bounds: bounds)

    // Anchor sampling and wing placement to the body band (eye-bottom -> content-bottom)
    // rather than the area above the eye. The "above the eye" region is headgear for
    // tall hats / helmets (wizard, robot), which previously polluted body color and
    // sizing.
    let bodyTopY = eye.bottomY
    let bodyHeight = max(eye.block * 4, bounds.maxY - bodyTopY + 1)
    let bodyMinX = max(bounds.minX, bounds.minX + bounds.width / 4)
    let bodyMaxX = max(bodyMinX + 1, eye.leftX - eye.block)
    let bodySampleMaxY = min(bounds.maxY, bodyTopY + (bodyHeight * 4) / 5)

    let roughBody = averageColor(
        idle,
        xRange: bodyMinX...bodyMaxX,
        yRange: bodyTopY...bodySampleMaxY
    ) { r, g, b in
        let brightness = luma(r, g, b)
        return brightness > 35
            && brightness < 250
            && !(r < 45 && g < 45 && b < 45)
            && !(r > 170 && g > 95 && b < 75)
    }
    let body = dominantColor(
        idle,
        xRange: bodyMinX...bodyMaxX,
        yRange: bodyTopY...bodySampleMaxY,
        fallback: roughBody
    ) { r, g, b in
        let brightness = luma(r, g, b)
        return brightness > 35
            && brightness < 250
            && !(r < 45 && g < 45 && b < 45)
            && !(r > 170 && g > 95 && b < 75)
    }
    let lowerBody = averageColor(
        idle,
        xRange: (bounds.minX + bounds.width / 4)...(bounds.minX + bounds.width * 3 / 5),
        yRange: (bounds.minY + bounds.height * 2 / 3)...(bounds.minY + bounds.height * 5 / 6)
    ) { r, g, b in
        let brightness = luma(r, g, b)
        return brightness > 45 && !(r > 170 && g > 95 && b < 65) && !(r > 235 && g > 235 && b > 235)
    }

    erasePixels(&output, pixels: detectedSpeculumPixels(in: idle, bounds: bounds), fallbackFill: lowerBody)

    // Wing block size is derived from body height so the wing keeps pirate-like
    // proportions even when eye detection finds an oversized visor (robot) or an
    // unusual shape (wizard). startY is anchored to the body band so the wing
    // doesn't slide off small bodies.
    let wingBlock = clamped(bodyHeight / 7, min: 6, max: 8)
    let startY = bodyTopY + (bodyHeight * 35) / 100

    drawStandardWing(
        &output,
        rightEdgeX: eye.leftX,
        startY: startY,
        block: wingBlock,
        fillColor: body,
        direction: direction
    )

    return output
}

func draw(_ source: RGBAImage, into destination: inout RGBAImage, x originX: Int, y originY: Int, maxWidth: Int, maxHeight: Int) {
    let scale = min(Double(maxWidth) / Double(source.width), Double(maxHeight) / Double(source.height))
    let drawW = max(1, Int(Double(source.width) * scale))
    let drawH = max(1, Int(Double(source.height) * scale))
    let xOffset = originX + (maxWidth - drawW) / 2
    let yOffset = originY + (maxHeight - drawH) / 2

    for y in 0..<drawH {
        for x in 0..<drawW {
            let sx = min(source.width - 1, Int(Double(x) / scale))
            let sy = min(source.height - 1, Int(Double(y) / scale))
            let src = source.index(x: sx, y: sy)
            let alpha = source.pixels[src + 3]
            guard alpha > 0 else { continue }
            let dx = xOffset + x
            let dy = yOffset + y
            guard dx >= 0, dy >= 0, dx < destination.width, dy < destination.height else { continue }
            let dst = destination.index(x: dx, y: dy)
            destination.pixels[dst] = source.pixels[src]
            destination.pixels[dst + 1] = source.pixels[src + 1]
            destination.pixels[dst + 2] = source.pixels[src + 2]
            destination.pixels[dst + 3] = 255
        }
    }
}

func fill(_ image: inout RGBAImage, x: Int, y: Int, width: Int, height: Int, color: (UInt8, UInt8, UInt8, UInt8)) {
    let minX = max(0, x)
    let minY = max(0, y)
    let maxX = min(image.width, x + width)
    let maxY = min(image.height, y + height)
    guard minX < maxX, minY < maxY else { return }

    for yy in minY..<maxY {
        for xx in minX..<maxX {
            let i = image.index(x: xx, y: yy)
            image.pixels[i] = color.0
            image.pixels[i + 1] = color.1
            image.pixels[i + 2] = color.2
            image.pixels[i + 3] = color.3
        }
    }
}

func makeContactSheet(_ generated: [(String, [String: RGBAImage])]) -> RGBAImage {
    let cellW = 180
    let cellH = 170
    let labelH = 24
    let columns = 3
    let rows = generated.count
    var sheet = RGBAImage(width: cellW * columns, height: rows * cellH)
    fill(&sheet, x: 0, y: 0, width: sheet.width, height: sheet.height, color: (255, 255, 255, 255))

    for (row, (_, frames)) in generated.enumerated() {
        for (col, frame) in frameOrder.enumerated() {
            let x = col * cellW
            let y = row * cellH
            fill(&sheet, x: x + 6, y: y + 6, width: cellW - 12, height: cellH - labelH - 12, color: (238, 238, 238, 255))
            if let image = frames[frame] {
                draw(image, into: &sheet, x: x + 14, y: y + 14, maxWidth: cellW - 28, maxHeight: cellH - labelH - 28)
            }
        }
    }
    return sheet
}

let rootFiles = try fileManager.contentsOfDirectory(at: repoURL, includingPropertiesForKeys: nil)
var sources = rootFiles
    .filter { $0.lastPathComponent.hasSuffix(" final.png") }
    .map { SkinSource(fileURL: $0, character: normalizedCharacterName(from: $0.lastPathComponent)) }
    .sorted { $0.character < $1.character }
if let onlyCharacter {
    sources = sources.filter { $0.character == onlyCharacter }
}

guard !sources.isEmpty else {
    print("No root '* final.png' files found.")
    exit(0)
}

try ensureDirectory(reviewRoot)
try ensureDirectory(assetRoot)
try """
{
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
""".data(using: .utf8)!.write(to: assetRoot.appendingPathComponent("Contents.json"))

var generated: [(String, [String: RGBAImage])] = []

for source in sources {
    let input = try loadImage(source.fileURL)
    let backgroundMask = makeBackgroundMask(input)
    let (cutout, sourceBounds) = transparentCutout(from: input, backgroundMask: backgroundMask)
    let margin = max(24, Int(Double(max(sourceBounds.width, sourceBounds.height)) * 0.16))
    let idle = padded(cutout, margin: margin)
    let wingUp = makeWingVariant(idle: idle, character: source.character, direction: -1)
    let wingDown = makeWingVariant(idle: idle, character: source.character, direction: 1)
    let frames = ["idle": idle, "wing_up": wingUp, "wing_down": wingDown]

    let reviewDirectory = reviewRoot.appendingPathComponent(source.character)
    try ensureDirectory(reviewDirectory)

    for frame in frameOrder {
        guard let image = frames[frame] else { continue }
        try saveImage(image, to: reviewDirectory.appendingPathComponent("\(frame).png"))

        let assetName = "duckskin_\(source.character)_\(frame)"
        let imageSet = assetRoot.appendingPathComponent("\(assetName).imageset")
        try ensureDirectory(imageSet)
        try saveImage(image, to: imageSet.appendingPathComponent("\(frame).png"))
        try makeContentsJSON(filename: "\(frame).png").write(to: imageSet.appendingPathComponent("Contents.json"))
    }

    generated.append((source.character, frames))
    print("\(source.character): source bbox \(sourceBounds.width)x\(sourceBounds.height), frame \(idle.width)x\(idle.height)")
}

let sheet = makeContactSheet(generated)
try saveImage(sheet, to: reviewRoot.appendingPathComponent("contact_sheet.png"))
print("Generated \(generated.count) skins in \(reviewRoot.path)")
