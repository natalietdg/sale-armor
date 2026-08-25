import XCTest
import FamilyControls
@testable import SaleArmorTests

/// **When payday actually falls.**
///
/// Every shape here has a way of quietly disappearing. A payday set to the 31st has no February. A
/// last working day is not a date at all. A fortnight counted in seconds drifts an hour twice a
/// year. Each of those failures looks identical from the outside — the notification simply never
/// arrives — so they are worth pinning down here rather than noticing three months later.
final class PaydayTests: XCTestCase {

    /// Fixed and UTC, so a fixture means the same thing on any machine.
    private let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    private func at(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private func parts(_ date: Date) -> DateComponents {
        calendar.dateComponents([.year, .month, .day, .hour], from: date)
    }

    // MARK: - a day of the month

    func testAPaydayOnTheTwentyFifthIsTheTwentyFifth() {
        let payday = Payday(shape: .dayOfMonth(25))
        let next = payday.nextNudge(after: at(2026, 8, 1), calendar: calendar)
        XCTAssertEqual(parts(next!).day, 25)
        XCTAssertEqual(parts(next!).month, 8)
    }

    func testTheNudgeIsAtSixInTheEvening() {
        let payday = Payday(shape: .dayOfMonth(25))
        let next = payday.nextNudge(after: at(2026, 8, 1), calendar: calendar)
        XCTAssertEqual(parts(next!).hour, 18,
                       "the risk window is the evening after the money lands, not the morning")
    }

    func testAPaydayOnTheThirtyFirstLandsOnTheLastDayOfFebruary() {
        let payday = Payday(shape: .dayOfMonth(31))
        // February 2026 has 28 days.
        let next = payday.nextNudge(after: at(2026, 2, 1), calendar: calendar)
        XCTAssertEqual(parts(next!).month, 2, "February must not be skipped — people get paid in it")
        XCTAssertEqual(parts(next!).day, 28)
    }

    func testAPaydayOnTheThirtyFirstLandsOnTheTwentyNinthInALeapFebruary() {
        let payday = Payday(shape: .dayOfMonth(31))
        // February 2028 has 29 days.
        let next = payday.nextNudge(after: at(2028, 2, 1), calendar: calendar)
        XCTAssertEqual(parts(next!).month, 2)
        XCTAssertEqual(parts(next!).day, 29)
    }

    func testAPaydayOnTheThirtyFirstIsStillTheThirtyFirstInALongMonth() {
        let payday = Payday(shape: .dayOfMonth(31))
        let next = payday.nextNudge(after: at(2026, 3, 1), calendar: calendar)
        XCTAssertEqual(parts(next!).day, 31, "clamping is for short months only")
    }

    // MARK: - the last working day

    func testAMonthEndingOnASaturdayPaysOnTheFriday() {
        let payday = Payday(shape: .lastWorkingDay)
        // 31 Jan 2026 is a Saturday.
        let next = payday.nextNudge(after: at(2026, 1, 1), calendar: calendar)
        XCTAssertEqual(parts(next!).day, 30)
        XCTAssertEqual(calendar.component(.weekday, from: next!), 6, "Friday")
    }

    func testAMonthEndingOnASundayPaysOnTheFridayBefore() {
        let payday = Payday(shape: .lastWorkingDay)
        // 31 May 2026 is a Sunday, so it steps back two days, not one.
        let next = payday.nextNudge(after: at(2026, 5, 1), calendar: calendar)
        XCTAssertEqual(parts(next!).day, 29)
        XCTAssertEqual(calendar.component(.weekday, from: next!), 6, "Friday")
    }

    func testAMonthEndingOnAWeekdayPaysOnThatDay() {
        let payday = Payday(shape: .lastWorkingDay)
        // 31 Aug 2026 is a Monday.
        let next = payday.nextNudge(after: at(2026, 8, 1), calendar: calendar)
        XCTAssertEqual(parts(next!).day, 31)
        XCTAssertEqual(calendar.component(.weekday, from: next!), 2, "Monday")
    }

    func testTheLastWorkingDayIsNeverAWeekend() {
        let payday = Payday(shape: .lastWorkingDay)
        for nudge in payday.upcoming(after: at(2026, 1, 1), count: 12, calendar: calendar) {
            let weekday = calendar.component(.weekday, from: nudge)
            XCTAssertFalse(weekday == 1 || weekday == 7,
                           "\(nudge) is a weekend — payroll does not run then")
        }
    }

    // MARK: - fortnightly

    func testAFortnightIsFourteenDaysOn() {
        let payday = Payday(shape: .fortnightly(anchor: at(2026, 8, 14)))
        let next = payday.nextNudge(after: at(2026, 8, 15), calendar: calendar)
        XCTAssertEqual(parts(next!).month, 8)
        XCTAssertEqual(parts(next!).day, 28)
    }

    func testTheAnchorsOwnEveningIsTheFirstPayday() {
        // "Your last payday" is a payday. Set it this morning and the nudge is tonight, not in
        // a fortnight — the evening the money landed is exactly the one this feature is about.
        let payday = Payday(shape: .fortnightly(anchor: at(2026, 8, 14, 9)))
        let next = payday.nextNudge(after: at(2026, 8, 14, 9), calendar: calendar)
        XCTAssertEqual(parts(next!).day, 14)
        XCTAssertEqual(parts(next!).hour, 18)
    }

    func testAFortnightCrossesTheMonthBoundary() {
        let payday = Payday(shape: .fortnightly(anchor: at(2026, 8, 28)))
        let next = payday.nextNudge(after: at(2026, 8, 29), calendar: calendar)
        XCTAssertEqual(parts(next!).month, 9, "28 Aug + 14 days is September, not the 42nd of August")
        XCTAssertEqual(parts(next!).day, 11)
    }

    func testFortnightsKeepMarchingAcrossSeveralMonths() {
        let payday = Payday(shape: .fortnightly(anchor: at(2026, 1, 2)))
        let upcoming = payday.upcoming(after: at(2026, 1, 3), count: 6, calendar: calendar)
        XCTAssertEqual(upcoming.count, 6)
        for (earlier, later) in zip(upcoming, upcoming.dropFirst()) {
            XCTAssertEqual(calendar.dateComponents([.day], from: earlier, to: later).day, 14)
        }
    }

    /// **The one that a naive `+ 14 * 86400` gets wrong.**
    ///
    /// A fortnight is fourteen sleeps, not 1,209,600 seconds. Across a daylight-saving change those
    /// differ by an hour, and an hour is the difference between a 18:00 nudge and a 17:00 one.
    func testAFortnightAcrossADaylightSavingChangeStillLandsAtSixInTheEvening() {
        var newYork = Calendar(identifier: .gregorian)
        newYork.timeZone = TimeZone(identifier: "America/New_York")!
        // US clocks go forward on 8 March 2026, between these two dates.
        let anchor = newYork.date(from: DateComponents(year: 2026, month: 3, day: 1, hour: 12))!
        let payday = Payday(shape: .fortnightly(anchor: anchor))

        // Asked the day after, so the answer is the fortnight and not the anchor's own evening.
        let dayAfter = newYork.date(from: DateComponents(year: 2026, month: 3, day: 2, hour: 12))!
        let next = payday.nextNudge(after: dayAfter, calendar: newYork)
        let landed = newYork.dateComponents([.month, .day, .hour], from: next!)
        XCTAssertEqual(landed.month, 3)
        XCTAssertEqual(landed.day, 15)
        XCTAssertEqual(landed.hour, 18, "an hour of drift is a nudge at the wrong time of day")
    }

    // MARK: - always ahead

    func testTheNextPaydayIsAlwaysStrictlyInTheFuture() {
        let shapes: [Payday.Shape] = [.dayOfMonth(25), .dayOfMonth(31), .dayOfMonth(1),
                                      .lastWorkingDay, .fortnightly(anchor: at(2026, 1, 2))]
        for shape in shapes {
            let payday = Payday(shape: shape)
            for day in [1, 15, 25, 28] {
                for hour in [0, 17, 18, 23] {
                    let now = at(2026, 2, day, hour)
                    let next = payday.nextNudge(after: now, calendar: calendar)
                    XCTAssertNotNil(next, "\(shape) found nothing after \(now)")
                    XCTAssertGreaterThan(next!, now,
                                         "\(shape) offered a payday that has already gone by")
                }
            }
        }
    }

    func testAskingOnPaydayEveningGivesTheNextOneNotThisOne() {
        let payday = Payday(shape: .dayOfMonth(25))
        let next = payday.nextNudge(after: at(2026, 8, 25, 18), calendar: calendar)
        XCTAssertEqual(parts(next!).month, 9, "18:00 on the 25th is spent, not upcoming")
    }

    /// Payday is a *day*, not a moment — the monitor can be woken at 00:00 by a whole-day interval
    /// and still has to recognise which evening it is standing in.
    func testTheDaysOwnNudgeIsFoundFromAnyHourOfThatDay() {
        let payday = Payday(shape: .dayOfMonth(25))
        XCTAssertEqual(parts(payday.nudge(on: at(2026, 8, 25, 0), calendar: calendar)!).hour, 18,
                       "woken at midnight on payday")
        XCTAssertEqual(parts(payday.nudge(on: at(2026, 8, 25, 23), calendar: calendar)!).day, 25,
                       "and late in the evening, after the nudge has gone")
        XCTAssertNil(payday.nudge(on: at(2026, 8, 24, 23), calendar: calendar))
        XCTAssertNil(payday.nudge(on: at(2026, 8, 26, 1), calendar: calendar))
    }

    // MARK: - the offered session

    func testTheOfferedSessionRunsFromTheTapUntilSixInTheMorning() {
        let accepted = at(2026, 8, 25, 18)
        guard case let .dateRange(start, end)? = Payday.session(acceptedAt: accepted, calendar: calendar) else {
            return XCTFail("payday offered no session")
        }
        XCTAssertLessThanOrEqual(start, accepted, "the shield has to go up on the tap, not later")
        XCTAssertEqual(parts(end).day, 26)
        XCTAssertEqual(parts(end).hour, 6)
    }

    func testAnOfferAcceptedAfterMidnightEndsThatSameMorning() {
        let accepted = at(2026, 8, 26, 1)
        guard case let .dateRange(_, end)? = Payday.session(acceptedAt: accepted, calendar: calendar) else {
            return XCTFail("payday offered no session")
        }
        XCTAssertEqual(parts(end).day, 26, "6am tomorrow would be twenty-nine hours of blocking")
        XCTAssertEqual(parts(end).hour, 6)
    }

    func testTheOfferedSessionIsTheEveningAndNoLonger() {
        let session = Payday.session(acceptedAt: at(2026, 8, 25, 18), calendar: calendar)
        XCTAssertEqual(session?.longestRun(calendar: calendar) ?? 0, 12 * 3600, accuracy: 120,
                       "18:00 to 06:00 is twelve hours — a session that outlives the night is a guard, not an offer")
    }

    // MARK: - the offer needs an empty window to land in

    func testTheOfferedSessionCanOnlyStartWhenNothingIsArmed() {
        XCTAssertTrue(Payday.canStartOfferedSession(whileArmed: nil))

        let standing = ArmorWindow(name: "LATE-NIGHT SCROLL",
                                   pattern: .daily(from: Clock(hour: 21, minute: 0),
                                                   to: Clock(hour: 2, minute: 0)),
                                   selection: FamilyActivitySelection())
        XCTAssertFalse(Payday.canStartOfferedSession(whileArmed: standing),
                       "the store holds one window — arming over this would delete it, with no undo")
    }

    /// **The data-loss case.**
    ///
    /// An offer booked weeks ago can be answered after something else has been armed. Honouring it
    /// then would overwrite the stored window and stop that guard's activities, silently and with
    /// no way back. This walks the exact sequence the controller walks.
    func testAStaleOfferNeverOverwritesAnArmedGuard() {
        let standing = ArmorWindow(name: "LATE-NIGHT SCROLL",
                                   pattern: .daily(from: Clock(hour: 21, minute: 0),
                                                   to: Clock(hour: 2, minute: 0)),
                                   selection: FamilyActivitySelection())
        ArmorStore.save(standing)
        defer { ArmorStore.save(nil) }

        // What `acceptPaydayOffer` does: ask the rule first, and only then arm.
        if Payday.canStartOfferedSession(whileArmed: ArmorStore.load()),
           let pattern = Payday.session(acceptedAt: at(2026, 8, 25, 18), calendar: calendar) {
            ArmorStore.save(ArmorWindow(name: Payday.sessionName, pattern: pattern,
                                        selection: FamilyActivitySelection()))
        }

        XCTAssertEqual(ArmorStore.load()?.name, "LATE-NIGHT SCROLL",
                       "the payday session replaced a standing guard — that is unrecoverable data loss")
    }
}

/// **Offer or status notice — the branch the whole feature turns on.**
///
/// Getting it backwards is not a cosmetic bug. Telling somebody "Blocked for Payday" when nothing
/// is armed is a lie from an app whose only job is to be trustworthy about that, and offering to
/// start blocking to somebody already blocked is the nagging the product promises not to do.
final class PaydayNoticeTests: XCTestCase {

    private let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    /// 18:00 on 25 Aug 2026, a Tuesday.
    private var nudge: Date {
        calendar.date(from: DateComponents(year: 2026, month: 8, day: 25, hour: 18))!
    }

    private let payday = Payday(shape: .dayOfMonth(25))

    private func window(_ pattern: ArmorPattern) -> ArmorWindow {
        ArmorWindow(name: "test", pattern: pattern, selection: FamilyActivitySelection())
    }

    func testNoPaydayMeansNoNotificationAtAll() {
        XCTAssertNil(PaydayNotice.decide(payday: nil, window: nil, nudgeAt: nudge, calendar: calendar),
                     "both notifications are opt-in — neither exists without a payday set")
        XCTAssertNil(PaydayNotice.decide(payday: nil, window: window(.monthly(days: [25])),
                                         nudgeAt: nudge, calendar: calendar),
                     "an armed guard is not consent to be told about payday")
    }

    func testNothingArmedEarnsTheOffer() {
        XCTAssertEqual(PaydayNotice.decide(payday: payday, window: nil,
                                           nudgeAt: nudge, calendar: calendar),
                       .offer)
    }

    func testAGuardCoveringPaydayEarnsTheStatusNotice() {
        XCTAssertEqual(PaydayNotice.decide(payday: payday, window: window(.monthly(days: [25])),
                                           nudgeAt: nudge, calendar: calendar),
                       .alreadyBlocked)
    }

    func testANightlyGuardCountsAsCoveringPaydayEvening() {
        // 21:00–02:00 does not cover 18:00 itself, but it does shut the apps that evening — which
        // is the question the branch is actually asking.
        let nightly = window(.daily(from: Clock(hour: 21, minute: 0), to: Clock(hour: 2, minute: 0)))
        XCTAssertEqual(PaydayNotice.decide(payday: payday, window: nightly,
                                           nudgeAt: nudge, calendar: calendar),
                       .alreadyBlocked)
    }

    /// **Neither notification, and that is the right answer.**
    ///
    /// A 09:00–12:00 guard on payday is armed, so there is no free window to offer a session in —
    /// and it is not covering payday evening, so "Blocked for Payday" would be a lie. Silence is
    /// what is left, and it beats either alternative.
    func testAGuardThatMissesPaydayEveningEarnsNeither() {
        let officeHours = window(.daily(from: Clock(hour: 9, minute: 0), to: Clock(hour: 12, minute: 0)))
        XCTAssertNil(PaydayNotice.decide(payday: payday, window: officeHours,
                                         nudgeAt: nudge, calendar: calendar),
                     "an offer here would destroy this guard, and a status notice here would be untrue")
    }

    func testAGuardOnADifferentDayOfTheMonthEarnsNeither() {
        XCTAssertNil(PaydayNotice.decide(payday: payday, window: window(.monthly(days: [1])),
                                         nudgeAt: nudge, calendar: calendar))
    }

    /// The booking-side half of the same rule: **anything armed means no offer is booked**, whatever
    /// shape it is. This is what removes the overwrite path rather than merely guarding it.
    func testNoOfferIsEverBookedWhileAnythingIsArmed() {
        let patterns: [ArmorPattern] = [
            .daily(from: Clock(hour: 9, minute: 0), to: Clock(hour: 12, minute: 0)),
            .daily(from: Clock(hour: 21, minute: 0), to: Clock(hour: 2, minute: 0)),
            .weekly(weekdays: [2], from: Clock(hour: 9, minute: 0), to: Clock(hour: 10, minute: 0)),
            .monthly(days: [1]),
            .monthly(days: [25]),
            .doubleDates,
            .dateRange(start: nudge.addingTimeInterval(-3600), end: nudge.addingTimeInterval(3600)),
        ]
        for pattern in patterns {
            XCTAssertNotEqual(PaydayNotice.decide(payday: payday, window: window(pattern),
                                                  nudgeAt: nudge, calendar: calendar),
                              .offer,
                              "\(pattern) is armed — an offer would arm a second guard over the top of it")
        }
    }

    /// The dedupe itself, not just the shape of its key.
    ///
    /// This test owns the stored marker: nothing else in the suite reads it, and the test bundle's
    /// defaults are its own rather than the shipped app's.
    func testTheStatusNoticeCanOnlyBeClaimedOncePerPayday() {
        let day = PaydayNotice.dayStamp(nudge, calendar: calendar)
        XCTAssertEqual(day, "2026-08-25", "one payday, one identifier")

        _ = ArmorStore.claimPaydayStatus("none-of-the-above")   // nothing said for this payday yet

        XCTAssertTrue(ArmorStore.claimPaydayStatus(day),
                      "the first interval to start on payday says it")
        XCTAssertFalse(ArmorStore.claimPaydayStatus(day),
                       "a second interval the same day must not say it again — that is the re-nag")

        let nextPayday = payday.nextNudge(after: nudge, calendar: calendar)!
        XCTAssertTrue(ArmorStore.claimPaydayStatus(PaydayNotice.dayStamp(nextPayday, calendar: calendar)),
                      "next month is a new claim, not a permanent mute")
    }
}
