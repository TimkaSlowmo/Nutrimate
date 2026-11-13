import Foundation
import SwiftUI

// MARK: - База продуктов и рецептов (генерируется из lib/main.dart скриптом tool/export_data.py)

struct Food: Codable, Hashable, Identifiable {
    let emoji: String
    let name: String
    let kcal: Int      // ккал на 100 г
    let category: String
    let shelf: Int     // срок хранения, дней
    /// Переводы названия (из tool/translations_src.txt); нет — показываем английское
    var ru: String? = nil
    var kk: String? = nil
    var id: String { name }
}

struct Ing: Codable, Hashable {
    let name: String
    let g: Int
}

struct Recipe: Codable, Hashable, Identifiable {
    let name: String
    let emoji: String
    let time: String
    let servings: Int
    let ingredients: [Ing]
    let steps: [String]
    let staples: String
    let zeroWaste: Bool
    var ru: String? = nil
    var kk: String? = nil
    /// шаги на русском/казахском (tool/recipe_steps_l10n.json → foods.json); нет перевода — английские
    var stepsRu: [String]? = nil
    var stepsKk: [String]? = nil
    var id: String { name }

    /// шаги на языке приложения
    var localizedSteps: [String] {
        let t: [String]?
        switch AppLang.current {
        case .ru: t = stepsRu
        case .kk: t = stepsKk
        case .en: t = nil
        }
        if let t, t.count == steps.count { return t }
        return steps
    }

    /// ккал на порцию
    var kcal: Int {
        let total = ingredients.reduce(0.0) { s, i in
            s + Double(i.g) * Double(FoodDB.shared.byName[i.name]?.kcal ?? 0) / 100
        }
        return Int((total / Double(max(1, servings))).rounded())
    }

    /// Примерный вес одной порции (г, до 10) — для остатков в холодильнике (v27).
    var portionGrams: Int {
        let g = Double(ingredients.reduce(0) { $0 + $1.g }) / Double(max(1, servings))
        return max(50, Int((g / 10).rounded()) * 10)
    }

    /// ккал на 100 г готового блюда — остатки в холодильнике хранят калорийность как обычные продукты.
    var kcalPer100: Int { Int((Double(kcal) * 100 / Double(portionGrams)).rounded()) }

    func missing(_ have: Set<String>) -> [String] {
        ingredients.map(\.name).filter { !have.contains($0) }
    }

    /// Тот же рецепт на `n` порций: граммы пропорционально (до 5 г), ккал на порцию не меняются.
    func scaled(to n: Int) -> Recipe {
        let n = max(1, n)
        guard n != servings else { return self }
        let f = Double(n) / Double(max(1, servings))
        let ings = ingredients.map { i -> Ing in
            let g = Double(i.g) * f
            let r = g < 20 ? max(1, Int(g.rounded())) : Int((g / 5).rounded()) * 5
            return Ing(name: i.name, g: r)
        }
        return Recipe(name: name, emoji: emoji, time: time, servings: n, ingredients: ings, steps: steps,
                      staples: staples, zeroWaste: zeroWaste, ru: ru, kk: kk, stepsRu: stepsRu, stepsKk: stepsKk)
    }
}

extension Ing {
    /// Вес одной штуки (г) для продуктов, которые в холодильнике считают штуками.
    static let pieceGrams: [String: Double] = [
        "Eggs": 60, "Quail Eggs": 11, "Banana": 120, "Apple": 180, "Pear": 180, "Peach": 150, "Nectarine": 140,
        "Plum": 65, "Apricot": 40, "Fig": 50, "Kiwi": 75, "Mango": 300, "Avocado": 170, "Orange": 150,
        "Tangerine": 80, "Clementine": 75, "Grapefruit": 300, "Lemon": 100, "Lime": 65, "Pomegranate": 280,
        "Persimmon": 200, "Quince": 250, "Plantain": 250, "Tomato": 120, "Cucumber": 200, "Bell Pepper": 150,
        "Zucchini": 250, "Eggplant": 300, "Onion": 110, "Red Onion": 110, "Shallot": 30, "Garlic": 45,
        "Leek": 200, "Potato": 170, "Sweet Potato": 200, "Carrot": 70, "Beetroot": 150, "Corn": 250,
        "Radish": 15, "Fennel": 250, "Artichoke": 300, "Chicken Breast": 200, "Chicken Thighs": 120,
        "Sausages": 60, "Tortilla": 45, "Bagel": 100, "Croissant": 60, "Burger Bun": 60, "English Muffin": 60,
        "Naan": 90, "Lavash": 80,
    ]

    /// Сколько штук нужно (nil — продукт не считают штуками). 0 — берём только часть одной штуки.
    var pieces: Int? {
        guard let w = Ing.pieceGrams[name] else { return nil }
        return Int((Double(g) / w).rounded())
    }
}

private struct DBFile: Codable {
    let foods: [Food]
    let recipes: [Recipe]
    let tips: [String: String]?
}

struct FoodDB {
    let foods: [Food]
    let recipes: [Recipe]
    let byName: [String: Food]
    let categories: [String]
    /// Советы по хранению (по названию продукта или категории) — из storageTips в lib/main.dart
    var tips: [String: String] = [:]
    /// Рецепты по названию (для переводов названий)
    var recipeByName: [String: Recipe] = [:]

    static let shared: FoodDB = {
        guard let url = Bundle.main.url(forResource: "foods", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(DBFile.self, from: data)
        else { return FoodDB(foods: [], recipes: [], byName: [:], categories: [], tips: [:]) }
        var seen = Set<String>()
        var cats: [String] = []
        for f in file.foods where !seen.contains(f.category) {
            seen.insert(f.category)
            cats.append(f.category)
        }
        var map: [String: Food] = [:]
        for f in file.foods where map[f.name] == nil { map[f.name] = f }
        var rmap: [String: Recipe] = [:]
        for r in file.recipes where rmap[r.name] == nil { rmap[r.name] = r }
        return FoodDB(foods: file.foods, recipes: file.recipes, byName: map, categories: cats, tips: file.tips ?? [:], recipeByName: rmap)
    }()

    static let catEmoji: [String: String] = [
        LK("Vegetables"): "🥕", LK("Fruits"): "🍎", LK("Berries"): "🍓", LK("Dairy"): "🧀", LK("Meat"): "🥩", LK("Seafood"): "🐟",
        LK("Grains"): "🌾", LK("Bakery"): "🍞", LK("Nuts & Legumes"): "🥜", LK("Pantry"): "🫙", LK("Sweets"): "🍫", LK("Drinks"): "🥤",
        LK("Frozen"): "🧊", LK("Spices"): "🧂", LK("Canned"): "🥫", LK("Ready Meals"): "🍱", LK("Snacks"): "🍿", LK("Plant-Based"): "🌱",
        LK("World Foods"): "🌏", LK("Baby Food"): "🍼",
    ]

    static let price: [String: Double] = [
        "Meat": 4.5, "Seafood": 5.0, "Dairy": 2.0, "Vegetables": 1.2, "Fruits": 1.5, "Berries": 3.0, "Bakery": 1.5,
        "Grains": 1.2, "Nuts & Legumes": 3.0, "Pantry": 2.5, "Sweets": 2.5, "Drinks": 1.8, "Frozen": 3.5, "Spices": 2.0,
        "Canned": 1.8, "Ready Meals": 4.0, "Snacks": 2.5, "Plant-Based": 3.0, "World Foods": 3.0, "Baby Food": 2.5,
    ]

    static let shelfStable: Set<String> = ["Grains", "Pantry", "Spices", "Canned", "Nuts & Legumes", "Snacks", "Sweets", "Drinks", "World Foods", "Plant-Based", "Baby Food"]
    static let freezable: Set<String> = ["Meat", "Seafood", "Bakery", "Fruits", "Berries", "Vegetables", "Ready Meals", "Dairy", "Plant-Based"]
    static let noFreeze: Set<String> = ["Eggs", "Lettuce", "Cucumber", "Salad Mix", "Yogurt", "Sour Cream", "Mayonnaise"]

    static func defaultStorage(_ f: Food) -> StorageKind {
        if f.category == "Frozen" { return .freezer }
        if shelfStable.contains(f.category) && f.shelf > 14 { return .pantry }
        return .fridge
    }

    static func canFreeze(_ f: Food) -> Bool { freezable.contains(f.category) && !noFreeze.contains(f.name) }

    /// Сколько дней продукт хранится ПОСЛЕ вскрытия упаковки (v28) — по типичным рекомендациям
    /// (молоко и йогурт ~5 дней, мягкий сыр 4, твёрдый месяц, сок неделя, консервы 3 дня, колбаса 4).
    /// nil — вскрытие на срок не влияет (овощи, крупы, специи, шоколад) или срок и так короче.
    static func openedDays(_ f: Food) -> Int? {
        guard let d = openedRule(f), d < f.shelf else { return nil }
        return d
    }

    /// Можно ли нажать «Я открыл(а)» для этой партии: срок после вскрытия короче обычного срока продукта
    /// или короче даты на этой упаковке (молоко с датой через 10 дней → открытое ~5).
    static func openedDays(_ f: Food, daysLeft: Int) -> Int? {
        guard let d = openedRule(f), d < max(f.shelf, daysLeft + 1) else { return nil }
        return d
    }

    static func openedRule(_ f: Food) -> Int? {
        let n = f.name.lowercased(), c = f.category
        func has(_ k: String...) -> Bool { k.contains { n.contains($0) } }
        let words = Set(n.split(separator: " ").map(String.init))
        let drink = c == "Drinks"
        var d: Int?
        if c == "Baby Food" { d = has("formula", "cereal", "biscuit") ? 30 : 2 }
        else if c == "Canned" { d = has("olive", "pickled", "caperberr", "giardiniera", "jalape") ? 30 : 3 }
        else if has("ice cream", "gelato", "sorbet", "popsicle", "egg white") { d = has("egg white") ? 3 : nil }
        else if has("egg", "ghee", "margarine", "lard", "kurt", "irimshik", "sary mai") || (has("butter") && !has("buttermilk")) { d = nil }
        else if has("cream cheese", "mascarpone", "sour cream", "creme fraiche", "crème") { d = 7 }
        else if has("condensed milk") { d = 10 }
        else if has("coconut milk", "coconut cream", "evaporated milk") { d = 4 }
        else if has("cream") && (c == "Dairy" || c == "Plant-Based") { d = 4 }
        else if has("burrata", "stracciatella", "mozzarella", "ricotta", "cottage", "quark", "paneer", "tvorog",
                    "queso fresco", "labneh", "cheese curds", "adyghe") { d = 4 }
        else if has("parmesan", "pecorino", "manchego", "comt", "gruyere", "asiago", "mimolette") { d = 30 }
        else if has("cheese", "cheddar", "gouda", "edam", "emmental", "provolone", "havarti", "jarlsberg", "halloumi",
                    "fontina", "feta", "brie", "camembert", "gorgonzola", "roquefort", "stilton", "taleggio", "raclette",
                    "scamorza", "suluguni", "sulguni", "brynza", "bryndza", "cotija") { d = 14 }
        else if c != "Sweets" && c != "Frozen" && has("milk", "kefir", "yogurt", "ayran", "skyr", "buttermilk", "ryazhenka", "matsoni", "katyk",
                    "prostokvasha", "varenets", "lassi", "kumys", "shubat", "yakult", "snezhok") {
            d = has("oat", "soy", "almond", "rice", "pea ", "cashew", "hemp", "hazelnut", "lactose") ? 7 : 5
        }
        else if has("juice", "nectar") { d = 7 }
        else if drink && has("champagne", "sparkling", "cola", "soda", "lemonade", "tonic", "ginger ale", "root beer",
                    "flavored water", "energy drink", "sports drink", "iced tea") { d = 3 }
        else if drink && has("beer") { d = 1 }
        else if drink && has("wine", "sangria", "cider", "sake") { d = 4 }
        else if has("kombucha", "cold brew", "chai concentrate", "water kefir", "coconut water") { d = 5 }
        else if c == "Meat" && has("salami", "chorizo", "pepperoni", "prosciutto", "soppressata", "bresaola", "basturma", "iberico",
                    "cervelat", "lap cheong", "pancetta", "guanciale", "lardo", "nduja", "kazy", "shuzhuk", "sur et",
                    "chuchuk", "smoked sausage") { d = 14 }
        else if (c == "Meat" || c == "Plant-Based") && (!words.isDisjoint(with: ["ham", "bacon"]) || has("sausage", "frankfurter", "hot dog", "bratwurst", "kielbasa", "mortadella",
                    "pastrami", "roast beef", "corned beef", "smoked chicken", "pate", "doktorskaya")) { d = 4 }
        else if has("smoked salmon", "salted salmon", "kippers", "smoked mackerel", "caviar", "roe", "tobiko",
                    "mentaiko", "crab sticks", "salted herring", "pickled herring") { d = 3 }
        else if has("anchov") { d = 14 }
        else if has("tofu", "tempeh", "seitan", "yuba") { d = 4 }
        else if has("hummus", "guacamole", "tzatziki", "pesto", "apple sauce", "broth", "red bean paste", "queso dip",
                    "fresh tortellini", "pasta sauce", "tomato sauce", "enchilada sauce", "sea moss") { d = 4 }
        else if has("tomato paste", "tomato puree", "tahini sauce") { d = 7 }
        else if has("mayo", "dressing", "tartar", "garlic sauce", "salsa", "horseradish", "ketchup", "bbq sauce",
                    "sweet chili", "adjika", "tkemali", "cranberry sauce", "chipotle") { d = 30 }
        else if c == "Pantry" && has("jam", "marmalade", "jelly", "curd", "dulce de leche", "spread", "pistachio cream") { d = 30 }
        else if has("jerky", "biltong") { d = 7 }
        else if c == "Snacks" && f.shelf > 30 && !has("bar", "pastr", "microwave", "fruit snacks", "fruit leather", "cookies") { d = 14 }
        else if has("tortilla", "wrappers", "bao bun", "puff pastry", "phyllo", "pizza dough", "kataifi", "tteok") { d = 4 }
        else if c == "Plant-Based" && f.shelf <= 60 { d = 5 }
        else if c == "Dairy" && f.shelf <= 30 { d = 5 }
        return d
    }

    /// Открытое из шкафа переезжает в холодильник (консервы, соусы, сок); чипсы и хлеб остаются на месте.
    static func fridgeWhenOpened(_ f: Food) -> Bool { !["Snacks", "Bakery", "Sweets"].contains(f.category) }

    /// Поиск: сначала совпадение с начала названия, потом с начала слова, потом где угодно.
    func search(_ query: String, category: String?) -> [Food] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        let pool = category == nil ? foods : foods.filter { $0.category == category }
        if q.isEmpty { return pool }
        var a: [Food] = [], b: [Food] = [], c: [Food] = []
        for f in pool {
            // ищем по-английски, по-русски и по-казахски
            let names = [f.name.lowercased(), f.ru?.lowercased() ?? "", f.kk?.lowercased() ?? ""].filter { !$0.isEmpty }
            if names.contains(where: { $0.hasPrefix(q) }) { a.append(f) }
            else if names.contains(where: { $0.contains(" " + q) }) { b.append(f) }
            else if names.contains(where: { $0.contains(q) }) || f.category.lowercased().hasPrefix(q) { c.append(f) }
        }
        return a.sorted { $0.name.count < $1.name.count } + b + c
    }
}

// MARK: - Данные пользователя (сохраняются в Application Support/nutrimate.json)

enum StorageKind: String, Codable, CaseIterable, Identifiable {
    case fridge, freezer, pantry
    var id: String { rawValue }
    /// Английский ключ (для чата на другом языке); на экране — title
    var key: String {
        switch self {
        case .fridge: return LK("Fridge")
        case .freezer: return LK("Freezer")
        case .pantry: return LK("Pantry")
        }
    }
    var title: String { L(key) }
    var emoji: String {
        switch self {
        case .fridge: return "🧊"
        case .freezer: return "❄️"
        case .pantry: return "🫙"
        }
    }
}

enum WasteReason: String, Codable, CaseIterable, Identifiable {
    case expired, forgot, tooMuch, spoiled, disliked
    var id: String { rawValue }
    var title: String {
        switch self {
        case .expired: return L("⏰ It expired")
        case .forgot: return L("🙈 Forgot about it")
        case .tooMuch: return L("🛒 Bought too much")
        case .spoiled: return L("🦠 Went bad early")
        case .disliked: return L("😖 Did not like it")
        }
    }
}

func dayStart(_ d: Date) -> Date { Calendar.current.startOfDay(for: d) }
func daysBetween(_ a: Date, _ b: Date) -> Int {
    Calendar.current.dateComponents([.day], from: dayStart(a), to: dayStart(b)).day ?? 0
}

struct PantryItem: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String
    var emoji: String
    var category: String
    var kcal: Int
    var added: Date
    var expiry: Date
    var storage: StorageKind
    /// Сколько штук/упаковок в этой партии (v9; в старых сохранениях нет → 1)
    var qty: Int = 1
    /// Остатки приготовленного блюда (v27): name — рецепт, qty — порции. В старых сохранениях нет → false.
    var leftover: Bool = false
    /// Когда открыли упаковку (v28): срок сокращён до «после вскрытия». В старых сохранениях нет → nil.
    var opened: Date? = nil

    var food: Food { FoodDB.shared.byName[name] ?? Food(emoji: emoji, name: name, kcal: kcal, category: category, shelf: 7) }
    var daysLeft: Int { daysBetween(Date(), expiry) }
    var shelf: Int { max(1, daysBetween(added, expiry)) }
    var fresh: Double { min(1, max(0, Double(daysLeft) / Double(shelf))) }
    var status: String {
        if daysLeft < 0 { return L("Expired {0} ago", Lp(-daysLeft, "day|days")) }
        if daysLeft == 0 { return L("Use today!") }
        if daysLeft == 1 { return L("Expires tomorrow") }
        return L("{0} left", Lp(daysLeft, "day|days"))
    }
}

extension PantryItem {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decodeIfPresent(UUID.self, forKey: .id)) ?? UUID()
        name = try c.decode(String.self, forKey: .name)
        emoji = (try? c.decodeIfPresent(String.self, forKey: .emoji)) ?? "🍽️"
        category = (try? c.decodeIfPresent(String.self, forKey: .category)) ?? "Pantry"
        kcal = (try? c.decodeIfPresent(Int.self, forKey: .kcal)) ?? 0
        added = (try? c.decodeIfPresent(Date.self, forKey: .added)) ?? Date()
        expiry = (try? c.decodeIfPresent(Date.self, forKey: .expiry)) ?? added
        storage = (try? c.decodeIfPresent(StorageKind.self, forKey: .storage)) ?? .fridge
        qty = max(1, (try? c.decodeIfPresent(Int.self, forKey: .qty)) ?? 1)
        leftover = (try? c.decodeIfPresent(Bool.self, forKey: .leftover)) ?? false
        opened = try? c.decodeIfPresent(Date.self, forKey: .opened)
    }

    var isLeftover: Bool { leftover }

    /// Ключ строки в холодильнике: одинаковый продукт в одном месте хранения складывается
    /// (остатки «Chicken Curry» не смешиваются с купленным готовым карри).
    /// Открытая упаковка — отдельная строка: у неё свой, короткий срок.
    var groupKey: String { "\(name)|\(storage.rawValue)\(leftover ? "|leftover" : "")\(opened != nil ? "|opened" : "")" }
}

/// Одна строка холодильника: «🥚 Eggs ×3» — все партии одного продукта в одном месте.
/// Партии отсортированы от самой старой (ближайший срок) к новой; действия списывают сначала старую.
struct PantryGroup: Identifiable, Hashable {
    let batches: [PantryItem]
    var id: String { first.groupKey }
    var first: PantryItem { batches[0] }
    var name: String { first.name }
    var emoji: String { first.emoji }
    var category: String { first.category }
    var kcal: Int { first.kcal }
    var storage: StorageKind { first.storage }
    var expiry: Date { first.expiry }
    var food: Food { first.food }
    var qty: Int { batches.reduce(0) { $0 + $1.qty } }
    var daysLeft: Int { first.daysLeft }
    var fresh: Double { first.fresh }
    var status: String { first.status }
    var title: String { qty > 1 ? "\(N(name)) ×\(qty)" : N(name) }
    var isLeftover: Bool { first.isLeftover }
    var opened: Date? { first.opened }
    /// «Съел» по умолчанию: 100 г продукта или одна порция остатков
    var defaultGrams: Int { isLeftover ? (FoodDB.shared.recipeByName[name]?.portionGrams ?? 100) : 100 }

    static func make(_ items: [PantryItem]) -> [PantryGroup] {
        var order: [String] = []
        var map: [String: [PantryItem]] = [:]
        for p in items {
            if map[p.groupKey] == nil { order.append(p.groupKey) }
            map[p.groupKey, default: []].append(p)
        }
        return order.map { PantryGroup(batches: map[$0]!.sorted { $0.expiry < $1.expiry }) }
    }
}

struct LogEntry: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var emoji: String
    var name: String
    var kcal: Int
    var date: Date = Date()
}

/// Сообщение в чате с Нутриком. `recipe` — название рецепта, который можно открыть из ответа.
struct ChatMessage: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var text: String
    var fromUser: Bool
    var recipe: String? = nil
    var date: Date = Date()
    /// Ответ от онлайн-ИИ (nil в старых сохранениях = офлайн)
    var ai: Bool? = nil
}

struct WeightEntry: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var date: Date
    var kg: Double
}

/// Событие для экрана Eco Impact (по датам): съел, спас, заморозил, поделился, выбросил.
enum EcoKind: String, Codable { case eaten, rescued, frozen, shared, wasted }

/// Действие для недельных заданий: kind — «cook», «buy», «leftover» (строка: незнакомые значения просто не считаются).
struct ActEvent: Codable, Hashable {
    var kind: String
    var n: Int = 1
    var date: Date = Date()
}

struct EcoEvent: Codable, Hashable {
    var kind: EcoKind
    var money: Double
    var date: Date = Date()
}

struct DayValue: Identifiable {
    let day: Date
    let value: Int
    var id: Date { day }
}

struct WeekEco: Identifiable {
    let week: Date
    let saved: Int
    let wasted: Int
    var id: Date { week }
}

struct NamedCount: Identifiable {
    let name: String
    let count: Int
    var id: String { name }
}

struct WasteEntry: Codable, Hashable {
    var name: String
    var category: String
    var reason: WasteReason
    var money: Double
    var date: Date = Date()
}

// Все структуры ниже декодируются «мягко»: новые поля в будущих версиях не ломают старые сохранения.

struct Profile: Codable {
    var registered = false
    var tutorialDone = false
    var name = "Friend"
    var email = ""
    var isMan = true
    var age = 20
    var weight = 70.0
    var height = 175.0
    /// Уровень активности: 0 сидячий … 4 очень активный (множитель к BMR)
    var activity = 1
    /// Цель: -1 похудеть, 0 держать вес, 1 набрать
    var goal = 0
    /// Когда начал пользоваться (для «с нами N дней»); у старых сохранений нет — берём самую раннюю запись
    var joined: Date? = nil
    /// Аватар: "" — Нутрик, "initials" — инициалы, иначе эмодзи
    var avatar = ""

    init() {}
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Profile()
        joined = try? c.decodeIfPresent(Date.self, forKey: .joined)
        avatar = (try? c.decodeIfPresent(String.self, forKey: .avatar)) ?? d.avatar
        registered = (try? c.decodeIfPresent(Bool.self, forKey: .registered)) ?? d.registered
        tutorialDone = (try? c.decodeIfPresent(Bool.self, forKey: .tutorialDone)) ?? d.tutorialDone
        name = (try? c.decodeIfPresent(String.self, forKey: .name)) ?? d.name
        email = (try? c.decodeIfPresent(String.self, forKey: .email)) ?? d.email
        isMan = (try? c.decodeIfPresent(Bool.self, forKey: .isMan)) ?? d.isMan
        age = (try? c.decodeIfPresent(Int.self, forKey: .age)) ?? d.age
        weight = (try? c.decodeIfPresent(Double.self, forKey: .weight)) ?? d.weight
        height = (try? c.decodeIfPresent(Double.self, forKey: .height)) ?? d.height
        activity = min(4, max(0, (try? c.decodeIfPresent(Int.self, forKey: .activity)) ?? d.activity))
        goal = min(1, max(-1, (try? c.decodeIfPresent(Int.self, forKey: .goal)) ?? d.goal))
    }

    // Ключи переводов (LK); на экране показывать через L(x)
    static let activityTitles = [LK("🛋️ Sitting most of the day"), LK("🚶 Light (walks, 1–2 workouts/week)"), LK("🏃 Moderate (3–5 workouts/week)"), LK("🏋️ Active (6–7 workouts/week)"), LK("⚡ Very active (sport + physical job)")]
    static let activityShort = [LK("Sitting"), LK("Light"), LK("Moderate"), LK("Active"), LK("Very active")]
    static let activityFactor = [1.2, 1.375, 1.55, 1.725, 1.9]
    static let goalTitles = [-1: LK("Lose"), 0: LK("Keep"), 1: LK("Gain")]

    /// Обмен веществ в покое — формула Миффлина — Сан-Жеора
    var bmr: Int {
        Int((10 * weight + 6.25 * height - 5 * Double(age) + (isMan ? 5 : -161)).rounded())
    }
    /// Сколько нужно, чтобы держать вес (BMR × активность)
    var maintenance: Int { Int((Double(bmr) * Profile.activityFactor[min(4, max(0, activity))]).rounded()) }
    /// Поправка на цель: −400 ккал похудеть, +300 ккал набрать
    var goalAdjust: Int { goal < 0 ? -400 : goal > 0 ? 300 : 0 }
    /// Цель на день (не ниже BMR при похудении)
    var targetCalories: Int { goal < 0 ? max(bmr, maintenance + goalAdjust) : maintenance + goalAdjust }

    /// Индекс массы тела
    var bmi: Double { height > 0 ? weight / pow(height / 100, 2) : 0 }
    var bmiCategory: BMICategory { BMICategory(bmi) }
    /// Здоровый вес для этого роста (ИМТ 18.5–24.9)
    var healthyRange: ClosedRange<Double> {
        let h2 = pow(height / 100, 2)
        return (18.5 * h2)...(24.9 * h2)
    }
}

enum BMICategory: String {
    case under, normal, over, obese
    init(_ bmi: Double) {
        self = bmi < 18.5 ? .under : bmi < 25 ? .normal : bmi < 30 ? .over : .obese
    }
    var key: String {
        switch self {
        case .under: return LK("Underweight")
        case .normal: return LK("Healthy weight")
        case .over: return LK("Overweight")
        case .obese: return LK("Obesity")
        }
    }
    var title: String { L(key) }
    var emoji: String {
        switch self {
        case .under: return "🪶"
        case .normal: return "💚"
        case .over: return "🟠"
        case .obese: return "❤️‍🩹"
        }
    }
}

struct Stats: Codable {
    var consumed = 0, rescued = 0, wasted = 0, cooked = 0, bought = 0, frozen = 0, shared = 0
    /// порций остатков, убранных в холодильник после готовки (v27)
    var leftoversSaved = 0
    var rescuedMoney = 0.0, wastedMoney = 0.0
    var streakStart = Date()

    init() {}
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func i(_ k: CodingKeys) -> Int { (try? c.decodeIfPresent(Int.self, forKey: k)) ?? 0 }
        func m(_ k: CodingKeys) -> Double { (try? c.decodeIfPresent(Double.self, forKey: k)) ?? 0 }
        consumed = i(.consumed); rescued = i(.rescued); wasted = i(.wasted); cooked = i(.cooked)
        bought = i(.bought); frozen = i(.frozen); shared = i(.shared); leftoversSaved = i(.leftoversSaved)
        rescuedMoney = m(.rescuedMoney); wastedMoney = m(.wastedMoney)
        streakStart = (try? c.decodeIfPresent(Date.self, forKey: .streakStart)) ?? Date()
    }
}

struct AppData: Codable {
    var schema = 1
    var profile = Profile()
    var pantry: [PantryItem] = []
    var log: [LogEntry] = []
    var shopping: [String] = []
    var weights: [WeightEntry] = []
    var unlocked: [String] = []
    var dislikes: [String] = []
    var wasteLog: [WasteEntry] = []
    var stats = Stats()
    var events: [EcoEvent] = []
    var notifications = false
    /// Нутрик выбегает и реагирует на действия (съел, выбросил, заморозил…)
    var nutrikBuddy = true
    /// История чата с Нутриком (последние 80 сообщений)
    var chat: [ChatMessage] = []
    /// Какой по счёту рецепт предлагать на «another»
    var suggestIndex = 0
    /// Онлайн-ИИ в чате (Cloudflare Workers AI), можно выключить в Profile
    var smartNutrik = true
    /// Случайный id устройства — только для дневного лимита ИИ на сервере
    var deviceId = UUID().uuidString
    /// Язык интерфейса (en/ru/kk); для старых сохранений — язык системы
    var language: AppLang = AppLang.system
    /// Оформление: светлое (фирменное, по умолчанию), тёмное или как в системе
    var appearance: AppAppearance = .light
    /// Валюта (nil — авто: тенге в Казахстане, иначе доллар)
    var currency: AppCurrency?
    /// Действия для недельных заданий (v32): готовка, покупки по списку, остатки — с датой (последние 300)
    var acts: [ActEvent] = []
    /// Выполненные недельные задания: «2026-46:rescue», «2026-46:all» (v32)
    var questsDone: [String] = []

    init() {}
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schema = (try? c.decodeIfPresent(Int.self, forKey: .schema)) ?? 1
        profile = (try? c.decodeIfPresent(Profile.self, forKey: .profile)) ?? Profile()
        pantry = (try? c.decodeIfPresent([PantryItem].self, forKey: .pantry)) ?? []
        log = (try? c.decodeIfPresent([LogEntry].self, forKey: .log)) ?? []
        shopping = (try? c.decodeIfPresent([String].self, forKey: .shopping)) ?? []
        weights = (try? c.decodeIfPresent([WeightEntry].self, forKey: .weights)) ?? []
        unlocked = (try? c.decodeIfPresent([String].self, forKey: .unlocked)) ?? []
        dislikes = (try? c.decodeIfPresent([String].self, forKey: .dislikes)) ?? []
        wasteLog = (try? c.decodeIfPresent([WasteEntry].self, forKey: .wasteLog)) ?? []
        stats = (try? c.decodeIfPresent(Stats.self, forKey: .stats)) ?? Stats()
        events = (try? c.decodeIfPresent([EcoEvent].self, forKey: .events)) ?? []
        notifications = (try? c.decodeIfPresent(Bool.self, forKey: .notifications)) ?? false
        nutrikBuddy = (try? c.decodeIfPresent(Bool.self, forKey: .nutrikBuddy)) ?? true
        chat = (try? c.decodeIfPresent([ChatMessage].self, forKey: .chat)) ?? []
        suggestIndex = (try? c.decodeIfPresent(Int.self, forKey: .suggestIndex)) ?? 0
        smartNutrik = (try? c.decodeIfPresent(Bool.self, forKey: .smartNutrik)) ?? true
        deviceId = (try? c.decodeIfPresent(String.self, forKey: .deviceId)) ?? UUID().uuidString
        language = (try? c.decodeIfPresent(AppLang.self, forKey: .language)) ?? AppLang.system
        appearance = (try? c.decodeIfPresent(AppAppearance.self, forKey: .appearance)) ?? .light
        currency = try? c.decodeIfPresent(AppCurrency.self, forKey: .currency)
        acts = (try? c.decodeIfPresent([ActEvent].self, forKey: .acts)) ?? []
        questsDone = (try? c.decodeIfPresent([String].self, forKey: .questsDone)) ?? []
    }
}

extension AppData {
    /// Валюта для показа: выбранная или авто по региону/языку
    var effectiveCurrency: AppCurrency { currency ?? AppCurrency.auto(language) }
}

struct Medal: Identifiable {
    let id: String
    let emoji: String
    let title: String
    let desc: String

    static let all: [Medal] = [
        Medal(id: "first", emoji: "🍽️", title: LK("First Bite"), desc: LK("Eat or cook your first product")),
        Medal(id: "rescue", emoji: "🦸", title: LK("Rescuer"), desc: LK("Save 3 products that were about to expire")),
        Medal(id: "chef", emoji: "👨‍🍳", title: LK("Home Chef"), desc: LK("Cook 3 recipes")),
        Medal(id: "fridge", emoji: "🧊", title: LK("Fridge Master"), desc: LK("Have 10 products in your fridge")),
        Medal(id: "streak", emoji: "🌱", title: LK("Zero Waste Week"), desc: LK("7 days without throwing food away")),
        Medal(id: "shop", emoji: "🛒", title: LK("Smart Shopper"), desc: LK("Buy a product from your shopping list")),
        Medal(id: "weight", emoji: "⚖️", title: LK("Weigh-in"), desc: LK("Log your weight 3 times")),
        Medal(id: "planet", emoji: "🌍", title: LK("Planet Hero"), desc: LK("Avoid 2 kg of CO₂ by rescuing food")),
        Medal(id: "freezer", emoji: "❄️", title: LK("Ice Saver"), desc: LK("Freeze 3 products before they spoil")),
        Medal(id: "share", emoji: "🤝", title: LK("Good Neighbor"), desc: LK("Share food with someone instead of binning it")),
        Medal(id: "cleanfridge", emoji: "✨", title: LK("Clean Fridge"), desc: LK("5+ products and nothing expired")),
        Medal(id: "chatty", emoji: "💬", title: LK("Chatterbox"), desc: LK("Ask Nutrik 5 questions")),
        Medal(id: "champion", emoji: "🏆", title: LK("Weekly Champion"), desc: LK("Complete all 3 challenges of a week")),
        Medal(id: "leftovers", emoji: "🥡", title: LK("Leftover Hero"), desc: LK("Save 3 leftover portions for later instead of binning them")),
    ]
}

/// Оформление приложения (Profile → Appearance). Новое поле — мягко: старые сохранения остаются светлыми.
enum AppAppearance: String, CaseIterable, Identifiable, Codable {
    case light, dark, system
    var id: String { rawValue }
    var title: String {
        switch self {
        case .light: return L("Day")
        case .dark: return L("Night")
        case .system: return L("Auto")
        }
    }
    var icon: String {
        switch self {
        case .light: return "sun.max.fill"
        case .dark: return "moon.stars.fill"
        case .system: return "iphone"
        }
    }
    var scheme: ColorScheme? {
        switch self {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }
}

/// Последнее действие, которое можно отменить (плашка «Отменить» над таб-баром).
struct UndoInfo: Equatable, Identifiable {
    let id = UUID()
    let icon: String
    let text: String
}
