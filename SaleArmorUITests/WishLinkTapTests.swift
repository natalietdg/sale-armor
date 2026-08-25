import XCTest

/// **A wishlist link has to open something.**
///
/// The seeded wish carries `shop.example.com` — a bare host, the form most people type and the form
/// in the shipped App Store screenshots. `URL(string:)` accepts it, so the old row drew a `Link`
/// that took the tap and did nothing. This drives the tap on the review device instead of trusting
/// that the row rendered.
final class WishLinkTapTests: XCTestCase {

    func testTheWishlistLinkOpensTheBrowser() {
        let app = XCUIApplication()
        app.launchArguments = ["-demo", "-seed", "-wishlist"]
        app.launch()

        let safari = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
        safari.terminate()   // so a Safari left running by an earlier test cannot pass this one

        let link = app.descendants(matching: .any).matching(identifier: "wish-link").firstMatch
        XCTAssertTrue(link.waitForExistence(timeout: 10),
                      "the seeded wish did not render its link at all")
        link.tap()

        XCTAssertTrue(safari.wait(for: .runningForeground, timeout: 15),
                      "tapping the wishlist link did not open the browser")
        safari.terminate()
    }
}
