import ManagedSettings
import ManagedSettingsUI
import SwiftUI
import UIKit

/// **The screen you actually see at 1:47 AM.**
///
/// Everything else in this app is setup. This is the product: the moment you tap the shopping app
/// and it does not open. Without this extension iOS draws its own grey panel — a padlock, the words
/// "Restricted", and a line about Screen Time limits — which is accurate, anonymous, and reads like
/// a phone malfunction rather than like something you chose.
///
/// ## Why it names the window back to you
///
/// A block with no author feels like an obstacle. A block that says **PAYDAY** feels like a
/// decision you made, being kept. The extension reads the armed window out of the shared App Group
/// and prints its name, so the shield is quoting you rather than scolding you.
///
/// It never says how much you have saved, how many times you have tried, or how you are doing.
/// This screen appears at the worst moment of someone's evening; the one thing it must not do is
/// have an opinion about them.
///
/// ## What it cannot know
///
/// The parameter is an `Application` whose `localizedDisplayName` is nil unless the system decides
/// otherwise, and there is no token-to-name lookup. The copy is therefore written to work without
/// ever naming the app being blocked — which is the same privacy property the picker has, enforced
/// here by the API rather than by our good behaviour.
class ShieldConfig: ShieldConfigurationDataSource {

    // MARK: - the four entry points

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        armed()
    }

    override func configuration(shielding application: Application,
                                in category: ActivityCategory) -> ShieldConfiguration {
        armed()
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        armed()
    }

    override func configuration(shielding webDomain: WebDomain,
                                in category: ActivityCategory) -> ShieldConfiguration {
        armed()
    }

    // MARK: - the screen itself

    private func armed() -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: nil,          // no blur: nothing in this app is soft
            // Passed, but do not count on it. A screenshot of the shipped shield measured #222224
            // at every corner while this was #0F0F1B, so iOS is discarding it and drawing its own
            // background. It stays here in case a future version honours it; the wall the user
            // actually sees is painted into the icon.
            backgroundColor: UIColor(Px.bg),
            icon: Self.panel,
            // A zero-width space, not nil.
            //
            // `title: nil` does not mean "no title" — iOS substitutes its own default, which is the
            // word "Restricted" in the system font, directly under the pixel ARMED baked into the
            // icon. Passing a label containing an invisible character keeps the system from
            // reaching for that fallback while showing nothing of its own.
            title: .init(text: "\u{200B}", color: .clear),
            subtitle: .init(text: Self.reason, color: UIColor(Px.dim)),
            // One button, and it closes the screen. A shield offering a way through is a shield
            // that has to be argued with, and losing that argument is the entire failure mode.
            primaryButtonLabel: .init(text: "OK", color: UIColor(Px.bg)),
            primaryButtonBackgroundColor: UIColor(Px.gold),
            secondaryButtonLabel: nil
        )
    }

    /// The armed window, in the user's own words where they gave any.
    ///
    /// Read fresh each time rather than cached: the extension is short-lived and may be started
    /// long after the window was set, so a stored copy would go stale without any way to notice.
    private static var reason: String {
        guard let window = ArmorStore.load() else {
            return "You asked for this one. It stands down on its own."
        }
        let name = window.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let when = schedule(window.pattern)
        if name.isEmpty { return "You told us about \(when). It stands down on its own." }
        return "You told us about \(name.uppercased()) — \(when)."
    }

    /// Plain English for a pattern. Deliberately lower-case and short: this sits under a word in
    /// capitals and competing with it would make neither readable.
    private static func schedule(_ pattern: ArmorPattern) -> String {
        switch pattern {
        case let .daily(from, to):
            return "every day, \(from.text) to \(to.text)"
        case let .weekly(_, from, to):
            return "some days, \(from.text) to \(to.text)"
        case .monthly:
            return "the days your money lands"
        case .doubleDates:
            return "the double-date sales"
        case .dateRange:
            return "these dates"
        }
    }

    /// The same sword as the app, drawn once per process.
    ///
    /// Core Graphics rather than `ImageRenderer`: this data source is not guaranteed to run on the
    /// main actor, and the previous version reached a main-actor API through
    /// `MainActor.assumeIsolated`, which asserts rather than checks. Off the main thread that trap
    /// crashed the extension, and a crashed shield extension is invisible — iOS just draws its own
    /// default panel, so the feature appears to have been never built.
    /// Bricks, glow and sword in one bitmap.
    ///
    /// `ShieldConfiguration` gives a flat `backgroundColor`, one `UIImage`, and labels carrying a
    /// string and a colour — no font, no background image. The app's wall and the sword's halo
    /// therefore cannot be separate layers here; they are painted into the only bitmap the API
    /// takes. Drawn once per process because the extension is short-lived and the artwork is fixed.
    private static let panel: UIImage = ShieldArt.panel()
}
