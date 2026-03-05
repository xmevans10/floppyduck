import UIKit

/// Lightweight haptic feedback helper.
/// Checks the hapticsEnabled UserDefaults key before firing.
enum Haptic {
    private static let impactLight = UIImpactFeedbackGenerator(style: .light)
    private static let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private static let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private static let notification = UINotificationFeedbackGenerator()

    private static var isEnabled: Bool {
        // Default true if key hasn't been set yet
        UserDefaults.standard.object(forKey: "hapticsEnabled") as? Bool ?? true
    }

    static func flap() {
        guard isEnabled else { return }
        impactLight.impactOccurred()
    }

    static func score() {
        guard isEnabled else { return }
        impactMedium.impactOccurred()
    }

    static func death() {
        guard isEnabled else { return }
        notification.notificationOccurred(.error)
    }

    static func buttonTap() {
        guard isEnabled else { return }
        impactLight.impactOccurred()
    }

    static func matchFound() {
        guard isEnabled else { return }
        notification.notificationOccurred(.success)
    }
}
