import XCTest
@testable import SaleArmorTests

/// **The rule that decides whether a paying customer gets locked out.**
///
/// This existed only as a `guard` inside `Subscription` until 25 August 2026, where nothing could
/// reach it — and it was wrong: an empty restore overwrote a cache that said "paid", against the
/// promise written at the top of that same file. These tests exist so the next edit to that rule
/// has to be deliberate.
final class AccessRuleTests: XCTestCase {

    // MARK: an entitled answer is never ambiguous

    func testAnEntitledAnswerAlwaysWritesThroughWhereverItCameFrom() {
        for answer in [EntitlementAnswer.directRead, .restore] {
            XCTAssertTrue(AccessRule.writesThrough(isEntitled: true, from: answer),
                          "being told yes is never ambiguous, including by \(answer)")
        }
    }

    // MARK: an empty answer depends entirely on who said it

    func testADirectReadWithNoEntitlementLocks() {
        XCTAssertTrue(AccessRule.writesThrough(isEntitled: false, from: .directRead),
                      "customerInfo describes the account signed in now, so a real lapse must lock")
    }

    func testAnEmptyRestoreNeverLocks() {
        XCTAssertFalse(AccessRule.writesThrough(isEntitled: false, from: .restore),
                       "a restore may have run against a different Apple Account, which is not "
                       + "evidence about this install — this is the refund-and-one-star case")
    }

    // MARK: the rule stated as a whole, so a partial edit fails loudly

    func testOnlyADirectReadMayLock() {
        XCTAssertTrue(EntitlementAnswer.directRead.mayLock)
        XCTAssertFalse(EntitlementAnswer.restore.mayLock)
    }

    /// The one combination that costs money if it ever flips.
    func testTheCacheSurvivesExactlyOneCombination() {
        let combinations: [(Bool, EntitlementAnswer)] = [
            (true, .directRead), (true, .restore), (false, .directRead), (false, .restore),
        ]
        let survives = combinations.filter {
            !AccessRule.writesThrough(isEntitled: $0.0, from: $0.1)
        }
        XCTAssertEqual(survives.count, 1, "exactly one case may leave the cache alone")
        XCTAssertEqual(survives.first?.1, .restore)
        XCTAssertEqual(survives.first?.0, false)
    }
}
