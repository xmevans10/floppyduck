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

    /// Pre-warm all generators to eliminate first-call latency (~20ms saved).
    /// Call once at scene start / didMove(to:).
    static func warmUp() {
        impactLight.prepare()
        impactMedium.prepare()
        impactHeavy.prepare()
        notification.prepare()
    }

    static func flap() {
        guard isEnabled else { return }
        impactLight.impactOccurred()
        impactLight.prepare()  // re-warm for next use
    }

    static func score() {
        guard isEnabled else { return }
        impactMedium.impactOccurred()
        impactMedium.prepare()
    }

    static func death() {
        guard isEnabled else { return }
        notification.notificationOccurred(.error)
        notification.prepare()
    }

    static func buttonTap() {
        guard isEnabled else { return }
        impactLight.impactOccurred()
        impactLight.prepare()
    }

    static func matchFound() {
        guard isEnabled else { return }
        notification.notificationOccurred(.success)
        notification.prepare()
    }

    /// Every 5 pipes scored — satisfying mid-game beat
    static func milestone() {
        guard isEnabled else { return }
        impactHeavy.impactOccurred()
        impactHeavy.prepare()
    }

    /// New personal best
    static func newBest() {
        guard isEnabled else { return }
        notification.notificationOccurred(.success)
        // Double-tap for emphasis
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            impactHeavy.impactOccurred()
        }
    }

    /// Won a VS Bot / ladder match
    static func win() {
        guard isEnabled else { return }
        notification.notificationOccurred(.success)
    }

    /// Lost a VS Bot match
    static func lose() {
        guard isEnabled else { return }
        notification.notificationOccurred(.warning)
    }

    /// Splash screen duck landing — satisfying medium thud
    static func splash() {
        guard isEnabled else { return }
        impactMedium.impactOccurred()
        impactMedium.prepare()
    }
}
