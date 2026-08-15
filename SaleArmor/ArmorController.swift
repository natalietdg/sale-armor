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
#else
    static let isOn = false
    static let isSeeded = false
    static let opensWishlist = false
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
    @Published var problem: String?

    init() {
        authorization = Demo.isOn ? .approved : AuthorizationCenter.shared.authorizationStatus
        window = ArmorStore.load()
        wishlist = ArmorStore.loadWishlist()
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
            WishItem(name: "Running shoes", link: "shop.example.com", price: 420,
                     addedAt: daysAgo(2)),
            WishItem(name: "Second air fryer", price: 289,
                     addedAt: daysAgo(9), skippedAt: daysAgo(6)),
            WishItem(name: "Concert resale ticket", price: 650,
                     addedAt: daysAgo(20), skippedAt: daysAgo(18)),
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

    func arm(name: String, pattern: ArmorPattern, selection: FamilyActivitySelection) {
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

        let candidate = ArmorWindow(name: name, pattern: pattern, selection: selection)
        guard !candidate.isEmpty || Demo.isOn else {
            problem = "Pick at least one app to shut."
            return
        }

        // **Save before scheduling.** The extension reads the window out of the shared store when
        // an interval starts, and a window starting now can wake it immediately.
        let previous = ArmorStore.load()
        ArmorStore.save(candidate)
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
    func disarm() {
        ArmorSchedule.stop()
        Shield.drop()
        window = nil
        ArmorStore.save(nil)
        problem = nil
    }

    // MARK: the wishlist

    func addWish(name: String, link: String?, price: Double) {
        let trimmed = link?.trimmingCharacters(in: .whitespaces)
        wishlist.add(WishItem(name: name,
                              link: (trimmed?.isEmpty ?? true) ? nil : trimmed,
                              price: max(0, price)))
        persistWishlist()
    }

    func skip(_ id: UUID) { wishlist.skip(id); persistWishlist() }
    func bought(_ id: UUID) { wishlist.bought(id); persistWishlist() }
    func removeWish(_ id: UUID) { wishlist.remove(id); persistWishlist() }

    private func persistWishlist() { ArmorStore.saveWishlist(wishlist) }

    // MARK: keeping it true

    func syncWithClock(now: Date = Date()) {
        guard !Demo.isOn else { return }
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
