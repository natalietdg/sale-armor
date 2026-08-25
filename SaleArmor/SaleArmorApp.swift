import SwiftUI

@main
struct SaleArmorApp: App {
    /// Only here to catch a tap on the payday offer, which can arrive before any view exists.
    @UIApplicationDelegateAdaptor(PaydayOfferRouter.self) private var router

    var body: some Scene {
        WindowGroup { ContentView() }
    }
}
