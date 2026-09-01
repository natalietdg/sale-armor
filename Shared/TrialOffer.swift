import Foundation

/// **A free trial, reduced to the only thing the paywall has to get right: how long it lasts.**
///
/// Lives in `Shared/` and knows nothing about RevenueCat or StoreKit, for the same reason
/// `AccessRule` and `SchedulePlan` do: the test target compiles `SaleArmorTests + Shared` only, so
/// anything that needs a host app cannot be pinned by a test. `Subscription` maps the SDK's
/// `StoreProductDiscount` onto this and everything downstream reads this.
///
/// **The length is computed once and read everywhere.** The plan row, the button and the renewal
/// sentence are three places that would otherwise each do their own arithmetic, and Apple rejects a
/// purchase screen whose stated terms disagree with the offer.
struct TrialOffer: Equatable {

    /// Mirrors `SubscriptionPeriod.Unit` without importing it.
    enum Unit: Equatable { case day, week, month, year }

    /// The period's own length. A one-week trial is `value 1, unit .week`.
    let value: Int
    let unit: Unit
    /// How many of those periods the offer runs for. Almost always 1.
    let periods: Int

    init(value: Int, unit: Unit, periods: Int = 1) {
        self.value = value
        self.unit = unit
        self.periods = periods
    }

    /// "7 days", "1 month", "14 days".
    ///
    /// **Weeks are spoken as days on purpose.** Apple returns a one-week trial as `1 week`, and
    /// "1 week free" reads as vaguer than the same offer written "7 days free" — a parent deciding
    /// on a paywall is counting days, not weeks. Months and years are left alone, because "30 days"
    /// is a claim about a length the store does not actually promise.
    var length: String {
        let total = value * max(periods, 1)
        switch unit {
        case .day:   return count(total, "day")
        case .week:  return count(total * 7, "day")
        case .month: return count(total, "month")
        case .year:  return count(total, "year")
        }
    }

    /// "7 days free" — the phrase the plan row and the button both use.
    var phrase: String { "\(length) free" }

    private func count(_ n: Int, _ noun: String) -> String {
        "\(n) \(noun)\(n == 1 ? "" : "s")"
    }

    /// **The sentence Apple requires on the purchase screen**: what is free, for how long, what is
    /// charged afterwards, and that it renews until cancelled.
    ///
    /// Takes the price already localised by the store rather than a number, so the currency is the
    /// customer's and this cannot drift from the figure printed beside it.
    static func terms(trial: TrialOffer?, price: String, term: String, renews: Bool) -> String {
        guard renews else { return "One payment. Nothing renews, nothing to cancel." }
        let tail = "Renews automatically until cancelled. Cancel any time in Settings."
        guard let trial else { return tail }
        return "Free for \(trial.length), then \(price) \(term.lowercased()). \(tail)"
    }
}
