import XCTest
@testable import SaleArmorTests

/// **A wishlist link has to open something.**
///
/// The list used to build its `Link` straight from `URL(string:)`, which does not return nil for a
/// bare host — `"amazon.com"` parses as a relative reference with no scheme. The link rendered, took
/// the tap and did nothing, on the form most people type. `shop.example.com` is in the shipped App
/// Store screenshots, so the broken form is the one the listing advertises.
final class WishLinkTests: XCTestCase {

    private func url(_ typed: String?) -> String? { WishItem.url(from: typed)?.absoluteString }

    func testABareHostGetsAScheme() {
        XCTAssertEqual(url("amazon.com"), "https://amazon.com")
        XCTAssertEqual(url("www.zalora.com.my"), "https://www.zalora.com.my")
        XCTAssertEqual(url("shop.example.com/thing?a=1"), "https://shop.example.com/thing?a=1")
    }

    func testAnExistingSchemeIsLeftAlone() {
        XCTAssertEqual(url("https://amazon.com"), "https://amazon.com")
        XCTAssertEqual(url("http://x.com"), "http://x.com")
    }

    func testSurroundingSpaceIsIgnored() {
        XCTAssertEqual(url("  amazon.com  "), "https://amazon.com")
    }

    /// Nil means the row draws plain text instead of a link. Nothing here could be opened.
    func testWhatCannotBeOpenedIsNotALink() {
        XCTAssertNil(url("a thing I want"))
        XCTAssertNil(url("!!!"))
        XCTAssertNil(url("localhost:3000"))       // no dot: not somewhere to shop
        XCTAssertNil(url("ftp://files.example.com"))   // not a scheme a browser opens
        XCTAssertNil(url("https://"))
    }

    func testNothingTypedStaysNil() {
        XCTAssertNil(url(nil))
        XCTAssertNil(url(""))
        XCTAssertNil(url("   "))
    }

    /// Wishes saved before the scheme was added are still in the App Group, so the same
    /// normalisation runs on read. This is the old stored form.
    func testAWishSavedWithoutASchemeStillOpens() {
        let saved = WishItem(name: "Headphones", link: "amazon.com", price: 199)
        XCTAssertEqual(saved.linkURL?.absoluteString, "https://amazon.com")
    }

    func testAWishWithNoLinkHasNoURL() {
        XCTAssertNil(WishItem(name: "Headphones", link: nil, price: 199).linkURL)
    }
}
