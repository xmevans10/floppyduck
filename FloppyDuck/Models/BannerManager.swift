import StoreKit
import SwiftUI

/// Manages battle banner purchases, ownership, and selection.
/// Mirrors `SkinManager` / `ThemeManager` pattern — UserDefaults persistence, StoreKit 2 IAP.
@MainActor
final class BannerManager: ObservableObject {
    static let shared = BannerManager()

    // MARK: - Published state

    @Published var selectedBanner: BattleBanner = .classic
    @Published var ownedBanners: Set<BattleBanner> = [.classic, .crimson, .midnight]
    @Published var products: [Product] = []
    @Published var purchasing: BattleBanner? = nil
    @Published var errorMessage: String? = nil

    // MARK: - Keys

    private let selectedKey = "selectedBattleBanner"
    private let ownedKey = "ownedBattleBanners"

    // MARK: - Init

    private init() {
        loadState()
        Task { await fetchProducts() }
        Task { await listenForTransactions() }
    }

    // MARK: - Persistence

    private func loadState() {
        if let raw = UserDefaults.standard.string(forKey: selectedKey),
           let banner = BattleBanner(rawValue: raw) {
            selectedBanner = banner
        }

        if let data = UserDefaults.standard.data(forKey: ownedKey),
           let ids = try? JSONDecoder().decode(Set<String>.self, from: data) {
            ownedBanners = Set(ids.compactMap { BattleBanner(rawValue: $0) })
        }
        // Free banners are always owned
        ownedBanners.formUnion([.classic, .crimson, .midnight])
    }

    private func saveState() {
        UserDefaults.standard.set(selectedBanner.rawValue, forKey: selectedKey)
        let ids = Set(ownedBanners.map { $0.rawValue })
        if let data = try? JSONEncoder().encode(ids) {
            UserDefaults.standard.set(data, forKey: ownedKey)
        }
    }

    // MARK: - Selection

    func select(_ banner: BattleBanner) {
        guard ownedBanners.contains(banner) else { return }
        selectedBanner = banner
        saveState()
        AnalyticsManager.shared.trackBannerEquipped(bannerId: banner.rawValue)
    }

    // MARK: - Bot reward unlock

    /// Call when a bot is beaten — auto-unlocks any associated banner.
    func checkBotRewardUnlock(beatenBotId: String) {
        for banner in BattleBanner.allCases where banner.isBotReward {
            if banner.requiredBotId == beatenBotId {
                grantBanner(banner)
            }
        }
    }

    /// Sync owned banners with beaten bots list (call on app launch).
    func syncWithBeatenBots(_ beatenBots: [String]) {
        for botId in beatenBots {
            checkBotRewardUnlock(beatenBotId: botId)
        }
    }

    // MARK: - Bread purchase

    func unlockNormal(_ banner: BattleBanner) {
        guard banner.isNormal else { return }
        grantBanner(banner)
    }

    // MARK: - StoreKit 2

    func fetchProducts() async {
        let ids = BattleBanner.allCases
            .compactMap { $0.premiumProductID }

        guard !ids.isEmpty else { return }

        do {
            products = try await Product.products(for: ids)
                .sorted { $0.id < $1.id }
        } catch {
            print("[BannerManager] Failed to fetch products: \(error)")
        }
    }

    func purchasePremium(_ banner: BattleBanner) async {
        guard banner.isPremium else { return }

        purchasing = banner
        errorMessage = nil

        guard let productID = banner.premiumProductID,
              let product = products.first(where: { $0.id == productID }) else {
            // Fallback when product not in store — grant immediately
            grantBanner(banner)
            purchasing = nil
            return
        }

        AnalyticsManager.shared.trackIAPPurchaseStarted(productId: productID, itemType: "banner")

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                grantBanner(banner)
                await transaction.finish()
                AnalyticsManager.shared.trackIAPPurchaseCompleted(productId: productID, itemType: "banner")
            case .userCancelled:
                break
            case .pending:
                errorMessage = "Purchase pending approval"
            @unknown default:
                break
            }
        } catch {
            errorMessage = "Purchase failed: \(error.localizedDescription)"
        }

        purchasing = nil
    }

    func restorePurchases() async {
        var restoredCount = 0
        for await result in Transaction.currentEntitlements {
            if let transaction = try? checkVerified(result) {
                if let banner = BattleBanner.allCases.first(where: { $0.premiumProductID == transaction.productID }) {
                    grantBanner(banner)
                    restoredCount += 1
                }
            }
        }
        AnalyticsManager.shared.trackIAPRestoreCompleted(itemType: "banner", count: restoredCount)
    }

    // MARK: - Helpers

    private func grantBanner(_ banner: BattleBanner) {
        ownedBanners.insert(banner)
        saveState()
    }

    func product(for banner: BattleBanner) -> Product? {
        guard let productID = banner.premiumProductID else { return nil }
        return products.first { $0.id == productID }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw BannerStoreError.failedVerification
        case .verified(let item):
            return item
        }
    }

    private func listenForTransactions() async {
        for await result in Transaction.updates {
            if let transaction = try? checkVerified(result) {
                if let banner = BattleBanner.allCases.first(where: { $0.premiumProductID == transaction.productID }) {
                    grantBanner(banner)
                }
                await transaction.finish()
            }
        }
    }
}

private enum BannerStoreError: Error {
    case failedVerification
}
