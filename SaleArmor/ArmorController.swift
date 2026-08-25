import Foundation
import SwiftUI
import FamilyControls
import ManagedSettings

/// Screenshot support, and nothing else.
///
/// A simulator has no Screen Time to grant and `FamilyActivityPicker` returns nothing there, so the
/// armed and wishlist screens — most of the app — cannot be reached to photograph. These flags fake
/// just enough to get there. **They compile to constant `false` in a release build**, so the
/// shipped binary has no demo path at all and the compiler strips every branch below.
enum Demo {
#if DEBUG
    private static let arguments = ProcessInfo.processInfo.arguments
    static let isOn = arguments.contains("-demo")
    /// Sample window and wishlist, held in memory only.
    static let isSeeded = isOn && arguments.contains("-seed")
    /// Opens on the second tab, so the wishlist can be shot without faking a tap.
    static let opensWishlist = isOn && arguments.contains("-wishlist")
    /// Shows the paywall with sample plans. A simulator cannot reach App Store products, so this
    /// is the only way to see the layout — and it is how the App Review screenshot is taken, since
    /// Apple needs to see where the subscription is presented, not a failed network call.
    static let showsPaywall = isOn && arguments.contains("-paywall")

    /// **Opens the gate without faking anything else.**
    ///
    /// `-demo` is for screenshots, so it stubs out the whole Screen Time layer: authorization is
    /// reported as approved without asking, the schedule is never started, and the shield is never
    /// raised. That makes it useless for the one thing you cannot check any other way — what a
    /// blocked app actually looks like.
    ///
    /// This flag skips only the paywall. Everything below it runs for real, so the Screen Time
    /// prompt appears, the picker returns real tokens and the shield genuinely goes up. Needed
    /// because the app is entirely gated and the store has no products until the Paid Apps
    /// Agreement is active.
    static let isUnlocked = arguments.contains("-unlocked")
#else
    static let isOn = false
    static let isSeeded = false
    static let opensWishlist = false
    static let showsPaywall = false
    static let isUnlocked = false
#endif
}

/// Arming, disarming, the wishlist, and keeping the shield honest with the clock.
///
/// The `DeviceActivity` extension raises and drops the shield while the app is closed. This object
/// does the same work on launch and on every foreground, because **a stale shield must never
/// outlive its window** — apps left shut after the window is the one failure with no easy escape.
@MainActor
final class ArmorController: ObservableObject {
    @Published private(set) var window: ArmorWindow?
    @Published private(set) var wishlist = Wishlist()
    @Published private(set) var authorization: AuthorizationStatus
    @Published private(set) var payday: Payday?
    @Published var problem: String?

    init() {
        authorization = Demo.isOn ? .approved : AuthorizationCenter.shared.authorizationStatus
        window = ArmorStore.load()
        wishlist = ArmorStore.loadWishlist()
        payday = ArmorStore.loadPayday()
        if Demo.isSeeded { seedForScreenshots() }
    }

    /// Sample state, held in memory and never written to the store.
    private func seedForScreenshots() {
        func daysAgo(_ days: Int) -> Date {
            Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        }
        window = ArmorWindow(name: "Payday",
                             pattern: .monthly(days: [25]),
                             selection: FamilyActivitySelection())
        wishlist = Wishlist(items: [
            WishItem(name: "New Balance 530", link: "shop.example.com", price: 489,
                     addedAt: daysAgo(5)),                       // cooled: wants an answer
            WishItem(name: "Second air fryer", price: 289, addedAt: daysAgo(1)),  // still cooling
            WishItem(name: "Concert resale ticket", price: 650,
                     addedAt: daysAgo(20), skippedAt: daysAgo(18)),
            WishItem(name: "COS bag", price: 690, addedAt: daysAgo(30), skippedAt: daysAgo(26)),
        ])
    }

    var isArmed: Bool { window != nil }
    var isShielding: Bool { window?.covers(Date()) == true }

    // MARK: permission

    /// `.individual`, not `.child` — this is a person shielding their own phone, so there is no
    /// parent, no pairing, and no Family Sharing requirement.
    func requestAuthorization() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            authorization = AuthorizationCenter.shared.authorizationStatus
            problem = nil
        } catch {
            authorization = AuthorizationCenter.shared.authorizationStatus
            problem = "Screen Time permission was declined. Sale Armor can't shut anything without it."
        }
    }

    // MARK: arming

    func arm(name: String, pattern: ArmorPattern, selection: FamilyActivitySelection,
             mode: GuardMode = .standard) {
        if case let .dateRange(start, end) = pattern, end <= start {
            problem = "The end has to come after the start."
            return
        }
        if case let .weekly(days, _, _) = pattern, days.isEmpty {
            problem = "Pick at least one day."
            return
        }
        if case let .monthly(days) = pattern, days.isEmpty {
            problem = "Pick at least one date."
            return
        }

        // A locked guard cannot be replaced either, not just not-disarmed.
        //
        // Today the setup form is unreachable while anything is armed, so this cannot be triggered
        // from the interface. That is a UI guarantee protecting a model invariant, and it stops
        // holding the moment someone adds a second way in — at which point "arm a new standard
        // guard" would be a one-tap bypass of the only feature that answers "can't I just turn it
        // off?". The rule belongs where the invariant is.
        if let current = window, !current.canDisarm() {
            problem = "\(current.name.isEmpty ? "The current guard" : current.name) is locked until it ends."
            return
        }

        // The cap is checked before anything is written, because the whole point of a locked guard
        // is that it cannot be undone afterwards — a mistake here is not correctable in the app.
        if mode == .locked, let span = pattern.longestRun(), span > GuardMode.lockedLimit {
            problem = "A locked guard can run for up to 3 days at a time."
            return
        }

        let candidate = ArmorWindow(name: name, pattern: pattern, selection: selection, mode: mode)
        guard !candidate.isEmpty || Demo.isOn else {
            problem = "Pick at least one app to shut."
            return
        }

        // **Save before scheduling.** The extension reads the window out of the shared store when
        // an interval starts, and a window starting now can wake it immediately.
        let previous = ArmorStore.load()
        ArmorStore.save(candidate)
        // Kept past the disarm, so the payday offer can start a session without asking again.
        ArmorStore.saveLastSelection(candidate.selection)
        do {
            // DeviceActivity has nothing to schedule against on a simulator.
            if !Demo.isOn { try ArmorSchedule.start(candidate) }
        } catch {
            ArmorStore.save(previous)
            problem = "Couldn't schedule that. \(error.localizedDescription)"
            return
        }

        window = candidate
        problem = nil
        syncWithClock()
    }

    /// One tap, never confirmed twice. A blocker that makes itself hard to switch off is a blocker
    /// people delete.
    /// Refuses while a locked guard is still running, and says so.
    ///
    /// This is the only place in the app that declines to do what it was asked, so it explains
    /// itself rather than doing nothing — a button that silently fails is a bug, and this has to
    /// read as the decision the user already made.
    @discardableResult
    func disarm(now: Date = Date()) -> Bool {
        if let window, !window.canDisarm(at: now) {
            problem = "\(window.name.isEmpty ? "This guard" : window.name) is locked until it ends."
            return false
        }
        ArmorSchedule.stop()
        Shield.drop()
        window = nil
        ArmorStore.save(nil)
        problem = nil
        // Payday evening is no longer covered, so its notice turns back into an offer.
        refreshPaydayOffers(now: now)
        return true
    }

    // MARK: payday

    /// Sets — or clears — the day money lands.
    ///
    /// **This is the only thing that brings the payday notifications into existence.** Clearing it
    /// takes them away again, pending offers included.
    func setPayday(_ payday: Payday?) {
        self.payday = payday
        ArmorStore.savePayday(payday)
        refreshPaydayOffers()

        guard payday != nil, !Demo.isOn else { return }
        // Asked here rather than at launch, for the same reason the wishlist asks when you park
        // something: a prompt that arrives while you are using the feature is one you understand.
        Task { await Reminders.requestPermission() }
    }

    /// One tap on the offer: the session it promised, from now until 6am.
    ///
    /// **Refuses while anything is armed.** The offer is only booked when nothing is, but a booked
    /// notification can be weeks old — arm a nightly guard on the 20th and tap the 25th's offer and
    /// this would otherwise replace that guard, silently and with no undo. `arm` itself only
    /// refuses *locked* guards, exactly as the comment above it predicted.
    ///
    /// Reuses the apps from the last guard. With none remembered, `arm` refuses and says "Pick at
    /// least one app to shut" on the form the app has just opened onto — which is the honest
    /// outcome, not a silent no-op.
    func acceptPaydayOffer(now: Date = Date()) {
        guard Payday.canStartOfferedSession(whileArmed: window) else {
            let armed = window.map { $0.name.isEmpty ? "A guard" : $0.name } ?? "A guard"
            problem = "\(armed) is already armed. Disarm it first if you want the payday session."
            return
        }
        guard let pattern = Payday.session(acceptedAt: now) else { return }
        arm(name: Payday.sessionName,
            pattern: pattern,
            selection: ArmorStore.loadLastSelection() ?? FamilyActivitySelection(),
            mode: .standard)
    }

    private func refreshPaydayOffers(now: Date = Date()) {
        guard !Demo.isOn else { return }
        PaydayNotice.refreshOffers(payday: payday, window: window, now: now)
    }

    // MARK: the wishlist

    func addWish(name: String, link: String?, price: Double) {
        // Stored with its scheme, so the saved value is the one that opens. A string that cannot be
        // a web address is kept as typed and simply never drawn as a link — see `WishItem.url`.
        let trimmed = link?.trimmingCharacters(in: .whitespaces)
        let cleaned = WishItem.url(from: trimmed)?.absoluteString
            ?? ((trimmed?.isEmpty ?? true) ? nil : trimmed)
        let item = WishItem(name: name, link: cleaned, price: max(0, price))
        wishlist.add(item)
        persistWishlist()

        guard !Demo.isOn else { return }
        // Asked here rather than at launch: a prompt that arrives while you are using the feature
        // is one you understand. The check is what makes parking work — without it, the decision
        // only happens if you happen to open the app on the right day.
        Task {
            await Reminders.requestPermission()
            Reminders.scheduleCheck(for: item)
        }
    }

    /// Deciding cancels the pending check. A question already answered must never arrive later.
    func skip(_ id: UUID) { decide { wishlist.skip(id) }; Reminders.cancelCheck(for: id) }
    func bought(_ id: UUID) { decide { wishlist.bought(id) }; Reminders.cancelCheck(for: id) }
    func removeWish(_ id: UUID) { decide { wishlist.remove(id) }; Reminders.cancelCheck(for: id) }

    private func decide(_ change: () -> Void) {
        change()
        persistWishlist()
    }

    private func persistWishlist() { ArmorStore.saveWishlist(wishlist) }

    // MARK: keeping it true

    func syncWithClock(now: Date = Date()) {
        guard !Demo.isOn else { return }
        // Offers are booked months ahead, so they are re-decided on every foreground: what is
        // armed by then decides whether payday earns an offer or a status notice.
        defer { refreshPaydayOffers(now: now) }
        guard let window else {
            Shield.drop()
            return
        }
        if window.covers(now) {
            Shield.raise(for: window)
        } else {
            Shield.drop()
            // A one-off window that has passed is spent. Repeating patterns stay armed.
            if case let .dateRange(_, end) = window.pattern, now >= end {
                ArmorSchedule.stop()
                self.window = nil
                ArmorStore.save(nil)
            }
        }
    }
}
