import Foundation
import SwiftUI
import UserNotifications

/// **What happens when the payday offer is tapped.**
///
/// The offer's whole promise is that a tap starts a session, and a tap can arrive before any view
/// exists — a cold launch straight from the lock screen. `UNUserNotificationCenter` only hands the
/// response to a delegate that was already in place when the app finished launching, so the
/// delegate is an app delegate rather than something a view sets up.
///
/// The delegate cannot reach the `ArmorController`, which the view owns, so it drops the tap here
/// and the view collects it. One boolean, one direction.
@MainActor
final class PaydayOfferInbox: ObservableObject {
    static let shared = PaydayOfferInbox()
    /// Set by the delegate, cleared by whoever acts on it.
    @Published var wasAccepted = false
    private init() {}
}

final class PaydayOfferRouter: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    /// Only the offer does anything on tap. The wishlist reminder and the payday status notice are
    /// both statements — opening the app is the whole of their response.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        if response.notification.request.identifier.hasPrefix(PaydayNotice.offerPrefix) {
            Task { @MainActor in PaydayOfferInbox.shared.wasAccepted = true }
        }
        completionHandler()
    }
}
