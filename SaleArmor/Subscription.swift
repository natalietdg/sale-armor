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
    /// Roughly what has been paid so far, for the return figure. Nil until the price is known.
    @Published private(set) var paidSoFar: Double?
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
        isActive = (Demo.isOn && !Demo.showsPaywall)
            || Demo.isUnlocked
            || UserDefaults.standard.bool(forKey: Self.cacheKey)
        if Demo.showsPaywall { plans = Self.samplePlans }
    }

    /// The real configured prices, with no store behind them. Used only for the paywall
    /// screenshot; `package` is nil, so nothing here can be bought.
    private static let samplePlans = [
        Plan(id: "weekly", term: "Every week", price: "$3.99", unit: "$0.57 a day",
             badge: "POPULAR", renews: true, package: nil,
             productID: "", amount: nil, periodDays: 7),
        Plan(id: "monthly", term: "Every month", price: "$9.99", unit: "$2.31 a week",
             badge: nil, renews: true, package: nil,
             productID: "", amount: nil, periodDays: 30.44),
        Plan(id: "annual", term: "Every year", price: "$99.99", unit: "$8.33 a month",
             badge: "BEST VALUE", renews: true, package: nil,
             productID: "", amount: nil, periodDays: 365.25),
        Plan(id: "lifetime", term: "Once, forever", price: "$299.99", unit: "No renewal, ever",
             badge: nil, renews: false, package: nil,
             productID: "", amount: nil, periodDays: nil),
    ]

    /// Reads the API key from the Info.plist rather than hardcoding it, so the key can change
    /// without a code edit. A RevenueCat *public* SDK key is not a secret — it is designed to ship
    /// inside the app — but it does differ per project.
    private static var apiKey: String? {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "RevenueCatAPIKey") as? String,
              !key.isEmpty, !key.hasPrefix("$(") else { return nil }
        return key
    }

    func start() async {
        guard !Demo.isOn else { return }   // sample plans are already in place
        guard let apiKey = Self.apiKey else {
            problem = "The store isn't configured yet."
            return
        }
        if !Purchases.isConfigured {
#if DEBUG
            Purchases.logLevel = .verbose
#endif
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

    /// Loads the offering, and says what went wrong when it does not.
    ///
    /// The previous version replaced every failure with "check your connection", which is a guess —
    /// and usually the wrong one. A missing agreement, an unapproved product and a genuine network
    /// failure all arrived as the same sentence, so the one piece of information that would have
    /// identified the problem was discarded at the moment it was produced. Three separate outcomes
    /// are now distinguished, because they need three different actions from whoever reads them.
    private func loadOffering() async {
        guard Purchases.isConfigured else { return }
        do {
            let offerings = try await Purchases.shared.offerings()
            guard let current = offerings.current else {
                // Reached RevenueCat, but no offering is marked current for this app.
                problem = "No pricing is set up for this app yet."
                return
            }
            let packages = current.availablePackages
            guard !packages.isEmpty else {
                // The offering exists and StoreKit returned nothing for it. This is what an
                // unaccepted agreement or an unavailable product looks like — never a network fault.
                problem = "The store returned no products. They may still be waiting on Apple."
                return
            }
            let rank: [PackageType: Int] = [.weekly: 0, .monthly: 1, .annual: 2, .lifetime: 3]
            plans = packages
                .sorted { rank[$0.packageType, default: 9] < rank[$1.packageType, default: 9] }
                .map(Self.plan(from:))
            problem = nil
            // The paid estimate needs a price, which only exists once the offering has loaded.
            await refresh()
        } catch {
            problem = "Couldn't load the prices. \(error.localizedDescription)"
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

        func plan(_ id: String, _ term: String, _ unit: String,
                  badge: String? = nil, renews: Bool = true, periodDays: Double?) -> Plan {
            Plan(id: id, term: term, price: product.localizedPriceString, unit: unit,
                 badge: badge, renews: renews, package: package,
                 productID: product.productIdentifier, amount: price.doubleValue,
                 periodDays: periodDays)
        }

        switch package.packageType {
        case .weekly:
            return plan("weekly", "Every week", "\(formatted(price.doubleValue / 7)) a day",
                        badge: "POPULAR", periodDays: 7)
        case .monthly:
            return plan("monthly", "Every month", "\(formatted(price.doubleValue / 4.33)) a week",
                        periodDays: 30.44)
        case .annual:
            return plan("annual", "Every year", "\(formatted(price.doubleValue / 12)) a month",
                        badge: "BEST VALUE", periodDays: 365.25)
        case .lifetime:
            return plan("lifetime", "Once, forever", "No renewal, ever",
                        renews: false, periodDays: nil)
        default:
            return plan(package.identifier, product.localizedTitle, "", periodDays: nil)
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
        let entitlement = info.entitlements[Self.entitlement]
        isActive = entitlement?.isActive == true
        UserDefaults.standard.set(isActive, forKey: Self.cacheKey)
        paidSoFar = paid(for: entitlement)
        problem = nil
    }

    /// Roughly what this person has paid Sale Armor, for the return figure on the armed screen.
    ///
    /// Elapsed periods since the original purchase, times the price of the plan they are on. It is
    /// an estimate and is treated as one: a lapse and resubscribe, or a plan switch, makes it read
    /// high. That is the safe direction to be wrong in — **the return comes out understated, never
    /// inflated** — and a number that flattered the app would be worth nothing to the person
    /// reading it.
    ///
    /// Returns nil when the price is not known yet, and the panel simply does not appear.
    private func paid(for entitlement: EntitlementInfo?) -> Double? {
        guard let entitlement, entitlement.isActive,
              let plan = plans.first(where: { $0.productID == entitlement.productIdentifier }),
              let price = plan.amount else { return nil }
        guard let start = entitlement.originalPurchaseDate else { return price }

        guard let periodDays = plan.periodDays else { return price }   // lifetime: paid once
        let days = Calendar.current.dateComponents([.day], from: start, to: Date()).day ?? 0
        let periods = floor(Double(days) / periodDays) + 1             // first period paid up front
        return periods * price
    }
}
