import XCTest
import FamilyControls
@testable import SaleArmorTests

/// **When the shield is up.**
///
/// This is the riskiest logic in the app and the hardest to see by hand: windows that cross
/// midnight, and deciding which weekday a 21:00→02:00 window belongs to. Getting it wrong means
/// either apps that never lock, or apps still locked the morning after — and a user cannot quickly
/// undo the second one.
final class ScheduleTests: XCTestCase {

    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    /// 2026-08-14 is a Friday, so weekday 6.
    private func at(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 8, day: day,
                                           hour: hour, minute: minute))!
    }

    private func window(_ pattern: ArmorPattern) -> ArmorWindow {
        ArmorWindow(name: "test", pattern: pattern, selection: FamilyActivitySelection())
    }

    func testFridayIsWeekdaySix() {
        XCTAssertEqual(calendar.component(.weekday, from: at(14, 12)), 6,
                       "the fixtures below assume 14 Aug 2026 is a Friday")
    }

    // MARK: once

    func testDateRangeCoversOnlyItsOwnDays() {
        let w = window(.dateRange(start: at(11, 0), end: at(15, 0)))
        XCTAssertFalse(w.covers(at(10, 23), calendar: calendar), "the day before")
        XCTAssertTrue(w.covers(at(11, 0), calendar: calendar), "the first instant is inside")
        XCTAssertTrue(w.covers(at(13, 12), calendar: calendar))
        XCTAssertFalse(w.covers(at(15, 0), calendar: calendar), "the end is exclusive")
    }

    // MARK: every day

    func testDailyWindowInsideOneDay() {
        let w = window(.daily(from: Clock(hour: 9, minute: 0), to: Clock(hour: 17, minute: 0)))
        XCTAssertFalse(w.covers(at(14, 8, 59), calendar: calendar))
        XCTAssertTrue(w.covers(at(14, 9, 0), calendar: calendar))
        XCTAssertTrue(w.covers(at(14, 16, 59), calendar: calendar))
        XCTAssertFalse(w.covers(at(14, 17, 0), calendar: calendar), "the end is exclusive")
    }

    /// **The late-night case, which is the whole reason this app exists.**
    func testDailyWindowThatCrossesMidnight() {
        let w = window(.daily(from: Clock(hour: 21, minute: 0), to: Clock(hour: 2, minute: 0)))
        XCTAssertFalse(w.covers(at(14, 20, 59), calendar: calendar))
        XCTAssertTrue(w.covers(at(14, 21, 0), calendar: calendar), "9pm, the evening it starts")
        XCTAssertTrue(w.covers(at(14, 23, 30), calendar: calendar))
        XCTAssertTrue(w.covers(at(15, 1, 0), calendar: calendar), "1am, still the same window")
        XCTAssertFalse(w.covers(at(15, 2, 0), calendar: calendar), "2am, it's over")
        XCTAssertFalse(w.covers(at(15, 12, 0), calendar: calendar), "the middle of the next day")
    }

    // MARK: some days

    func testWeeklyOnlyCoversChosenDays() {
        let w = window(.weekly(weekdays: [6], from: Clock(hour: 9, minute: 0),
                               to: Clock(hour: 17, minute: 0)))
        XCTAssertTrue(w.covers(at(14, 12), calendar: calendar), "Friday noon")
        XCTAssertFalse(w.covers(at(15, 12), calendar: calendar), "Saturday noon")
        XCTAssertFalse(w.covers(at(13, 12), calendar: calendar), "Thursday noon")
    }

    /// **A Friday-night window is still Friday's at 1am on Saturday.**
    ///
    /// Without this, selecting Friday would shut apps on Saturday morning and leave Friday's small
    /// hours open — the exact opposite of what was asked for.
    func testAWeeklyNightWindowBelongsToTheDayItStartedOn() {
        let w = window(.weekly(weekdays: [6], from: Clock(hour: 21, minute: 0),
                               to: Clock(hour: 2, minute: 0)))
        XCTAssertTrue(w.covers(at(14, 22), calendar: calendar), "Friday 10pm")
        XCTAssertTrue(w.covers(at(15, 1), calendar: calendar), "Saturday 1am is still Friday's window")
        XCTAssertFalse(w.covers(at(15, 22), calendar: calendar),
                       "Saturday 10pm must NOT be covered — Saturday was not chosen")
        XCTAssertFalse(w.covers(at(16, 1), calendar: calendar),
                       "Sunday 1am belongs to Saturday, which was not chosen")
    }

    /// Sunday is weekday 1, so "yesterday" has to wrap to 7 rather than going to 0.
    func testTheWeekWrapsFromSundayBackToSaturday() {
        let w = window(.weekly(weekdays: [7], from: Clock(hour: 21, minute: 0),
                               to: Clock(hour: 2, minute: 0)))
        XCTAssertTrue(w.covers(at(15, 23), calendar: calendar), "Saturday 11pm")
        XCTAssertTrue(w.covers(at(16, 1), calendar: calendar), "Sunday 1am is still Saturday's window")
    }

    // MARK: days of the month

    func testMonthlyCoversTheWholeChosenDay() {
        let w = window(.monthly(days: [25, 1]))
        XCTAssertTrue(w.covers(at(25, 0), calendar: calendar), "midnight on the 25th")
        XCTAssertTrue(w.covers(at(25, 23, 59), calendar: calendar), "just before the 26th")
        XCTAssertFalse(w.covers(at(24, 23), calendar: calendar))
        XCTAssertFalse(w.covers(at(26, 0), calendar: calendar))
    }

    // MARK: what gets scheduled

    /// A pattern can need several monitored intervals, because `DeviceActivitySchedule` carries
    /// exactly one. Three chosen weekdays must produce three activities, not one.
    func testOneActivityPerChosenDay() {
        XCTAssertEqual(ArmorSchedule.activities(for: window(.dateRange(start: at(11, 0), end: at(12, 0)))).count, 1)
        XCTAssertEqual(ArmorSchedule.activities(for: window(.daily(from: .evening, to: .lateNight))).count, 1)
        XCTAssertEqual(ArmorSchedule.activities(for: window(.weekly(weekdays: [2, 4, 6], from: .evening, to: .lateNight))).count, 3)
        XCTAssertEqual(ArmorSchedule.activities(for: window(.monthly(days: [1, 15, 25]))).count, 3)
    }

    /// Every activity this app owns must share the prefix, because `stop()` finds them by it.
    /// A name that misses the prefix is a schedule that can never be cancelled.
    func testEveryActivityCarriesTheSharedPrefix() {
        let patterns: [ArmorPattern] = [
            .dateRange(start: at(11, 0), end: at(12, 0)),
            .daily(from: .evening, to: .lateNight),
            .weekly(weekdays: [1, 7], from: .evening, to: .lateNight),
            .monthly(days: [3])
        ]
        for pattern in patterns {
            for (name, _) in ArmorSchedule.activities(for: window(pattern)) {
                XCTAssertTrue(name.rawValue.hasPrefix(ArmorSchedule.prefix),
                              "\(name.rawValue) would be unstoppable")
            }
        }
    }

    func testOnlyTheOneOffPatternIsNonRepeating() {
        let once = ArmorSchedule.activities(for: window(.dateRange(start: at(11, 0), end: at(12, 0))))
        XCTAssertFalse(once[0].1.repeats, "a sale happens once")

        for (_, schedule) in ArmorSchedule.activities(for: window(.daily(from: .evening, to: .lateNight))) {
            XCTAssertTrue(schedule.repeats, "a daily guard must come back tomorrow")
        }
        for (_, schedule) in ArmorSchedule.activities(for: window(.weekly(weekdays: [6], from: .evening, to: .lateNight))) {
            XCTAssertTrue(schedule.repeats)
        }
    }

    func testClockOrdersByTimeOfDay() {
        XCTAssertTrue(Clock(hour: 9, minute: 30) < Clock(hour: 10, minute: 0))
        XCTAssertTrue(Clock(hour: 9, minute: 30) < Clock(hour: 9, minute: 31))
        XCTAssertFalse(Clock(hour: 21, minute: 0) < Clock(hour: 2, minute: 0),
                       "21:00 is later in the day than 02:00 — this is what detects a wrap")
    }
}
