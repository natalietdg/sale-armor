import XCTest
@testable import SaleArmorTests

/// **The numbers on the stats page, and the two ways they could lie.**
///
/// The first is arithmetic: a total that quietly counts open items, or double-counts an item
/// carrying both dates. The second is worse and is the reason `waitingVerdict` has a guard on it —
/// a comparative claim made from one bucket is a coincidence presented as evidence, and this page
/// exists to tell somebody whether the product's central promise is true *for them*.
final class StatsTests: XCTestCase {

    /// `added` is how many days ago it was parked; `skipped`/`bought` is **how many days they
    /// waited before deciding**, not the day they decided on. Naming it `waited` in the callers
    /// below, because reading it the other way is exactly the mistake these tests were written with.
    private func item(_ price: Double, added: Int, skipped: Int? = nil, bought: Int? = nil,
                      name: String = "Thing") -> WishItem {
        let day = 86_400.0
        let now = Date()
        var w = WishItem(name: name, link: nil, price: price,
                         addedAt: now.addingTimeInterval(-Double(added) * day))
        if let skipped { w.skippedAt = now.addingTimeInterval(-Double(added - skipped) * day) }
        if let bought { w.boughtAt = now.addingTimeInterval(-Double(added - bought) * day) }
        return w
    }

    // MARK: money

    func testNotSpentCountsOnlySkippedItems() {
        let s = Stats([item(100, added: 5, skipped: 4),
                       item(50, added: 5, bought: 4),
                       item(30, added: 1)])
        XCTAssertEqual(s.notSpent, 100)
        XCTAssertEqual(s.spentAnyway, 50, "bought is shown, not hidden — otherwise the total is fiction")
        XCTAssertEqual(s.stillParked, 30, "open items are neither saved nor spent")
    }

    func testAnEmptyWishlistSaysNothingRatherThanZeroPercent() {
        let s = Stats([])
        XCTAssertEqual(s, Stats.empty)
        XCTAssertNil(s.skipRate, "0% on an empty list reads as a verdict, not an absence")
        XCTAssertNil(s.waitingVerdict())
    }

    func testOpenItemsAreNotCountedAsDecisions() {
        let s = Stats([item(20, added: 1), item(20, added: 2)])
        XCTAssertEqual(s.openCount, 2)
        XCTAssertEqual(s.decidedCount, 0)
        XCTAssertNil(s.skipRate)
    }

    // MARK: rates

    func testSkipRateIsOverDecisionsNotOverEverything() {
        let s = Stats([item(10, added: 5, skipped: 4),
                       item(10, added: 5, skipped: 4),
                       item(10, added: 5, skipped: 4),
                       item(10, added: 5, bought: 4),
                       item(10, added: 1)])           // still open, must not dilute the rate
        XCTAssertEqual(s.skipRate!, 0.75, accuracy: 0.001)
        XCTAssertEqual(s.skipRateText, "75%")
    }

    // MARK: the claim the product makes about itself

    func testWaitingIsMeasuredAcrossTheCoolingOffLine() {
        let s = Stats([item(10, added: 10, skipped: 4),   // waited 4 -> after, skipped
                       item(10, added: 10, skipped: 4),   // waited 4 -> after, skipped
                       item(10, added: 10, bought: 4),    // waited 4 -> after, bought
                       item(10, added: 10, skipped: 1),   // waited 1 -> before, skipped
                       item(10, added: 10, bought: 1),    // waited 1 -> before, bought
                       item(10, added: 10, bought: 1)])   // waited 1 -> before, bought
        XCTAssertEqual(s.skipRateAfterCooling!, 2.0 / 3.0, accuracy: 0.001)
        XCTAssertEqual(s.skipRateBeforeCooling!, 1.0 / 3.0, accuracy: 0.001)
        let verdict = s.waitingVerdict()
        XCTAssertNotNil(verdict)
        XCTAssertTrue(verdict!.contains("67%") && verdict!.contains("33%"), verdict!)
    }

    func testTheVerdictIsWithheldWithOnlyOneBucketFilled() {
        let s = Stats([item(10, added: 10, skipped: 6), item(10, added: 10, skipped: 5)])
        // both waited well past the line, so the "before" bucket stays empty
        XCTAssertNotNil(s.skipRateAfterCooling)
        XCTAssertNil(s.skipRateBeforeCooling)
        XCTAssertNil(s.waitingVerdict(),
                     "a comparative claim from one bucket is a coincidence dressed as evidence")
    }

    func testTheVerdictIsHonestWhenWaitingHasNotHelped() {
        let s = Stats([item(10, added: 10, bought: 4),    // waited 4 -> after, bought
                       item(10, added: 10, skipped: 1)])  // waited 1 -> before, skipped
        let verdict = s.waitingVerdict()
        XCTAssertNotNil(verdict)
        XCTAssertTrue(verdict!.lowercased().contains("not changed your mind"), verdict!)
    }

    func testAnItemDecidedTheSameDayCountsAsBeforeCooling() {
        let s = Stats([item(10, added: 0, skipped: 0)])
        XCTAssertNil(s.skipRateAfterCooling)
        XCTAssertEqual(s.skipRateBeforeCooling!, 1.0, accuracy: 0.001)
    }

    func testDecidingExactlyOnTheCoolingOffDayCountsAsAfter() {
        // coolingOff is 3, so a wait of exactly 3 belongs to the "waited" side.
        let s = Stats([item(10, added: 10, skipped: 3)])
        XCTAssertEqual(s.skipRateAfterCooling!, 1.0, accuracy: 0.001)
        XCTAssertNil(s.skipRateBeforeCooling)
    }

    // MARK: the rest

    func testMedianIgnoresOneAbandonedItem() {
        let s = Stats([item(10, added: 100, skipped: 100),  // waited 100
                       item(10, added: 5, skipped: 2),      // waited 2
                       item(10, added: 5, skipped: 2)])     // waited 2
        XCTAssertEqual(s.medianDaysToDecide, 2, "a mean would report 34")
    }

    func testBiggestSkippedIgnoresThingsThatWereBought() {
        let s = Stats([item(80, added: 5, skipped: 4, name: "Coat"),
                       item(900, added: 5, bought: 4, name: "Laptop")])
        XCTAssertEqual(s.biggestSkipped?.name, "Coat")
    }

    func testBiggestSkippedIsNilWithNothingSkipped() {
        XCTAssertNil(Stats([item(900, added: 5, bought: 4)]).biggestSkipped)
    }
}
