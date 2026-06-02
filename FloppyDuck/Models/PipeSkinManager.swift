import StoreKit
import SwiftUI

/// Manages pipe skin purchases, ownership, and selection.
/// Mirrors `SkinManager` / `ThemeManager` / `BannerManager` pattern —
/// UserDefaults persistence, StoreKit 2 IAP.
@MainActor
final class PipeSkinManager: ObservableObject {
    static let shared = PipeSkinManager()

    // MARK: - Published state

    @Published var selectedSkin: PipeSkin = .classic
    @Published var ownedSkins: Set<PipeSkin> = [.classic]
    @Published var products: [Product] = []
    @Published var purchasing: PipeSkin? = nil
    @Published var errorMessage: String? = nil

    // MARK: - Keys

    private let selectedKey = "selectedPipeSkin"
    private let ownedKey = "ownedPipeSkins"

    // MARK: - Init

    private init() {
        loadState()
        // Product fetching and transaction listening are handled by
        // IAPCoordinator.shared — one batch call instead of 8 Tasks.
    }

    // MARK: - Persistence

    private func loadState() {
        if let raw = UserDefaults.standard.string(forKey: selectedKey),
           let skin = PipeSkin(rawValue: raw) {
            selectedSkin = skin
        }

        if let data = UserDefaults.standard.data(forKey: ownedKey),
           let ids = try? JSONDecoder().decode(Set<String>.self, from: data) {
            ownedSkins = Set(ids.compactMap { PipeSkin(rawValue: $0) })
        }
        // Classic is always owned
        ownedSkins.insert(.classic)
    }

    private func saveState() {
        UserDefaults.standard.set(selectedSkin.rawValue, forKey: selectedKey)
        let ids = Set(ownedSkins.map { $0.rawValue })
        if let data = try? JSONEncoder().encode(ids) {
            UserDefaults.standard.set(data, forKey: ownedKey)
        }
    }

    // MARK: - Selection

    func select(_ skin: PipeSkin) {
        guard ownedSkins.contains(skin) else { return }
        selectedSkin = skin
        saveState()

        // Invalidate cached pipe textures so the new skin takes effect next game
        TextureFactory.shared.invalidatePipeCache()

        AnalyticsManager.shared.trackPipeSkinEquipped(pipeSkinId: skin.rawValue)
    }

    // MARK: - Bot reward unlock

    /// Call when a bot is beaten — auto-unlocks any associated pipe skin.
    func checkBotRewardUnlock(beatenBotId: String) {
        for skin in PipeSkin.allCases where skin.isBotReward {
            if skin.requiredBotId == beatenBotId {
                grantSkin(skin)
            }
        }
    }

    /// Sync owned pipe skins with beaten bots list (call on app launch).
    func syncWithBeatenBots(_ beatenBots: [String]) {
        for botId in beatenBots {
            checkBotRewardUnlock(beatenBotId: botId)
        }
    }

    // MARK: - Bread purchase

    func unlockNormal(_ skin: PipeSkin) {
        guard skin.isNormal else { return }
        grantSkin(skin)
    }

    // MARK: - StoreKit 2

    func fetchProducts() async {
        let ids = PipeSkin.allCases
            .compactMap { $0.premiumProductID }

        guard !ids.isEmpty else { return }

        do {
            products = try await Product.products(for: ids)
                .sorted { $0.id < $1.id }
        } catch {
            print("[PipeSkinManager] Failed to fetch products: \(error)")
        }
    }

    func purchasePremium(_ skin: PipeSkin) async {
        guard skin.isPremium else { return }

        purchasing = skin
        errorMessage = nil

        guard let productID = skin.premiumProductID,
              let product = products.first(where: { $0.id == productID }) else {
            // Fallback when product not in store — grant immediately
            grantSkin(skin)
            purchasing = nil
            return
        }

        AnalyticsManager.shared.trackIAPPurchaseStarted(productId: productID, itemType: "pipe")

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                grantSkin(skin)
                await transaction.finish()
                AnalyticsManager.shared.trackIAPPurchaseCompleted(productId: productID, itemType: "pipe")
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
        for await result in StoreKit.Transaction.currentEntitlements {
            if let transaction = try? checkVerified(result) {
                if let skin = PipeSkin.allCases.first(where: { $0.premiumProductID == transaction.productID }) {
                    grantSkin(skin)
                    restoredCount += 1
                }
            }
        }
        AnalyticsManager.shared.trackIAPRestoreCompleted(itemType: "pipe", count: restoredCount)
    }

    // MARK: - Helpers

    private func grantSkin(_ skin: PipeSkin) {
        ownedSkins.insert(skin)
        saveState()
    }

    func product(for skin: PipeSkin) -> Product? {
        guard let productID = skin.premiumProductID else { return nil }
        return products.first { $0.id == productID }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw PipeSkinStoreError.failedVerification
        case .verified(let item):
            return item
        }
    }

    // Transaction listening is handled by IAPCoordinator.

    /// Called by IAPCoordinator to distribute batch-fetched products.
    func applyFetchedProducts(_ fetched: [Product]) {
        products = fetched
    }

    /// Called by IAPCoordinator when a verified transaction matches a pipe skin ID.
    func handleVerifiedTransaction(_ transaction: StoreKit.Transaction) async {
        if let skin = PipeSkin.allCases.first(where: { $0.premiumProductID == transaction.productID }) {
            grantSkin(skin)
        }
    }
}

private enum PipeSkinStoreError: Error {
    case failedVerification
}
