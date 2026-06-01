import StoreKit
import SwiftUI

/// Manages background theme purchases, ownership, and selection.
/// Mirrors `SkinManager` pattern — UserDefaults persistence, StoreKit 2 IAP.
@MainActor
final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    // MARK: - Published state

    @Published var selectedTheme: BackgroundTheme = .day
    @Published var ownedThemes: Set<BackgroundTheme> = [.day, .sunset, .night]
    @Published var products: [Product] = []
    @Published var purchasing: BackgroundTheme? = nil
    @Published var errorMessage: String? = nil

    // MARK: - Keys

    private let selectedKey = "selectedBackgroundTheme"
    private let ownedKey = "ownedBackgroundThemes"

    // MARK: - Init

    private init() {
        loadState()
        // Product fetching and transaction listening are handled by
        // IAPCoordinator.shared — one batch call instead of 8 Tasks.
    }

    // MARK: - Persistence

    private func loadState() {
        if let raw = UserDefaults.standard.string(forKey: selectedKey),
           let theme = BackgroundTheme(rawValue: raw) {
            selectedTheme = theme
        }

        if let data = UserDefaults.standard.data(forKey: ownedKey),
           let ids = try? JSONDecoder().decode(Set<String>.self, from: data) {
            ownedThemes = Set(ids.compactMap { BackgroundTheme(rawValue: $0) })
        }
        // Free themes are always owned
        ownedThemes.formUnion(BackgroundTheme.allCases.filter { $0.isFree })
    }

    private func saveState() {
        UserDefaults.standard.set(selectedTheme.rawValue, forKey: selectedKey)
        let ids = Set(ownedThemes.map { $0.rawValue })
        if let data = try? JSONEncoder().encode(ids) {
            UserDefaults.standard.set(data, forKey: ownedKey)
        }
    }

    // MARK: - Selection

    func select(_ theme: BackgroundTheme) {
        guard ownedThemes.contains(theme) else { return }
        selectedTheme = theme
        SoundManager.shared.setActiveTheme(theme)
        saveState()
        AnalyticsManager.shared.trackThemeEquipped(themeId: theme.rawValue)
    }

    // MARK: - StoreKit 2

    func fetchProducts() async {
        let ids = BackgroundTheme.allCases
            .compactMap { $0.premiumProductID }

        guard !ids.isEmpty else { return }

        do {
            products = try await Product.products(for: ids)
                .sorted { $0.id < $1.id }
        } catch {
            print("[ThemeManager] Failed to fetch products: \(error)")
        }
    }

    func purchasePremium(_ theme: BackgroundTheme) async {
        guard theme.isPremium else { return }

        purchasing = theme
        errorMessage = nil

        guard let productID = theme.premiumProductID,
              let product = products.first(where: { $0.id == productID }) else {
            // Fallback when product not in store — grant immediately
            grantTheme(theme)
            purchasing = nil
            return
        }

        AnalyticsManager.shared.trackIAPPurchaseStarted(productId: productID, itemType: "theme")

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                grantTheme(theme)
                await transaction.finish()
                AnalyticsManager.shared.trackIAPPurchaseCompleted(productId: productID, itemType: "theme")
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
                if let theme = BackgroundTheme.allCases.first(where: { $0.premiumProductID == transaction.productID }) {
                    grantTheme(theme)
                    restoredCount += 1
                }
            }
        }
        AnalyticsManager.shared.trackIAPRestoreCompleted(itemType: "theme", count: restoredCount)
    }

    // MARK: - Helpers

    private func grantTheme(_ theme: BackgroundTheme) {
        ownedThemes.insert(theme)
        saveState()
    }

    func unlockNormal(_ theme: BackgroundTheme) {
        guard theme.isNormal else { return }
        grantTheme(theme)
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw ThemeStoreError.failedVerification
        case .verified(let item):
            return item
        }
    }

    // Transaction listening is handled by IAPCoordinator.

    /// Called by IAPCoordinator to distribute batch-fetched products.
    func applyFetchedProducts(_ fetched: [Product]) {
        products = fetched
    }

    /// Called by IAPCoordinator when a verified transaction matches a theme ID.
    func handleVerifiedTransaction(_ transaction: Transaction) async {
        if let theme = BackgroundTheme.allCases.first(where: { $0.premiumProductID == transaction.productID }) {
            grantTheme(theme)
        }
    }

    func product(for theme: BackgroundTheme) -> Product? {
        guard let productID = theme.premiumProductID else { return nil }
        return products.first { $0.id == productID }
    }
}

private enum ThemeStoreError: Error {
    case failedVerification
}
