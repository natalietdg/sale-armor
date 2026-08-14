import XCTest
@testable import SaleArmorTests

/// The wishlist. A blocker only ever takes things away; this is the half that counts what the
/// shield was worth.
final class WishlistTests: XCTestCase {

    private func item(_ name: String, _ price: Double) -> WishItem {
        WishItem(name: name, link: nil, price: price)
    }

    func testANewItemIsOpenAndWorthNothingYet() {
        var list = Wishlist()
        list.add(item("Trainers", 120))
        XCTAssertEqual(list.open.count, 1)
        XCTAssertEqual(list.saved, 0, "wanting something is not saving anything")
    }

    func testSkippingCountsTowardsWhatYouDidNotSpend() {
        var list = Wishlist()
        let trainers = item("Trainers", 120)
        list.add(trainers)
        list.skip(trainers.id)

        XCTAssertEqual(list.saved, 120)
        XCTAssertTrue(list.open.isEmpty, "a skipped item leaves the parked list")
        XCTAssertEqual(list.skipped.count, 1)
    }

    /// **Buying it is recorded without judgement, and must not inflate the total.**
    /// An app that punishes honesty gets lied to, and then its number is fiction.
    func testBuyingItDoesNotCountAsSaved() {
        var list = Wishlist()
        let bag = item("Bag", 300)
        list.add(bag)
        list.bought(bag.id)

        XCTAssertEqual(list.saved, 0)
        XCTAssertTrue(list.open.isEmpty)
        XCTAssertTrue(list.skipped.isEmpty)
    }

    /// Changing your mind must move the money, not add it twice.
    func testChangingYourMindMovesTheMoneyRatherThanDoublingIt() {
        var list = Wishlist()
        let lamp = item("Lamp", 80)
        list.add(lamp)

        list.skip(lamp.id)
        XCTAssertEqual(list.saved, 80)

        list.bought(lamp.id)
        XCTAssertEqual(list.saved, 0, "buying it after skipping must take the money back off")

        list.skip(lamp.id)
        XCTAssertEqual(list.saved, 80, "and skipping again puts it back exactly once")
    }

    func testSavedIsTheSumOfEverythingSkipped() {
        var list = Wishlist()
        let a = item("A", 10), b = item("B", 25.5), c = item("C", 4.5)
        [a, b, c].forEach { list.add($0) }
        list.skip(a.id); list.skip(b.id); list.skip(c.id)
        XCTAssertEqual(list.saved, 40, accuracy: 0.001)
    }

    func testOpenItemsAreNewestFirst() {
        var list = Wishlist()
        var older = item("Older", 5)
        older.addedAt = Date(timeIntervalSince1970: 1_000)
        var newer = item("Newer", 5)
        newer.addedAt = Date(timeIntervalSince1970: 2_000)
        list.add(older); list.add(newer)

        XCTAssertEqual(list.open.first?.name, "Newer")
    }

    func testRemovingAnItemTakesItsMoneyWithIt() {
        var list = Wishlist()
        let watch = item("Watch", 500)
        list.add(watch)
        list.skip(watch.id)
        XCTAssertEqual(list.saved, 500)

        list.remove(watch.id)
        XCTAssertEqual(list.saved, 0)
        XCTAssertTrue(list.items.isEmpty)
    }

    func testTheListSurvivesBeingEncodedAndDecoded() throws {
        var list = Wishlist()
        let shoes = item("Shoes", 99.99)
        list.add(shoes)
        list.skip(shoes.id)

        let data = try JSONEncoder().encode(list)
        let back = try JSONDecoder().decode(Wishlist.self, from: data)
        XCTAssertEqual(back.saved, 99.99, accuracy: 0.001)
        XCTAssertEqual(back.skipped.first?.name, "Shoes")
    }
}
