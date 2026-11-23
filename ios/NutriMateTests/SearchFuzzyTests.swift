import XCTest
@testable import NutriMate

/// Умный поиск (v34): опечатки, раскладка, формы слов, три языка.
final class SearchFuzzyTests: XCTestCase {
    private let db = FoodDB.shared

    func names(_ q: String) -> [String] { db.search(q, category: nil).map(\.name) }

    func testExactStillFirst() {
        XCTAssertEqual(names("banana").first, "Banana")
    }

    func testEnglishTypo() {
        XCTAssertTrue(names("tomatoo paste").contains { $0.lowercased().contains("tomato") })
        XCTAssertTrue(names("chiken breast").contains("Chicken Breast"))
    }

    func testRussianTypo() {
        let r = db.search("томатная пасат", category: nil)
        XCTAssertFalse(r.isEmpty)
        XCTAssertTrue(r.prefix(5).contains { ($0.ru ?? "").lowercased().contains("томат") })
    }

    func testWrongKeyboardLayout() {
        // «vjkjrj» = «молоко» на английской раскладке
        XCTAssertTrue(names("vjkjrj").contains("Milk"))
    }

    func testSwapLayout() {
        XCTAssertEqual(FoodDB.swapLayout("vjkjrj"), "молоко")
        XCTAssertNil(FoodDB.swapLayout("milk 123 молоко"))
    }

    func testEditDistance() {
        XCTAssertEqual(FoodDB.editDistance(Array("milk"), Array("mlik"), limit: 2), 1)
        XCTAssertEqual(FoodDB.editDistance(Array("abc"), Array("xyz"), limit: 1), 2)
    }
}
