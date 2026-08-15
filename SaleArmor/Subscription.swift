import Foundation
import RevenueCat

/// Whether the app is unlocked, and the only place that decides it.
///
/// Sale Armor is **entirely** behind the paywall: there is no free tier and no limited mode. The
/// gate sits above everything else in `ContentView`, before the Screen Time prompt, so a person
/// who has not subscribed never reaches the picker at all.
///
/// The one thing this must never do is lock out a paying customer. Every failure path below —
/// no network, RevenueCat unreachable, a key that will not configure — leaves `isActive` alone
/// rather than setting it false, because a wrongly-locked subscriber is a refund and a one-star
/// review, while a wrongly-unlocked non-subscriber is a few days of free use.
@MainActor
final class Subscription: ObservableObject {
    /// Unlocked. Starts from the cached value so a returning subscriber is not made to wait for
    /// the network on every cold launch.
    @Published private(set) var isActive: Bool
    /// Ordered cheapest first and already formatted. The order is enforced here rather than
    /// inherited from the offering, because position on the paywall is doing real work.
    @Published private(set) var plans: [Plan] = []
    @Published private(set) var isWorking = false
    @Published var problem: String?

    /// The entitlement configured in RevenueCat, matched by its **lookup key** — not its display
    /// name, though here they happen to be the same string. One entitlement, because there is one
    /// thing to buy: every product grants the same access and they differ only in how long it lasts.
    ///
    /// A typo here does not fail loudly. It reads as "this customer has not paid", so a real
    /// purchase would go through and the paywall would still be there afterwards.
    private static let entitlement = "Sale Armor Pro"

    /// Cached across launches so the app opens unlocked instead of flashing the paywall while
    /// RevenueCat is asked. `UserDefaults` is the right store here: losing it costs one refresh,
    /// and treating it as the source of truth is exactly what a receipt check is for.
    private static let cacheKey = "subscription.isActive"

    init() {
        isActive = Demo.isOn || UserDefaults.standard.bool(forKey: Self.cacheKey)
    }

    /// Reads the API key from the Info.plist rather than hardcoding it, so the key can change
    /// without a code edit. A RevenueCat *public* SDK key is not a secret — it is designed to ship
    /// inside the app — but it does differ per project.
    private static var apiKey: String? {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "RevenueCatAPIKey") as? String,
              !key.isEmpty, !key.hasPrefix("$(") else { return nil }
        return key
    }

    func start() async {
        guard !Demo.isOn else { return }
        guard let apiKey = Self.apiKey else {
            problem = "The store isn't configured yet."
            return
        }
        if !Purchases.isConfigured {
            Purchases.configure(withAPIKey: apiKey)
        }
        await refresh()
        await loadOffering()
    }

    /// Asks RevenueCat what this customer owns. A thrown error means *unknown*, not *unsubscribed*.
    func refresh() async {
        guard Purchases.isConfigured else { return }
        do {
            apply(try await Purchases.shared.customerInfo())
        } catch {
            // Deliberately silent: an offline launch must not lock a subscriber out.
        }
    }

    private func loadOffering() async {
        guard Purchases.isConfigured else { return }
        do {
            let packages = try await Purchases.shared.offerings().current?.availablePackages ?? []
            let rank: [PackageType: Int] = [.weekly: 0, .monthly: 1, .annual: 2, .lifetime: 3]
            plans = packages
                .sorted { rank[$0.packageType, default: 9] < rank[$1.packageType, default: 9] }
                .map(Self.plan(from:))
        } catch {
            problem = "Couldn't load the prices. Check your connection."
        }
    }

    /// Turns a package into the four strings the paywall draws.
    ///
    /// The per-unit line is the honest version of a price comparison: the same money at a scale a
    /// person can picture, computed from the real price rather than written into the copy, so it
    /// cannot drift out of step with the store or be wrong in another currency.
    private static func plan(from package: Package) -> Plan {
        let product = package.storeProduct
        let price = product.price as NSDecimalNumber

        func formatted(_ amount: Double) -> String {
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencyCode = product.currencyCode ?? "USD"
            return formatter.string(from: NSNumber(value: amount)) ?? ""
        }

        switch package.packageType {
        case .weekly:
            return Plan(id: "weekly", term: "Every week", price: product.localizedPriceString,
                        unit: "\(formatted(price.doubleValue / 7)) a day",
                        badge: "POPULAR", renews: true, package: package)
        case .monthly:
            return Plan(id: "monthly", term: "Every month", price: product.localizedPriceString,
                        unit: "\(formatted(price.doubleValue / 4.33)) a week",
                        badge: nil, renews: true, package: package)
        case .annual:
            return Plan(id: "annual", term: "Every year", price: product.localizedPriceString,
                        unit: "\(formatted(price.doubleValue / 12)) a month",
                        badge: "BEST VALUE", renews: true, package: package)
        case .lifetime:
            return Plan(id: "lifetime", term: "Once, forever", price: product.localizedPriceString,
                        unit: "No renewal, ever",
                        badge: nil, renews: false, package: package)
        default:
            return Plan(id: package.identifier, term: product.localizedTitle,
                        price: product.localizedPriceString, unit: "",
                        badge: nil, renews: true, package: package)
        }
    }

    // MARK: buying

    func buy(_ plan: Plan) async {
        guard let package = plan.package, Purchases.isConfigured else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            let result = try await Purchases.shared.purchase(package: package)
            guard !result.userCancelled else { return }
            apply(result.customerInfo)
        } catch {
            problem = error.localizedDescription
        }
    }

    /// Required by App Review, and by anyone who changes phone. Without a visible restore control
    /// a subscription app is rejected under guideline 3.1.1.
    func restore() async {
        guard Purchases.isConfigured else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            apply(try await Purchases.shared.restorePurchases())
            if !isActive { problem = "No subscription found for this Apple Account." }
        } catch {
            problem = error.localizedDescription
        }
    }

    private func apply(_ info: CustomerInfo) {
        isActive = info.entitlements[Self.entitlement]?.isActive == true
        UserDefaults.standard.set(isActive, forKey: Self.cacheKey)
        problem = nil
    }
}
