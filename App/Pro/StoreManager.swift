import Foundation
import StoreKit

/// StoreKit 2 entitlement authority for the Punctual Pro ladder:
///   • monthly  (auto-renewable)  com.punctual.app.pro.monthly
///   • yearly   (auto-renewable)  com.punctual.app.pro.yearly
///   • lifetime (non-consumable)  com.punctual.app.pro.lifetime
///
/// Any tier grants `isPro` (all Pro features). Only an active subscription grants
/// `isSubscriber` (ongoing perks). Entitlements come straight from StoreKit so
/// refunds/expiry/Ask-to-Buy are always reflected.
@MainActor
@Observable
final class StoreManager {
    static let monthlyID = "com.punctual.app.pro.monthly"
    static let yearlyID = "com.punctual.app.pro.yearly"
    static let lifetimeID = "com.punctual.app.pro.lifetime"
    static let allIDs = [monthlyID, yearlyID, lifetimeID]
    static let subscriptionIDs: Set<String> = [monthlyID, yearlyID]

    private(set) var products: [String: Product] = [:]
    private(set) var isPro = false
    private(set) var isSubscriber = false
    /// False until entitlements have been read at least once. Until then we must
    /// not downgrade Pro edits or reset Pro themes (avoids cold-start clobbering).
    private(set) var resolved = false
    var purchaseError: String?

    private var updatesTask: Task<Void, Never>?

    init() {
        updatesTask = listenForTransactions()
    }

    func start() async {
        await loadProducts()
        await refreshEntitlements()
    }

    func loadProducts() async {
        do {
            let loaded = try await Product.products(for: Self.allIDs)
            products = Dictionary(uniqueKeysWithValues: loaded.map { ($0.id, $0) })
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    var monthly: Product? { products[Self.monthlyID] }
    var yearly: Product? { products[Self.yearlyID] }
    var lifetime: Product? { products[Self.lifetimeID] }

    func displayPrice(_ id: String) -> String { products[id]?.displayPrice ?? "—" }

    /// "Save N%" for yearly vs 12× monthly, when both prices are known.
    var yearlySavingsText: String? {
        guard let m = monthly?.price, let y = yearly?.price, m > 0 else { return nil }
        let full = m * 12
        guard full > 0 else { return nil }
        let pct = (Decimal(1) - (y / full)) * 100
        let rounded = Int((pct as NSDecimalNumber).doubleValue.rounded())
        return rounded > 0 ? "Save \(rounded)%" : nil
    }

    func refreshEntitlements() async {
        #if DEBUG
        // Screenshot mode: present as Free so the paywall shows purchase tiers.
        if ProcessInfo.processInfo.arguments.contains("--demo-free") {
            isPro = false; isSubscriber = false; resolved = true; return
        }
        #endif
        var pro = false
        var sub = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let t) = result, t.revocationDate == nil else { continue }
            if t.productID == Self.lifetimeID { pro = true }
            if Self.subscriptionIDs.contains(t.productID) {
                // currentEntitlements only yields active (non-expired) subs.
                pro = true
                sub = true
            }
        }
        isPro = pro
        isSubscriber = sub
        resolved = true
    }

    @discardableResult
    func purchase(_ id: String) async -> Bool {
        guard let product = products[id] else { return false }
        do {
            switch try await product.purchase() {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    await refreshEntitlements() // authoritative
                    return isPro
                }
                purchaseError = "Purchase couldn't be verified. Please try Restore Purchases."
                return false
            case .userCancelled, .pending:
                return false
            @unknown default:
                return false
            }
        } catch {
            purchaseError = error.localizedDescription
            return false
        }
    }

    func restore() async {
        try? await AppStore.sync()
        await refreshEntitlements()
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                    await self?.refreshEntitlements()
                }
            }
        }
    }
}
