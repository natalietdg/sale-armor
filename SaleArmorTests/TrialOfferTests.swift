import XCTest
@testable import SaleArmorTests

/// **The free trial, and the sentence Apple reads.**
///
/// Two things are worth pinning and neither is the arithmetic. The first is that a one-week trial
/// is spoken as seven days, because the store returns it as `1 week` and the paywall must not.
/// The second is the disclosure sentence, which is the one piece of copy on the purchase screen
/// that has been rejected before: it has to say what is free, for how long, and what is charged
/// after, in the customer's own currency.
final class TrialOfferTests: XCTestCase {

    // MARK: - length

    func testOneWeekIsSpokenAsSevenDays() {
        XCTAssertEqual(TrialOffer(value: 1, unit: .week).length, "7 days",
                       "the store says 1 week; a person deciding on a paywall counts days")
    }

    func testTwoWeeksIsFourteenDays() {
        XCTAssertEqual(TrialOffer(value: 2, unit: .week).length, "14 days")
    }

    func testDaysArePassedThrough() {
        XCTAssertEqual(TrialOffer(value: 3, unit: .day).length, "3 days")
    }

    func testASingleDayIsNotPluralised() {
        XCTAssertEqual(TrialOffer(value: 1, unit: .day).length, "1 day")
    }

    func testMonthsAreLeftAsMonths() {
        XCTAssertEqual(TrialOffer(value: 1, unit: .month).length, "1 month",
                       "'30 days' would be a claim about a length the store never promised")
        XCTAssertEqual(TrialOffer(value: 2, unit: .month).length, "2 months")
    }

    func testYearsAreLeftAsYears() {
        XCTAssertEqual(TrialOffer(value: 1, unit: .year).length, "1 year")
    }

    func testMultiplePeriodsMultiplyTheLength() {
        XCTAssertEqual(TrialOffer(value: 1, unit: .week, periods: 2).length, "14 days")
        XCTAssertEqual(TrialOffer(value: 1, unit: .month, periods: 3).length, "3 months")
    }

    func testZeroPeriodsIsTreatedAsOne() {
        // numberOfPeriods should never be 0, but a 0 here would silently print "0 days free".
        XCTAssertEqual(TrialOffer(value: 1, unit: .week, periods: 0).length, "7 days")
    }

    func testThePhraseIsTheLengthPlusFree() {
        XCTAssertEqual(TrialOffer(value: 1, unit: .week).phrase, "7 days free")
    }

    // MARK: - the disclosure

    func testTermsStateTheLengthThePriceAndTheRenewal() {
        let terms = TrialOffer.terms(trial: TrialOffer(value: 1, unit: .week),
                                     price: "$3.99", term: "Every week", renews: true)
        XCTAssertEqual(terms, "Free for 7 days, then $3.99 every week. "
                            + "Renews automatically until cancelled. Cancel any time in Settings.")
    }

    func testTermsUseTheStoresOwnPriceString() {
        // Whatever the store hands over goes through untouched, so a Malaysian customer is not
        // told a dollar figure. #218 records this going wrong elsewhere in the app.
        let terms = TrialOffer.terms(trial: TrialOffer(value: 1, unit: .week),
                                     price: "RM 18.90", term: "Every week", renews: true)
        XCTAssertTrue(terms.contains("then RM 18.90 every week"), terms)
    }

    func testTermsWithoutATrialDoNotMentionOne() {
        let terms = TrialOffer.terms(trial: nil, price: "$3.99", term: "Every week", renews: true)
        XCTAssertFalse(terms.lowercased().contains("free"),
                       "an ineligible customer must not be shown the word free")
        XCTAssertEqual(terms, "Renews automatically until cancelled. Cancel any time in Settings.")
    }

    func testALifetimePurchaseNeverClaimsToRenew() {
        let terms = TrialOffer.terms(trial: nil, price: "$299.99", term: "Once, forever",
                                     renews: false)
        XCTAssertEqual(terms, "One payment. Nothing renews, nothing to cancel.")
    }

    func testALifetimePurchaseIgnoresATrialRatherThanAdvertisingOne() {
        // Defensive: a non-renewing product cannot carry a trial, and if one ever appeared the
        // screen must not offer it.
        let terms = TrialOffer.terms(trial: TrialOffer(value: 1, unit: .week),
                                     price: "$299.99", term: "Once, forever", renews: false)
        XCTAssertEqual(terms, "One payment. Nothing renews, nothing to cancel.")
    }
}
