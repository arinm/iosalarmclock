import Foundation
import StoreKit
import OSLog

/// Purchase-flow diagnostics — view in Console.app (subsystem "com.punctual.app",
/// category "Store"). TestFlight/sandbox purchase issues are invisible without this.
private let storeLog = Logger(subsystem: "com.punctual.app", category: "Store")

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
    /// True once a product load has completed (success OR empty). Lets the
    /// paywall tell "still loading" apart from "loaded but App Store returned
    /// nothing" (agreement not active / IAPs not ready) instead of showing
    /// silent "—" prices.
    private(set) var productsLoaded = false
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
        productsLoaded = true
    }

    var monthly: Product? { products[Self.monthlyID] }
    var yearly: Product? { products[Self.yearlyID] }
    var lifetime: Product? { products[Self.lifetimeID] }

    func displayPrice(_ id: String) -> String { products[id]?.displayPrice ?? "-" }

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
        // Merge in a fresh direct grant (see `directGrantAt`) — the stream can
        // lag a just-finished purchase; never let a stale read downgrade it.
        if let at = directGrantAt, Date.now.timeIntervalSince(at) < directGrantGrace {
            pro = pro || grantedPro
            sub = sub || grantedSub
        }
        isPro = pro
        isSubscriber = sub
        resolved = true
    }

    /// Grant entitlement from a single verified, in-hand transaction. Used on the
    /// purchase path and the updates stream: right after a purchase,
    /// `Transaction.currentEntitlements` can LAG (notoriously in TestFlight /
    /// sandbox), so re-deriving from it made a successful purchase look like a
    /// silent failure — spinner, then nothing, still Free. The transaction we
    /// were just handed IS the entitlement; apply it directly.
    /// A direct grant's timestamp. `refreshEntitlements` derives from
    /// `Transaction.currentEntitlements`, which can LAG a just-finished
    /// transaction — a refresh running inside this window (e.g. the user taps
    /// "Restore Purchases" right after buying, or a queued transaction applies
    /// at launch before start()) must not OVERWRITE the fresh grant, or a paying
    /// user gets downgraded + theme-reset mid-session. Grants are merged
    /// monotonically within the window; refunds/expiry still win at any later
    /// refresh and at every launch.
    private var directGrantAt: Date?
    private var grantedPro = false
    private var grantedSub = false
    private let directGrantGrace: TimeInterval = 300

    private func apply(_ t: Transaction) {
        #if DEBUG
        // Screenshot mode stays Free (mirrors refreshEntitlements' guard).
        if ProcessInfo.processInfo.arguments.contains("--demo-free") { return }
        #endif
        guard t.revocationDate == nil else { return }
        if let exp = t.expirationDate, exp <= .now { return } // stale/expired renewal
        if t.productID == Self.lifetimeID { isPro = true }
        if Self.subscriptionIDs.contains(t.productID) { isPro = true; isSubscriber = true }
        grantedPro = isPro
        grantedSub = isSubscriber
        directGrantAt = .now
        purchaseError = nil // a grant supersedes any earlier failure/pending note
        resolved = true
        storeLog.notice("Entitlement applied from transaction: \(t.productID, privacy: .public)")
    }

    @discardableResult
    func purchase(_ id: String) async -> Bool {
        guard let product = products[id] else {
            storeLog.error("purchase(\(id, privacy: .public)): product not loaded")
            return false
        }
        purchaseError = nil // fresh attempt: clear any stale failure/pending note
        do {
            storeLog.notice("purchase(\(id, privacy: .public)): starting")
            switch try await product.purchase() {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    apply(transaction) // direct grant — don't wait on currentEntitlements
                    return isPro
                }
                storeLog.error("purchase(\(id, privacy: .public)): UNVERIFIED result")
                purchaseError = "Purchase couldn't be verified. Please try Restore Purchases."
                return false
            case .userCancelled:
                storeLog.notice("purchase(\(id, privacy: .public)): user cancelled")
                return false
            case .pending:
                // Ask to Buy / deferred — not a failure, but not Pro yet either.
                // Say so instead of leaving the user in silent limbo.
                storeLog.notice("purchase(\(id, privacy: .public)): pending (Ask to Buy)")
                purchaseError = "Purchase is pending approval. Pro unlocks automatically once it's approved."
                return false
            @unknown default:
                storeLog.error("purchase(\(id, privacy: .public)): unknown result case")
                return false
            }
        } catch {
            storeLog.error("purchase(\(id, privacy: .public)) threw: \(error.localizedDescription, privacy: .public)")
            purchaseError = error.localizedDescription
            return false
        }
    }

    /// Returns whether the App Store sync actually ran — a cancelled sign-in or
    /// network failure must NOT be reported as "no purchases found" (the
    /// definitive wrong answer for a paying user on a new device).
    @discardableResult
    func restore() async -> Bool {
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            return true
        } catch {
            storeLog.error("restore: AppStore.sync failed: \(error.localizedDescription, privacy: .public)")
            await refreshEntitlements() // still read whatever is locally known
            return false
        }
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                    if transaction.revocationDate == nil {
                        // Grant directly (same lag rationale as in purchase()).
                        self?.apply(transaction)
                    } else {
                        // Refund/revocation — re-derive the full truth.
                        await self?.refreshEntitlements()
                    }
                }
            }
        }
    }
}
