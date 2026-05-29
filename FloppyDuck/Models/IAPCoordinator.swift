import StoreKit

/// Centralises the single `Product.products(for:)` network call that was
/// previously duplicated across 4 IAP managers (SkinManager, PipeSkinManager,
/// BannerManager, ThemeManager) — 8 concurrent StoreKit Tasks at startup
/// reduced to 1 batch fetch + 1 shared transaction listener.
@MainActor
final class IAPCoordinator: ObservableObject {

    static let shared = IAPCoordinator()

    /// All fetched products keyed by product ID for O(1) lookup.
    private(set) var productsByID: [String: Product] = [:]

    /// Whether the initial batch fetch has completed at least once.
    private(set) var hasFetched = false

    private var fetchTask: Task<Void, Never>?
    private var transactionTask: Task<Void, Never>?

    private init() {
        fetchTask = Task { await batchFetchProducts() }
        transactionTask = Task { await listenForTransactions() }
    }

    // MARK: - Batch Fetch

    /// Single `Product.products(for:)` call with every premium ID in the app.
    func batchFetchProducts() async {
        let skinIDs = DuckSkin.allCases.compactMap(\.premiumProductID)
        let pipeIDs = PipeSkin.allCases.compactMap(\.premiumProductID)
        let bannerIDs = BattleBanner.allCases.compactMap(\.premiumProductID)
        let themeIDs = BackgroundTheme.allCases.compactMap(\.premiumProductID)

        let allIDs = skinIDs + pipeIDs + bannerIDs + themeIDs
        guard !allIDs.isEmpty else {
            hasFetched = true
            return
        }

        do {
            let fetched = try await Product.products(for: Set(allIDs))
            var map: [String: Product] = [:]
            for product in fetched {
                map[product.id] = product
            }
            productsByID = map
            hasFetched = true

            // Distribute to each manager so their existing `products` arrays
            // stay populated for purchase flows / UI.
            SkinManager.shared.applyFetchedProducts(fetched.filter { skinIDs.contains($0.id) }
                .sorted { $0.id < $1.id })
            PipeSkinManager.shared.applyFetchedProducts(fetched.filter { pipeIDs.contains($0.id) }
                .sorted { $0.id < $1.id })
            BannerManager.shared.applyFetchedProducts(fetched.filter { bannerIDs.contains($0.id) }
                .sorted { $0.id < $1.id })
            ThemeManager.shared.applyFetchedProducts(fetched.filter { themeIDs.contains($0.id) }
                .sorted { $0.id < $1.id })
        } catch {
            print("[IAPCoordinator] Batch product fetch failed: \(error)")
        }
    }

    // MARK: - Transaction Listener

    /// Single listener that routes verified transactions to the correct
    /// manager. Replaces 4 identical `listenForTransactions()` loops.
    private func listenForTransactions() async {
        for await result in Transaction.updates {
            guard case .verified(let transaction) = result else { continue }

            let id = transaction.productID

            // Route to the manager that owns this product ID
            if DuckSkin.allCases.contains(where: { $0.premiumProductID == id }) {
                await SkinManager.shared.handleVerifiedTransaction(transaction)
            } else if PipeSkin.allCases.contains(where: { $0.premiumProductID == id }) {
                await PipeSkinManager.shared.handleVerifiedTransaction(transaction)
            } else if BattleBanner.allCases.contains(where: { $0.premiumProductID == id }) {
                await BannerManager.shared.handleVerifiedTransaction(transaction)
            } else if BackgroundTheme.allCases.contains(where: { $0.premiumProductID == id }) {
                await ThemeManager.shared.handleVerifiedTransaction(transaction)
            }

            await transaction.finish()
        }
    }
}
