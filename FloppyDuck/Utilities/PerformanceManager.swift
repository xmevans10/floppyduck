import Foundation
import UIKit

/// Detects iOS Low Power Mode and thermal state to dynamically adjust visual
/// quality. GameScene and ParallaxManager read `quality` each frame to reduce
/// particle counts, disable decorative animations, and simplify effects — keeping
/// gameplay at 60 fps even under system throttling.
///
/// Usage:
///   - Read `PerformanceManager.shared.quality` for current level.
///   - Observe `qualityDidChange` notification for reactive UI updates.
final class PerformanceManager {
    static let shared = PerformanceManager()

    /// Quality tiers — higher tiers get fewer visual effects.
    enum Quality: Int, Comparable {
        case full = 0       // Default: all effects enabled
        case reduced = 1    // Low Power Mode OR warm thermal state
        case minimal = 2    // Serious thermal (critical) — bare minimum

        static func < (lhs: Quality, rhs: Quality) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    /// Posted on the main queue whenever `quality` changes.
    static let qualityDidChange = Notification.Name("PerformanceManager.qualityDidChange")

    /// Current quality level — thread-safe read.
    private(set) var quality: Quality = .full

    // MARK: - Convenience Queries

    /// True when visual effects should be reduced (low power or thermal pressure).
    var isReduced: Bool { quality >= .reduced }

    /// Max cloud count for ParallaxManager.
    var cloudCount: Int {
        switch quality {
        case .full:    return 5
        case .reduced: return 2
        case .minimal: return 1
        }
    }

    /// Max death particles.
    var deathParticleCount: Int {
        switch quality {
        case .full:    return Int.random(in: 12...15)
        case .reduced: return 5
        case .minimal: return 0
        }
    }

    /// Max celebration particles (bot ladder win).
    var celebrationParticleCount: Int {
        switch quality {
        case .full:    return 20
        case .reduced: return 8
        case .minimal: return 0
        }
    }

    /// Whether to show ground detail tiles (grass blades, pebbles).
    var showGroundDetails: Bool { quality == .full }

    /// Whether to animate star twinkle.
    var showStarTwinkle: Bool { quality == .full }

    /// Whether to run screen shake on death.
    var showScreenShake: Bool { quality != .minimal }

    /// Whether to show the camera zoom on death.
    var showDeathZoom: Bool { quality != .minimal }

    /// Whether to run decorative parallax (clouds, hills, trees).
    var showDecorativeParallax: Bool { quality != .minimal }

    // MARK: - Init

    private init() {
        recalculate()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(powerStateChanged),
            name: .NSProcessInfoPowerStateDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(thermalStateChanged),
            name: ProcessInfo.thermalStateDidChangeNotification,
            object: nil
        )
    }

    // MARK: - Recalculation

    @objc private func powerStateChanged() { recalculate() }
    @objc private func thermalStateChanged() { recalculate() }

    private func recalculate() {
        let lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        let thermal = ProcessInfo.processInfo.thermalState

        let newQuality: Quality
        if thermal == .critical || thermal == .serious {
            newQuality = .minimal
        } else if lowPower || thermal == .fair {
            newQuality = .reduced
        } else {
            newQuality = .full
        }

        guard newQuality != quality else { return }
        quality = newQuality
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: Self.qualityDidChange, object: nil)
        }
    }
}
