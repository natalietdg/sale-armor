import Foundation
import UserNotifications

/// **When money lands, and the one notification that earns.**
///
/// Payday is a *setting*, not a sixth `ArmorPattern`. It does not shut anything by itself: it is
/// the app's answer to "when is the risk highest", and the risk is the evening after the money
/// arrives, not the morning it does.
///
/// **Both payday notifications are opt-in and neither exists until a payday is set.** Sale Armor's
/// App Store description promises no streaks, no guilt and no notification telling you you have
/// slipped, and this keeps that promise: nothing here is scheduled for somebody who has not set a
/// payday, there is no second nudge if the first is ignored, and no notification anywhere in this
/// file mentions failing. A declined offer is an answer — the next one is a fortnight or a month
/// away. This paragraph exists so the next person to read the file can see the promise was
/// checked rather than overlooked.
///
/// **One window, so at most one notification.** `ArmorStore` holds a single `ArmorWindow`: arming
/// the offered session while another guard is armed would delete that guard, with no undo. So the
/// offer is only made when *nothing at all* is armed, and the status notice is only sent when the
/// armed guard genuinely covers payday evening. A guard that is armed but misses that evening —
/// office hours on payday — earns **neither**, and silence is the honest answer: there is no
/// second guard to offer, and "Blocked for Payday" would not be about payday.
struct Payday: Codable, Equatable {

    /// **Three shapes, because payroll has three shapes.**
    enum Shape: Codable, Equatable, Hashable {
        /// The common case. The 25th, the 1st.
        case dayOfMonth(Int)
        /// Malaysian payroll's usual shape, and it is not a fixed date.
        case lastWorkingDay
        /// Every 14 days, counted from a payday you already had.
        case fortnightly(anchor: Date)
    }

    var shape: Shape

    /// **18:00, because the risk window is the evening after the money lands.**
    static let nudgeHour = 18
    /// Where the offered session ends. Long enough to cover the night it is for.
    static let morningHour = 6
    /// How many paydays are booked ahead. Six covers half a year of monthly paydays and three
    /// months of fortnightly ones, and the app tops the queue up on every foreground.
    static let offersBookedAhead = 6

    // MARK: - when the next one falls

    /// The next payday nudge strictly after `now`, or nil if the calendar refuses to build one.
    ///
    /// Strictly after, so asking at 18:00 on payday gives you *next* payday rather than the moment
    /// you are standing in.
    func nextNudge(after now: Date, calendar: Calendar = .current) -> Date? {
        upcoming(after: now, count: 1, calendar: calendar).first
    }

    /// The next `count` payday nudges, in order, all strictly after `now`.
    func upcoming(after now: Date, count: Int, calendar: Calendar = .current) -> [Date] {
        switch shape {
        case let .dayOfMonth(day):     monthlyNudges(day: day, after: now, count: count, calendar: calendar)
        case .lastWorkingDay:          lastWorkingDayNudges(after: now, count: count, calendar: calendar)
        case let .fortnightly(anchor): fortnightlyNudges(from: anchor, after: now, count: count, calendar: calendar)
        }
    }

    /// Payday's own 18:00 on the day `date` falls in, or nil when that day is not a payday.
    ///
    /// Asked by working out the next nudge after the last instant of the day before — one
    /// implementation of "when is payday", used both ways round.
    func nudge(on date: Date, calendar: Calendar = .current) -> Date? {
        let dayBefore = calendar.startOfDay(for: date).addingTimeInterval(-1)
        guard let next = nextNudge(after: dayBefore, calendar: calendar),
              calendar.isDate(next, inSameDayAs: date) else { return nil }
        return next
    }

    // MARK: - the shapes

    private func monthlyNudges(day: Int, after now: Date, count: Int, calendar: Calendar) -> [Date] {
        // A payday on the 31st is **clamped to the month's last day, not skipped** — February pays
        // people too, and a nudge that silently vanishes for a month is worse than one a day early.
        walkingMonths(after: now, count: count, calendar: calendar) { month in
            guard let days = calendar.range(of: .day, in: .month, for: month) else { return nil }
            return evening(inMonthOf: month, onDay: min(max(day, 1), days.count), calendar: calendar)
        }
    }

    private func lastWorkingDayNudges(after now: Date, count: Int, calendar: Calendar) -> [Date] {
        walkingMonths(after: now, count: count, calendar: calendar) {
            lastWorkingDay(inMonthOf: $0, calendar: calendar)
        }
    }

    /// Walks forward a month at a time, asking `paydayIn` for that month's payday and keeping the
    /// ones still ahead of `now`.
    ///
    /// `count + 1` months is always enough for `count` results: there is at most one payday per
    /// month, and this month's may already have gone by.
    private func walkingMonths(after now: Date, count: Int, calendar: Calendar,
                               _ paydayIn: (Date) -> Date?) -> [Date] {
        var month = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        var found: [Date] = []
        for _ in 0...count where found.count < count {
            if let candidate = paydayIn(month), candidate > now { found.append(candidate) }
            guard let next = calendar.date(byAdding: .month, value: 1, to: month) else { break }
            month = next
        }
        return found
    }

    /// The last Monday–Friday of the month. **Public holidays are not considered** — the app has no
    /// holiday calendar, and inventing one would be wrong in a different country every month.
    private func lastWorkingDay(inMonthOf month: Date, calendar: Calendar) -> Date? {
        guard let days = calendar.range(of: .day, in: .month, for: month) else { return nil }
        for day in stride(from: days.count, through: 1, by: -1) {
            guard let candidate = evening(inMonthOf: month, onDay: day, calendar: calendar) else { continue }
            // 1 = Sunday, 7 = Saturday, matching `Calendar`.
            let weekday = calendar.component(.weekday, from: candidate)
            if weekday != 1 && weekday != 7 { return candidate }
        }
        return nil
    }

    private func fortnightlyNudges(from anchor: Date, after now: Date, count: Int,
                                   calendar: Calendar) -> [Date] {
        guard var evening = calendar.date(bySettingHour: Self.nudgeHour, minute: 0, second: 0,
                                          of: calendar.startOfDay(for: anchor)) else { return [] }

        // Skip whole fortnights in one step so an anchor set years ago does not loop a thousand
        // times, then walk the remainder.
        if let elapsed = calendar.dateComponents([.day], from: evening, to: now).day, elapsed >= 14 {
            evening = calendar.date(byAdding: .day, value: (elapsed / 14) * 14, to: evening) ?? evening
        }
        // **Day arithmetic, not 14 × 86400.** A fortnight that crosses a daylight-saving change is
        // still fourteen sleeps, and the nudge still belongs at 18:00 local.
        while evening <= now {
            guard let next = calendar.date(byAdding: .day, value: 14, to: evening) else { return [] }
            evening = next
        }

        var found = [evening]
        while found.count < count, let last = found.last,
              let next = calendar.date(byAdding: .day, value: 14, to: last) {
            found.append(next)
        }
        return found
    }

    /// 18:00 on one particular day of one particular month.
    private func evening(inMonthOf month: Date, onDay day: Int, calendar: Calendar) -> Date? {
        var parts = calendar.dateComponents([.year, .month], from: month)
        parts.day = day
        parts.hour = Self.nudgeHour
        parts.minute = 0
        parts.second = 0
        return calendar.date(from: parts)
    }

    // MARK: - the evening it is about

    /// The payday evening, sampled hourly from 18:00 up to (not including) 06:00.
    ///
    /// Sampled rather than reasoned about per pattern: every schedule in this app is set to the
    /// hour — `Clock` only ever steps hours — so an hourly walk catches everything a cleverer
    /// per-pattern intersection would, and it cannot fall out of step when a pattern is added.
    static func eveningSamples(from nudge: Date, calendar: Calendar = .current) -> [Date] {
        let hours = (24 - nudgeHour) + morningHour
        return (0..<hours).compactMap { calendar.date(byAdding: .hour, value: $0, to: nudge) }
    }

    /// **The offered session: from the moment it is accepted until 06:00.**
    ///
    /// Accepted at 18:00 that is exactly the 18:00 → 06:00 window the offer promised. Accepted at
    /// 20:00 — a notification noticed late — it is 20:00 → 06:00 rather than a window that started
    /// in the past and would look armed while the apps opened fine.
    ///
    /// Starting a minute early is the same trick the "Now" preset uses: the shield has to go up on
    /// this tap, not at the next scheduled edge.
    static func session(acceptedAt now: Date, calendar: Calendar = .current) -> ArmorPattern? {
        guard let sameDayMorning = calendar.date(bySettingHour: morningHour, minute: 0, second: 0,
                                                 of: now) else { return nil }
        let end = sameDayMorning > now
            ? sameDayMorning
            : calendar.date(byAdding: .day, value: 1, to: sameDayMorning)
        guard let end else { return nil }
        return .dateRange(start: now.addingTimeInterval(-60), end: end)
    }

    /// What the offered session is called once it is armed.
    static let sessionName = "Payday"

    /// **Whether the offered session can be started at all.**
    ///
    /// `ArmorStore` holds exactly one window, so arming the payday session over a standing guard
    /// would delete it — silently, with no undo, which is the one failure this app cannot have.
    /// The offer is therefore only booked when nothing is armed, and asked again here at the tap:
    /// a notification booked weeks ago can be stale by the time it is answered.
    ///
    /// The rule lives on the model rather than in the controller for the reason `ArmorController`
    /// already gives about locked guards — a UI guarantee stops holding the moment somebody adds a
    /// second way in, and the payday offer is exactly that second way in.
    static func canStartOfferedSession(whileArmed window: ArmorWindow?) -> Bool { window == nil }
}

// MARK: - the two notifications

/// **Which of the two payday notifications a given payday evening has earned.**
///
/// The whole table, in one type. See `Payday`'s doc comment for why neither exists unless a payday
/// has been set.
enum PaydayNotice: Equatable {
    /// *"Wanna start blocking now?"* — **nothing at all is armed**, so this asks.
    ///
    /// Scheduled ahead, because an offer is allowed to go stale: you can ignore it, and the tap
    /// checks again before it arms anything.
    case offer
    /// *"Blocked for Payday"* — the armed guard genuinely covers payday evening.
    ///
    /// **Never scheduled ahead.** It is a statement, so it must be true when it fires — which means
    /// it is sent by the thing that actually raises the shield (`ShieldMonitor.intervalDidStart`)
    /// and not by a timer that assumes the shield went up.
    case alreadyBlocked

    /// **Nil means silence, and silence is a real outcome here.**
    ///
    /// Three ways to get it: no payday set, so neither notification exists at all; or a guard is
    /// armed but misses payday evening — office hours on the 25th — which earns neither, because
    /// there is only one window to hold a guard in (so nothing can be offered) and the guard that
    /// is running is not about payday (so nothing can be claimed).
    static func decide(payday: Payday?, window: ArmorWindow?, nudgeAt: Date,
                       calendar: Calendar = .current) -> PaydayNotice? {
        guard payday != nil else { return nil }
        guard let window else { return .offer }
        let coversPaydayEvening = Payday.eveningSamples(from: nudgeAt, calendar: calendar)
            .contains { window.covers($0, calendar: calendar) }
        return coversPaydayEvening ? .alreadyBlocked : nil
    }

    // MARK: sending

    /// Identifiers carry a prefix so cancelling only ever touches Sale Armor's own payday requests.
    static let offerPrefix = "payday.offer."
    static let statusPrefix = "payday.status."

    /// **Re-books the next few offers from scratch.** Called on launch, on every foreground, and
    /// whenever anything is armed or disarmed — because arming *anything* withdraws the offer
    /// (there is only one window, and it is taken), and the queue has to agree.
    ///
    /// Booked as one-shot requests rather than one repeating trigger: a repeating calendar trigger
    /// cannot express "the 31st, or the last day of a short month", a last working day, or a
    /// fortnight.
    static func refreshOffers(payday: Payday?,
                              window: ArmorWindow?,
                              now: Date = Date(),
                              calendar: Calendar = .current,
                              center: UNUserNotificationCenter = .current()) {
        center.getPendingNotificationRequests { pending in
            let ours = pending.map(\.identifier).filter { $0.hasPrefix(offerPrefix) }
            center.removePendingNotificationRequests(withIdentifiers: ours)

            guard let payday else { return }
            for nudge in payday.upcoming(after: now, count: Payday.offersBookedAhead, calendar: calendar)
            where decide(payday: payday, window: window, nudgeAt: nudge, calendar: calendar) == .offer {
                center.add(offerRequest(at: nudge, calendar: calendar))
            }
        }
    }

    private static func offerRequest(at nudge: Date, calendar: Calendar) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = "Payday"
        content.body = "Money's landed. Start blocking now?"
        content.sound = .default

        let fields: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute]
        return UNNotificationRequest(
            identifier: offerPrefix + dayStamp(nudge, calendar: calendar),
            content: content,
            trigger: UNCalendarNotificationTrigger(
                dateMatching: calendar.dateComponents(fields, from: nudge), repeats: false))
    }

    /// **Sent by whatever actually shut the apps**, so "Blocked for Payday" is a fact by the time
    /// it arrives.
    ///
    /// Runs the same branch the booking side runs, against the window that was just raised: today
    /// being payday is not enough, because a nine-to-five guard shutting at 09:00 on the 25th has
    /// nothing to do with payday and saying so would be a lie from the one app that must not tell
    /// them.
    ///
    /// **Silent.** Whole-day patterns start their interval at 00:00, so even a correct status
    /// notice can arrive at midnight — and a statement nobody has to act on must not wake anyone.
    /// The offer keeps its sound; it is the one that asks a question.
    ///
    /// Sent at most once per payday: several activities can start on the same day — a monthly
    /// pattern with two dates, a weekly one with three — and a second "we're blocking" is the
    /// re-nag this app does not do.
    static func postStatus(payday: Payday?,
                           window: ArmorWindow?,
                           now: Date = Date(),
                           calendar: Calendar = .current,
                           center: UNUserNotificationCenter = .current()) {
        guard let payday, let nudgeAt = payday.nudge(on: now, calendar: calendar),
              decide(payday: payday, window: window, nudgeAt: nudgeAt,
                     calendar: calendar) == .alreadyBlocked else { return }

        let today = dayStamp(now, calendar: calendar)
        guard ArmorStore.claimPaydayStatus(today) else { return }

        let content = UNMutableNotificationContent()
        content.title = "Blocked for Payday"
        content.body = "Your apps are shut. Nothing to do."
        content.sound = nil

        // No trigger: it has already happened.
        center.add(UNNotificationRequest(identifier: statusPrefix + today,
                                         content: content, trigger: nil))
    }

    /// One payday, one identifier. The day is the natural key — a payday cannot happen twice.
    static func dayStamp(_ date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}
