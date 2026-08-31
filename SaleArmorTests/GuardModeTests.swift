import XCTest
import FamilyControls
@testable import SaleArmorTests

/// **Locked guards, and the migration that could quietly delete one.**
///
/// Two things are worth testing here and they are not the obvious one. The first is that a locked
/// guard refuses to end while it is running and agrees to end once it is over — the feature itself.
/// The second is that a window saved before `mode` existed still decodes: adding a required field
/// to a `Codable` model is how somebody's armed guard disappears on upgrade, silently, with the
/// shopping apps left open on the night it mattered.
final class GuardModeTests: XCTestCase {

    private func window(_ mode: GuardMode, _ pattern: ArmorPattern) -> ArmorWindow {
        ArmorWindow(name: "PAYDAY", pattern: pattern, selection: FamilyActivitySelection(), mode: mode)
    }

    private func at(_ hour: Int, _ minute: Int = 0) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date())!
    }

    func testStandardGuardCanAlwaysBeDisarmed() {
        let guardWindow = window(.standard, .daily(from: Clock(hour: 21, minute: 0),
                                                   to: Clock(hour: 7, minute: 0)))
        XCTAssertTrue(guardWindow.canDisarm(at: at(23)), "a standard guard is friction, not a cage")
        XCTAssertTrue(guardWindow.canDisarm(at: at(12)))
    }

    func testLockedGuardRefusesWhileItIsRunning() {
        let guardWindow = window(.locked, .daily(from: Clock(hour: 21, minute: 0),
                                                  to: Clock(hour: 7, minute: 0)))
        XCTAssertFalse(guardWindow.canDisarm(at: at(23)), "1:47am is exactly when it must refuse")
        XCTAssertFalse(guardWindow.canDisarm(at: at(2)), "and after midnight, where the window wraps")
    }

    func testLockedGuardReleasesOnceTheWindowIsOver() {
        let guardWindow = window(.locked, .daily(from: Clock(hour: 21, minute: 0),
                                                  to: Clock(hour: 7, minute: 0)))
        XCTAssertTrue(guardWindow.canDisarm(at: at(12)),
                      "locked means no early exit, not permanent — a guard you can never remove is one you uninstall")
    }

    func testWindowSavedBeforeModeExistedStillDecodes() throws {
        // Exactly what is already in the App Group on every device running an earlier build.
        let legacy = """
        {"name":"PAYDAY","pattern":{"monthly":{"days":[25]}},"selection":{}}
        """
        let selection = try JSONEncoder().encode(FamilyActivitySelection())
        let json = legacy.replacingOccurrences(of: "{\"selection\":{}}",
                                               with: "{\"selection\":\(String(data: selection, encoding: .utf8)!)}")
            .replacingOccurrences(of: "\"selection\":{}",
                                  with: "\"selection\":\(String(data: selection, encoding: .utf8)!)")
        let decoded = try? JSONDecoder().decode(ArmorWindow.self, from: Data(json.utf8))
        XCTAssertEqual(decoded?.mode, .standard,
                       "a window saved without a mode must load as standard, not fail to load at all")
    }

    func testLockedLimitIsThreeDays() {
        XCTAssertEqual(GuardMode.lockedLimit, 72 * 3600,
                       "long enough for a sale weekend, short enough that a mistake is survivable")
    }
}

/// The 72-hour cap, checked at the point where it still matters.
///
/// A locked guard cannot be undone in the app, so a duration that turns out to be a mistake has no
/// remedy short of revoking permissions or deleting Sale Armor. The cap therefore has to be refused
/// *before* anything is written, not explained afterwards.
final class LockedDurationTests: XCTestCase {

    func testANightlyWindowIsWithinTheCap() {
        let nightly = ArmorPattern.daily(from: Clock(hour: 21, minute: 0), to: Clock(hour: 7, minute: 0))
        let run = try? XCTUnwrap(nightly.longestRun())
        XCTAssertEqual(run ?? 0, 10 * 3600, accuracy: 1, "9pm to 7am is ten hours, not ten hours a night forever")
        XCTAssertLessThan(run ?? 0, GuardMode.lockedLimit)
    }

    func testAWrappingWindowIsMeasuredAcrossMidnight() {
        let wraps = ArmorPattern.daily(from: Clock(hour: 23, minute: 0), to: Clock(hour: 2, minute: 0))
        XCTAssertEqual(wraps.longestRun() ?? 0, 3 * 3600, accuracy: 1,
                       "11pm to 2am is three hours; measured naively it is minus twenty-one")
    }

    func testALongDateRangeExceedsTheCap() {
        let start = Date()
        let month = ArmorPattern.dateRange(start: start, end: start.addingTimeInterval(30 * 24 * 3600))
        XCTAssertGreaterThan(month.longestRun() ?? 0, GuardMode.lockedLimit,
                             "locking Amazon for a month is the mistake the cap exists to refuse")
    }

    func testRepeatingPatternsAreMeasuredPerOccurrence() {
        XCTAssertLessThanOrEqual(ArmorPattern.monthly(days: [25, 1]).longestRun() ?? 0,
                                 GuardMode.lockedLimit,
                                 "payday repeats forever but shuts the apps a day at a time")
        XCTAssertLessThanOrEqual(ArmorPattern.doubleDates.longestRun() ?? 0, GuardMode.lockedLimit)
    }
}

/// The bypass that would have made LOCKED decorative.
///
/// Refusing to *disarm* a locked guard is only half of it. If a new guard can simply be armed over
/// the top, "arm a standard guard" is a one-tap escape and the whole feature is theatre. The
/// interface happens to prevent it today by not showing the form while anything is armed — but
/// that is a property of one screen, not of the model.
final class LockedReplacementTests: XCTestCase {

    func testALockedGuardBlocksReplacementWhileItRuns() {
        let running = ArmorWindow(name: "PAYDAY",
                                  pattern: .daily(from: Clock(hour: 21, minute: 0),
                                                  to: Clock(hour: 7, minute: 0)),
                                  selection: FamilyActivitySelection(),
                                  mode: .locked)
        let inside = Calendar.current.date(bySettingHour: 23, minute: 0, second: 0, of: Date())!
        XCTAssertFalse(running.canDisarm(at: inside),
                       "if this passes, arming over the top is a one-tap bypass")
    }

    func testItLetsGoOnceTheWindowEnds() {
        let running = ArmorWindow(name: "PAYDAY",
                                  pattern: .daily(from: Clock(hour: 21, minute: 0),
                                                  to: Clock(hour: 7, minute: 0)),
                                  selection: FamilyActivitySelection(),
                                  mode: .locked)
        let outside = Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: Date())!
        XCTAssertTrue(running.canDisarm(at: outside))
    }
}

/// The "Now" guard: the one that shuts the apps this second.
///
/// Every other pattern schedules something for later, which is why a freshly armed guard could sit
/// there saying "Armed" while the shopping apps opened perfectly well — correct behaviour that
/// reads exactly like a broken app. The website promised this option long before the app had it.
final class ImmediateGuardTests: XCTestCase {

    private func now(hours: Int) -> ArmorPattern {
        .dateRange(start: Date().addingTimeInterval(-60),
                   end: Date().addingTimeInterval(TimeInterval(hours) * 3600))
    }

    func testAnImmediateGuardCoversThisSecond() {
        let window = ArmorWindow(name: "RETAIL THERAPY", pattern: now(hours: 3),
                                 selection: .init(), mode: .standard)
        XCTAssertTrue(window.covers(Date()), "if this is false the apps stay open and the app looks broken")
    }

    func testItEndsWhenItSaysItWill() {
        let window = ArmorWindow(name: "RETAIL THERAPY", pattern: now(hours: 3),
                                 selection: .init(), mode: .standard)
        XCTAssertFalse(window.covers(Date().addingTimeInterval(4 * 3600)))
    }

    func testEveryImmediateLengthFitsUnderTheLockedCap() {
        for hours in [3, 8, 24] {
            XCTAssertLessThanOrEqual(now(hours: hours).longestRun() ?? .infinity,
                                     GuardMode.lockedLimit,
                                     "\(hours)h must be lockable — 'don't let me negotiate' is exactly this case")
        }
    }
}

/// **The 20:55 hole, and the rule that closes it.**
///
/// LOCKED used to mean "refuses while the shield is up", which is the weakest possible reading: a
/// nightly 21:00 guard was fully cancellable at 20:55, five minutes before the only moment it
/// exists for. `lockedUntil` pins the end of the first window the guard must sit through, decided
/// while calm at arming, so the decision cannot be unmade as it approaches.
///
/// Every case below is asserted against a window carrying `lockedUntil`. The legacy case — a window
/// saved before the field existed — is pinned separately, because tightening a promise somebody
/// already armed under is its own kind of bug.
final class LockedCommitmentTests: XCTestCase {

    private let nightly = ArmorPattern.daily(from: Clock(hour: 21, minute: 0),
                                             to: Clock(hour: 2, minute: 0))

    private func at(_ hour: Int, _ minute: Int = 0, dayOffset: Int = 0) -> Date {
        let base = Calendar.current.date(byAdding: .day, value: dayOffset, to: Date())!
        return Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: base)!
    }

    private func locked(_ pattern: ArmorPattern, armedAt: Date) -> ArmorWindow {
        ArmorWindow(name: "PAYDAY", pattern: pattern, selection: FamilyActivitySelection(),
                    mode: .locked,
                    lockedUntil: ArmorWindow.commitmentEnd(pattern: pattern, from: armedAt))
    }

    // MARK: - the bug

    func testALockedGuardRefusesBeforeItsWindowEvenOpens() {
        let guardWindow = locked(nightly, armedAt: at(18))
        XCTAssertFalse(guardWindow.canDisarm(at: at(20, 55)),
                       "20:55 on a 21:00 guard is the exact minute somebody wants out — this is the bug")
        XCTAssertFalse(guardWindow.canDisarm(at: at(18, 1)), "and immediately after arming")
    }

    func testItStillRefusesInsideTheWindow() {
        let guardWindow = locked(nightly, armedAt: at(18))
        XCTAssertFalse(guardWindow.canDisarm(at: at(23)))
        XCTAssertFalse(guardWindow.canDisarm(at: at(1, 30, dayOffset: 1)),
                       "after midnight, where the window wraps")
    }

    func testItLetsGoOnceTheWindowItMustSitThroughHasEnded() {
        let guardWindow = locked(nightly, armedAt: at(18))
        XCTAssertTrue(guardWindow.canDisarm(at: at(2, 1, dayOffset: 1)),
                      "one window sat through is the price; a guard nobody can remove is one they uninstall")
    }

    // MARK: - back-compatibility

    func testALockedWindowWithoutLockedUntilKeepsItsOldBehaviour() {
        let legacy = ArmorWindow(name: "PAYDAY", pattern: nightly,
                                 selection: FamilyActivitySelection(), mode: .locked)
        XCTAssertNil(legacy.lockedUntil)
        XCTAssertFalse(legacy.canDisarm(at: at(23)), "still refuses while the shield is up")
        XCTAssertTrue(legacy.canDisarm(at: at(12)),
                      "and still releases between windows — the behaviour it was armed under")
    }

    func testAWindowSavedBeforeLockedUntilExistedStillDecodes() throws {
        let selection = String(data: try JSONEncoder().encode(FamilyActivitySelection()),
                              encoding: .utf8)!
        let json = """
        {"name":"PAYDAY","pattern":{"monthly":{"days":[25]}},"mode":"locked","selection":\(selection)}
        """
        let decoded = try JSONDecoder().decode(ArmorWindow.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.mode, .locked)
        XCTAssertNil(decoded.lockedUntil, "absent, not a decode failure that loses the guard")
    }

    func testLockedUntilSurvivesARoundTrip() throws {
        let original = locked(nightly, armedAt: at(18))
        let decoded = try JSONDecoder().decode(ArmorWindow.self,
                                               from: try JSONEncoder().encode(original))
        XCTAssertEqual(decoded.lockedUntil, original.lockedUntil,
                       "if this drifts, a relaunch silently unlocks the guard")
    }
}

/// `commitmentEnd` — the one number the whole feature now rests on.
final class CommitmentEndTests: XCTestCase {

    private func at(_ hour: Int, _ minute: Int = 0, dayOffset: Int = 0) -> Date {
        let base = Calendar.current.date(byAdding: .day, value: dayOffset, to: Date())!
        return Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: base)!
    }

    func testAWrappingNightlyWindowEndsAfterMidnight() throws {
        let end = try XCTUnwrap(ArmorWindow.commitmentEnd(
            pattern: .daily(from: Clock(hour: 21, minute: 0), to: Clock(hour: 2, minute: 0)),
            from: at(18)))
        XCTAssertEqual(end.timeIntervalSince(at(2, 0, dayOffset: 1)), 0, accuracy: 61,
                       "armed at 18:00, the first window it must sit through ends at 02:00 tomorrow")
    }

    func testANonWrappingWindowEndsTheSameDay() throws {
        let end = try XCTUnwrap(ArmorWindow.commitmentEnd(
            pattern: .daily(from: Clock(hour: 9, minute: 0), to: Clock(hour: 17, minute: 0)),
            from: at(8)))
        XCTAssertEqual(end.timeIntervalSince(at(17)), 0, accuracy: 61)
    }

    func testArmingInsideAWindowLocksUntilThatWindowEnds() throws {
        let end = try XCTUnwrap(ArmorWindow.commitmentEnd(
            pattern: .daily(from: Clock(hour: 9, minute: 0), to: Clock(hour: 17, minute: 0)),
            from: at(12)))
        XCTAssertEqual(end.timeIntervalSince(at(17)), 0, accuracy: 61,
                       "not the end of tomorrow's window — the one you are already in")
    }

    func testAOneOffReportsItsOwnEnd() throws {
        let start = at(20), finish = at(23)
        let end = try XCTUnwrap(ArmorWindow.commitmentEnd(
            pattern: .dateRange(start: start, end: finish), from: at(18)))
        XCTAssertEqual(end, finish, "a one-off does not need searching for; it says when it ends")
    }

    func testAOneOffAlreadyPastCommitsToNothing() {
        let start = at(1), finish = at(2)
        XCTAssertNil(ArmorWindow.commitmentEnd(pattern: .dateRange(start: start, end: finish),
                                               from: at(12)))
    }

    func testAPaydayGuardCommitsPastTheEndOfThePaydayItself() throws {
        let today = Calendar.current.component(.day, from: Date())
        let end = try XCTUnwrap(ArmorWindow.commitmentEnd(pattern: .monthly(days: [today]),
                                                          from: at(12)))
        XCTAssertGreaterThan(end, at(12))
        XCTAssertLessThanOrEqual(end.timeIntervalSince(at(12)), 36 * 3600,
                                 "armed on the day itself, it lifts at midnight, not next month")
    }

    func testTheCommitmentIsWhatTheCapMustMeasure() throws {
        // The bug the new cap fixes: one occurrence of a payday guard is 24h and passed the old
        // `longestRun` check, while the person arming it days early could not disarm until it ended.
        let day = Calendar.current.component(.day, from: Date())
        let paydayInFiveDays = ((day + 5 - 1) % 28) + 1
        let end = ArmorWindow.commitmentEnd(pattern: .monthly(days: [paydayInFiveDays]), from: Date())
        let span = try XCTUnwrap(end).timeIntervalSince(Date())
        XCTAssertGreaterThan(span, GuardMode.lockedLimit,
                             "so arm() must refuse it, though longestRun() reports only 24h")
        XCTAssertEqual(ArmorPattern.monthly(days: [paydayInFiveDays]).longestRun(), 24 * 3600)
    }
}
