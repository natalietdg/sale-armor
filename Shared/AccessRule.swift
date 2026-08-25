import Foundation

/// **Where a "this account owns nothing" answer came from, and whether it may lock the app.**
///
/// The distinction exists because the two sources are not equally trustworthy, and the code that
/// reads them cannot tell them apart afterwards. A `customerInfo()` read describes the Apple
/// Account signed in right now. A restore may have run against an entirely different one — someone
/// signing in to check a family member's purchases produces the same empty response as a genuine
/// lapse.
///
/// Locking the wrong person is the expensive mistake: a paying subscriber who opens the app and
/// finds the paywall asks for a refund and leaves a one-star review. Leaving the wrong person
/// unlocked costs a few days of access until the next direct read corrects it.
///
/// This lives in `Shared/` rather than beside `Subscription` so it can be tested. The test target
/// compiles `SaleArmorTests` and `Shared` only, with no dependency on the app target, so a rule
/// left inside `Subscription` is a rule nothing can pin.
enum EntitlementAnswer {
    /// A direct read of the account signed in now — `customerInfo()`, or a purchase that just
    /// finished. Real information about this install.
    case directRead
    /// A restore. Says nothing reliable about this install, because it may not be this account.
    case restore

    /// Whether an answer carrying no entitlement is allowed to overwrite a cache that says "paid".
    var mayLock: Bool { self == .directRead }
}

/// The whole access rule, in one place, as a value.
///
/// Deliberately a pure function of two booleans: `Subscription` decides *when* to call it, and this
/// decides *what the answer means*. Splitting them is what makes the rule checkable at all.
enum AccessRule {
    /// Whether to write the entitlement state through to `isActive` and the cache.
    ///
    /// An entitled answer always writes — being told "yes" is never ambiguous. An empty answer
    /// writes only when its source was allowed to lock.
    static func writesThrough(isEntitled: Bool, from answer: EntitlementAnswer) -> Bool {
        isEntitled || answer.mayLock
    }
}
