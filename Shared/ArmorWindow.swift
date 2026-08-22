import Foundation
import FamilyControls
import ManagedSettings
import DeviceActivity

/// **What gets shut, and when.**
///
/// Four shapes, because impulse spending has four shapes: a sale that happens once, a time of day
/// you always cave at, certain weekdays, and payday.
enum ArmorPattern: Codable, Equatable, Hashable {
    /// A one-off window. 11.11, Black Friday, a holiday.
    case dateRange(start: Date, end: Date)
    /// Every day between two times. The 11pm scroll.
    case daily(from: Clock, to: Clock)
    /// Chosen weekdays, between two times. 1 = Sunday, matching `Calendar`.
    case weekly(weekdays: Set<Int>, from: Clock, to: Clock)
    /// Whole days of the month. Payday, the 1st, the 25th.
    case monthly(days: Set<Int>)
    /// **The day that matches the month, every month**: 1.1, 2.2, 3.3 … 11.11, 12.12.
    /// A dozen sales a year, so it cannot be expressed as `monthly` — the day changes each time.
    case doubleDates

    /// The longest single stretch this pattern keeps the shield up, or nil when it does not have a
    /// bounded one. Only locked guards ask, and only to refuse a lock nobody could live with.
    ///
    /// A repeating pattern is measured by one occurrence rather than by the whole schedule: a nightly
    /// 9pm–7am guard shuts the apps for ten hours at a time, not forever, and there is a way out of
    /// it every single morning.
    func longestRun(calendar: Calendar = .current) -> TimeInterval? {
        func span(_ from: Clock, _ to: Clock) -> TimeInterval {
            let a = from.hour * 60 + from.minute, b = to.hour * 60 + to.minute
            return TimeInterval(((b - a) + 24 * 60) % (24 * 60)) * 60
        }
        switch self {
        case let .dateRange(start, end): return end.timeIntervalSince(start)
        case let .daily(from, to):       return span(from, to)
        case let .weekly(_, from, to):   return span(from, to)
        case .monthly, .doubleDates:     return 24 * 3600   // whole days, one at a time
        }
    }

    var label: String {
        switch self {
        case .dateRange:  "Once"
        case .daily:      "Every day"
        case .weekly:     "Some days"
        case .monthly:    "Days of the month"
        case .doubleDates: "Double dates"
        }
    }
}

/// A time of day, to the minute. Stored rather than a `Date` because "11pm" is not a date.
struct Clock: Codable, Equatable, Hashable, Comparable {
    var hour: Int
    var minute: Int

    var components: DateComponents { DateComponents(hour: hour, minute: minute) }
    var text: String { String(format: "%02d:%02d", hour, minute) }

    /// Ordering is what tells a window that wraps midnight (21:00 → 02:00) from one that doesn't.
    private var minutes: Int { hour * 60 + minute }
    static func < (a: Clock, b: Clock) -> Bool { a.minutes < b.minutes }

    static let evening = Clock(hour: 21, minute: 0)
    static let lateNight = Clock(hour: 2, minute: 0)
}

/// **One armed guard: some apps, and a pattern that says when they are shut.**
/// **How much rope the guard gives you.**
///
/// The whole product rests on a decision made at two in the afternoon binding the person who shows
/// up at 1:47 in the morning. A guard you can end whenever you like is friction, which is enough
/// for most people most of the time. A guard you cannot end is precommitment, which is the only
/// answer to "can't I just switch it off?".
enum GuardMode: String, Codable, Equatable {
    /// Friction when you want it. Disarm whenever.
    case standard
    /// No negotiating later. Sale Armor will not end this one early.
    case locked

    /// **Locked guards are capped, and this is why.**
    ///
    /// Somebody who locks Amazon for thirty days and then needs a replacement charger tomorrow has
    /// been failed by the feature, not helped by it. Three days covers every window this app is
    /// actually for — a night, a payday, a sale weekend — and is short enough that a mistake is
    /// survivable rather than something to uninstall the app over.
    static let lockedLimit: TimeInterval = 72 * 3600
}

struct ArmorWindow: Codable, Equatable {
    var name: String
    var pattern: ArmorPattern

    /// Standard unless chosen otherwise.
    ///
    /// Decoded with a default rather than required: a window saved before this existed must still
    /// load, and the failure mode of a stricter decode is somebody's armed guard silently vanishing
    /// on upgrade.
    var mode: GuardMode = .standard

    /// The chosen apps, as opaque tokens. **This app never learns which apps they are** — the
    /// picker hands back tokens the system can resolve and we cannot.
    var selection: FamilyActivitySelection

    var isEmpty: Bool {
        selection.applicationTokens.isEmpty && selection.categoryTokens.isEmpty
    }

    var appCount: Int {
        selection.applicationTokens.count + selection.categoryTokens.count
    }

    /// Whether Sale Armor will let this guard be ended right now.
    ///
    /// **Deliberately not "can this be bypassed".** It cannot be made impossible: Family Controls
    /// authorization can be revoked in Settings, and deleting the app clears its ManagedSettings
    /// along with it. No iPhone app is sovereign over the person holding the phone, and copy that
    /// claims otherwise is a promise the product cannot keep. What this returns is the honest
    /// version — whether *this app* will do it for you.
    func canDisarm(at date: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard mode == .locked else { return true }
        return !covers(date, calendar: calendar)
    }

    /// Whether the shield should be up at this instant. The extension handles the edges; this is
    /// what the app itself checks on launch so a stale shield never outlives its window.
    func covers(_ date: Date, calendar: Calendar = .current) -> Bool {
        switch pattern {
        case let .dateRange(start, end):
            return date >= start && date < end
        case let .daily(from, to):
            return withinTime(date, from, to, calendar)
        case let .weekly(weekdays, from, to):
            let today = calendar.component(.weekday, from: date)
            // A window that runs past midnight belongs to the day it STARTED on, so Friday 9pm–2am
            // is still Friday's window at 1am on Saturday.
            let startedYesterday = to <= from
                && withinTime(date, Clock(hour: 0, minute: 0), to, calendar)
            let day = startedYesterday ? (today == 1 ? 7 : today - 1) : today
            return weekdays.contains(day) && withinTime(date, from, to, calendar)
        case let .monthly(days):
            return days.contains(calendar.component(.day, from: date))
        case .doubleDates:
            return calendar.component(.day, from: date) == calendar.component(.month, from: date)
        }
    }

    init(name: String, pattern: ArmorPattern, selection: FamilyActivitySelection,
         mode: GuardMode = .standard) {
        self.name = name
        self.pattern = pattern
        self.selection = selection
        self.mode = mode
    }

    init(from decoder: Decoder) throws {
        let box = try decoder.container(keyedBy: CodingKeys.self)
        name = try box.decode(String.self, forKey: .name)
        pattern = try box.decode(ArmorPattern.self, forKey: .pattern)
        selection = try box.decode(FamilyActivitySelection.self, forKey: .selection)
        mode = try box.decodeIfPresent(GuardMode.self, forKey: .mode) ?? .standard
    }

    /// True when `date`'s time of day falls in the window, including windows that wrap midnight.
    private func withinTime(_ date: Date, _ from: Clock, _ to: Clock, _ calendar: Calendar) -> Bool {
        let now = calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
        let a = from.hour * 60 + from.minute, b = to.hour * 60 + to.minute
        return a <= b ? (now >= a && now < b) : (now >= a || now < b)
    }
}

// MARK: - the wishlist

/// **The thing you wanted, and what happened.**
///
/// A blocker only ever takes things away. This is the half that gives something back: every time
/// the shield stops a purchase, the money is not gone — it is counted.
///
/// **No goals, no targets, no streaks.** A running total of what you did not spend, and nothing
/// that turns saving into a game you can lose.
struct WishItem: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    var name: String
    /// Where it was. Kept so a decision later is made against the real thing, not a memory of it.
    var link: String?
    var price: Double
    var addedAt: Date = Date()
    /// Set when they decide not to buy it. Nil while it is still wanted.
    var skippedAt: Date?
    /// Set if they bought it anyway. **Recorded without judgement** — an app that punishes honesty
    /// gets lied to, and then its total is fiction.
    var boughtAt: Date?

    var isOpen: Bool { skippedAt == nil && boughtAt == nil }

    /// Whole days since it was parked.
    ///
    /// Shown as "survived", because waiting is the only thing that turns a want into a decision.
    /// It is also the honest unit: the app cannot know whether you wanted it less, only that you
    /// did not buy it, and for how long.
    func daysParked(now: Date = Date(), calendar: Calendar = .current) -> Int {
        max(0, calendar.dateComponents([.day], from: addedAt, to: now).day ?? 0)
    }

    /// Long enough for the impulse to have passed, so the question is worth asking.
    static let coolingOff = 3

    func isCool(now: Date = Date(), calendar: Calendar = .current) -> Bool {
        daysParked(now: now, calendar: calendar) >= Self.coolingOff
    }
}

struct Wishlist: Codable, Equatable {
    var items: [WishItem] = []

    var open: [WishItem] { items.filter(\.isOpen).sorted { $0.addedAt > $1.addedAt } }
    var skipped: [WishItem] { items.filter { $0.skippedAt != nil } }

    /// What the shield is worth so far.
    ///
    /// **Only things deliberately killed count.** Parking a thousand-pound coat does not make you a
    /// thousand pounds richer five seconds later, and a total that moved the moment you typed a
    /// price would be a number nobody believes — including the person who typed it.
    var saved: Double { skipped.reduce(0) { $0 + $1.price } }

    /// How many wants were seen off. The count is the streak-free version of a streak.
    var killed: Int { skipped.count }

    mutating func add(_ item: WishItem) { items.append(item) }

    mutating func skip(_ id: UUID, at date: Date = Date()) {
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        items[i].skippedAt = date
        items[i].boughtAt = nil
    }

    mutating func bought(_ id: UUID, at date: Date = Date()) {
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        items[i].boughtAt = date
        items[i].skippedAt = nil
    }

    mutating func remove(_ id: UUID) { items.removeAll { $0.id == id } }
}

// MARK: - the shared box

/// **One place the app and the extension both read.** They are separate processes, so a plain
/// `UserDefaults.standard` would be two different boxes.
enum ArmorStore {
    static let appGroup = "group.com.natalieleong.salearmor"
    private static let windowKey = "salearmor.window.v2"
    private static let wishKey = "salearmor.wishlist.v1"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroup) ?? .standard
    }

    static func load() -> ArmorWindow? {
        guard let data = defaults.data(forKey: windowKey) else { return nil }
        return try? JSONDecoder().decode(ArmorWindow.self, from: data)
    }

    static func save(_ window: ArmorWindow?) {
        guard let window, let data = try? JSONEncoder().encode(window) else {
            defaults.removeObject(forKey: windowKey)
            return
        }
        defaults.set(data, forKey: windowKey)
    }

    static func loadWishlist() -> Wishlist {
        guard let data = defaults.data(forKey: wishKey),
              let list = try? JSONDecoder().decode(Wishlist.self, from: data) else { return Wishlist() }
        return list
    }

    static func saveWishlist(_ list: Wishlist) {
        guard let data = try? JSONEncoder().encode(list) else { return }
        defaults.set(data, forKey: wishKey)
    }
}

// MARK: - raising and dropping the shield

extension ManagedSettingsStore.Name {
    static let armor = Self("salearmor")
}

enum Shield {
    private static var store: ManagedSettingsStore { ManagedSettingsStore(named: .armor) }

    static func raise(for window: ArmorWindow) {
        store.shield.applications = window.selection.applicationTokens.isEmpty
            ? nil : window.selection.applicationTokens
        store.shield.applicationCategories = window.selection.categoryTokens.isEmpty
            ? nil : .specific(window.selection.categoryTokens)
    }

    /// **Clearing has to be unconditional.** Apps left shut after a window is over is the one
    /// failure this app cannot have — there is no quick way for a user to undo it.
    static func drop() {
        store.shield.applications = nil
        store.shield.applicationCategories = nil
    }
}

// MARK: - the schedule

enum ArmorSchedule {
    static let prefix = "salearmor.window"

    /// One pattern can need several monitored activities: a weekly guard on three days is three
    /// schedules, because `DeviceActivitySchedule` carries a single interval.
    static func activities(for window: ArmorWindow) -> [(DeviceActivityName, DeviceActivitySchedule)] {
        let all = DateComponents(hour: 0, minute: 0)
        let endOfDay = DateComponents(hour: 23, minute: 59)

        switch window.pattern {
        case let .dateRange(start, end):
            let fields: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute]
            return [(DeviceActivityName("\(prefix).once"),
                     DeviceActivitySchedule(
                        intervalStart: Calendar.current.dateComponents(fields, from: start),
                        intervalEnd: Calendar.current.dateComponents(fields, from: end),
                        repeats: false))]

        case let .daily(from, to):
            return [(DeviceActivityName("\(prefix).daily"),
                     DeviceActivitySchedule(intervalStart: from.components,
                                            intervalEnd: to.components,
                                            repeats: true))]

        case let .weekly(weekdays, from, to):
            return weekdays.sorted().map { day in
                var start = from.components; start.weekday = day
                var end = to.components; end.weekday = day
                return (DeviceActivityName("\(prefix).weekly.\(day)"),
                        DeviceActivitySchedule(intervalStart: start, intervalEnd: end, repeats: true))
            }

        case let .monthly(days):
            return days.sorted().map { day in
                var start = all; start.day = day
                var end = endOfDay; end.day = day
                return (DeviceActivityName("\(prefix).monthly.\(day)"),
                        DeviceActivitySchedule(intervalStart: start, intervalEnd: end, repeats: true))
            }

        case .doubleDates:
            // Twelve schedules, one per month, each pinned to the day matching its month. A
            // repeating interval carries a single day, so 1.1 through 12.12 is twelve of them.
            return (1...12).map { month in
                var start = all; start.month = month; start.day = month
                var end = endOfDay; end.month = month; end.day = month
                return (DeviceActivityName("\(prefix).double.\(month)"),
                        DeviceActivitySchedule(intervalStart: start, intervalEnd: end, repeats: true))
            }
        }
    }

    static func start(_ window: ArmorWindow) throws {
        let center = DeviceActivityCenter()
        stop()
        for (name, schedule) in activities(for: window) {
            try center.startMonitoring(name, during: schedule)
        }
    }

    /// Stops **every** activity this app owns, not just the ones the current pattern would create.
    /// Switching from weekly to daily must not leave last week's schedules running.
    static func stop() {
        let center = DeviceActivityCenter()
        let ours = center.activities.filter { $0.rawValue.hasPrefix(prefix) }
        center.stopMonitoring(ours)
    }
}

// MARK: - the kinds of trouble

/// **The five shapes impulse spending actually takes.**
///
/// A blank "what is it" field asked the user to invent a name and then work out a schedule for it.
/// These name the thing and bring their own schedule, so arming a guard is one tap and a check.
/// Every preset stays editable afterwards — it is a starting point, not a rule.
enum SaleKind: String, CaseIterable, Identifiable {
    case lateNight      = "Late-night scroll"
    case payday         = "Payday sale"
    case blackFriday    = "Black Friday"
    case doubleDate     = "Double-date sale"
    case retailTherapy  = "Retail therapy"

    var id: String { rawValue }

    /// What you are actually fighting. Flavour, not progression — there is no XP here and
    /// nothing to level, because a wellbeing app you can lose is one people delete.
    var foe: String {
        switch self {
        case .lateNight:     return "Imp"
        case .retailTherapy: return "Siren"
        case .payday:        return "Coin Wraith"
        case .doubleDate:    return "The Twins"
        case .blackFriday:   return "Demon"
        }
    }

    /// Tier is earned by the shape of the threat, not invented: an imp is nightly and short, a
    /// boss is annual and four days long.
    var tier: String {
        switch self {
        case .lateNight, .retailTherapy: return "Normal"
        case .payday, .doubleDate:       return "Elite"
        case .blackFriday:               return "Boss"
        }
    }

    /// Rarity, so the tier reads at a glance without being explained.
    var tierRank: Int {
        switch self {
        case .lateNight, .retailTherapy: return 0
        case .payday, .doubleDate:       return 1
        case .blackFriday:               return 2
        }
    }

    /// A short label for the chip.
    ///
    /// The double-date one is **computed from the calendar**, so in September it reads 9.9 and in
    /// November 11.11. A fixed "9.9 · 11.11" would be wrong eleven months of the year and would
    /// not tell anyone which sale is actually coming.
    func short(now: Date = Date(), calendar: Calendar = .current) -> String {
        switch self {
        case .lateNight:     return "Late night"
        case .payday:        return "Payday"
        case .blackFriday:   return "Black Friday"
        case .doubleDate:  return "Double dates"
        case .retailTherapy: return "Retail therapy"
        }
    }

    func pattern(now: Date = Date(), calendar: Calendar = .current) -> ArmorPattern {
        switch self {
        case .lateNight:
            // The scroll that starts as a wind-down and ends as a checkout.
            return .daily(from: Clock(hour: 21, minute: 0), to: Clock(hour: 2, minute: 0))

        case .payday:
            // Money lands and the apps know it.
            return .monthly(days: [25, 1])

        case .blackFriday:
            let start = SaleDates.nextBlackFriday(after: now, calendar: calendar)
            // Through Cyber Monday, because the sale does not stop on the Friday.
            let end = calendar.date(byAdding: .day, value: 4, to: start) ?? start
            return .dateRange(start: start, end: end)

        case .doubleDate:
            // Every one of them: 1.1, 2.2, 3.3 … 12.12. Twelve sales a year, not one.
            return .doubleDates

        case .retailTherapy:
            // Not a sale. A mood, and it has a timetable: Friday to Sunday evenings.
            return .weekly(weekdays: [6, 7, 1],
                           from: Clock(hour: 18, minute: 0), to: Clock(hour: 23, minute: 30))
        }
    }
}

/// The two sale dates that have to be worked out rather than stored.
enum SaleDates {

    /// The Friday after the fourth Thursday of November — the next one that has not passed.
    static func nextBlackFriday(after now: Date, calendar: Calendar = .current) -> Date {
        for year in [calendar.component(.year, from: now), calendar.component(.year, from: now) + 1] {
            guard let friday = blackFriday(in: year, calendar: calendar) else { continue }
            if friday >= calendar.startOfDay(for: now) { return friday }
        }
        return now
    }

    private static func blackFriday(in year: Int, calendar: Calendar) -> Date? {
        var components = DateComponents()
        components.year = year
        components.month = 11
        components.weekday = 5          // Thursday
        components.weekdayOrdinal = 4   // the fourth one
        guard let thanksgiving = calendar.date(from: components) else { return nil }
        return calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: thanksgiving))
    }

    /// This month's double date — the day matching the month number. 8 Aug, 9 Sep, 11 Nov.
    /// If it has already gone by, the same date next year, so the window is never in the past.
    static func doubleDate(inMonthOf now: Date, calendar: Calendar = .current) -> Date {
        let month = calendar.component(.month, from: now)
        let year = calendar.component(.year, from: now)
        let thisYear = calendar.date(from: DateComponents(year: year, month: month, day: month))
        if let thisYear, thisYear >= calendar.startOfDay(for: now) { return thisYear }
        return calendar.date(from: DateComponents(year: year + 1, month: month, day: month))
            ?? calendar.startOfDay(for: now)
    }

    /// The next date whose day equals its month: 9 Sep, 10 Oct, 11 Nov, 12 Dec, then 1 Jan.
    static func nextDoubleDate(after now: Date, calendar: Calendar = .current) -> Date {
        let today = calendar.startOfDay(for: now)
        let year = calendar.component(.year, from: now)

        for (y, month) in ((1...12).map { (year, $0) } + (1...12).map { (year + 1, $0) }) {
            guard let date = calendar.date(from: DateComponents(year: y, month: month, day: month)),
                  date >= today else { continue }
            return date
        }
        return today
    }
}
