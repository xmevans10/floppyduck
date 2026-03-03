import UIKit

/// Lightweight haptic feedback helper.
enum Haptic {
    private static let impactLight = UIImpactFeedbackGenerator(style: .light)
    private static let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private static let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private static let notification = UINotificationFeedbackGenerator()
    
    static func flap() {
        impactLight.impactOccurred()
    }
    
    static func score() {
        impactMedium.impactOccurred()
    }
    
    static func death() {
        notification.notificationOccurred(.error)
    }
    
    static func buttonTap() {
        impactLight.impactOccurred()
    }
    
    static func matchFound() {
        notification.notificationOccurred(.success)
    }
}
