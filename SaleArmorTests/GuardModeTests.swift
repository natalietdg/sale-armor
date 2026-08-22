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
