import SwiftUI

/// Value-ladder paywall: free core forever, three ways to go Pro (monthly /
/// yearly / lifetime), with subscriber-only ongoing perks called out. Soft and
/// honest — the free hero loop is never blocked.
struct PaywallView: View {
    @Environment(StoreManager.self) private var storeKit
    @Environment(\.dismiss) private var dismiss
    @State private var working: String?   // product id being purchased

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    header

                    if storeKit.isPro {
                        ownedBadge
                    } else {
                        tiers
                    }

                    // Right under the buy buttons — after a failed/pending purchase
                    // this must be visible without scrolling.
                    if let error = storeKit.purchaseError {
                        Text(error).font(.footnote).foregroundStyle(.red).multilineTextAlignment(.center)
                    }

                    featureList
                    comingSoon

                    Text("The core alarm — countdown, pre-alert and Skip today — is free forever. No ads.")
                        .font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)

                    legalFooter
                }
                .padding()
            }
            .punctualBackground()
            .navigationTitle("Upgrade")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            BrandMark(size: 56)
                .padding(22)
                .background(
                    LinearGradient(colors: [Theme.accent.opacity(0.22), Theme.accent.opacity(0.06)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                )
            Text("Punctual Pro").font(.largeTitle.weight(.bold))
            Text("Make it yours. Pay how you like.")
                .foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
    }

    private var ownedBadge: some View {
        Label(storeKit.isSubscriber ? "You're a Pro subscriber — thank you!" : "You have Pro Lifetime — thank you!",
              systemImage: "checkmark.seal.fill")
            .font(.headline).foregroundStyle(Theme.accent)
            .padding().frame(maxWidth: .infinity).punctualCard()
    }

    private var tiers: some View {
        VStack(spacing: 12) {
            tierButton(id: StoreManager.yearlyID, title: "Yearly",
                       caption: "Billed annually · cancel anytime",
                       highlighted: true, badge: storeKit.yearlySavingsText ?? "Best value")
            tierButton(id: StoreManager.monthlyID, title: "Monthly",
                       caption: "Lowest entry · cancel anytime", highlighted: false, badge: nil)
            tierButton(id: StoreManager.lifetimeID, title: "Lifetime",
                       caption: "Pay once · features forever", highlighted: false, badge: nil)

            // App Store returned no products (agreement not active, IAPs not
            // ready, or offline) — say so and let the user retry instead of
            // leaving three dead "—" rows.
            if storeKit.productsLoaded && storeKit.products.isEmpty {
                VStack(spacing: 6) {
                    Text("Prices couldn't load right now.")
                        .font(.footnote.weight(.medium))
                    Text("Check your connection and try again.")
                        .font(.caption2).foregroundStyle(.secondary)
                    Button("Retry") { Task { await storeKit.loadProducts() } }
                        .font(.subheadline.weight(.semibold)).padding(.top, 2)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 4)
            }
        }
    }

    private func tierButton(id: String, title: String, caption: String, highlighted: Bool, badge: String?) -> some View {
        Button {
            Task {
                working = id
                if await storeKit.purchase(id) { dismiss() }
                working = nil
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(title).font(.headline)
                        if let badge {
                            Text(badge.uppercased())
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 7).padding(.vertical, 3)
                                .background(Theme.accent, in: Capsule())
                                .foregroundStyle(.white)
                        }
                    }
                    Text(caption).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if working == id {
                    ProgressView()
                } else {
                    Text(storeKit.displayPrice(id)).font(.title3.weight(.bold))
                        .foregroundStyle(highlighted ? Theme.accent : .primary)
                }
            }
            .padding(.vertical, 16).padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: Theme.radiusInner, style: .continuous)
                    .fill(highlighted ? Theme.accent.opacity(0.18) : Color.secondary.opacity(0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusInner, style: .continuous)
                    .strokeBorder(highlighted ? Theme.accent.opacity(0.6) : .clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .disabled(working != nil || storeKit.products[id] == nil)
    }

    /// Restore + required legal links (App Review expects these on a paywall).
    private var legalFooter: some View {
        VStack(spacing: 8) {
            Button("Restore Purchases") { Task { await storeKit.restore() } }
                .font(.subheadline)
            HStack(spacing: 16) {
                Link("Terms", destination: URL(string: "https://arinm.github.io/iosalarmclock/terms.html")!)
                Link("Privacy", destination: URL(string: "https://arinm.github.io/iosalarmclock/privacy.html")!)
            }
            .font(.caption2).foregroundStyle(.secondary)
        }
        .padding(.top, 4)
    }

    /// ONLY features that work today — two-line rows (title + benefit). This is
    /// the visually dominant block: it sells what the purchase delivers now.
    private var featureList: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Unlock in Pro").font(.headline)
            ForEach(ProFeatureManager.Feature.live, id: \.self) { f in
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill").foregroundStyle(Theme.accent)
                        .frame(width: 22)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(f.title).font(.subheadline.weight(.medium))
                        Text(f.benefit).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding().punctualCard()
    }

    /// ONE compact, de-emphasized roadmap disclosure — live value leads, "coming
    /// soon" is collapsed so it doesn't dominate the paywall.
    private var comingSoon: some View {
        let planned = ProFeatureManager.Feature.planned.map(\.title)
            + ProFeatureManager.SubscriberPerk.allCases.map(\.title)
        return DisclosureGroup {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(planned, id: \.self) { title in
                    Label(title, systemImage: "circle.dashed")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Text("Not available yet. Pro owners get these free as they ship; subscriber perks are for monthly & yearly plans.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            .padding(.top, 6)
        } label: {
            Label("Coming soon (\(planned.count))", systemImage: "hammer")
                .font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
        }
        .tint(.secondary)
        .padding().punctualCard()
    }
}
