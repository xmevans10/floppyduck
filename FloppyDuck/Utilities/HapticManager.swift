import UIKit

/// Lightweight haptic feedback helper.
/// Checks the hapticsEnabled UserDefaults key before firing.
/// Preference is cached to avoid UserDefaults dictionary lookup on every tap/frame.
enum Haptic {
    private static let impactLight = UIImpactFeedbackGenerator(style: .light)
    private static let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private static let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private static let notification = UINotificationFeedbackGenerator()

    /// Dedicated serial queue for haptic feedback — keeps UIImpactFeedbackGenerator
    /// IPC (~0.5-2ms) off the main/render thread to prevent tap-correlated micro-stutters.
    private static let hapticQueue = DispatchQueue(label: "com.floppyduck.haptics", qos: .userInteractive)

    /// Cached preference — avoids UserDefaults lookup on every haptic call.
    private static var _isEnabled: Bool = {
        UserDefaults.standard.object(forKey: "hapticsEnabled") as? Bool ?? true
    }()

    private static var isEnabled: Bool { _isEnabled }

    // PERF: Coalesced re-prepare — avoids calling prepare() on the hot tap path.
    // Each generator type tracks its last prepare time and skips re-prepare within
    // a short window, since prepare() is a synchronous IPC call (~0.5–1 ms each).
    private static var lastPrepareTime: [ObjectIdentifier: TimeInterval] = [:]
    private static let prepareThrottleInterval: TimeInterval = 0.3

    private static func throttledPrepare(_ generator: Any, key: ObjectIdentifier) {
        let now = CACurrentMediaTime()
        guard now - (lastPrepareTime[key] ?? 0) >= prepareThrottleInterval else { return }
        lastPrepareTime[key] = now
        (generator as? UIImpactFeedbackGenerator)?.prepare()
        (generator as? UINotificationFeedbackGenerator)?.prepare()
    }

    /// Call when the user toggles the haptics setting to update the cached value.
    static func refreshPreference() {
        _isEnabled = UserDefaults.standard.object(forKey: "hapticsEnabled") as? Bool ?? true
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
        hapticQueue.async {
            impactLight.impactOccurred()
            throttledPrepare(impactLight, key: ObjectIdentifier(impactLight))
        }
    }

    /// Quick tick — used for slot-machine cycling and countdown ticks.
    static func light() {
        guard isEnabled else { return }
        hapticQueue.async {
            impactLight.impactOccurred()
            throttledPrepare(impactLight, key: ObjectIdentifier(impactLight))
        }
    }

    /// Medium emphasis — used for reveals, power-up collection.
    static func medium() {
        guard isEnabled else { return }
        hapticQueue.async {
            impactMedium.impactOccurred()
            throttledPrepare(impactMedium, key: ObjectIdentifier(impactMedium))
        }
    }

    static func score() {
        guard isEnabled else { return }
        hapticQueue.async {
            impactMedium.impactOccurred()
            throttledPrepare(impactMedium, key: ObjectIdentifier(impactMedium))
        }
    }

    static func death() {
        guard isEnabled else { return }
        notification.notificationOccurred(.error)
        throttledPrepare(notification, key: ObjectIdentifier(notification))
    }

    static func buttonTap() {
        guard isEnabled else { return }
        impactLight.impactOccurred()
        throttledPrepare(impactLight, key: ObjectIdentifier(impactLight))
    }

    static func matchFound() {
        guard isEnabled else { return }
        notification.notificationOccurred(.success)
        throttledPrepare(notification, key: ObjectIdentifier(notification))
    }

    /// Every 5 pipes scored — satisfying mid-game beat
    static func milestone() {
        guard isEnabled else { return }
        hapticQueue.async {
            impactHeavy.impactOccurred()
            throttledPrepare(impactHeavy, key: ObjectIdentifier(impactHeavy))
        }
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
        throttledPrepare(notification, key: ObjectIdentifier(notification))
    }

    /// Lost a VS Bot match
    static func lose() {
        guard isEnabled else { return }
        notification.notificationOccurred(.warning)
        throttledPrepare(notification, key: ObjectIdentifier(notification))
    }

    /// Splash screen — heavy pop when duck appears
    static func splashImpact() {
        guard isEnabled else { return }
        impactHeavy.impactOccurred(intensity: 1.0)
        throttledPrepare(impactHeavy, key: ObjectIdentifier(impactHeavy))
    }

    /// Splash screen — satisfying coin-collect thud at mid-spin
    static func splashCoin() {
        guard isEnabled else { return }
        impactMedium.impactOccurred(intensity: 0.9)
        throttledPrepare(impactMedium, key: ObjectIdentifier(impactMedium))
    }

    /// Splash screen — medium punch when title pops in
    static func splashTitlePop() {
        guard isEnabled else { return }
        impactMedium.impactOccurred(intensity: 0.8)
        throttledPrepare(impactMedium, key: ObjectIdentifier(impactMedium))
    }

    /// Splash screen — light tap on shimmer sweep
    static func splashShimmer() {
        guard isEnabled else { return }
        impactLight.impactOccurred(intensity: 0.5)
        throttledPrepare(impactLight, key: ObjectIdentifier(impactLight))
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
