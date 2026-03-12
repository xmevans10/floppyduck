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

    /// Every 5 pipes scored — satisfying mid-game beat
    static func milestone() {
        guard isEnabled else { return }
        impactHeavy.impactOccurred()
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

    /// Splash screen — heavy pop when duck appears
    static func splashImpact() {
        guard isEnabled else { return }
        impactHeavy.impactOccurred(intensity: 1.0)
    }

    /// Splash screen — satisfying coin-collect thud at mid-spin
    static func splashCoin() {
        guard isEnabled else { return }
        impactMedium.impactOccurred(intensity: 0.9)
    }

    /// Splash screen — medium punch when title pops in
    static func splashTitlePop() {
        guard isEnabled else { return }
        impactMedium.impactOccurred(intensity: 0.8)
    }

    /// Splash screen — light tap on shimmer sweep
    static func splashShimmer() {
        guard isEnabled else { return }
        impactLight.impactOccurred(intensity: 0.5)
    }

    /// Legacy alias for backward compat
    static func splash() {
        splashImpact()
    }

    /// Enhanced death impact — stronger/longer shake feeling
    static func enhancedDeath() {
        guard isEnabled else { return }
        impactHeavy.impactOccurred(intensity: 1.0)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            notification.notificationOccurred(.error)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            impactMedium.impactOccurred()
        }
    }
}
