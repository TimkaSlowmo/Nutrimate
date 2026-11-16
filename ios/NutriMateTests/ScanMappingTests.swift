import XCTest
@testable import NutriMate

/// Сканер по фото (v33): «метка Vision → продукт», «имя от сервера → продукт», решение «уверен / не уверен», «чек или продукты».
final class ScanMappingTests: XCTestCase {
    private let db = FoodDB.shared

    override func setUp() {
        super.setUp()
        AppLang.current = .en
    }

    func testFoodBaseAndLabelsLoaded() {
        XCTAssertGreaterThan(db.foods.count, 1000)
        XCTAssertGreaterThan(VisionLabels.file.labels.count, 300)
        XCTAssertFalse(VisionLabels.file.generic.isEmpty)
    }

    func testEveryLabelTargetExists() {
        for (label, name) in VisionLabels.file.labels {
            XCTAssertNotNil(db.byName[name], "\(label) → \(name) is not in foods.json")
        }
        for (label, names) in VisionLabels.file.generic {
            for n in names { XCTAssertNotNil(db.byName[n], "generic \(label) → \(n) is not in foods.json") }
        }
    }

    func testLabelToProduct() {
        let cases = ["banana": "Banana", "apple": "Apple", "orange": "Orange", "lemon": "Lemon", "broccoli": "Broccoli",
                     "bread": "White Bread", "croissant": "Croissant", "cheese": "Cheddar Cheese", "egg": "Eggs",
                     "milk": "Milk", "strawberry": "Strawberry", "bell_pepper": "Bell Pepper", "Bell Pepper": "Bell Pepper",
                     "ice-cream": "Ice Cream", "salmon": "Salmon"]
        for (label, name) in cases {
            XCTAssertEqual(VisionLabels.food(for: label, db: db)?.name, name, label)
        }
        for generic in ["food", "fruit", "produce", "vegetable", "dessert", "baked_goods"] {
            XCTAssertNil(VisionLabels.food(for: generic, db: db), generic)
            XCTAssertTrue(VisionLabels.isGeneric(generic), generic)
        }
        XCTAssertNil(VisionLabels.food(for: "wood_processed", db: db))
        XCTAssertNil(VisionLabels.food(for: "table", db: db))
    }

    func testServerNameToProduct() {
        let cases = ["Banana": "Banana", "Bananas": "Banana", "banana": "Banana", "Red Apple": "Apple", "Apples": "Apple",
                     "Green Apple": "Green Apple", "Cherry Tomato": "Cherry Tomato", "Tomatoes": "Tomato", "Egg": "Eggs",
                     "Eggs": "Eggs", "Milk": "Milk", "Chicken Breast": "Chicken Breast", "Strawberries": "Strawberry",
                     "Bell Pepper": "Bell Pepper", "Fresh Carrots": "Carrot", "Cucumbr": "Cucumber", "Bananna": "Banana",
                     "молоко": "Milk", "Банан": "Banana", "сүт": "Milk", "Potatoes": "Potato", "Grape": "Grapes"]
        for (raw, name) in cases {
            XCTAssertEqual(FoodMatch.food(named: raw, db: db)?.name, name, raw)
        }
        XCTAssertNil(FoodMatch.food(named: "xyzzy qwrt", db: db))
        XCTAssertNil(FoodMatch.food(named: "", db: db))
        XCTAssertNil(FoodMatch.food(named: "42", db: db))
    }

    func testServerAnswerMerging() {
        let items = [NutrikVision.Item(name: "Banana", qty: 5, confidence: 0.9),
                     NutrikVision.Item(name: "Bananas", qty: 2, confidence: 0.8),
                     NutrikVision.Item(name: "Red Apple", qty: 3, confidence: 0.85),
                     NutrikVision.Item(name: "Glorpfruit", qty: 1, confidence: 0.4)]
        let m = PhotoScan.mapServer(items, db: db)
        XCTAssertEqual(m.items.map(\.food.name), ["Banana", "Apple"])
        XCTAssertEqual(m.items.first?.qty, 7)
        XCTAssertEqual(m.items.last?.qty, 3)
        XCTAssertEqual(m.unknown, ["Glorpfruit"])
    }

    func testConfidentBananas() {
        let full = [VisionLabel(id: "food", confidence: 0.95), VisionLabel(id: "fruit", confidence: 0.9),
                    VisionLabel(id: "banana", confidence: 0.86), VisionLabel(id: "wood_processed", confidence: 0.4)]
        let d = PhotoScan.decide(full: full, crops: [], db: db)
        XCTAssertFalse(d.uncertain)
        XCTAssertEqual(d.items.map(\.food.name), ["Banana"])
        XCTAssertEqual(d.items.first?.qty, 1)
    }

    func testThreeApplesFromCrops() {
        let crop = [VisionLabel(id: "apple", confidence: 0.7), VisionLabel(id: "fruit", confidence: 0.8)]
        let d = PhotoScan.decide(full: [VisionLabel(id: "apple", confidence: 0.6)], crops: [crop, crop, crop], db: db)
        XCTAssertFalse(d.uncertain)
        XCTAssertEqual(d.items.first?.food.name, "Apple")
        XCTAssertEqual(d.items.first?.qty, 3)
    }

    func testOnlyGenericIsUncertainWithSuggestions() {
        let d = PhotoScan.decide(full: [VisionLabel(id: "food", confidence: 0.9), VisionLabel(id: "fruit", confidence: 0.8)],
                                 crops: [], db: db)
        XCTAssertTrue(d.uncertain)
        XCTAssertTrue(d.items.isEmpty)
        XCTAssertEqual(d.alternatives.map(\.name), ["Apple", "Banana", "Orange"])
        XCTAssertEqual(d.query, "Apple")
    }

    func testLowConfidenceIsUncertain() {
        let d = PhotoScan.decide(full: [VisionLabel(id: "lemon", confidence: 0.3), VisionLabel(id: "lime", confidence: 0.25)],
                                 crops: [], db: db)
        XCTAssertTrue(d.uncertain)
        XCTAssertEqual(Set(d.alternatives.map(\.name)), ["Lemon", "Lime"])
    }

    func testNothingRecognized() {
        let d = PhotoScan.decide(full: [VisionLabel(id: "wood_processed", confidence: 0.9), VisionLabel(id: "structure", confidence: 0.5)],
                                 crops: [], db: db)
        XCTAssertTrue(d.uncertain)
        XCTAssertTrue(d.items.isEmpty)
        XCTAssertTrue(d.alternatives.isEmpty)
    }

    func testReceiptHeuristic() {
        let receipt = "SUPERMARKET #12\nМОЛОКО 2,5% 1Л 2 x 520,00\nЯЙЦО С1 10ШТ 890,00\nБАНАНЫ ВЕС 1,2 КГ 640,00\nИТОГО 5090,00"
        XCTAssertTrue(PhotoScan.looksLikeReceipt(receipt, db: db))
        XCTAssertTrue(PhotoScan.looksLikeReceipt("milk\n2 eggs\nbananas", db: db))
        XCTAssertFalse(PhotoScan.looksLikeReceipt("Chiquita", db: db))
        XCTAssertFalse(PhotoScan.looksLikeReceipt("", db: db))
        XCTAssertFalse(PhotoScan.looksLikeReceipt("FRESH\n100% NATURAL", db: db))
    }

    func testShelfText() {
        XCTAssertEqual(ScanResultView.shelfText(5), "5 days")
        XCTAssertEqual(ScanResultView.shelfText(1), "1 day")
        XCTAssertEqual(ScanResultView.shelfText(90), "3 months")
        XCTAssertEqual(ScanResultView.shelfText(730), "2 years")
    }
}
