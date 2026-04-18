import Foundation
import PostHog

/// Lightweight PostHog wrapper — typed event methods for every tracked event.
/// See tracking.md for the full event taxonomy and prioritization.
@MainActor
final class AnalyticsManager {
    static let shared = AnalyticsManager()
    private init() {}

    /// Call once from FloppyDuckApp.init() after Sentry setup.
    static func configure() {
        let config = PostHogConfig(
            apiKey: "phc_DSZGupxsSlreIJxdSzEHhGjnQbRLVtvrSEE2TahVoad",
            host: "https://us.i.posthog.com"
        )
        #if DEBUG
        // Opt-in only — verbose logging adds main-thread overhead during gameplay.
        config.debug = ProcessInfo.processInfo.environment["POSTHOG_VERBOSE"] != nil
        #endif
        PostHogSDK.shared.setup(config)
    }

    /// Associate all future events with a known user.
    static func identify(userId: String, properties: [String: Any]? = nil) {
        PostHogSDK.shared.identify(userId, userProperties: properties)
    }

    /// Clear identity (sign-out).
    static func reset() {
        PostHogSDK.shared.reset()
    }

    // MARK: - App Lifecycle (Launch-Critical)

    func trackAppOpen() {
        PostHogSDK.shared.capture("app_open")
    }

    func trackOnboardingCompleted(method: String) {
        PostHogSDK.shared.capture("onboarding_completed", properties: ["method": method])
    }

    func trackGuestBootstrapSucceeded() {
        PostHogSDK.shared.capture("guest_bootstrap_succeeded")
    }

    // MARK: - Auth (Launch-Critical)

    func trackAppleSignInStarted() {
        PostHogSDK.shared.capture("apple_sign_in_started")
    }

    func trackAppleSignInSucceeded() {
        PostHogSDK.shared.capture("apple_sign_in_succeeded")
    }

    // MARK: - Gameplay (Launch-Critical)

    func trackGameStarted(mode: String, seed: Int, isRanked: Bool) {
        PostHogSDK.shared.capture("game_started", properties: [
            "mode": mode,
            "seed": seed,
            "is_ranked": isRanked
        ])
    }

    func trackGameCompleted(mode: String, score: Int, won: Bool?) {
        var props: [String: Any] = ["mode": mode, "score": score]
        if let won { props["won"] = won }
        PostHogSDK.shared.capture("game_completed", properties: props)
    }

    func trackModeSelected(mode: String) {
        PostHogSDK.shared.capture("mode_selected", properties: ["mode": mode])
    }

    // MARK: - Shop & IAP (Launch-Critical)

    func trackShopViewed() {
        PostHogSDK.shared.capture("shop_viewed")
    }

    func trackItemViewed(itemType: String, itemId: String) {
        PostHogSDK.shared.capture("item_viewed", properties: [
            "item_type": itemType,
            "item_id": itemId
        ])
    }

    func trackIAPPurchaseStarted(productId: String, itemType: String) {
        PostHogSDK.shared.capture("iap_purchase_started", properties: [
            "product_id": productId,
            "item_type": itemType
        ])
    }

    func trackIAPPurchaseCompleted(productId: String, itemType: String) {
        PostHogSDK.shared.capture("iap_purchase_completed", properties: [
            "product_id": productId,
            "item_type": itemType
        ])
    }

    func trackIAPRestoreCompleted(itemType: String, count: Int) {
        PostHogSDK.shared.capture("iap_restore_completed", properties: [
            "item_type": itemType,
            "items_restored": count
        ])
    }

    // MARK: - Bot Ladder (Post-Launch)

    func trackBotMatchStarted(botId: String, botName: String, targetScore: Int) {
        PostHogSDK.shared.capture("bot_match_started", properties: [
            "bot_id": botId,
            "bot_name": botName,
            "target_score": targetScore
        ])
    }

    func trackBotMatchCompleted(botId: String, won: Bool, score: Int) {
        PostHogSDK.shared.capture("bot_match_completed", properties: [
            "bot_id": botId,
            "won": won,
            "score": score
        ])
    }

    // MARK: - Multiplayer (Post-Launch)

    func trackMultiplayerQueueStarted(mode: String) {
        PostHogSDK.shared.capture("multiplayer_queue_started", properties: ["mode": mode])
    }

    func trackMultiplayerMatchFound(mode: String) {
        PostHogSDK.shared.capture("multiplayer_match_found", properties: ["mode": mode])
    }

    func trackMultiplayerMatchFinished(mode: String, won: Bool, score: Int, opponentScore: Int) {
        PostHogSDK.shared.capture("multiplayer_match_finished", properties: [
            "mode": mode,
            "won": won,
            "score": score,
            "opponent_score": opponentScore
        ])
    }

    // MARK: - Cosmetics (Post-Launch)

    func trackSkinEquipped(skinId: String) {
        PostHogSDK.shared.capture("skin_equipped", properties: ["skin_id": skinId])
    }

    func trackThemeEquipped(themeId: String) {
        PostHogSDK.shared.capture("theme_equipped", properties: ["theme_id": themeId])
    }

    func trackBannerEquipped(bannerId: String) {
        PostHogSDK.shared.capture("banner_equipped", properties: ["banner_id": bannerId])
    }

    // MARK: - Feature Adoption (Post-Launch)

    func trackStatsViewed() {
        PostHogSDK.shared.capture("stats_viewed")
    }

    func trackLeaderboardViewed() {
        PostHogSDK.shared.capture("leaderboard_viewed")
    }

    func trackShareSheetOpened(mode: String?, score: Int?) {
        var props: [String: Any] = [:]
        if let mode { props["mode"] = mode }
        if let score { props["score"] = score }
        PostHogSDK.shared.capture("share_sheet_opened", properties: props)
    }
}
