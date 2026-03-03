import SpriteKit

/// Generates all game textures programmatically — no external image assets needed.
/// Renders classic Flappy Bird aesthetic with gradients, shading, and detail.
enum TextureFactory {
    
    // MARK: - Duck
    
    static func duckTexture(radius: CGFloat = GK.duckRadius, wingPhase: Int = 0) -> SKTexture {
        let size = CGSize(width: radius * 2.8, height: radius * 2.4)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            let c = ctx.cgContext
            let cx = size.width * 0.45
            let cy = size.height * 0.5
            let r = radius
            
            // Body shadow
            c.setFillColor(UIColor(red: 0.85, green: 0.6, blue: 0.0, alpha: 0.3).cgColor)
            c.fillEllipse(in: CGRect(x: cx - r + 2, y: cy - r + 2, width: r * 2, height: r * 2))
            
            // Body
            let bodyGrad = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [
                    UIColor(red: 1.0, green: 0.85, blue: 0.15, alpha: 1).cgColor,
                    UIColor(red: 0.95, green: 0.72, blue: 0.05, alpha: 1).cgColor,
                    UIColor(red: 0.85, green: 0.55, blue: 0.0, alpha: 1).cgColor
                ] as CFArray,
                locations: [0, 0.5, 1]
            )!
            c.saveGState()
            c.addEllipse(in: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
            c.clip()
            c.drawLinearGradient(bodyGrad,
                start: CGPoint(x: cx, y: cy - r),
                end: CGPoint(x: cx, y: cy + r),
                options: [])
            c.restoreGState()
            
            // Body outline
            c.setStrokeColor(UIColor(red: 0.6, green: 0.4, blue: 0.0, alpha: 0.6).cgColor)
            c.setLineWidth(1.5)
            c.strokeEllipse(in: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
            
            // Belly highlight
            c.setFillColor(UIColor(red: 1, green: 0.95, blue: 0.7, alpha: 0.4).cgColor)
            c.fillEllipse(in: CGRect(x: cx - r * 0.5, y: cy - r * 0.1, width: r * 1.2, height: r * 1.0))
            
            // Eye (white)
            let eyeX = cx + r * 0.35
            let eyeY = cy - r * 0.35
            let eyeR: CGFloat = r * 0.42
            c.setFillColor(UIColor.white.cgColor)
            c.fillEllipse(in: CGRect(x: eyeX - eyeR, y: eyeY - eyeR, width: eyeR * 2, height: eyeR * 2))
            c.setStrokeColor(UIColor(white: 0.3, alpha: 0.5).cgColor)
            c.setLineWidth(1)
            c.strokeEllipse(in: CGRect(x: eyeX - eyeR, y: eyeY - eyeR, width: eyeR * 2, height: eyeR * 2))
            
            // Pupil
            let pupilR = eyeR * 0.5
            c.setFillColor(UIColor(white: 0.1, alpha: 1).cgColor)
            c.fillEllipse(in: CGRect(x: eyeX + pupilR * 0.3 - pupilR,
                                     y: eyeY - pupilR,
                                     width: pupilR * 2, height: pupilR * 2))
            
            // Eye shine
            let shineR = pupilR * 0.35
            c.setFillColor(UIColor.white.cgColor)
            c.fillEllipse(in: CGRect(x: eyeX + pupilR * 0.1 - shineR,
                                     y: eyeY - pupilR * 0.5 - shineR,
                                     width: shineR * 2, height: shineR * 2))
            
            // Beak
            let beakPath = UIBezierPath()
            beakPath.move(to: CGPoint(x: cx + r * 0.7, y: cy + r * 0.05))
            beakPath.addLine(to: CGPoint(x: cx + r * 1.6, y: cy + r * 0.15))
            beakPath.addLine(to: CGPoint(x: cx + r * 0.7, y: cy + r * 0.45))
            beakPath.close()
            UIColor(red: 0.95, green: 0.45, blue: 0.15, alpha: 1).setFill()
            beakPath.fill()
            UIColor(red: 0.7, green: 0.3, blue: 0.1, alpha: 0.5).setStroke()
            beakPath.lineWidth = 1
            beakPath.stroke()
            
            // Wing
            let wingY: CGFloat
            switch wingPhase {
            case 0: wingY = cy + r * 0.1    // mid
            case 1: wingY = cy - r * 0.15   // up
            default: wingY = cy + r * 0.35  // down
            }
            let wingPath = UIBezierPath()
            wingPath.move(to: CGPoint(x: cx - r * 0.3, y: wingY))
            wingPath.addQuadCurve(to: CGPoint(x: cx - r * 1.1, y: wingY + r * 0.1),
                                  controlPoint: CGPoint(x: cx - r * 0.7, y: wingY - r * 0.5))
            wingPath.addQuadCurve(to: CGPoint(x: cx - r * 0.3, y: wingY + r * 0.3),
                                  controlPoint: CGPoint(x: cx - r * 0.7, y: wingY + r * 0.5))
            wingPath.close()
            UIColor(red: 0.95, green: 0.78, blue: 0.15, alpha: 1).setFill()
            wingPath.fill()
            UIColor(red: 0.7, green: 0.5, blue: 0.0, alpha: 0.4).setStroke()
            wingPath.lineWidth = 1
            wingPath.stroke()
        }
        return SKTexture(image: image)
    }
    
    // MARK: - Pipe Body
    
    static func pipeBodyTexture(width: CGFloat = GK.pipeWidth, height: CGFloat) -> SKTexture {
        let size = CGSize(width: width, height: height)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            let c = ctx.cgContext
            
            // Main pipe gradient
            let grad = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [
                    UIColor(red: 0.30, green: 0.62, blue: 0.15, alpha: 1).cgColor,
                    UIColor(red: 0.39, green: 0.76, blue: 0.23, alpha: 1).cgColor,
                    UIColor(red: 0.45, green: 0.82, blue: 0.30, alpha: 1).cgColor,
                    UIColor(red: 0.39, green: 0.76, blue: 0.23, alpha: 1).cgColor,
                    UIColor(red: 0.22, green: 0.56, blue: 0.11, alpha: 1).cgColor,
                ] as CFArray,
                locations: [0, 0.2, 0.4, 0.7, 1]
            )!
            c.drawLinearGradient(grad,
                start: CGPoint(x: 0, y: 0),
                end: CGPoint(x: width, y: 0),
                options: [])
            
            // Left highlight stripe
            c.setFillColor(UIColor(white: 1, alpha: 0.15).cgColor)
            c.fill(CGRect(x: 6, y: 0, width: 4, height: height))
            
            // Right shadow stripe
            c.setFillColor(UIColor(white: 0, alpha: 0.1).cgColor)
            c.fill(CGRect(x: width - 8, y: 0, width: 4, height: height))
            
            // Outline
            c.setStrokeColor(UIColor(red: 0.15, green: 0.35, blue: 0.08, alpha: 0.8).cgColor)
            c.setLineWidth(2)
            c.stroke(CGRect(x: 1, y: 0, width: width - 2, height: height))
        }
        return SKTexture(image: image)
    }
    
    // MARK: - Pipe Cap
    
    static func pipeCapTexture(width: CGFloat = GK.pipeWidth + 10) -> SKTexture {
        let capH: CGFloat = 30
        let size = CGSize(width: width, height: capH)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            let c = ctx.cgContext
            let rect = CGRect(x: 0, y: 0, width: width, height: capH)
            let path = UIBezierPath(roundedRect: rect, cornerRadius: 4)
            
            // Cap gradient
            let grad = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [
                    UIColor(red: 0.31, green: 0.66, blue: 0.17, alpha: 1).cgColor,
                    UIColor(red: 0.42, green: 0.80, blue: 0.28, alpha: 1).cgColor,
                    UIColor(red: 0.35, green: 0.70, blue: 0.22, alpha: 1).cgColor,
                ] as CFArray,
                locations: [0, 0.5, 1]
            )!
            c.saveGState()
            path.addClip()
            c.drawLinearGradient(grad,
                start: CGPoint(x: 0, y: 0),
                end: CGPoint(x: width, y: 0),
                options: [])
            c.restoreGState()
            
            // Outline
            UIColor(red: 0.15, green: 0.35, blue: 0.08, alpha: 0.8).setStroke()
            path.lineWidth = 2.5
            path.stroke()
            
            // Top highlight
            c.setFillColor(UIColor(white: 1, alpha: 0.2).cgColor)
            c.fill(CGRect(x: 4, y: 2, width: width - 8, height: 5))
        }
        return SKTexture(image: image)
    }
    
    // MARK: - Ground
    
    static func groundTexture(width: CGFloat, height: CGFloat = GK.groundHeight) -> SKTexture {
        let size = CGSize(width: width, height: height)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            let c = ctx.cgContext
            
            // Dirt gradient
            let dirtGrad = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [
                    UIColor(red: 0.87, green: 0.85, blue: 0.58, alpha: 1).cgColor,
                    UIColor(red: 0.83, green: 0.78, blue: 0.48, alpha: 1).cgColor,
                    UIColor(red: 0.77, green: 0.72, blue: 0.42, alpha: 1).cgColor,
                ] as CFArray,
                locations: [0, 0.5, 1]
            )!
            c.drawLinearGradient(dirtGrad,
                start: CGPoint(x: 0, y: height),
                end: CGPoint(x: 0, y: 0),
                options: [])
            
            // Dirt stripes
            c.setFillColor(UIColor(white: 0, alpha: 0.04).cgColor)
            for i in stride(from: CGFloat(0), to: width, by: 48) {
                c.fill(CGRect(x: i, y: 0, width: 24, height: height - 20))
            }
            
            // Grass strip
            c.setFillColor(UIColor(red: 0.54, green: 0.81, blue: 0.34, alpha: 1).cgColor)
            c.fill(CGRect(x: 0, y: height - 20, width: width, height: 20))
            
            // Grass highlight
            c.setFillColor(UIColor(red: 0.63, green: 0.88, blue: 0.41, alpha: 1).cgColor)
            c.fill(CGRect(x: 0, y: height - 20, width: width, height: 8))
            
            // Grass edge line
            c.setStrokeColor(UIColor(red: 0.34, green: 0.56, blue: 0.13, alpha: 1).cgColor)
            c.setLineWidth(2)
            c.move(to: CGPoint(x: 0, y: height - 0.5))
            c.addLine(to: CGPoint(x: width, y: height - 0.5))
            c.strokePath()
            
            // Grass tufts
            c.setFillColor(UIColor(red: 0.43, green: 0.72, blue: 0.24, alpha: 1).cgColor)
            for i in stride(from: CGFloat(0), to: width, by: 34) {
                c.move(to: CGPoint(x: i, y: height - 18))
                c.addLine(to: CGPoint(x: i + 4, y: height - 14))
                c.addLine(to: CGPoint(x: i + 8, y: height - 18))
                c.closePath()
                c.fillPath()
            }
        }
        return SKTexture(image: image)
    }
    
    // MARK: - Sky Background
    
    static func skyTexture(size: CGSize) -> SKTexture {
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            let c = ctx.cgContext
            let grad = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [
                    UIColor(red: 0.30, green: 0.79, blue: 0.96, alpha: 1).cgColor,
                    UIColor(red: 0.49, green: 0.83, blue: 0.99, alpha: 1).cgColor,
                    UIColor(red: 0.76, green: 0.90, blue: 0.64, alpha: 1).cgColor,
                    UIColor(red: 0.83, green: 0.91, blue: 0.55, alpha: 1).cgColor,
                ] as CFArray,
                locations: [0, 0.45, 0.85, 1]
            )!
            c.drawLinearGradient(grad,
                start: CGPoint(x: 0, y: size.height),
                end: CGPoint(x: 0, y: 0),
                options: [])
        }
        return SKTexture(image: image)
    }
    
    // MARK: - Cloud
    
    static func cloudTexture(width: CGFloat = 80, height: CGFloat = 40) -> SKTexture {
        let size = CGSize(width: width, height: height)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            let c = ctx.cgContext
            c.setFillColor(UIColor(white: 1, alpha: 0.5).cgColor)
            
            // Cloud puffs
            let cx = width * 0.5, cy = height * 0.55
            c.fillEllipse(in: CGRect(x: cx - 30, y: cy - 10, width: 40, height: 25))
            c.fillEllipse(in: CGRect(x: cx - 10, y: cy - 20, width: 35, height: 30))
            c.fillEllipse(in: CGRect(x: cx + 10, y: cy - 8, width: 30, height: 22))
        }
        return SKTexture(image: image)
    }
    
    // MARK: - Building Silhouettes
    
    static func buildingTexture(width: CGFloat, height: CGFloat, shade: CGFloat = 0.65) -> SKTexture {
        let size = CGSize(width: width, height: height)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            let c = ctx.cgContext
            c.setFillColor(UIColor(red: 0.54 * shade, green: 0.66 * shade, blue: 0.35 * shade, alpha: 1).cgColor)
            c.fill(CGRect(origin: .zero, size: size))
        }
        return SKTexture(image: image)
    }
}
