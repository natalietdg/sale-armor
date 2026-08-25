import Foundation

/// **The "When" form, as data — so its two halves can be held against each other by a test.**
///
/// The form used to keep its chosen shape as a raw segment index, with the preset buttons writing
/// one numbering and the pattern reader interpreting another. `"Now"` was added at the front of the
/// segments and only the reader was renumbered, so every preset armed the shape one below the one
/// it meant: "Late night" armed a stale one-off date range, "Retail therapy" ran every day instead
/// of at weekends, "Black Friday" threw its own dates away. Nothing caught it, because the reader's
/// `default:` arm quietly absorbed every mismatch.
///
/// So the index is gone. One enum drives both the segments and the reader, the reader switches over
/// it with **no `default:`**, and `apply` and `pattern(now:)` are a round trip a unit test can run —
/// which is why this lives in `Shared` rather than inside the view that draws it.
struct SchedulePlan: Equatable {

    /// The segments of the "When" control, in the order they are drawn.
    enum Shape: Int, CaseIterable, Identifiable {
        case now, once, daily, weekly, monthly, doubleDates

        var id: Int { rawValue }

        /// Short enough for all six to sit on one phone-width row.
        var title: String {
            switch self {
            case .now:         "Now"
            case .once:        "Once"
            case .daily:       "Daily"
            case .weekly:      "Days"
            case .monthly:     "Dates"
            case .doubleDates: "N.N"
            }
        }
    }

    var shape: Shape = .daily                     // every day, the commonest case
    var start = Date()
    var end = Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date()
    var from = Clock.evening
    var to = Clock.lateNight
    var weekdays: Set<Int> = [6, 7]               // Friday, Saturday
    var monthDays: Set<Int> = [25]                // payday
    /// How long "now" lasts, in hours.
    var nowHours = 3

    /// No `default:` on purpose. A seventh shape has to be answered for here, or the app stops
    /// compiling — which is the whole point of the enum.
    func pattern(now: Date = Date()) -> ArmorPattern {
        switch shape {
        // A window that has already started. `syncWithClock` raises the shield the moment this is
        // armed, so the apps shut immediately rather than at the next scheduled edge.
        case .now:         .dateRange(start: now.addingTimeInterval(-60),
                                      end: now.addingTimeInterval(TimeInterval(nowHours) * 3600))
        case .once:        .dateRange(start: start, end: end)
        case .daily:       .daily(from: from, to: to)
        case .weekly:      .weekly(weekdays: weekdays, from: from, to: to)
        case .monthly:     .monthly(days: monthDays)
        case .doubleDates: .doubleDates
        }
    }

    /// Fills the form in from a preset. Every control stays live afterwards, so this is a starting
    /// point rather than a decision taken away.
    mutating func apply(_ sale: SaleKind, now: Date = Date(), calendar: Calendar = .current) {
        switch sale.pattern(now: now, calendar: calendar) {
        case let .dateRange(s, e):    shape = .once;    start = s; end = e
        case let .daily(f, t):        shape = .daily;   from = f; to = t
        case let .weekly(days, f, t): shape = .weekly;  weekdays = days; from = f; to = t
        case let .monthly(days):      shape = .monthly; monthDays = days
        case .doubleDates:            shape = .doubleDates
        }
    }
}
