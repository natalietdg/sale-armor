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
    @Published private(set) var offering: Offering?
    @Published private(set) var isWorking = false
    @Published var problem: String?

    /// The entitlement configured in RevenueCat. One entitlement, because there is one thing to
    /// buy — every product grants the same access, they only differ in how long it lasts.
    private static let entitlement = "pro"

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
            offering = try await Purchases.shared.offerings().current
        } catch {
            problem = "Couldn't load the prices. Check your connection."
        }
    }

    // MARK: buying

    func buy(_ package: Package) async {
        guard Purchases.isConfigured else { return }
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
