import XCTest
@testable import SaleArmorTests

/// **Does tapping a preset arm the schedule the preset promises?**
///
/// For five presets across builds 20 and 21 the answer was no. `"Now"` was inserted at the front of
/// the "When" segments and only the reader was renumbered, so every preset wrote the index of the
/// shape below the one it meant — "Late night" armed a stale one-off range, "Retail therapy" ran
/// every day rather than at weekends, "Black Friday" discarded its own dates. Silently, because the
/// reader's `default:` arm turned every mismatch into `.daily`.
///
/// The round trip below is the whole check: fill the form in from a preset, read the pattern back
/// out, and require it to be the one the preset defines. It fails for all five on the old code.
final class SchedulePlanTests: XCTestCase {

    /// Fixed so `.blackFriday` resolves to the same dates on both sides of the round trip.
    private let now = Date(timeIntervalSince1970: 1_756_000_000)   // 2025-08-24

    func testEveryPresetArmsThePatternItPromises() {
        for sale in SaleKind.allCases {
            var plan = SchedulePlan()
            plan.apply(sale, now: now)
            XCTAssertEqual(plan.pattern(now: now), sale.pattern(now: now),
                           "\(sale.rawValue) armed the wrong schedule")
        }
    }

    /// The shape drives which controls the form shows, so a preset landing on the right pattern by
    /// accident while showing the wrong editor would still be a bug.
    func testEveryPresetSelectsTheMatchingSegment() {
        let expected: [SaleKind: SchedulePlan.Shape] = [
            .lateNight: .daily,
            .payday: .monthly,
            .blackFriday: .once,
            .doubleDate: .doubleDates,
            .retailTherapy: .weekly,
        ]
        for sale in SaleKind.allCases {
            var plan = SchedulePlan()
            plan.apply(sale, now: now)
            XCTAssertEqual(plan.shape, expected[sale], "\(sale.rawValue) selected the wrong segment")
        }
    }

    /// Applying a preset must not leave another shape's stale state behind where the pattern can
    /// pick it up. Black Friday is the one that matters: it carries dates, and it used to write them
    /// into a slot the reader never looked at.
    func testApplyingAPresetOverwritesTheShapeBefore() {
        var plan = SchedulePlan()
        plan.apply(.lateNight, now: now)
        plan.apply(.blackFriday, now: now)
        XCTAssertEqual(plan.pattern(now: now), SaleKind.blackFriday.pattern(now: now))
    }

    /// Every segment is drawn from `allCases`, so a shape with no title would ship as a blank tab.
    func testEverySegmentHasATitle() {
        for shape in SchedulePlan.Shape.allCases {
            XCTAssertFalse(shape.title.isEmpty, "segment \(shape) has no title")
        }
    }
}
