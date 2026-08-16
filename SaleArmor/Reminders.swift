import Foundation
import UserNotifications

/// One notification per parked thing, fired when its cooling-off ends. Nothing else, ever.
///
/// Sale Armor promises no streaks, no guilt, and no notification telling you you have slipped, and
/// this does not break that promise: it is the question the product exists to ask, delivered at the
/// only moment it is worth asking. **There is no daily digest, no re-nag, and no reminder for
/// something already decided.** If a person ignores the one notification, that is an answer too.
///
/// Permission is requested when the first thing is parked rather than at launch. A prompt that
/// arrives while someone is using the feature is a prompt they understand; one that arrives on a
/// cold launch is one they decline.
enum Reminders {
    /// The prefix makes the app's own requests identifiable, so cancelling never touches anything
    /// scheduled by something else.
    private static let prefix = "cooled."

    private static func identifier(for item: WishItem) -> String { prefix + item.id.uuidString }

    /// Asks once. A refusal is remembered by the system, so calling this again is a no-op rather
    /// than a second prompt.
    static func requestPermission() async {
        _ = try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound])
    }

    /// Schedules the check for the moment this item goes cool.
    ///
    /// Nothing is scheduled if that moment has already passed — the card is on screen by then, and
    /// a notification about something already visible is noise.
    static func scheduleCheck(for item: WishItem,
                              now: Date = Date(),
                              calendar: Calendar = .current) {
        guard let due = calendar.date(byAdding: .day, value: WishItem.coolingOff, to: item.addedAt),
              due > now else { return }

        let content = UNMutableNotificationContent()
        content.title = "Still worth it?"
        content.body = "\(item.name) has been parked \(WishItem.coolingOff) days."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: identifier(for: item),
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: due.timeIntervalSince(now),
                                                       repeats: false))
        UNUserNotificationCenter.current().add(request)
    }

    /// Decided early, or deleted. Either way the question is spent and must not arrive later.
    static func cancelCheck(for id: UUID) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [prefix + id.uuidString])
    }
}
