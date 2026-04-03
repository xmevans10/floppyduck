import StoreKit
import SwiftUI

/// Manages duck skin purchases (StoreKit 2), ownership, and selection.
@MainActor
final class SkinManager: ObservableObject {
    static let shared = SkinManager()

    // MARK: - Published state

    @Published var selectedSkin: DuckSkin = .classic
    @Published var ownedSkins: Set<DuckSkin> = [.classic]
    @Published var products: [Product] = []
    @Published var purchasing: DuckSkin? = nil
    @Published var errorMessage: String? = nil

    // MARK: - Keys

    private let selectedKey = "selectedDuckSkin"
    private let ownedKey = "ownedDuckSkins"

    // MARK: - Init

    private init() {
        loadState()
        Task { await fetchProducts() }
        Task { await listenForTransactions() }
    }

    // MARK: - Persistence

    private func loadState() {
        if let raw = UserDefaults.standard.string(forKey: selectedKey),
           let skin = DuckSkin(rawValue: raw) {
            selectedSkin = skin
        }

        if let data = UserDefaults.standard.data(forKey: ownedKey),
           let ids = try? JSONDecoder().decode(Set<String>.self, from: data) {
            ownedSkins = Set(ids.compactMap { DuckSkin(rawValue: $0) })
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

    func select(_ skin: DuckSkin) {
        guard ownedSkins.contains(skin) else { return }
        selectedSkin = skin
        saveState()
        AnalyticsManager.shared.trackSkinEquipped(skinId: skin.rawValue)
    }

    // MARK: - StoreKit 2

    func fetchProducts() async {
        let ids = DuckSkin.allCases
            .compactMap { $0.premiumProductID }

        do {
            products = try await Product.products(for: ids)
                .sorted { $0.id < $1.id }
        } catch {
            print("[SkinManager] Failed to fetch products: \(error)")
        }
    }

    func purchasePremium(_ skin: DuckSkin) async {
        guard skin.isPremium else { return }

        purchasing = skin
        errorMessage = nil

        guard let productID = skin.premiumProductID,
              let product = products.first(where: { $0.id == productID }) else {
            // Fallback for testing without StoreKit config — grant immediately
            #if DEBUG
            grantSkin(skin)
            purchasing = nil
            return
            #else
            errorMessage = "Product not found"
            purchasing = nil
            return
            #endif
        }

        AnalyticsManager.shared.trackIAPPurchaseStarted(productId: productID, itemType: "skin")

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                grantSkin(skin)
                await transaction.finish()
                AnalyticsManager.shared.trackIAPPurchaseCompleted(productId: productID, itemType: "skin")
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
                if let skin = DuckSkin.allCases.first(where: { $0.premiumProductID == transaction.productID }) {
                    grantSkin(skin)
                    restoredCount += 1
                }
            }
        }
        AnalyticsManager.shared.trackIAPRestoreCompleted(itemType: "skin", count: restoredCount)
    }

    // MARK: - Helpers

    private func grantSkin(_ skin: DuckSkin) {
        let wasNew = ownedSkins.insert(skin).inserted
        saveState()

        // Fire skin achievement event when a new skin is acquired
        if wasNew {
            // GameManager may not be available here, so award bread through
            // AchievementManager directly (it will save progress).
            AchievementManager.shared.process(
                event: .skinPurchased(totalOwned: ownedSkins.count),
                stats: PlayerStats(),  // stats not needed for skin achievements
                skinsOwned: ownedSkins.count
            )
        }
    }

    func unlockNormal(_ skin: DuckSkin) {
        guard skin.isNormal else { return }
        grantSkin(skin)
    }

    func unlockBotReward(_ skin: DuckSkin) {
        grantSkin(skin)
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let item):
            return item
        }
    }

    private func listenForTransactions() async {
        for await result in Transaction.updates {
            if let transaction = try? checkVerified(result) {
                if let skin = DuckSkin.allCases.first(where: { $0.premiumProductID == transaction.productID }) {
                    grantSkin(skin)
                }
                await transaction.finish()
            }
        }
    }

    func product(for skin: DuckSkin) -> Product? {
        guard let productID = skin.premiumProductID else { return nil }
        return products.first { $0.id == productID }
    }
}

private enum StoreError: Error {
    case failedVerification
}
