import Foundation

/// **What the wishlist can honestly say about you.**
///
/// Every figure here comes from four dates on a `WishItem` — `addedAt`, `skippedAt`, `boughtAt`,
/// and the price — because that is all the app records. In `Shared/` with no UI and no
/// FamilyControls, for the reason `AccessRule` and `TrialOffer` are: the test target compiles
/// `SaleArmorTests + Shared`, so anything needing the host app cannot be pinned by a test.
///
/// **Three things this deliberately cannot show.**
///
/// *Times you were stopped.* There is no block counter and there cannot be one: `ManagedSettings`
/// raises a shield and iOS never reports back how often it was hit. The armed screen's "Apps shut"
/// is the number of apps *selected*, not blocks, and calling it anything else would be a lie the
/// data cannot support.
///
/// *Which guard was running when something was parked.* `WishItem` carries no guard reference.
///
/// *Whether you wanted it less.* Only that you did not buy it, and for how long.
struct Stats: Equatable {

    // MARK: money

    /// Everything turned down, at the price it was turned down at.
    let notSpent: Double
    /// **Everything bought anyway, shown rather than hidden.**
    ///
    /// The model's own comment says an app that punishes honesty gets lied to, "and then its total
    /// is fiction". The screen showing only `notSpent` was quietly making that total a half-truth,
    /// so this sits beside it, in the same size, with no red and no scolding.
    let spentAnyway: Double
    /// Still parked and undecided. Not a debt, just what is still open.
    let stillParked: Double

    // MARK: counts

    let skippedCount: Int
    let boughtCount: Int
    let openCount: Int

    var decidedCount: Int { skippedCount + boughtCount }

    /// Of everything decided, the share turned down. Nil until something has been decided, because
    /// "0%" on an empty wishlist reads as a verdict rather than an absence.
    var skipRate: Double? {
        decidedCount == 0 ? nil : Double(skippedCount) / Double(decidedCount)
    }

    // MARK: does waiting actually work

    /// The skip rate for things decided **on or after** the cooling-off day, and for things decided
    /// before it.
    ///
    /// **This is the only number in the app that tests its own central claim.** The product says
    /// parking a purchase for three days turns a want into a decision. These two rates are how a
    /// person finds out whether that is true for them, rather than being told that it is.
    ///
    /// Nil on either side when nothing has been decided in that bucket.
    let skipRateAfterCooling: Double?
    let skipRateBeforeCooling: Double?

    /// Median whole days from parking to deciding. Median rather than mean, because one item left
    /// open for a year would otherwise swallow the answer.
    let medianDaysToDecide: Int?

    /// The dearest single thing turned down.
    let biggestSkipped: WishItem?

    static let empty = Stats(notSpent: 0, spentAnyway: 0, stillParked: 0,
                            skippedCount: 0, boughtCount: 0, openCount: 0,
                            skipRateAfterCooling: nil, skipRateBeforeCooling: nil,
                            medianDaysToDecide: nil, biggestSkipped: nil)

    init(notSpent: Double, spentAnyway: Double, stillParked: Double,
         skippedCount: Int, boughtCount: Int, openCount: Int,
         skipRateAfterCooling: Double?, skipRateBeforeCooling: Double?,
         medianDaysToDecide: Int?, biggestSkipped: WishItem?) {
        self.notSpent = notSpent
        self.spentAnyway = spentAnyway
        self.stillParked = stillParked
        self.skippedCount = skippedCount
        self.boughtCount = boughtCount
        self.openCount = openCount
        self.skipRateAfterCooling = skipRateAfterCooling
        self.skipRateBeforeCooling = skipRateBeforeCooling
        self.medianDaysToDecide = medianDaysToDecide
        self.biggestSkipped = biggestSkipped
    }

    /// Everything above, in one pass over the items.
    init(_ items: [WishItem], calendar: Calendar = .current) {
        var notSpent = 0.0, spentAnyway = 0.0, stillParked = 0.0
        var skipped = 0, bought = 0, open = 0
        var afterSkip = 0, afterTotal = 0, beforeSkip = 0, beforeTotal = 0
        var waits: [Int] = []
        var dearest: WishItem?

        for item in items {
            // An item carrying both dates would be ambiguous; `skip` and `buy` each clear the
            // other, so skipped is checked first and the two branches stay exclusive.
            if let decided = item.skippedAt ?? item.boughtAt {
                let waited = max(0, calendar.dateComponents([.day], from: item.addedAt,
                                                            to: decided).day ?? 0)
                waits.append(waited)
                let cooled = waited >= WishItem.coolingOff
                if cooled { afterTotal += 1 } else { beforeTotal += 1 }

                if item.skippedAt != nil {
                    skipped += 1
                    notSpent += item.price
                    if cooled { afterSkip += 1 } else { beforeSkip += 1 }
                    if item.price > (dearest?.price ?? -1) { dearest = item }
                } else {
                    bought += 1
                    spentAnyway += item.price
                }
            } else {
                open += 1
                stillParked += item.price
            }
        }

        func rate(_ hits: Int, _ total: Int) -> Double? {
            total == 0 ? nil : Double(hits) / Double(total)
        }
        func median(_ xs: [Int]) -> Int? {
            guard !xs.isEmpty else { return nil }
            let s = xs.sorted()
            return s.count % 2 == 1 ? s[s.count / 2] : (s[s.count / 2 - 1] + s[s.count / 2]) / 2
        }

        self.init(notSpent: notSpent, spentAnyway: spentAnyway, stillParked: stillParked,
                  skippedCount: skipped, boughtCount: bought, openCount: open,
                  skipRateAfterCooling: rate(afterSkip, afterTotal),
                  skipRateBeforeCooling: rate(beforeSkip, beforeTotal),
                  medianDaysToDecide: median(waits), biggestSkipped: dearest)
    }

    /// **The one sentence the page is for**, or nil when there is not enough to say it honestly.
    ///
    /// Requires decisions on both sides of the cooling-off line, because the claim is comparative:
    /// with only one bucket filled there is nothing to compare and the sentence would be a
    /// coincidence dressed as evidence.
    func waitingVerdict() -> String? {
        guard let after = skipRateAfterCooling, let before = skipRateBeforeCooling,
              let a = percent(after), let b = percent(before) else { return nil }
        if after > before {
            return "When you waited \(WishItem.coolingOff) days you turned down \(a) of them. "
                 + "When you decided sooner, \(b)."
        }
        if after < before {
            return "Waiting has not changed your mind so far: \(a) turned down after "
                 + "\(WishItem.coolingOff) days, \(b) before."
        }
        return "Waiting has made no difference yet. \(a) either way."
    }

    private func percent(_ value: Double?) -> String? {
        guard let value else { return nil }
        return "\(Int((value * 100).rounded()))%"
    }

    /// Formatted shares, for the view.
    var skipRateText: String? { percent(skipRate) }
    var afterCoolingText: String? { percent(skipRateAfterCooling) }
    var beforeCoolingText: String? { percent(skipRateBeforeCooling) }
}
