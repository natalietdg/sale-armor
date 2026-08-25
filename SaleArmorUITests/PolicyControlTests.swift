import XCTest

/// **The check three App Store rejections turned on.**
///
/// Apple rejected build 20 under 2.1(a) and 3.1.2(c) — "Terms of use and privacy policy links were
/// unresponsive when we tapped them" — on an iPad Air 11-inch (M3). Nothing in the unit suite could
/// have caught it: a unit test cannot see a rendered frame, and every one of these controls exists,
/// points at a live URL and reports itself hittable. What it could not do is be hit by a finger.
///
/// So these tests measure what is actually drawn on the review device and hold it to the two things
/// a tappable control has to be: big enough for a fingertip, and clear of the system's own gesture
/// strip along the bottom of the screen.
///
/// `Restore` is measured alongside the two links although Apple did not cite it. It sits on the same
/// row at the same size, and it is the app's only restore path — a reviewer who cannot tap Terms has
/// no reason to try it, but 3.1.1 requires it to work.
final class PolicyControlTests: XCTestCase {

    /// Apple's minimum touch target, from the Human Interface Guidelines. Not a house preference.
    private static let minimumTouchTarget: CGFloat = 44

    override func setUp() {
        // Every control gets reported, not just the first one to fail. The point of this suite is
        // to say which controls are wrong, not that one of them is.
        continueAfterFailure = true
    }

    // MARK: the two screens that carry the links

    func testPaywallControlsAreTappable() {
        let app = launch(paywall: true)
        for id in ["policy-restore", "policy-terms", "policy-privacy"] {
            assertTappable(control(id, in: app), named: id, in: app)
        }
    }

    /// A subscriber never sees the paywall again, so this footer is their only copy of the links.
    /// Same row shape, same defect, same guarantee.
    func testSubscribedFooterLinksAreTappable() {
        let app = launch(paywall: false)
        XCTAssertTrue(app.buttons["tab-Guard"].waitForExistence(timeout: 10),
                      "did not reach the subscribed screen — the paywall is still up")
        for id in ["policy-terms", "policy-privacy"] {
            assertTappable(control(id, in: app), named: id, in: app)
        }
    }

    // MARK: the tap itself

    func testTermsLinkOpensTheBrowser() { assertOpensBrowser("policy-terms") }

    func testPrivacyLinkOpensTheBrowser() { assertOpensBrowser("policy-privacy") }

    // MARK: - measurement

    private func assertTappable(_ element: XCUIElement, named name: String, in app: XCUIApplication,
                                file: StaticString = #filePath, line: UInt = #line) {
        guard element.waitForExistence(timeout: 10) else {
            return XCTFail("\(name) is not on screen at all", file: file, line: line)
        }
        XCTAssertTrue(element.isHittable, "\(name) is on screen but not hittable",
                      file: file, line: line)

        let frame = element.frame
        let window = app.windows.firstMatch.frame
        guard let inset = Self.bottomSafeAreaInset[window.size] else {
            return XCTFail("no bottom safe-area inset recorded for a \(window.size) window",
                           file: file, line: line)
        }

        // The home indicator owns the bottom inset. A control drawn into it is competing with a
        // system swipe gesture, and the gesture wins.
        let safeAreaBottom = window.maxY - inset
        XCTAssertLessThanOrEqual(frame.maxY, safeAreaBottom,
            "\(name) reaches \(frame.maxY)pt, into the \(inset)pt bottom safe-area inset "
            + "that starts at \(safeAreaBottom)pt",
            file: file, line: line)

        XCTAssertGreaterThanOrEqual(frame.width, Self.minimumTouchTarget,
            "\(name) is \(frame.width)pt wide, under Apple's \(Self.minimumTouchTarget)pt minimum",
            file: file, line: line)
        XCTAssertGreaterThanOrEqual(frame.height, Self.minimumTouchTarget,
            "\(name) is \(frame.height)pt tall, under Apple's \(Self.minimumTouchTarget)pt minimum",
            file: file, line: line)
    }

    /// A tap has to end somewhere the policy can be read, which means the browser in the foreground.
    /// Asserting on the control alone would pass for a link wired to a dead URL.
    private func assertOpensBrowser(_ id: String, file: StaticString = #filePath, line: UInt = #line) {
        let app = launch(paywall: true)
        let safari = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
        safari.terminate()   // so a Safari left running by an earlier test cannot pass this one

        let link = control(id, in: app)
        XCTAssertTrue(link.waitForExistence(timeout: 10), "\(id) is not on screen",
                      file: file, line: line)
        link.tap()

        XCTAssertTrue(safari.wait(for: .runningForeground, timeout: 15),
                      "tapping \(id) did not open the browser", file: file, line: line)
        safari.terminate()
    }

    // MARK: - the device

    /// **Stated here rather than asked for at runtime.**
    ///
    /// Xcode's UI-test runner ships without a launch screen, so it runs in iPhone compatibility mode
    /// and reports a 768x1024 window whose insets are not the device's. The app under test is a
    /// separate process and cannot be asked either. So each window size carries the inset the device
    /// itself lays out against, and an unlisted size fails rather than being measured against a guess.
    private static let bottomSafeAreaInset: [CGSize: CGFloat] = [
        CGSize(width: 820, height: 1180): 20,   // iPad Air 11-inch (M3), portrait — the review device
        CGSize(width: 402, height: 874): 34,    // iPhone 17, portrait
    ]

    /// Matched on identifier rather than type: `Link` and `Button` are both plain buttons to the
    /// accessibility tree today, and neither this suite nor App Review cares which one it is.
    private func control(_ id: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private func launch(paywall: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        // `-demo` alone opens the app as a subscriber; adding `-paywall` puts the gate back with
        // sample plans. The cached entitlement is overridden through UserDefaults' argument domain,
        // so a previous run cannot leave the paywall unreachable.
        app.launchArguments = paywall
            ? ["-demo", "-paywall", "-subscription.isActive", "NO"]
            : ["-demo", "-seed"]
        app.launch()
        return app
    }
}
